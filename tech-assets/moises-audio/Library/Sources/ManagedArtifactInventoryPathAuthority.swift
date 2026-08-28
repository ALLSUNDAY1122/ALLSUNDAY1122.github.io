import Foundation

/// Shared fail-closed filesystem authority for the canonical managed-artifact inventory surfaces.
///
/// This is intentionally a topology guard, not a syscall-atomic capability. It rejects symlink,
/// dangling-link and non-directory ancestors before an inventory operation reaches Foundation I/O.
/// Callers still revalidate leaves immediately around destructive/persistent operations because a
/// hostile concurrent replacement between separate syscalls remains outside this portable proof.
struct Lane2ManagedArtifactInventoryPathAuthority {
    let rootURL: URL
    let recoveryDirectoryName: String
    let fileManager: FileManager

    init(
        rootURL: URL,
        recoveryDirectoryName: String,
        fileManager: FileManager = .default
    ) {
        self.rootURL = rootURL.standardizedFileURL
        self.recoveryDirectoryName = recoveryDirectoryName
        self.fileManager = fileManager
    }

    var boundary: LibraryManagedPathBoundary {
        LibraryManagedPathBoundary(rootURL: rootURL)
    }

    var v1DirectoryURL: URL {
        rootURL
            .appendingPathComponent(recoveryDirectoryName, isDirectory: true)
            .appendingPathComponent("ArtifactInventory", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
    }

    var shardsDirectoryURL: URL {
        v1DirectoryURL.appendingPathComponent("Shards", isDirectory: true)
    }

    var segmentedDirectoryURL: URL {
        v1DirectoryURL.appendingPathComponent("Segmented", isDirectory: true)
    }

    var authoritativeMarkerURL: URL {
        v1DirectoryURL.appendingPathComponent("authoritative", isDirectory: false)
    }

    var cursorURL: URL {
        v1DirectoryURL.appendingPathComponent("cursor.json", isDirectory: false)
    }

    func ensureV1Directory() throws {
        try boundary.ensureDirectory(v1DirectoryURL, fileManager: fileManager)
    }

    @discardableResult
    func requireV1DirectoryIfPresent() throws -> Bool {
        guard try boundary.nodeExists(v1DirectoryURL, fileManager: fileManager) else { return false }
        try boundary.requireDirectory(v1DirectoryURL, fileManager: fileManager)
        return true
    }

    @discardableResult
    func requireDirectoryIfPresent(_ directoryURL: URL) throws -> Bool {
        guard try boundary.nodeExists(directoryURL, fileManager: fileManager) else { return false }
        try boundary.requireDirectory(directoryURL, fileManager: fileManager)
        return true
    }

    func nodeExists(_ url: URL) throws -> Bool {
        try boundary.nodeExists(url, fileManager: fileManager)
    }

    @discardableResult
    func requireRegularFileOrMissing(_ fileURL: URL, within ancestorURL: URL) throws -> Bool {
        try boundary.requireRegularFileOrMissing(
            fileURL,
            within: ancestorURL,
            fileManager: fileManager
        )
    }

    func requireExistingRegularFile(_ fileURL: URL, within ancestorURL: URL) throws {
        try boundary.requireExistingRegularFile(
            fileURL,
            within: ancestorURL,
            fileManager: fileManager
        )
    }

    func managedRootURL(_ rootName: String) -> URL {
        rootURL.appendingPathComponent(rootName, isDirectory: true)
    }

    @discardableResult
    func requireManagedRootIfPresent(_ rootName: String) throws -> Bool {
        let managedRoot = managedRootURL(rootName)
        guard try boundary.nodeExists(managedRoot, fileManager: fileManager) else { return false }
        try boundary.requireDirectory(managedRoot, fileManager: fileManager)
        return true
    }

    /// Returns false only for a genuinely missing managed leaf under a proven-real directory chain.
    /// Symlink/dangling/non-regular leaves and unsafe ancestors throw instead of becoming "missing".
    func requireManagedRegularFileIfPresent(
        _ fileURL: URL,
        managedRootName: String
    ) throws -> Bool {
        let managedRoot = managedRootURL(managedRootName)
        guard try requireManagedRootIfPresent(managedRootName) else { return false }
        guard try boundary.nodeExists(fileURL, fileManager: fileManager) else { return false }
        try boundary.requireExistingRegularFile(
            fileURL,
            within: managedRoot,
            fileManager: fileManager
        )
        return true
    }
}
