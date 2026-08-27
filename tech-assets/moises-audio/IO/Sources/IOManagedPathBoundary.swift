import Foundation

enum IOManagedPathBoundaryFailure: Error, Equatable, Sendable {
    case pathEscapesRoot(String)
    case unsafePath(String)
    case destinationExists(String)
    case fileOperation(String)
}

/// Filesystem boundary guard for app-owned IO paths.
///
/// Lexical containment alone does not prevent an existing path component from being replaced by a
/// symbolic link. This guard validates the configured root and every existing descendant component
/// before managed IO reads, writes, moves, or removals. Missing managed directories are created one
/// component at a time only after their parent has been proven to be a real directory.
///
/// `attributesOfItem(atPath:)` is intentionally used as the existence primitive instead of only
/// `fileExists(atPath:)`: the latter reports false for a dangling symlink, which would otherwise let a
/// hostile broken link masquerade as a safe missing future destination.
struct IOManagedPathBoundary: Sendable {
    let rootURL: URL

    init(rootURL: URL) {
        self.rootURL = rootURL.standardizedFileURL
    }

    func ensureRootDirectory(fileManager: FileManager = .default) throws {
        if let attributes = try attributesIfPresent(rootURL, fileManager: fileManager) {
            try requireDirectoryNode(rootURL, attributes: attributes)
            return
        }
        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        } catch {
            throw IOManagedPathBoundaryFailure.fileOperation(rootURL.path)
        }
        try requireDirectoryNode(rootURL, fileManager: fileManager)
    }

    func ensureDirectory(_ directoryURL: URL, fileManager: FileManager = .default) throws {
        let components = try relativeComponents(for: directoryURL)
        try ensureRootDirectory(fileManager: fileManager)
        var cursor = rootURL
        for component in components {
            cursor.appendPathComponent(component, isDirectory: true)
            if let attributes = try attributesIfPresent(cursor, fileManager: fileManager) {
                try requireDirectoryNode(cursor, attributes: attributes)
                continue
            }
            do {
                try fileManager.createDirectory(at: cursor, withIntermediateDirectories: false)
            } catch {
                throw IOManagedPathBoundaryFailure.fileOperation(cursor.path)
            }
            try requireDirectoryNode(cursor, fileManager: fileManager)
        }
    }

    func requireDirectory(_ directoryURL: URL, fileManager: FileManager = .default) throws {
        let components = try relativeComponents(for: directoryURL)
        try requireDirectoryNode(rootURL, fileManager: fileManager)
        var cursor = rootURL
        for component in components {
            cursor.appendPathComponent(component, isDirectory: true)
            try requireDirectoryNode(cursor, fileManager: fileManager)
        }
    }

    func nodeExists(_ url: URL, fileManager: FileManager = .default) throws -> Bool {
        let candidate = url.standardizedFileURL
        guard candidate == rootURL || isDescendant(candidate, of: rootURL) else {
            throw IOManagedPathBoundaryFailure.pathEscapesRoot(candidate.path)
        }
        return try attributesIfPresent(candidate, fileManager: fileManager) != nil
    }

    /// Validates the parent chain and accepts either a missing leaf or an existing real regular file.
    /// Returns true when a regular file already exists and false when the leaf is genuinely absent.
    @discardableResult
    func requireRegularFileOrMissing(
        _ fileURL: URL,
        within ancestorURL: URL,
        fileManager: FileManager = .default
    ) throws -> Bool {
        let file = fileURL.standardizedFileURL
        let ancestor = ancestorURL.standardizedFileURL
        try requireContained(file, within: ancestor)
        try requireDirectory(file.deletingLastPathComponent(), fileManager: fileManager)
        guard let attributes = try attributesIfPresent(file, fileManager: fileManager) else {
            return false
        }
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw IOManagedPathBoundaryFailure.unsafePath(file.path)
        }
        return true
    }

    func requireExistingRegularFile(
        _ fileURL: URL,
        within ancestorURL: URL,
        fileManager: FileManager = .default
    ) throws {
        let file = fileURL.standardizedFileURL
        let ancestor = ancestorURL.standardizedFileURL
        try requireContained(file, within: ancestor)
        try requireDirectory(file.deletingLastPathComponent(), fileManager: fileManager)
        guard let attributes = try attributesIfPresent(file, fileManager: fileManager),
              attributes[.type] as? FileAttributeType == .typeRegular else {
            throw IOManagedPathBoundaryFailure.unsafePath(file.path)
        }
    }

    func requireSafeDestination(
        _ fileURL: URL,
        within ancestorURL: URL,
        fileManager: FileManager = .default
    ) throws {
        let file = fileURL.standardizedFileURL
        let ancestor = ancestorURL.standardizedFileURL
        try requireContained(file, within: ancestor)
        try requireDirectory(file.deletingLastPathComponent(), fileManager: fileManager)
        if try attributesIfPresent(file, fileManager: fileManager) != nil {
            throw IOManagedPathBoundaryFailure.destinationExists(file.path)
        }
    }

    private func requireContained(_ file: URL, within ancestor: URL) throws {
        guard isDescendant(file, of: ancestor),
              isDescendant(ancestor, of: rootURL) || ancestor == rootURL else {
            throw IOManagedPathBoundaryFailure.pathEscapesRoot(file.path)
        }
    }

    private func requireDirectoryNode(_ url: URL, fileManager: FileManager) throws {
        guard let attributes = try attributesIfPresent(url, fileManager: fileManager) else {
            throw IOManagedPathBoundaryFailure.unsafePath(url.path)
        }
        try requireDirectoryNode(url, attributes: attributes)
    }

    private func requireDirectoryNode(
        _ url: URL,
        attributes: [FileAttributeKey: Any]
    ) throws {
        guard attributes[.type] as? FileAttributeType == .typeDirectory else {
            throw IOManagedPathBoundaryFailure.unsafePath(url.path)
        }
    }

    private func attributesIfPresent(
        _ url: URL,
        fileManager: FileManager
    ) throws -> [FileAttributeKey: Any]? {
        do {
            return try fileManager.attributesOfItem(atPath: url.path)
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileNoSuchFileError {
                return nil
            }
            throw IOManagedPathBoundaryFailure.unsafePath(url.path)
        }
    }

    private func relativeComponents(for candidateURL: URL) throws -> [String] {
        let candidate = candidateURL.standardizedFileURL
        if candidate == rootURL { return [] }
        guard isDescendant(candidate, of: rootURL) else {
            throw IOManagedPathBoundaryFailure.pathEscapesRoot(candidate.path)
        }
        let prefix = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        let suffix = String(candidate.path.dropFirst(prefix.count))
        let components = suffix.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw IOManagedPathBoundaryFailure.unsafePath(candidate.path)
        }
        return components
    }

    private func isDescendant(_ candidate: URL, of ancestor: URL) -> Bool {
        let ancestorPath = ancestor.standardizedFileURL.path
        let prefix = ancestorPath.hasSuffix("/") ? ancestorPath : ancestorPath + "/"
        let child = candidate.standardizedFileURL.path
        return child.hasPrefix(prefix) && child.count > prefix.count
    }
}
