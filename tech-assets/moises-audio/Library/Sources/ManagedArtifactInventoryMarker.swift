import Foundation

public struct Lane2ManagedArtifactInventoryShardPreflight: Hashable, Sendable {
    public let checkedShards: Int
    public let largestEncodedBytes: Int
    public let safeForAuthoritativeDecode: Bool

    public init(
        checkedShards: Int,
        largestEncodedBytes: Int,
        safeForAuthoritativeDecode: Bool
    ) {
        self.checkedShards = max(checkedShards, 0)
        self.largestEncodedBytes = max(largestEncodedBytes, 0)
        self.safeForAuthoritativeDecode = safeForAuthoritativeDecode
    }
}

public extension Lane2ManagedArtifactInventory {
    /// AW38 guard for the v1 single-JSON-per-shard layout. This is intentionally a byte cap rather
    /// than an entry-count claim: checking encoded size requires only metadata syscalls and occurs
    /// before JSONDecoder can materialize a pathological shard. A future segmented migration may
    /// remove this compatibility ceiling after it has its own durable crash protocol.
    static let maximumAuthoritativeShardEncodedBytes = 8 * 1024 * 1024

    func authoritativeShardPreflight(
        maximumEncodedBytes: Int = Self.maximumAuthoritativeShardEncodedBytes
    ) -> Lane2ManagedArtifactInventoryShardPreflight {
        let effectiveMaximum = max(maximumEncodedBytes, 1)
        let authority = Lane2ManagedArtifactInventoryPathAuthority(
            rootURL: rootURL,
            recoveryDirectoryName: recoveryDirectoryName,
            fileManager: inventoryFileManager
        )
        let shards = authority.shardsDirectoryURL

        do {
            guard try authority.requireDirectoryIfPresent(shards) else {
                return Lane2ManagedArtifactInventoryShardPreflight(
                    checkedShards: 0,
                    largestEncodedBytes: 0,
                    safeForAuthoritativeDecode: true
                )
            }

            let entries = try inventoryFileManager.contentsOfDirectory(
                at: shards,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            guard entries.count <= Self.shardCount else {
                return Lane2ManagedArtifactInventoryShardPreflight(
                    checkedShards: entries.count,
                    largestEncodedBytes: 0,
                    safeForAuthoritativeDecode: false
                )
            }

            var largest = 0
            for url in entries {
                let stem = url.deletingPathExtension().lastPathComponent
                guard url.pathExtension == "json",
                      stem.count == 2,
                      let index = Int(stem, radix: 16),
                      (0..<Self.shardCount).contains(index) else {
                    return Lane2ManagedArtifactInventoryShardPreflight(
                        checkedShards: entries.count,
                        largestEncodedBytes: largest,
                        safeForAuthoritativeDecode: false
                    )
                }
                try authority.requireExistingRegularFile(url, within: shards)
                let values = try url.resourceValues(
                    forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
                )
                guard values.isRegularFile == true, values.isSymbolicLink != true else {
                    return Lane2ManagedArtifactInventoryShardPreflight(
                        checkedShards: entries.count,
                        largestEncodedBytes: largest,
                        safeForAuthoritativeDecode: false
                    )
                }
                let bytes = max(values.fileSize ?? 0, 0)
                largest = max(largest, bytes)
                guard bytes > 0, bytes <= effectiveMaximum else {
                    return Lane2ManagedArtifactInventoryShardPreflight(
                        checkedShards: entries.count,
                        largestEncodedBytes: largest,
                        safeForAuthoritativeDecode: false
                    )
                }
            }
            return Lane2ManagedArtifactInventoryShardPreflight(
                checkedShards: entries.count,
                largestEncodedBytes: largest,
                safeForAuthoritativeDecode: true
            )
        } catch {
            return Lane2ManagedArtifactInventoryShardPreflight(
                checkedShards: 0,
                largestEncodedBytes: 0,
                safeForAuthoritativeDecode: false
            )
        }
    }

    var hasValidAuthoritativeMarker: Bool {
        let authority = Lane2ManagedArtifactInventoryPathAuthority(
            rootURL: rootURL,
            recoveryDirectoryName: recoveryDirectoryName,
            fileManager: inventoryFileManager
        )
        let marker = authority.authoritativeMarkerURL
        let descriptorIO = Lane2LibraryDescriptorRelativeIO(rootURL: rootURL)
        do {
            guard try authority.nodeExists(marker) else { return false }
            try authority.requireExistingRegularFile(marker, within: authority.v1DirectoryURL)
            let data = try descriptorIO.readRegularFile(at: marker, maximumBytes: 64)
            guard data == Data("lane2-managed-artifact-inventory-v1\n".utf8) else { return false }
            return authoritativeShardPreflight().safeForAuthoritativeDecode
        } catch {
            return false
        }
    }
}
