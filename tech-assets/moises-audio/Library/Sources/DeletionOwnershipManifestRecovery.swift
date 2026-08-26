import Foundation

public struct Lane2DeletionOwnershipManifestRecoveryReport: Hashable, Sendable {
    public let discoveredActiveShards: [Int]
    public let manifestWasPresent: Bool
    public let manifestWasValid: Bool
    public let manifestRewritten: Bool

    public init(
        discoveredActiveShards: [Int],
        manifestWasPresent: Bool,
        manifestWasValid: Bool,
        manifestRewritten: Bool
    ) {
        self.discoveredActiveShards = discoveredActiveShards
        self.manifestWasPresent = manifestWasPresent
        self.manifestWasValid = manifestWasValid
        self.manifestRewritten = manifestRewritten
    }
}

/// AW46 repair path for the tiny deletion-ownership active-shard manifest.
///
/// The record directories are the recoverable source of truth: record publication happens only after
/// the shard has first been made active. Recovery therefore probes the fixed 256-shard namespace,
/// validates at most the first visible record in each existing shard, and atomically rebuilds a
/// missing/corrupt/stale manifest without walking a shard-wide record inventory.
public struct Lane2DeletionOwnershipManifestRecovery: Sendable {
    public static let manifestFilename = ".active-shards-v2.json"
    public static let manifestSchemaVersion = 2

    public let rootURL: URL
    public let recoveryDirectoryName: String

    public init(rootURL: URL, recoveryDirectoryName: String = ".LibraryRecovery") {
        self.rootURL = rootURL.standardizedFileURL
        self.recoveryDirectoryName = recoveryDirectoryName
    }

    @discardableResult
    public func reconcile() throws -> Lane2DeletionOwnershipManifestRecoveryReport {
        try ensureLayout()
        let discovered = try discoverActiveShards()
        let manifestState = try readManifestState()

        let shouldRewrite: Bool
        if manifestState.present {
            shouldRewrite = !manifestState.valid || manifestState.shardIndices != discovered
        } else {
            shouldRewrite = !discovered.isEmpty
        }
        if shouldRewrite {
            try writeManifest(discovered)
        }

        return Lane2DeletionOwnershipManifestRecoveryReport(
            discoveredActiveShards: discovered,
            manifestWasPresent: manifestState.present,
            manifestWasValid: manifestState.valid,
            manifestRewritten: shouldRewrite
        )
    }

    private func discoverActiveShards() throws -> [Int] {
        var active: [Int] = []
        active.reserveCapacity(Lane2DeletionOwnershipIndex.shardCount)
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]

        for shardIndex in 0..<Lane2DeletionOwnershipIndex.shardCount {
            let directory = shardDirectoryURL(shardIndex)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory) else {
                continue
            }
            let directoryValues = try directory.resourceValues(forKeys: Set(keys))
            guard isDirectory.boolValue,
                  directoryValues.isDirectory == true,
                  directoryValues.isSymbolicLink != true else {
                throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(
                    String(format: "%02x", shardIndex)
                )
            }

            var enumerationFailed = false
            guard let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
                errorHandler: { _, _ in
                    enumerationFailed = true
                    return false
                }
            ) else {
                throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(
                    String(format: "%02x", shardIndex)
                )
            }

            guard let value = enumerator.nextObject() else {
                if enumerationFailed {
                    throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(
                        String(format: "%02x", shardIndex)
                    )
                }
                continue
            }
            guard let recordURL = value as? URL,
                  recordURL.pathExtension == "json" else {
                throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(
                    String(format: "%02x", shardIndex)
                )
            }
            let recordValues = try recordURL.resourceValues(
                forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
            )
            guard recordValues.isRegularFile == true,
                  recordValues.isSymbolicLink != true else {
                throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(recordURL.lastPathComponent)
            }
            let filename = recordURL.deletingPathExtension().lastPathComponent
            guard let projectUUID = UUID(uuidString: filename),
                  filename == projectUUID.uuidString,
                  recordURL.lastPathComponent == projectUUID.uuidString + ".json",
                  Lane2DeletionOwnershipIndex.shardIndex(for: projectUUID) == shardIndex else {
                throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(recordURL.lastPathComponent)
            }
            active.append(shardIndex)
        }
        return active
    }

    private func readManifestState() throws -> (present: Bool, valid: Bool, shardIndices: [Int]) {
        let url = manifestURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return (false, false, [])
        }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(url.lastPathComponent)
        }
        do {
            let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
            let sorted = manifest.shardIndices.sorted()
            let valid = manifest.schemaVersion == Self.manifestSchemaVersion
                && sorted == Array(Set(sorted)).sorted()
                && sorted.allSatisfy { (0..<Lane2DeletionOwnershipIndex.shardCount).contains($0) }
            return (true, valid, valid ? sorted : [])
        } catch {
            return (true, false, [])
        }
    }

    private func writeManifest(_ shardIndices: [Int]) throws {
        let normalized = Array(Set(shardIndices)).sorted()
        guard normalized.allSatisfy({ (0..<Lane2DeletionOwnershipIndex.shardCount).contains($0) }) else {
            throw Lane2DeletionOwnershipIndexFailure.recordCorrupt(Self.manifestFilename)
        }
        let manifest = Manifest(
            schemaVersion: Self.manifestSchemaVersion,
            shardIndices: normalized
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(manifest).write(to: manifestURL, options: [.atomic])
    }

    private func ensureLayout() throws {
        try FileManager.default.createDirectory(
            at: ownershipDirectoryURL,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: shardDirectoryRootURL,
            withIntermediateDirectories: true
        )
    }

    private var ownershipDirectoryURL: URL {
        rootURL
            .appendingPathComponent(recoveryDirectoryName, isDirectory: true)
            .appendingPathComponent("DeleteOwnership", isDirectory: true)
    }

    private var shardDirectoryRootURL: URL {
        ownershipDirectoryURL.appendingPathComponent("Shards", isDirectory: true)
    }

    private var manifestURL: URL {
        ownershipDirectoryURL.appendingPathComponent(Self.manifestFilename, isDirectory: false)
    }

    private func shardDirectoryURL(_ shardIndex: Int) -> URL {
        shardDirectoryRootURL.appendingPathComponent(
            String(format: "%02x", shardIndex),
            isDirectory: true
        )
    }

    private struct Manifest: Codable, Sendable {
        let schemaVersion: Int
        let shardIndices: [Int]
    }
}
