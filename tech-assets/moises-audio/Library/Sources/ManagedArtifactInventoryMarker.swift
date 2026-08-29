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
    /// before JSONDecoder can materialize a pathological shard. Descriptor-pinned enumeration keeps
    /// the shard directory and leaf metadata on one no-follow authority path instead of reopening
    /// each entry through Foundation pathname/resource-value lookups.
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
        let descriptorEnumerator = Lane2ManagedArtifactInventoryDescriptorEnumerator(rootURL: rootURL)

        do {
            guard try authority.requireDirectoryIfPresent(shards) else {
                return Lane2ManagedArtifactInventoryShardPreflight(
                    checkedShards: 0,
                    largestEncodedBytes: 0,
                    safeForAuthoritativeDecode: true
                )
            }

            let entries = try descriptorEnumerator.visibleImmediateEntries(in: shards)
            guard entries.count <= Self.shardCount else {
                return Lane2ManagedArtifactInventoryShardPreflight(
                    checkedShards: entries.count,
                    largestEncodedBytes: 0,
                    safeForAuthoritativeDecode: false
                )
            }

            var largest = 0
            for entry in entries {
                let name = entry.name
                let filename = name as NSString
                let stem = filename.deletingPathExtension
                guard filename.pathExtension == "json",
                      stem.count == 2,
                      let index = Int(stem, radix: 16),
                      (0..<Self.shardCount).contains(index),
                      entry.kind == .regularFile else {
                    return Lane2ManagedArtifactInventoryShardPreflight(
                        checkedShards: entries.count,
                        largestEncodedBytes: largest,
                        safeForAuthoritativeDecode: false
                    )
                }
                largest = max(largest, entry.byteCount)
                guard entry.byteCount > 0, entry.byteCount <= effectiveMaximum else {
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
