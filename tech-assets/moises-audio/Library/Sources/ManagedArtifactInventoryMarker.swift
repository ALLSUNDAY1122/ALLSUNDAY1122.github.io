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
        let shards = rootURL
            .appendingPathComponent(recoveryDirectoryName, isDirectory: true)
            .appendingPathComponent("ArtifactInventory", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("Shards", isDirectory: true)

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: shards.path, isDirectory: &isDirectory) else {
            return Lane2ManagedArtifactInventoryShardPreflight(
                checkedShards: 0,
                largestEncodedBytes: 0,
                safeForAuthoritativeDecode: true
            )
        }
        guard isDirectory.boolValue else {
            return Lane2ManagedArtifactInventoryShardPreflight(
                checkedShards: 0,
                largestEncodedBytes: 0,
                safeForAuthoritativeDecode: false
            )
        }

        do {
            let entries = try FileManager.default.contentsOfDirectory(
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
        let marker = rootURL
            .appendingPathComponent(recoveryDirectoryName, isDirectory: true)
            .appendingPathComponent("ArtifactInventory", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("authoritative", isDirectory: false)
        guard FileManager.default.fileExists(atPath: marker.path) else { return false }
        guard let values = try? marker.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              values.isRegularFile == true,
              values.isSymbolicLink != true,
              let data = try? Data(contentsOf: marker),
              data == Data("lane2-managed-artifact-inventory-v1\n".utf8) else { return false }
        return authoritativeShardPreflight().safeForAuthoritativeDecode
    }
}
