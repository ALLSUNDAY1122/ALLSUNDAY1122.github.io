import Foundation

public struct Lane2ManagedArtifactBoundedMutationMetrics: Hashable, Sendable { public let generationsPublished: Int; public let maximumDecodedSegmentEntries: Int; public let maximumMutationBatchEntries: Int }
public enum Lane2ManagedArtifactBoundedMutationFailure: Error, Equatable, Sendable { case invalidRelativePath(String); case corruptManifest(String); case corruptSegment(String); case verificationFailed(Int) }

public struct Lane2ManagedArtifactSegmentedBoundedMutation: Sendable {
    public static let shardCount = 256, entriesPerSegment = 512, mutationBatchLimit = 256
    public static let managedRootNames = ["Imports", "Stems", "Exports"]
    private struct Manifest: Codable, Equatable, Sendable { let schemaVersion: Int; let shardIndex: Int; let generation: UUID; let segmentCount: Int; let entryCount: Int }
    private struct Segment: Codable, Sendable { let schemaVersion: Int; let shardIndex: Int; let generation: UUID; let segmentIndex: Int; let entries: [Lane2ManagedArtifactRuntimeEntry] }
    public let rootURL: URL; public let recoveryDirectoryName: String; private let fileManager: FileManager
    public init(rootURL: URL, recoveryDirectoryName: String = ".LibraryRecovery", fileManager: FileManager = .default) { self.rootURL = rootURL.standardizedFileURL; self.recoveryDirectoryName = recoveryDirectoryName; self.fileManager = fileManager }

    @discardableResult public func upsertManaged(relativePaths: [String]) throws -> Lane2ManagedArtifactBoundedMutationMetrics {
        var published = 0, maximumDecoded = 0, offset = 0; let deduplicated = Array(Set(relativePaths)).sorted()
        while offset < deduplicated.count {
            let end = min(offset + Self.mutationBatchLimit, deduplicated.count); var grouped: [Int: [Lane2ManagedArtifactRuntimeEntry]] = [:]
            for raw in deduplicated[offset..<end] { let path = try Self.normalize(raw); guard Self.isManaged(path) else { throw Lane2ManagedArtifactBoundedMutationFailure.invalidRelativePath(raw) }; guard let snapshot = try snapshot(path) else { continue }; grouped[Self.shardIndex(path), default: []].append(snapshot) }
            for (shardIndex, updates) in grouped {
                if try loadManifest(shardIndex) == nil { try Lane2ManagedArtifactSegmentedRuntime(rootURL: rootURL, recoveryDirectoryName: recoveryDirectoryName, fileManager: fileManager).upsertManaged(relativePaths: updates.map(\.relativePath)); published += 1; continue }
                maximumDecoded = max(maximumDecoded, try streamRepublish(shardIndex: shardIndex, updates: updates, removals: [])); published += 1
            }
            offset = end
        }
        return .init(generationsPublished: published, maximumDecodedSegmentEntries: maximumDecoded, maximumMutationBatchEntries: min(Self.mutationBatchLimit, deduplicated.count))
    }

    @discardableResult public func removeManaged(relativePaths: [String]) throws -> Lane2ManagedArtifactBoundedMutationMetrics {
        var published = 0, maximumDecoded = 0, offset = 0; let deduplicated = Array(Set(relativePaths)).sorted()
        while offset < deduplicated.count {
            let end = min(offset + Self.mutationBatchLimit, deduplicated.count); var grouped: [Int: Set<String>] = [:]
            for raw in deduplicated[offset..<end] { let path = try Self.normalize(raw); guard Self.isManaged(path) else { continue }; grouped[Self.shardIndex(path), default: []].insert(path) }
            for (shardIndex, removals) in grouped {
                if try loadManifest(shardIndex) == nil { try Lane2ManagedArtifactSegmentedRuntime(rootURL: rootURL, recoveryDirectoryName: recoveryDirectoryName, fileManager: fileManager).removeManaged(relativePaths: Array(removals)); published += 1; continue }
                maximumDecoded = max(maximumDecoded, try streamRepublish(shardIndex: shardIndex, updates: [], removals: removals)); published += 1
            }
            offset = end
        }
        return .init(generationsPublished: published, maximumDecodedSegmentEntries: maximumDecoded, maximumMutationBatchEntries: min(Self.mutationBatchLimit, deduplicated.count))
    }

    private func streamRepublish(shardIndex: Int, updates: [Lane2ManagedArtifactRuntimeEntry], removals: Set<String>) throws -> Int {
        guard let source = try loadManifest(shardIndex) else { throw Lane2ManagedArtifactBoundedMutationFailure.verificationFailed(shardIndex) }
        let updatesByPath = Dictionary(uniqueKeysWithValues: updates.map { ($0.relativePath, $0) }), paths = updatesByPath.keys.sorted(); var updateIndex = 0, buffer: [Lane2ManagedArtifactRuntimeEntry] = []; buffer.reserveCapacity(Self.entriesPerSegment); let generation = UUID()
        do { try boundary.ensureDirectory(segmentedDirectoryURL, fileManager: fileManager) } catch { throw Lane2ManagedArtifactBoundedMutationFailure.corruptManifest(segmentedDirectoryURL.lastPathComponent) }
        var outputSegmentIndex = 0, outputCount = 0, maximumDecoded = 0; var previousPath: String?
        func appendOutput(_ entry: Lane2ManagedArtifactRuntimeEntry) throws { if let previousPath, entry.relativePath <= previousPath { throw Lane2ManagedArtifactBoundedMutationFailure.verificationFailed(shardIndex) }; previousPath = entry.relativePath; buffer.append(entry); outputCount += 1; if buffer.count == Self.entriesPerSegment { try writeSegment(shardIndex: shardIndex, generation: generation, segmentIndex: outputSegmentIndex, entries: buffer); outputSegmentIndex += 1; buffer.removeAll(keepingCapacity: true) } }
        for sourceSegmentIndex in 0..<source.segmentCount {
            let segment = try loadSegment(manifest: source, segmentIndex: sourceSegmentIndex); maximumDecoded = max(maximumDecoded, segment.entries.count)
            for old in segment.entries {
                while updateIndex < paths.count && paths[updateIndex] < old.relativePath { let path = paths[updateIndex]; if !removals.contains(path), let update = updatesByPath[path] { try appendOutput(update) }; updateIndex += 1 }
                if updateIndex < paths.count && paths[updateIndex] == old.relativePath { let path = paths[updateIndex]; if !removals.contains(path), let update = updatesByPath[path] { try appendOutput(update) }; updateIndex += 1 } else if !removals.contains(old.relativePath) { try appendOutput(old) }
            }
        }
        while updateIndex < paths.count { let path = paths[updateIndex]; if !removals.contains(path), let update = updatesByPath[path] { try appendOutput(update) }; updateIndex += 1 }
        if !buffer.isEmpty { try writeSegment(shardIndex: shardIndex, generation: generation, segmentIndex: outputSegmentIndex, entries: buffer); outputSegmentIndex += 1 }
        let manifest = Manifest(schemaVersion: 1, shardIndex: shardIndex, generation: generation, segmentCount: outputSegmentIndex, entryCount: outputCount); var verified = 0
        for index in 0..<manifest.segmentCount { let segment = try loadSegment(manifest: manifest, segmentIndex: index); maximumDecoded = max(maximumDecoded, segment.entries.count); verified += segment.entries.count }
        guard verified == outputCount else { throw Lane2ManagedArtifactBoundedMutationFailure.verificationFailed(shardIndex) }
        let url = manifestURL(shardIndex)
        do { _ = try boundary.requireRegularFileOrMissing(url, within: segmentedDirectoryURL, fileManager: fileManager) } catch { throw Lane2ManagedArtifactBoundedMutationFailure.corruptManifest(url.lastPathComponent) }
        try stableEncoder.encode(manifest).write(to: url, options: [.atomic])
        do { try boundary.requireExistingRegularFile(url, within: segmentedDirectoryURL, fileManager: fileManager) } catch { throw Lane2ManagedArtifactBoundedMutationFailure.corruptManifest(url.lastPathComponent) }
        guard try loadManifest(shardIndex) == manifest else { throw Lane2ManagedArtifactBoundedMutationFailure.verificationFailed(shardIndex) }
        return maximumDecoded
    }

    private func snapshot(_ path: String) throws -> Lane2ManagedArtifactRuntimeEntry? {
        let url = try absoluteURL(path)
        do { guard try boundary.nodeExists(url, fileManager: fileManager) else { return nil }; try boundary.requireExistingRegularFile(url, within: rootURL, fileManager: fileManager); let attributes = try fileManager.attributesOfItem(atPath: url.path); let modified = attributes[.modificationDate] as? Date ?? .distantPast; return .init(relativePath: path, modificationTime: modified.timeIntervalSince1970) }
        catch { throw Lane2ManagedArtifactBoundedMutationFailure.invalidRelativePath(path) }
    }

    private func loadManifest(_ shardIndex: Int) throws -> Manifest? {
        let url = manifestURL(shardIndex)
        do { guard try boundary.nodeExists(url, fileManager: fileManager) else { return nil }; try boundary.requireExistingRegularFile(url, within: segmentedDirectoryURL, fileManager: fileManager) } catch { throw Lane2ManagedArtifactBoundedMutationFailure.corruptManifest(url.lastPathComponent) }
        let manifest: Manifest
        do { manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url)) } catch { throw Lane2ManagedArtifactBoundedMutationFailure.corruptManifest(url.lastPathComponent) }
        guard manifest.schemaVersion == 1, manifest.shardIndex == shardIndex, manifest.entryCount >= 0, manifest.segmentCount == Self.segmentCount(manifest.entryCount) else { throw Lane2ManagedArtifactBoundedMutationFailure.corruptManifest(url.lastPathComponent) }
        return manifest
    }

    private func loadSegment(manifest: Manifest, segmentIndex: Int) throws -> Segment {
        let url = segmentURL(shardIndex: manifest.shardIndex, generation: manifest.generation, segmentIndex: segmentIndex)
        do { try boundary.requireExistingRegularFile(url, within: segmentedDirectoryURL, fileManager: fileManager) } catch { throw Lane2ManagedArtifactBoundedMutationFailure.corruptSegment(url.lastPathComponent) }
        let segment: Segment
        do { segment = try JSONDecoder().decode(Segment.self, from: Data(contentsOf: url)) } catch { throw Lane2ManagedArtifactBoundedMutationFailure.corruptSegment(url.lastPathComponent) }
        guard segment.schemaVersion == 1, segment.shardIndex == manifest.shardIndex, segment.generation == manifest.generation, segment.segmentIndex == segmentIndex, segment.entries.count <= Self.entriesPerSegment else { throw Lane2ManagedArtifactBoundedMutationFailure.corruptSegment(url.lastPathComponent) }
        var previous: String?
        for entry in segment.entries { let path = try Self.normalize(entry.relativePath); guard path == entry.relativePath, Self.isManaged(path), Self.shardIndex(path) == manifest.shardIndex, previous == nil || path > previous! else { throw Lane2ManagedArtifactBoundedMutationFailure.corruptSegment(url.lastPathComponent) }; previous = path }
        return segment
    }

    private func writeSegment(shardIndex: Int, generation: UUID, segmentIndex: Int, entries: [Lane2ManagedArtifactRuntimeEntry]) throws {
        guard entries.count <= Self.entriesPerSegment else { throw Lane2ManagedArtifactBoundedMutationFailure.verificationFailed(shardIndex) }
        let segment = Segment(schemaVersion: 1, shardIndex: shardIndex, generation: generation, segmentIndex: segmentIndex, entries: entries), url = segmentURL(shardIndex: shardIndex, generation: generation, segmentIndex: segmentIndex)
        do { try boundary.requireSafeDestination(url, within: segmentedDirectoryURL, fileManager: fileManager) } catch { throw Lane2ManagedArtifactBoundedMutationFailure.corruptSegment(url.lastPathComponent) }
        try stableEncoder.encode(segment).write(to: url, options: [.atomic])
        do { try boundary.requireExistingRegularFile(url, within: segmentedDirectoryURL, fileManager: fileManager) } catch { throw Lane2ManagedArtifactBoundedMutationFailure.corruptSegment(url.lastPathComponent) }
    }

    private func absoluteURL(_ p: String) throws -> URL { let p = try Self.normalize(p), u = rootURL.appendingPathComponent(p).standardizedFileURL, prefix = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"; guard u.path.hasPrefix(prefix) else { throw Lane2ManagedArtifactBoundedMutationFailure.invalidRelativePath(p) }; return u }
    private var boundary: LibraryManagedPathBoundary { .init(rootURL: rootURL) }
    private var segmentedDirectoryURL: URL { rootURL.appendingPathComponent(recoveryDirectoryName, isDirectory: true).appendingPathComponent("ArtifactInventory", isDirectory: true).appendingPathComponent("v1", isDirectory: true).appendingPathComponent("Segmented", isDirectory: true) }
    private func manifestURL(_ i: Int) -> URL { segmentedDirectoryURL.appendingPathComponent(String(format: "%02x.manifest.json", i)) }
    private func segmentURL(shardIndex: Int, generation: UUID, segmentIndex: Int) -> URL { segmentedDirectoryURL.appendingPathComponent(String(format: "%02x.%@.%04d.json", shardIndex, generation.uuidString, segmentIndex)) }
    private var stableEncoder: JSONEncoder { let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]; return e }
    private static func segmentCount(_ c: Int) -> Int { guard c > 0 else { return 0 }; let q = c / entriesPerSegment; return q + (c % entriesPerSegment == 0 ? 0 : 1) }
    private static func isManaged(_ p: String) -> Bool { p.split(separator: "/").first.map { managedRootNames.contains(String($0)) } ?? false }
    private static func normalize(_ raw: String) throws -> String { let p = raw.replacingOccurrences(of: "\\", with: "/"); guard !p.isEmpty, !p.hasPrefix("/"), !p.contains("\0"), !(p as NSString).isAbsolutePath else { throw Lane2ManagedArtifactBoundedMutationFailure.invalidRelativePath(raw) }; let xs = p.split(separator: "/", omittingEmptySubsequences: false); guard xs.count >= 2, !xs.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else { throw Lane2ManagedArtifactBoundedMutationFailure.invalidRelativePath(raw) }; return xs.joined(separator: "/") }
    private static func shardIndex(_ p: String) -> Int { var h: UInt64 = 14_695_981_039_346_656_037; for b in p.utf8 { h ^= UInt64(b); h &*= 1_099_511_628_211 }; return Int(h % UInt64(shardCount)) }
}
