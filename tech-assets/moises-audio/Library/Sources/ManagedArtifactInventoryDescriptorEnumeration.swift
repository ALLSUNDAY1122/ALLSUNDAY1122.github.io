import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Descriptor-pinned recursive enumeration for managed-artifact activation/preflight surfaces.
///
/// The caller still performs the higher-level managed-root policy check. This walker then pins
/// the repository root, opens each descendant directory with `O_DIRECTORY | O_NOFOLLOW`, and
/// classifies each visible child with `fstatat(..., AT_SYMLINK_NOFOLLOW)`. It therefore does not
/// follow a directory or leaf symlink that appears after the higher-level Foundation check.
///
/// Hidden names are skipped to preserve the existing `.skipsHiddenFiles` inventory semantics.
/// Same-parent replacement by another real directory/file remains outside the exact-inode proof.
struct Lane2ManagedArtifactInventoryDescriptorEnumerator: Sendable {
    enum EntryKind: Hashable, Sendable {
        case regularFile
        case directory
        case symbolicLink
        case other
    }

    struct Entry: Hashable, Sendable {
        let relativePath: String
        let kind: EntryKind
    }

    struct ImmediateEntry: Hashable, Sendable {
        let name: String
        let kind: EntryKind
        let byteCount: Int
    }

    enum Failure: Error, Equatable, Sendable {
        case invalidManagedPath(String)
        case openFailed(String)
        case enumerateFailed(String)
        case statFailed(String)
    }

    let rootURL: URL

    init(rootURL: URL) {
        self.rootURL = rootURL.standardizedFileURL
    }

    func visibleEntriesRecursively(in directoryURL: URL) throws -> [Entry] {
        let relative = try relativeComponents(for: directoryURL)
        return try withPinnedDirectory(relativeComponents: relative) { directoryFD in
            var entries: [Entry] = []
            try appendVisibleEntries(
                directoryFD: directoryFD,
                relativeComponents: relative,
                entries: &entries
            )
            return entries
        }
    }

    /// Enumerates only immediate visible children while the target directory remains descriptor-pinned.
    /// Metadata comes from the same `fstatat(..., AT_SYMLINK_NOFOLLOW)` observation used for type
    /// classification, so callers do not need to reopen each child through a pathname just to learn size.
    func visibleImmediateEntries(in directoryURL: URL) throws -> [ImmediateEntry] {
        let relative = try relativeComponents(for: directoryURL)
        return try withPinnedDirectory(relativeComponents: relative) { directoryFD in
            try readVisibleImmediateEntries(
                directoryFD: directoryFD,
                relativeComponents: relative
            )
        }
    }

    private func appendVisibleEntries(
        directoryFD: Int32,
        relativeComponents: [String],
        entries: inout [Entry]
    ) throws {
        let streamFD = lane2InventoryDup(directoryFD)
        guard streamFD >= 0 else {
            throw Failure.openFailed(relativeComponents.joined(separator: "/"))
        }
        guard let directory = lane2InventoryFDOpenDir(streamFD) else {
            _ = lane2InventoryClose(streamFD)
            throw Failure.enumerateFailed(relativeComponents.joined(separator: "/"))
        }
        defer { _ = lane2InventoryCloseDir(directory) }

        while true {
            errno = 0
            guard let entryPointer = lane2InventoryReadDir(directory) else {
                if errno != 0 {
                    throw Failure.enumerateFailed(relativeComponents.joined(separator: "/"))
                }
                break
            }

            let name = lane2InventoryEntryName(entryPointer.pointee)
            if name == "." || name == ".." || name.hasPrefix(".") {
                continue
            }
            guard isSafePathComponent(name) else {
                throw Failure.invalidManagedPath(name)
            }

            var status = stat()
            let statResult = name.withCString { pointer in
                lane2InventoryFstatAt(directoryFD, pointer, &status, lane2InventoryNoFollowStatFlag)
            }
            guard statResult == 0 else {
                throw Failure.statFailed((relativeComponents + [name]).joined(separator: "/"))
            }

            let pathComponents = relativeComponents + [name]
            let relativePath = pathComponents.joined(separator: "/")
            let fileType = status.st_mode & mode_t(S_IFMT)

            if fileType == mode_t(S_IFDIR) {
                entries.append(Entry(relativePath: relativePath, kind: .directory))
                try withChildDirectory(
                    parentFD: directoryFD,
                    name: name,
                    relativePath: relativePath
                ) { childFD in
                    try appendVisibleEntries(
                        directoryFD: childFD,
                        relativeComponents: pathComponents,
                        entries: &entries
                    )
                }
            } else if fileType == mode_t(S_IFREG) {
                entries.append(Entry(relativePath: relativePath, kind: .regularFile))
            } else if fileType == mode_t(S_IFLNK) {
                entries.append(Entry(relativePath: relativePath, kind: .symbolicLink))
            } else {
                entries.append(Entry(relativePath: relativePath, kind: .other))
            }
        }
    }

    private func readVisibleImmediateEntries(
        directoryFD: Int32,
        relativeComponents: [String]
    ) throws -> [ImmediateEntry] {
        let streamFD = lane2InventoryDup(directoryFD)
        guard streamFD >= 0 else {
            throw Failure.openFailed(relativeComponents.joined(separator: "/"))
        }
        guard let directory = lane2InventoryFDOpenDir(streamFD) else {
            _ = lane2InventoryClose(streamFD)
            throw Failure.enumerateFailed(relativeComponents.joined(separator: "/"))
        }
        defer { _ = lane2InventoryCloseDir(directory) }

        var entries: [ImmediateEntry] = []
        while true {
            errno = 0
            guard let entryPointer = lane2InventoryReadDir(directory) else {
                if errno != 0 {
                    throw Failure.enumerateFailed(relativeComponents.joined(separator: "/"))
                }
                break
            }

            let name = lane2InventoryEntryName(entryPointer.pointee)
            if name == "." || name == ".." || name.hasPrefix(".") {
                continue
            }
            guard isSafePathComponent(name) else {
                throw Failure.invalidManagedPath(name)
            }

            var status = stat()
            let statResult = name.withCString { pointer in
                lane2InventoryFstatAt(directoryFD, pointer, &status, lane2InventoryNoFollowStatFlag)
            }
            let relativePath = (relativeComponents + [name]).joined(separator: "/")
            guard statResult == 0 else {
                throw Failure.statFailed(relativePath)
            }
            guard status.st_size >= 0,
                  let byteCount = Int(exactly: status.st_size) else {
                throw Failure.statFailed(relativePath)
            }
            entries.append(
                ImmediateEntry(
                    name: name,
                    kind: entryKind(for: status),
                    byteCount: byteCount
                )
            )
        }
        return entries
    }

    private func entryKind(for status: stat) -> EntryKind {
        let fileType = status.st_mode & mode_t(S_IFMT)
        if fileType == mode_t(S_IFREG) { return .regularFile }
        if fileType == mode_t(S_IFDIR) { return .directory }
        if fileType == mode_t(S_IFLNK) { return .symbolicLink }
        return .other
    }

    private func withChildDirectory<T>(
        parentFD: Int32,
        name: String,
        relativePath: String,
        _ body: (Int32) throws -> T
    ) throws -> T {
        let childFD = name.withCString { pointer in
            lane2InventoryOpenAt(parentFD, pointer, lane2InventoryDirectoryNoFollowFlags, 0)
        }
        guard childFD >= 0 else { throw Failure.openFailed(relativePath) }
        defer { _ = lane2InventoryClose(childFD) }
        return try body(childFD)
    }

    private func relativeComponents(for url: URL) throws -> [String] {
        let candidate = url.standardizedFileURL
        let rootComponents = rootURL.pathComponents
        let candidateComponents = candidate.pathComponents
        guard candidateComponents.count > rootComponents.count,
              Array(candidateComponents.prefix(rootComponents.count)) == rootComponents else {
            throw Failure.invalidManagedPath(candidate.path)
        }
        let relative = Array(candidateComponents.dropFirst(rootComponents.count))
        guard relative.allSatisfy(isSafePathComponent) else {
            throw Failure.invalidManagedPath(candidate.path)
        }
        return relative
    }

    private func isSafePathComponent(_ component: String) -> Bool {
        !component.isEmpty && component != "." && component != ".." && !component.contains("/")
    }

    private func withPinnedDirectory<T>(
        relativeComponents: [String],
        _ body: (Int32) throws -> T
    ) throws -> T {
        let rootFD = rootURL.path.withCString { pointer in
            lane2InventoryOpen(pointer, lane2InventoryDirectoryNoFollowFlags, 0)
        }
        guard rootFD >= 0 else { throw Failure.openFailed(rootURL.lastPathComponent) }
        var currentFD = rootFD
        defer { _ = lane2InventoryClose(currentFD) }

        for component in relativeComponents {
            let nextFD = component.withCString { pointer in
                lane2InventoryOpenAt(currentFD, pointer, lane2InventoryDirectoryNoFollowFlags, 0)
            }
            guard nextFD >= 0 else { throw Failure.openFailed(component) }
            _ = lane2InventoryClose(currentFD)
            currentFD = nextFD
        }

        return try body(currentFD)
    }
}

private func lane2InventoryEntryName(_ entry: dirent) -> String {
    var copy = entry
    let capacity = MemoryLayout.size(ofValue: copy.d_name)
    return withUnsafePointer(to: &copy.d_name) { pointer in
        pointer.withMemoryRebound(to: CChar.self, capacity: capacity) { namePointer in
            String(cString: namePointer)
        }
    }
}

#if canImport(Darwin)
private typealias Lane2InventoryDirectoryStream = UnsafeMutablePointer<DIR>
private let lane2InventoryDirectoryNoFollowFlags = O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
private let lane2InventoryNoFollowStatFlag = AT_SYMLINK_NOFOLLOW

@inline(__always) private func lane2InventoryOpen(_ path: UnsafePointer<CChar>, _ flags: Int32, _ mode: mode_t) -> Int32 {
    Darwin.open(path, flags, mode)
}
@inline(__always) private func lane2InventoryOpenAt(_ fd: Int32, _ path: UnsafePointer<CChar>, _ flags: Int32, _ mode: mode_t) -> Int32 {
    Darwin.openat(fd, path, flags, mode)
}
@inline(__always) private func lane2InventoryClose(_ fd: Int32) -> Int32 { Darwin.close(fd) }
@inline(__always) private func lane2InventoryDup(_ fd: Int32) -> Int32 { Darwin.dup(fd) }
@inline(__always) private func lane2InventoryFDOpenDir(_ fd: Int32) -> Lane2InventoryDirectoryStream? { Darwin.fdopendir(fd) }
@inline(__always) private func lane2InventoryReadDir(_ directory: Lane2InventoryDirectoryStream) -> UnsafeMutablePointer<dirent>? { Darwin.readdir(directory) }
@inline(__always) private func lane2InventoryCloseDir(_ directory: Lane2InventoryDirectoryStream) -> Int32 { Darwin.closedir(directory) }
@inline(__always) private func lane2InventoryFstatAt(_ fd: Int32, _ path: UnsafePointer<CChar>, _ status: UnsafeMutablePointer<stat>, _ flags: Int32) -> Int32 {
    Darwin.fstatat(fd, path, status, flags)
}
#elseif canImport(Glibc)
private typealias Lane2InventoryDirectoryStream = OpaquePointer
private let lane2InventoryDirectoryNoFollowFlags = O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
private let lane2InventoryNoFollowStatFlag = AT_SYMLINK_NOFOLLOW

@inline(__always) private func lane2InventoryOpen(_ path: UnsafePointer<CChar>, _ flags: Int32, _ mode: mode_t) -> Int32 {
    Glibc.open(path, flags, mode)
}
@inline(__always) private func lane2InventoryOpenAt(_ fd: Int32, _ path: UnsafePointer<CChar>, _ flags: Int32, _ mode: mode_t) -> Int32 {
    Glibc.openat(fd, path, flags, mode)
}
@inline(__always) private func lane2InventoryClose(_ fd: Int32) -> Int32 { Glibc.close(fd) }
@inline(__always) private func lane2InventoryDup(_ fd: Int32) -> Int32 { Glibc.dup(fd) }
@inline(__always) private func lane2InventoryFDOpenDir(_ fd: Int32) -> Lane2InventoryDirectoryStream? { Glibc.fdopendir(fd) }
@inline(__always) private func lane2InventoryReadDir(_ directory: Lane2InventoryDirectoryStream) -> UnsafeMutablePointer<dirent>? { Glibc.readdir(directory) }
@inline(__always) private func lane2InventoryCloseDir(_ directory: Lane2InventoryDirectoryStream) -> Int32 { Glibc.closedir(directory) }
@inline(__always) private func lane2InventoryFstatAt(_ fd: Int32, _ path: UnsafePointer<CChar>, _ status: UnsafeMutablePointer<stat>, _ flags: Int32) -> Int32 {
    Glibc.fstatat(fd, path, status, flags)
}
#endif
