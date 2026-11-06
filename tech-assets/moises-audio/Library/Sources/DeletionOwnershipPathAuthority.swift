import Foundation

/// Fail-closed topology authority for deletion-ownership recovery metadata.
///
/// This guard intentionally reuses `LibraryManagedPathBoundary`: it distinguishes genuinely missing
/// nodes from symlink/dangling/non-directory topology and validates every ancestor under the configured
/// Library root before callers reach Foundation I/O. It is not a descriptor-relative capability;
/// same-path replacement between separate validation and I/O syscalls remains outside this proof.
struct Lane2DeletionOwnershipPathAuthority {
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

    var ownershipDirectoryURL: URL {
        rootURL
            .appendingPathComponent(recoveryDirectoryName, isDirectory: true)
            .appendingPathComponent("DeleteOwnership", isDirectory: true)
    }

    var shardDirectoryRootURL: URL {
        ownershipDirectoryURL.appendingPathComponent("Shards", isDirectory: true)
    }

    func shardDirectoryURL(_ shardIndex: Int) -> URL {
        shardDirectoryRootURL.appendingPathComponent(
            String(format: "%02x", shardIndex),
            isDirectory: true
        )
    }

    func ensureLayout() throws {
        do {
            try boundary.ensureDirectory(shardDirectoryRootURL, fileManager: fileManager)
        } catch {
            throw corrupt("DeleteOwnership")
        }
    }

    @discardableResult
    func requireOwnershipDirectoryIfPresent() throws -> Bool {
        try requireDirectoryIfPresent(ownershipDirectoryURL, label: "DeleteOwnership")
    }

    @discardableResult
    func requireShardRootIfPresent() throws -> Bool {
        try requireDirectoryIfPresent(shardDirectoryRootURL, label: "Shards")
    }

    @discardableResult
    func requireShardDirectoryIfPresent(_ shardIndex: Int) throws -> Bool {
        guard try requireShardRootIfPresent() else { return false }
        return try requireDirectoryIfPresent(
            shardDirectoryURL(shardIndex),
            label: String(format: "%02x", shardIndex)
        )
    }

    func ensureShardDirectory(_ shardIndex: Int) throws {
        do {
            try boundary.ensureDirectory(shardDirectoryURL(shardIndex), fileManager: fileManager)
        } catch {
            throw corrupt(String(format: "%02x", shardIndex))
        }
    }

    /// Returns false only for a genuinely missing metadata leaf under a proven-real directory chain.
    /// Existing symlink/dangling/non-regular leaves fail closed as record corruption.
    @discardableResult
    func requireRegularFileOrMissing(
        _ fileURL: URL,
        within ancestorURL: URL,
        label: String? = nil
    ) throws -> Bool {
        do {
            return try boundary.requireRegularFileOrMissing(
                fileURL,
                within: ancestorURL,
                fileManager: fileManager
            )
        } catch {
            throw corrupt(label ?? fileURL.lastPathComponent)
        }
    }

    func requireExistingRegularFile(
        _ fileURL: URL,
        within ancestorURL: URL,
        label: String? = nil
    ) throws {
        do {
            try boundary.requireExistingRegularFile(
                fileURL,
                within: ancestorURL,
                fileManager: fileManager
            )
        } catch {
            throw corrupt(label ?? fileURL.lastPathComponent)
        }
    }

    func recordExists(_ fileURL: URL, shardIndex: Int? = nil) throws -> Bool {
        if let shardIndex {
            guard try requireShardDirectoryIfPresent(shardIndex) else { return false }
            return try requireRegularFileOrMissing(
                fileURL,
                within: shardDirectoryURL(shardIndex)
            )
        }
        guard try requireOwnershipDirectoryIfPresent() else { return false }
        return try requireRegularFileOrMissing(fileURL, within: ownershipDirectoryURL)
    }

    func metadataExists(_ fileURL: URL) throws -> Bool {
        guard try requireOwnershipDirectoryIfPresent() else { return false }
        return try requireRegularFileOrMissing(fileURL, within: ownershipDirectoryURL)
    }

    private func requireDirectoryIfPresent(_ url: URL, label: String) throws -> Bool {
        do {
            guard try boundary.nodeExists(url, fileManager: fileManager) else { return false }
            try boundary.requireDirectory(url, fileManager: fileManager)
            return true
        } catch {
            throw corrupt(label)
        }
    }

    private func corrupt(_ label: String) -> Lane2DeletionOwnershipIndexFailure {
        .recordCorrupt(label)
    }
}
