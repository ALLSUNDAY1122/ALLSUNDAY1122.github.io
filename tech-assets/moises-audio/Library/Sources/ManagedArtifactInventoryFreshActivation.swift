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

        let fileManager = inventoryFileManager
        let authority = Lane2ManagedArtifactInventoryPathAuthority(
            rootURL: rootURL,
            recoveryDirectoryName: recoveryDirectoryName,
            fileManager: fileManager
        )
        let descriptorEnumerator = Lane2ManagedArtifactInventoryDescriptorEnumerator(rootURL: rootURL)
        var sawTarget = false

        for rootName in Lane2ManagedArtifactInventory.managedRootNames {
            let managedRoot = authority.managedRootURL(rootName)
            do {
                guard try authority.requireManagedRootIfPresent(rootName) else { continue }
            } catch {
                throw Lane2ManagedArtifactInventoryFailure.unsafeManagedArtifact(rootName)
            }

            let entries: [Lane2ManagedArtifactInventoryDescriptorEnumerator.Entry]
            do {
                entries = try descriptorEnumerator.visibleEntriesRecursively(in: managedRoot)
            } catch {
                // Preserve the existing compatibility-mode fallback for enumeration failures.
                return false
            }

            for entry in entries {
                if entry.kind == .symbolicLink { return false }
                guard entry.kind == .regularFile else { continue }
                let item = try lane2InventoryActivationNormalize(entry.relativePath)
                if item == normalized {
                    sawTarget = true
                    continue
                }
                return false
            }
        }
        guard sawTarget else { return false }
        try markAuthoritativeAfterCompatibilityCensus()
        return true
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
