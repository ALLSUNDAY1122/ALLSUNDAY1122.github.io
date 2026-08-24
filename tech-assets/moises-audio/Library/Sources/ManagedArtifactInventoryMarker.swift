import Foundation

public extension Lane2ManagedArtifactInventory {
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
              let data = try? Data(contentsOf: marker) else { return false }
        return data == Data("lane2-managed-artifact-inventory-v1\n".utf8)
    }
}
