import Foundation

enum IOManagedPathBoundaryFailure: Error, Equatable, Sendable {
    case pathEscapesRoot(String)
    case unsafePath(String)
    case destinationExists(String)
}

/// Filesystem boundary guard for app-owned IO paths.
///
/// Lexical containment alone does not prevent an existing path component from being replaced by a
/// symbolic link. This guard validates the configured root and every existing descendant component
/// before managed IO reads, writes, moves, or removals. Missing managed directories are created one
/// component at a time only after their parent has been proven to be a real directory.
struct IOManagedPathBoundary: Sendable {
    let rootURL: URL

    init(rootURL: URL) {
        self.rootURL = rootURL.standardizedFileURL
    }

    func ensureRootDirectory(fileManager: FileManager = .default) throws {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory) {
            try requireDirectoryNode(rootURL, fileManager: fileManager)
            return
        }
        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        } catch {
            throw IOManagedPathBoundaryFailure.unsafePath(rootURL.path)
        }
        try requireDirectoryNode(rootURL, fileManager: fileManager)
    }

    func ensureDirectory(_ directoryURL: URL, fileManager: FileManager = .default) throws {
        let components = try relativeComponents(for: directoryURL)
        try ensureRootDirectory(fileManager: fileManager)
        var cursor = rootURL
        for component in components {
            cursor.appendPathComponent(component, isDirectory: true)
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: cursor.path, isDirectory: &isDirectory) {
                try requireDirectoryNode(cursor, fileManager: fileManager)
                continue
            }
            do {
                try fileManager.createDirectory(
                    at: cursor,
                    withIntermediateDirectories: false
                )
            } catch {
                throw IOManagedPathBoundaryFailure.unsafePath(cursor.path)
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

    func requireExistingRegularFile(
        _ fileURL: URL,
        within ancestorURL: URL,
        fileManager: FileManager = .default
    ) throws {
        let file = fileURL.standardizedFileURL
        let ancestor = ancestorURL.standardizedFileURL
        guard isDescendant(file, of: ancestor),
              isDescendant(ancestor, of: rootURL) || ancestor == rootURL else {
            throw IOManagedPathBoundaryFailure.pathEscapesRoot(file.path)
        }
        try requireDirectory(file.deletingLastPathComponent(), fileManager: fileManager)
        let values: URLResourceValues
        do {
            values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        } catch {
            throw IOManagedPathBoundaryFailure.unsafePath(file.path)
        }
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
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
        guard isDescendant(file, of: ancestor),
              isDescendant(ancestor, of: rootURL) || ancestor == rootURL else {
            throw IOManagedPathBoundaryFailure.pathEscapesRoot(file.path)
        }
        try requireDirectory(file.deletingLastPathComponent(), fileManager: fileManager)
        if fileManager.fileExists(atPath: file.path) {
            throw IOManagedPathBoundaryFailure.destinationExists(file.path)
        }
    }

    private func requireDirectoryNode(_ url: URL, fileManager: FileManager) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw IOManagedPathBoundaryFailure.unsafePath(url.path)
        }
        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        } catch {
            throw IOManagedPathBoundaryFailure.unsafePath(url.path)
        }
        guard values.isDirectory == true, values.isSymbolicLink != true else {
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
