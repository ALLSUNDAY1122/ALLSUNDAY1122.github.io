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

private final class Lane2SegmentedBoundedMutationFileManagerHandle: @unchecked Sendable {
    let value: FileManager
    init(_ value: FileManager) { self.value = value }
}

public struct Lane2ManagedArtifactSegmentedBoundedMutation: Sendable {
    public static let shardCount = 256
    public static let entriesPerSegment = 512
    public static let mutationBatchLimit = 256
    public static let managedRootNames = ["Imports", "Stems", "Exports"]

    private static let maximumManifestEncodedBytes = 64 * 1024
    private static let maximumSegmentEncodedBytes = 8 * 1024 * 1024

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
    private let fileManagerHandle: Lane2SegmentedBoundedMutationFileManagerHandle

    public init(
        rootURL: URL,
        recoveryDirectoryName: String = ".LibraryRecovery",
        fileManager: FileManager = .default
    ) {
        self.rootURL = rootURL.standardizedFileURL
        self.recoveryDirectoryName = recoveryDirectoryName
        self.fileManagerHandle = Lane2SegmentedBoundedMutationFileManagerHandle(fileManager)
    }

    private var fileManager: FileManager { fileManagerHandle.value }

    /// Final use-time authority for committed segmented metadata. Higher-level Foundation checks
    /// still validate topology/semantics, while actual manifest/segment reads and publications are
    /// performed relative to a pinned managed-root descriptor chain with O_NOFOLLOW semantics.
    private var descriptorIO: Lane2LibraryDescriptorRelativeIO {
        Lane2LibraryDescriptorRelativeIO(rootURL: rootURL)
    }

    @discardableResult
    public func upsertManaged(relativePaths: [String]) throws -> Lane2ManagedArtifactBoundedMutationMetrics {
        var published = 0
        var maximumDecoded = 0
        var offset = 0
        let dedup = Array(Set(relativePaths)).sorted()

        while offset < dedup.count {
            let end = min(offset + Self.mutationBatchLimit, dedup.count)
            var grouped: [Int: [Lane2ManagedArtifactRuntimeEntry]] = [:]
            for raw in dedup[offset..<end] {
                let path = try Self.normalize(raw)
                guard Self.isManaged(path) else {
                    throw Lane2ManagedArtifactBoundedMutationFailure.invalidRelativePath(raw)
                }
                guard let snapshot = try snapshot(path) else { continue }
                grouped[Self.shardIndex(path), default: []].append(snapshot)
            }

            for (shard, updates) in grouped {
                if try loadManifest(shard) == nil {
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
                    try streamRepublish(shardIndex: shard, updates: updates, removals: [])
                )
                published += 1
            }
            offset = end
        }

        return .init(
            generationsPublished: published,
            maximumDecodedSegmentEntries: maximumDecoded,
            maximumMutationBatchEntries: min(Self.mutationBatchLimit, dedup.count)
        )
    }

    @discardableResult
    public func removeManaged(relativePaths: [String]) throws -> Lane2ManagedArtifactBoundedMutationMetrics {
        var published = 0
        var maximumDecoded = 0
        var offset = 0
        let dedup = Array(Set(relativePaths)).sorted()

        while offset < dedup.count {
            let end = min(offset + Self.mutationBatchLimit, dedup.count)
            var grouped: [Int: Set<String>] = [:]
            for raw in dedup[offset..<end] {
                let path = try Self.normalize(raw)
                guard Self.isManaged(path) else { continue }
                grouped[Self.shardIndex(path), default: []].insert(path)
            }

            for (shard, removals) in grouped {
                if try loadManifest(shard) == nil {
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
                    try streamRepublish(shardIndex: shard, updates: [], removals: removals)
                )
                published += 1
            }
            offset = end
        }

        return .init(
            generationsPublished: published,
            maximumDecodedSegmentEntries: maximumDecoded,
            maximumMutationBatchEntries: min(Self.mutationBatchLimit, dedup.count)
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
        let paths = updatesByPath.keys.sorted()
        var updateIndex = 0
        var buffer: [Lane2ManagedArtifactRuntimeEntry] = []
        buffer.reserveCapacity(Self.entriesPerSegment)
        let generation = UUID()

        do {
            try boundary.ensureDirectory(segmentedDirectoryURL, fileManager: fileManager)
        } catch {
            throw Lane2ManagedArtifactBoundedMutationFailure.corruptManifest(
                segmentedDirectoryURL.lastPathComponent
            )
        }

        var outIndex = 0
        var outCount = 0
        var maxDecoded = 0
        var previous: String?

        func append(_ entry: Lane2ManagedArtifactRuntimeEntry) throws {
            if let previous, entry.relativePath <= previous {
                throw Lane2ManagedArtifactBoundedMutationFailure.verificationFailed(shardIndex)
            }
            previous = entry.relativePath
            buffer.append(entry)
            outCount += 1
            if buffer.count == Self.entriesPerSegment {
                try writeSegment(
                    shardIndex: shardIndex,
                    generation: generation,
                    segmentIndex: outIndex,
                    entries: buffer
                )
                outIndex += 1
                buffer.removeAll(keepingCapacity: true)
            }
        }

        for sourceIndex in 0..<source.segmentCount {
            let segment = try loadSegment(manifest: source, segmentIndex: sourceIndex)
            maxDecoded = max(maxDecoded, segment.entries.count)
            for old in segment.entries {
                while updateIndex < paths.count && paths[updateIndex] < old.relativePath {
                    let path = paths[updateIndex]
                    if !removals.contains(path), let update = updatesByPath[path] {
                        try append(update)
                    }
                    updateIndex += 1
                }

                if updateIndex < paths.count && paths[updateIndex] == old.relativePath {
                    let path = paths[updateIndex]
                    if !removals.contains(path), let update = updatesByPath[path] {
                        try append(update)
                    }
                    updateIndex += 1
                } else if !removals.contains(old.relativePath) {
                    try append(old)
                }
            }
        }

        while updateIndex < paths.count {
            let path = paths[updateIndex]
            if !removals.contains(path), let update = updatesByPath[path] {
                try append(update)
            }
            updateIndex += 1
        }

        if !buffer.isEmpty {
            try writeSegment(
                shardIndex: shardIndex,
                generation: generation,
                segmentIndex: outIndex,
                entries: buffer
            )
            outIndex += 1
        }

        let manifest = Manifest(
            schemaVersion: 1,
            shardIndex: shardIndex,
            generation: generation,
            segmentCount: outIndex,
            entryCount: outCount
        )
        var verified = 0
        for index in 0..<manifest.segmentCount {
            let segment = try loadSegment(manifest: manifest, segmentIndex: index)
            maxDecoded = max(maxDecoded, segment.entries.count)
            verified += segment.entries.count
        }
        guard verified == outCount else {
            throw Lane2ManagedArtifactBoundedMutationFailure.verificationFailed(shardIndex)
        }

        let url = manifestURL(shardIndex)
        do {
            let data = try stableEncoder.encode(manifest)
            try descriptorIO.writeRegularFileAtomically(data, to: url)
        } catch {
            throw Lane2ManagedArtifactBoundedMutationFailure.corruptManifest(url.lastPathComponent)
        }

        guard try loadManifest(shardIndex) == manifest else {
            throw Lane2ManagedArtifactBoundedMutationFailure.verificationFailed(shardIndex)
        }
        return maxDecoded
    }

    private func snapshot(_ path: String) throws -> Lane2ManagedArtifactRuntimeEntry? {
        let url = try absoluteURL(path)
        do {
            guard try boundary.nodeExists(url, fileManager: fileManager) else { return nil }
            try boundary.requireExistingRegularFile(url, within: rootURL, fileManager: fileManager)
            let modificationTime = try descriptorIO.regularFileModificationTime(at: url)
            return .init(relativePath: path, modificationTime: modificationTime)
        } catch {
            throw Lane2ManagedArtifactBoundedMutationFailure.invalidRelativePath(path)
        }
    }

    private func loadManifest(_ shardIndex: Int) throws -> Manifest? {
        let url = manifestURL(shardIndex)
        do {
            guard try boundary.nodeExists(url, fileManager: fileManager) else { return nil }
        } catch {
            throw Lane2ManagedArtifactBoundedMutationFailure.corruptManifest(url.lastPathComponent)
        }

        let data: Data
        do {
            data = try descriptorIO.readRegularFile(
                at: url,
                maximumBytes: Self.maximumManifestEncodedBytes
            )
        } catch {
            throw Lane2ManagedArtifactBoundedMutationFailure.corruptManifest(url.lastPathComponent)
        }

        let manifest: Manifest
        do {
            manifest = try JSONDecoder().decode(Manifest.self, from: data)
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

        let data: Data
        do {
            data = try descriptorIO.readRegularFile(
                at: url,
                maximumBytes: Self.maximumSegmentEncodedBytes
            )
        } catch {
            throw Lane2ManagedArtifactBoundedMutationFailure.corruptSegment(url.lastPathComponent)
        }

        let segment: Segment
        do {
            segment = try JSONDecoder().decode(Segment.self, from: data)
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
        let url = segmentURL(
            shardIndex: shardIndex,
            generation: generation,
            segmentIndex: segmentIndex
        )
        do {
            let data = try stableEncoder.encode(segment)
            try descriptorIO.writeRegularFileAtomically(data, to: url)
        } catch {
            throw Lane2ManagedArtifactBoundedMutationFailure.corruptSegment(url.lastPathComponent)
        }
    }

    private func absoluteURL(_ path: String) throws -> URL {
        let path = try Self.normalize(path)
        let url = rootURL.appendingPathComponent(path).standardizedFileURL
        let prefix = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        guard url.path.hasPrefix(prefix) else {
            throw Lane2ManagedArtifactBoundedMutationFailure.invalidRelativePath(path)
        }
        return url
    }

    private var boundary: LibraryManagedPathBoundary { .init(rootURL: rootURL) }

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
        guard count > 0 else { return 0 }
        let quotient = count / entriesPerSegment
        return quotient + (count % entriesPerSegment == 0 ? 0 : 1)
    }

    private static func isManaged(_ path: String) -> Bool {
        path.split(separator: "/").first.map {
            managedRootNames.contains(String($0))
        } ?? false
    }

    private static func normalize(_ raw: String) throws -> String {
        let path = raw.replacingOccurrences(of: "\\", with: "/")
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.contains("\0"),
              !(path as NSString).isAbsolutePath else {
            throw Lane2ManagedArtifactBoundedMutationFailure.invalidRelativePath(raw)
        }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count >= 2,
              !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
            throw Lane2ManagedArtifactBoundedMutationFailure.invalidRelativePath(raw)
        }
        return components.joined(separator: "/")
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