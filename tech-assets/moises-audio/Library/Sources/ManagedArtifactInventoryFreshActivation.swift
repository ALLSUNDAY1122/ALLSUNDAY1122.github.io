import Foundation

public extension Lane2ManagedArtifactInventory {
    /// Called at the first readiness boundary for a managed artifact. It may activate steady-state
    /// inventory mode only when every visible regular managed artifact is exactly this path. Any
    /// second file, symlink or enumeration error leaves the installation in AW28 compatibility mode.
    @discardableResult
    func activateForFirstManagedArtifactIfSafe(relativePath: String) throws -> Bool {
        if hasValidAuthoritativeMarker { return true }
        let normalized = try lane2InventoryActivationNormalize(relativePath)
        guard Lane2ManagedArtifactInventory.managedRootNames.contains(
            String(normalized.split(separator: "/", omittingEmptySubsequences: false)[0])
        ) else { return false }

        let fileManager = FileManager.default
        let boundary = LibraryManagedPathBoundary(rootURL: rootURL)
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey]
        var sawTarget = false
        for rootName in Lane2ManagedArtifactInventory.managedRootNames {
            let managedRoot = rootURL.appendingPathComponent(rootName, isDirectory: true)
            guard try boundary.nodeExists(managedRoot, fileManager: fileManager) else { continue }
            try boundary.requireDirectory(managedRoot, fileManager: fileManager)
            var enumerationFailed = false
            guard let enumerator = fileManager.enumerator(
                at: managedRoot,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in
                    enumerationFailed = true
                    return false
                }
            ) else { return false }

            for case let url as URL in enumerator {
                guard try boundary.nodeExists(url, fileManager: fileManager) else { return false }
                let values = try url.resourceValues(forKeys: keys)
                if values.isSymbolicLink == true { return false }
                guard values.isRegularFile == true else { continue }
                let item = try lane2InventoryActivationRelativePath(for: url)
                if item == normalized {
                    sawTarget = true
                    continue
                }
                return false
            }
            if enumerationFailed { return false }
        }
        guard sawTarget else { return false }
        try markAuthoritativeAfterCompatibilityCensus()
        return true
    }

    private func lane2InventoryActivationRelativePath(for url: URL) throws -> String {
        let standardized = url.standardizedFileURL
        let prefix = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        guard standardized.path.hasPrefix(prefix) else {
            throw Lane2ManagedArtifactInventoryFailure.invalidRelativePath(url.path)
        }
        return try lane2InventoryActivationNormalize(
            String(standardized.path.dropFirst(prefix.count))
        )
    }
}

private func lane2InventoryActivationNormalize(_ relativePath: String) throws -> String {
    let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
    guard !normalized.isEmpty,
          !normalized.hasPrefix("/"),
          !normalized.contains("\0"),
          !(normalized as NSString).isAbsolutePath else {
        throw Lane2ManagedArtifactInventoryFailure.invalidRelativePath(relativePath)
    }
    let parts = normalized.split(separator: "/", omittingEmptySubsequences: false)
    guard parts.count >= 2,
          !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
        throw Lane2ManagedArtifactInventoryFailure.invalidRelativePath(relativePath)
    }
    return parts.joined(separator: "/")
}
