import Foundation

public struct Lane2ManagedArtifactBoundedMutationMetrics: Hashable, Sendable {
    public let generationsPublished: Int
    public let maximumDecodedSegmentEntries: Int
    public let maximumMutationBatchEntries: Int
}

public enum Lane2ManagedArtifactBoundedMutationFailure: Error, Equatable, Sendable {
    case invalidRelativePath(String)
    case corruptManifest(String)
    case corruptSegment(String)
    case verificationFailed(Int)
}

/// AW44 bounded mutation path for already-segmented managed-artifact shards.
/// Existing committed generations are merged one <=512-entry segment at a time into a new
/// generation. Mutation inputs are processed in <=256-path batches. Legacy v1 fallback remains
/// bounded by the AW38 8 MiB ceiling inside Lane2ManagedArtifactSegmentedRuntime.
public struct Lane2ManagedArtifactSegmentedBoundedMutation: Sendable {
    public static let shardCount = 256
    public static let entriesPerSegment = 512
    public static let mutationBatchLimit = 256
    public static let managedRootNames = ["Imports", "Stems", "Exports"]

    private struct Manifest: Codable, Equatable, Sendable {
        let schemaVersion: Int
        let shardIndex: Int
        let generation: UUID
        let segmentCount: Int
        let entryCount: Int
    }

    private struct Segment: Codable, Sendable {
        let schemaVersion: Int
        let shardIndex: Int
        let generation: UUID
        let segmentIndex: Int
        let entries: [Lane2ManagedArtifactRuntimeEntry]
    }

    public let rootURL: URL
    public let recoveryDirectoryName: String
    private let fileManager: FileManager

    public init(rootURL: URL, recoveryDirectoryName: String = ".LibraryRecovery", fileManager: FileManager = .default) {
        self.rootURL = rootURL.standardizedFileURL
        self.recoveryDirectoryName = recoveryDirectoryName
        self.fileManager = fileManager
    }

    @discardableResult
    public func upsertManaged(relativePaths: [String]) throws -> Lane2ManagedArtifactBoundedMutationMetrics {
        var published = 0
        var maximumDecoded = 0
        var offset = 0
        let deduplicated = Array(Set(relativePaths)).sorted()

        while offset < deduplicated.count {
            let end = min(offset + Self.mutationBatchLimit, deduplicated.count)
            var grouped: [Int: [Lane2ManagedArtifactRuntimeEntry]] = [:]
            for raw in deduplicated[offset..<end] {
                let path = try Self.normalize(raw)
                guard Self.isManaged(path) else {
                    throw Lane2ManagedArtifactBoundedMutationFailure.invalidRelativePath(raw)
                }
                guard let snapshot = try snapshot(path) else { continue }
                grouped[Self.shardIndex(path), default: []].append(snapshot)
            }

            for (shardIndex, updates) in grouped {
                if try loadManifest(shardIndex) == nil {
                    try Lane2ManagedArtifactSegmentedRuntime(
                        rootURL: rootURL,
                        recoveryDirectoryName: recoveryDirectoryName,
                        fileManager: fileManager
                    ).upsertManaged(relativePaths: updates.map(\.relativePath))
                    published += 1
                    continue
                }
                maximumDecoded = max(
                    maximumDecoded,
                    try streamRepublish(shardIndex: shardIndex, updates: updates, removals: [])
                )
                published += 1
            }
            offset = end
        }

        return Lane2ManagedArtifactBoundedMutationMetrics(
            generationsPublished: published,
            maximumDecodedSegmentEntries: maximumDecoded,
            maximumMutationBatchEntries: min(Self.mutationBatchLimit, deduplicated.count)
        )
    }

    @discardableResult
    public func removeManaged(relativePaths: [String]) throws -> Lane2ManagedArtifactBoundedMutationMetrics {
        var published = 0
        var maximumDecoded = 0
        var offset = 0
        let deduplicated = Array(Set(relativePaths)).sorted()

        while offset < deduplicated.count {
            let end = min(offset + Self.mutationBatchLimit, deduplicated.count)
            var grouped: [Int: Set<String>] = [:]
            for raw in deduplicated[offset..<end] {
                let path = try Self.normalize(raw)
                guard Self.isManaged(path) else { continue }
                grouped[Self.shardIndex(path), default: []].insert(path)
            }

            for (shardIndex, removals) in grouped {
                if try loadManifest(shardIndex) == nil {
                    try Lane2ManagedArtifactSegmentedRuntime(
                        rootURL: rootURL,
                        recoveryDirectoryName: recoveryDirectoryName,
                        fileManager: fileManager
                    ).removeManaged(relativePaths: Array(removals))
                    published += 1
                    continue
                }
                maximumDecoded = max(
                    maximumDecoded,
                    try streamRepublish(shardIndex: shardIndex, updates: [], removals: removals)
                )
                published += 1
            }
            offset = end
        }

        return Lane2ManagedArtifactBoundedMutationMetrics(
            generationsPublished: published,
            maximumDecodedSegmentEntries: maximumDecoded,
            maximumMutationBatchEntries: min(Self.mutationBatchLimit, deduplicated.count)
        )
    }

    private func streamRepublish(
        shardIndex: Int,
        updates: [Lane2ManagedArtifactRuntimeEntry],
        removals: Set<String>
    ) throws -> Int {
        guard let source = try loadManifest(shardIndex) else {
            throw Lane2ManagedArtifactBoundedMutationFailure.verificationFailed(shardIndex)
        }

        let updatesByPath = Dictionary(uniqueKeysWithValues: updates.map { ($0.relativePath, $0) })
        let orderedUpdatePaths = updatesByPath.keys.sorted()
        var updateIndex = 0
        var outputBuffer: [Lane2ManagedArtifactRuntimeEntry] = []
        outputBuffer.reserveCapacity(Self.entriesPerSegment)
        let generation = UUID()
        try fileManager.createDirectory(at: segmentedDirectoryURL, withIntermediateDirectories: true)

        var outputSegmentIndex = 0
        var outputCount = 0
        var maximumDecoded = 0
        var previousPath: String?

        func appendOutput(_ entry: Lane2ManagedArtifactRuntimeEntry) throws {
            if let previousPath, entry.relativePath <= previousPath {
                throw Lane2ManagedArtifactBoundedMutationFailure.verificationFailed(shardIndex)
            }
            previousPath = entry.relativePath
            outputBuffer.append(entry)
            outputCount += 1
            if outputBuffer.count == Self.entriesPerSegment {
                try writeSegment(
                    shardIndex: shardIndex,
                    generation: generation,
                    segmentIndex: outputSegmentIndex,
                    entries: outputBuffer
                )
                outputSegmentIndex += 1
                outputBuffer.removeAll(keepingCapacity: true)
            }
        }

        for sourceSegmentIndex in 0..<source.segmentCount {
            let segment = try loadSegment(manifest: source, segmentIndex: sourceSegmentIndex)
            maximumDecoded = max(maximumDecoded, segment.entries.count)

            for old in segment.entries {
                while updateIndex < orderedUpdatePaths.count && orderedUpdatePaths[updateIndex] < old.relativePath {
                    let path = orderedUpdatePaths[updateIndex]
                    if !removals.contains(path), let update = updatesByPath[path] {
                        try appendOutput(update)
                    }
                    updateIndex += 1
                }

                if updateIndex < orderedUpdatePaths.count && orderedUpdatePaths[updateIndex] == old.relativePath {
                    let path = orderedUpdatePaths[updateIndex]
                    if !removals.contains(path), let update = updatesByPath[path] {
                        try appendOutput(update)
                    }
                    updateIndex += 1
                } else if !removals.contains(old.relativePath) {
                    try appendOutput(old)
                }
            }
        }

        while updateIndex < orderedUpdatePaths.count {
            let path = orderedUpdatePaths[updateIndex]
            if !removals.contains(path), let update = updatesByPath[path] {
                try appendOutput(update)
            }
            updateIndex += 1
        }

        if !outputBuffer.isEmpty {
            try writeSegment(
                shardIndex: shardIndex,
                generation: generation,
                segmentIndex: outputSegmentIndex,
                entries: outputBuffer
            )
            outputSegmentIndex += 1
        }

        let manifest = Manifest(
            schemaVersion: 1,
            shardIndex: shardIndex,
            generation: generation,
            segmentCount: outputSegmentIndex,
            entryCount: outputCount
        )

        var verified = 0
        for index in 0..<manifest.segmentCount {
            let segment = try loadSegment(manifest: manifest, segmentIndex: index)
            maximumDecoded = max(maximumDecoded, segment.entries.count)
            verified += segment.entries.count
        }
        guard verified == outputCount else {
            throw Lane2ManagedArtifactBoundedMutationFailure.verificationFailed(shardIndex)
        }

        try stableEncoder.encode(manifest).write(to: manifestURL(shardIndex), options: [.atomic])
        guard try loadManifest(shardIndex) == manifest else {
            throw Lane2ManagedArtifactBoundedMutationFailure.verificationFailed(shardIndex)
        }
        return maximumDecoded
    }

    private func snapshot(_ path: String) throws -> Lane2ManagedArtifactRuntimeEntry? {
        let url = try absoluteURL(path)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let values = try url.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .contentModificationDateKey
        ])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw Lane2ManagedArtifactBoundedMutationFailure.invalidRelativePath(path)
        }
        return Lane2ManagedArtifactRuntimeEntry(
            relativePath: path,
            modificationTime: (values.contentModificationDate ?? .distantPast).timeIntervalSince1970
        )
    }

    private func loadManifest(_ shardIndex: Int) throws -> Manifest? {
        let url = manifestURL(shardIndex)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw Lane2ManagedArtifactBoundedMutationFailure.corruptManifest(url.lastPathComponent)
        }
        let manifest: Manifest
        do {
            manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
        } catch {
            throw Lane2ManagedArtifactBoundedMutationFailure.corruptManifest(url.lastPathComponent)
        }
        guard manifest.schemaVersion == 1,
              manifest.shardIndex == shardIndex,
              manifest.entryCount >= 0,
              manifest.segmentCount == Self.segmentCount(manifest.entryCount) else {
            throw Lane2ManagedArtifactBoundedMutationFailure.corruptManifest(url.lastPathComponent)
        }
        return manifest
    }

    private func loadSegment(manifest: Manifest, segmentIndex: Int) throws -> Segment {
        let url = segmentURL(
            shardIndex: manifest.shardIndex,
            generation: manifest.generation,
            segmentIndex: segmentIndex
        )
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw Lane2ManagedArtifactBoundedMutationFailure.corruptSegment(url.lastPathComponent)
        }
        let segment: Segment
        do {
            segment = try JSONDecoder().decode(Segment.self, from: Data(contentsOf: url))
        } catch {
            throw Lane2ManagedArtifactBoundedMutationFailure.corruptSegment(url.lastPathComponent)
        }
        guard segment.schemaVersion == 1,
              segment.shardIndex == manifest.shardIndex,
              segment.generation == manifest.generation,
              segment.segmentIndex == segmentIndex,
              segment.entries.count <= Self.entriesPerSegment else {
            throw Lane2ManagedArtifactBoundedMutationFailure.corruptSegment(url.lastPathComponent)
        }

        var previous: String?
        for entry in segment.entries {
            let path = try Self.normalize(entry.relativePath)
            guard path == entry.relativePath,
                  Self.isManaged(path),
                  Self.shardIndex(path) == manifest.shardIndex,
                  previous == nil || path > previous! else {
                throw Lane2ManagedArtifactBoundedMutationFailure.corruptSegment(url.lastPathComponent)
            }
            previous = path
        }
        return segment
    }

    private func writeSegment(
        shardIndex: Int,
        generation: UUID,
        segmentIndex: Int,
        entries: [Lane2ManagedArtifactRuntimeEntry]
    ) throws {
        guard entries.count <= Self.entriesPerSegment else {
            throw Lane2ManagedArtifactBoundedMutationFailure.verificationFailed(shardIndex)
        }
        let segment = Segment(
            schemaVersion: 1,
            shardIndex: shardIndex,
            generation: generation,
            segmentIndex: segmentIndex,
            entries: entries
        )
        try stableEncoder.encode(segment).write(
            to: segmentURL(shardIndex: shardIndex, generation: generation, segmentIndex: segmentIndex),
            options: [.atomic]
        )
    }

    private func absoluteURL(_ relativePath: String) throws -> URL {
        let path = try Self.normalize(relativePath)
        let url = rootURL.appendingPathComponent(path).standardizedFileURL
        let prefix = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        guard url.path.hasPrefix(prefix) else {
            throw Lane2ManagedArtifactBoundedMutationFailure.invalidRelativePath(relativePath)
        }
        return url
    }

    private var segmentedDirectoryURL: URL {
        rootURL
            .appendingPathComponent(recoveryDirectoryName, isDirectory: true)
            .appendingPathComponent("ArtifactInventory", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("Segmented", isDirectory: true)
    }

    private func manifestURL(_ index: Int) -> URL {
        segmentedDirectoryURL.appendingPathComponent(String(format: "%02x.manifest.json", index))
    }

    private func segmentURL(shardIndex: Int, generation: UUID, segmentIndex: Int) -> URL {
        segmentedDirectoryURL.appendingPathComponent(
            String(format: "%02x.%@.%04d.json", shardIndex, generation.uuidString, segmentIndex)
        )
    }

    private var stableEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static func segmentCount(_ count: Int) -> Int {
        count == 0 ? 0 : (count + entriesPerSegment - 1) / entriesPerSegment
    }

    private static func isManaged(_ path: String) -> Bool {
        path.split(separator: "/").first.map { managedRootNames.contains(String($0)) } ?? false
    }

    private static func normalize(_ raw: String) throws -> String {
        let path = raw.replacingOccurrences(of: "\\", with: "/")
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.contains("\0"),
              !(path as NSString).isAbsolutePath else {
            throw Lane2ManagedArtifactBoundedMutationFailure.invalidRelativePath(raw)
        }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count >= 2,
              !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
            throw Lane2ManagedArtifactBoundedMutationFailure.invalidRelativePath(raw)
        }
        return parts.joined(separator: "/")
    }

    private static func shardIndex(_ path: String) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in path.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(shardCount))
    }
}
