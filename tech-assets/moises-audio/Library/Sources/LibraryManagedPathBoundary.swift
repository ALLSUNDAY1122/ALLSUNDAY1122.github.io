import Foundation

enum LibraryManagedPathBoundaryFailure: Error, Equatable, Sendable {
    case pathEscapesRoot(String)
    case unsafePath(String)
    case destinationExists(String)
    case fileOperation(String)
}

/// Fail-closed filesystem authority for Library-owned metadata under one configured root.
///
/// This deliberately distinguishes a genuinely missing node from an existing symbolic link,
/// including a dangling link. Directory creation proceeds one component at a time only after the
/// parent chain has been proven to contain real directories. Existing metadata leaves must be real
/// regular files before reads, overwrites, moves, or removals are allowed.
struct LibraryManagedPathBoundary: Sendable {
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
            throw LibraryManagedPathBoundaryFailure.fileOperation(rootURL.path)
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
                throw LibraryManagedPathBoundaryFailure.fileOperation(cursor.path)
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
            throw LibraryManagedPathBoundaryFailure.pathEscapesRoot(candidate.path)
        }
        if candidate == rootURL {
            return try attributesIfPresent(candidate, fileManager: fileManager) != nil
        }

        // A missing leaf is safe only when every existing ancestor from the configured root is a
        // real directory. This prevents a symlinked parent from turning a missing external target
        // into an apparent "missing managed node" compatibility path.
        guard let rootAttributes = try attributesIfPresent(rootURL, fileManager: fileManager) else {
            return false
        }
        try requireDirectoryNode(rootURL, attributes: rootAttributes)

        let components = try relativeComponents(for: candidate)
        var cursor = rootURL
        for component in components.dropLast() {
            cursor.appendPathComponent(component, isDirectory: true)
            guard let attributes = try attributesIfPresent(cursor, fileManager: fileManager) else {
                return false
            }
            try requireDirectoryNode(cursor, attributes: attributes)
        }
        return try attributesIfPresent(candidate, fileManager: fileManager) != nil
    }

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
        try requireRegularFileNode(file, attributes: attributes)
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
        guard let attributes = try attributesIfPresent(file, fileManager: fileManager) else {
            throw LibraryManagedPathBoundaryFailure.unsafePath(file.path)
        }
        try requireRegularFileNode(file, attributes: attributes)
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
            throw LibraryManagedPathBoundaryFailure.destinationExists(file.path)
        }
    }

    private func requireContained(_ file: URL, within ancestor: URL) throws {
        guard isDescendant(file, of: ancestor),
              isDescendant(ancestor, of: rootURL) || ancestor == rootURL else {
            throw LibraryManagedPathBoundaryFailure.pathEscapesRoot(file.path)
        }
    }

    private func requireDirectoryNode(_ url: URL, fileManager: FileManager) throws {
        guard let attributes = try attributesIfPresent(url, fileManager: fileManager) else {
            throw LibraryManagedPathBoundaryFailure.unsafePath(url.path)
        }
        try requireDirectoryNode(url, attributes: attributes)
    }

    private func requireDirectoryNode(
        _ url: URL,
        attributes: [FileAttributeKey: Any]
    ) throws {
        guard attributes[.type] as? FileAttributeType == .typeDirectory else {
            throw LibraryManagedPathBoundaryFailure.unsafePath(url.path)
        }
    }

    private func requireRegularFileNode(
        _ url: URL,
        attributes: [FileAttributeKey: Any]
    ) throws {
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw LibraryManagedPathBoundaryFailure.unsafePath(url.path)
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
            if nsError.domain == NSCocoaErrorDomain,
               nsError.code == NSFileReadNoSuchFileError || nsError.code == NSFileNoSuchFileError {
                return nil
            }
            throw LibraryManagedPathBoundaryFailure.unsafePath(url.path)
        }
    }

    private func relativeComponents(for candidateURL: URL) throws -> [String] {
        let candidate = candidateURL.standardizedFileURL
        if candidate == rootURL { return [] }
        guard isDescendant(candidate, of: rootURL) else {
            throw LibraryManagedPathBoundaryFailure.pathEscapesRoot(candidate.path)
        }
        let prefix = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        let suffix = String(candidate.path.dropFirst(prefix.count))
        let components = suffix.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw LibraryManagedPathBoundaryFailure.unsafePath(candidate.path)
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
