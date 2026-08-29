import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

struct Lane2LibraryDescriptorRelativeRegularFileMetadata: Equatable, Sendable {
    let modificationTimeSince1970: TimeInterval
}

/// Descriptor-relative managed-root I/O used after higher-level path-authority validation.
///
/// This pins the managed root and every descendant directory while the leaf operation is
/// performed. Descendant directories and read leaves are opened with `O_NOFOLLOW`, so a
/// path component swapped to a symlink after Foundation-level validation cannot redirect
/// the operation outside the pinned managed tree.
///
/// This intentionally does not claim exact-inode preservation if an attacker replaces one
/// regular file with another regular file under the same pinned parent directory. Physical
/// APFS/File Provider/protection-class/force-termination behavior remains a separate gate.
struct Lane2LibraryDescriptorRelativeIO: Sendable {
    enum Failure: Error, Equatable, Sendable {
        case invalidManagedPath(String)
        case openFailed(String)
        case notRegularFile(String)
        case fileTooLarge(String)
        case readFailed(String)
        case writeFailed(String)
        case syncFailed(String)
        case renameFailed(String)
        case removeFailed(String)
    }

    let rootURL: URL

    init(rootURL: URL) {
        self.rootURL = rootURL.standardizedFileURL
    }

    /// Reads one regular managed file through a pinned descriptor chain.
    ///
    /// `maximumBytes` is enforced while streaming from the descriptor, rather than via a
    /// separate pathname stat. This keeps oversized-input rejection bounded even if the leaf
    /// grows after higher-level validation.
    func readRegularFile(at url: URL, maximumBytes: Int? = nil) throws -> Data {
        if let maximumBytes, maximumBytes < 0 {
            throw Failure.invalidManagedPath(url.path)
        }
        let relative = try relativeComponents(for: url)
        return try withPinnedParent(relativeComponents: relative) { parentFD, leaf in
            let fd = leaf.withCString { pointer in
                lane2OpenAt(parentFD, pointer, lane2ReadOnlyNoFollowFlags, 0)
            }
            guard fd >= 0 else { throw Failure.openFailed(leaf) }
            defer { _ = lane2Close(fd) }
            try requireRegularFile(fd: fd, label: leaf)

            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 64 * 1024)
            while true {
                let count = buffer.withUnsafeMutableBytes { rawBuffer -> Int in
                    guard let baseAddress = rawBuffer.baseAddress else { return -1 }
                    return lane2Read(fd, baseAddress, rawBuffer.count)
                }
                if count == 0 { break }
                guard count > 0 else {
                    if errno == EINTR { continue }
                    throw Failure.readFailed(leaf)
                }
                if let maximumBytes {
                    guard data.count <= maximumBytes,
                          count <= maximumBytes - data.count else {
                        throw Failure.fileTooLarge(leaf)
                    }
                }
                data.append(contentsOf: buffer.prefix(count))
            }
            return data
        }
    }

    /// Returns metadata from the same `O_NOFOLLOW` regular-file descriptor authority used by
    /// managed reads. Callers can therefore make freshness decisions without re-resolving the
    /// leaf through Foundation pathname metadata APIs.
    ///
    /// This does not bind a later independent open/unlink to the exact inode observed here.
    func regularFileMetadata(at url: URL) throws -> Lane2LibraryDescriptorRelativeRegularFileMetadata {
        let relative = try relativeComponents(for: url)
        return try withPinnedParent(relativeComponents: relative) { parentFD, leaf in
            let fd = leaf.withCString { pointer in
                lane2OpenAt(parentFD, pointer, lane2ReadOnlyNoFollowFlags, 0)
            }
            guard fd >= 0 else { throw Failure.openFailed(leaf) }
            defer { _ = lane2Close(fd) }
            let status = try regularFileStatus(fd: fd, label: leaf)
            return Lane2LibraryDescriptorRelativeRegularFileMetadata(
                modificationTimeSince1970: lane2ModificationTimeSince1970(status)
            )
        }
    }

    func writeRegularFileAtomically(_ data: Data, to url: URL) throws {
        let relative = try relativeComponents(for: url)
        try withPinnedParent(relativeComponents: relative) { parentFD, leaf in
            let temporaryLeaf = ".\(leaf).lane2-tmp-\(UUID().uuidString)"
            let fd = temporaryLeaf.withCString { pointer in
                lane2OpenAt(parentFD, pointer, lane2CreateExclusiveNoFollowFlags, 0o600)
            }
            guard fd >= 0 else { throw Failure.openFailed(temporaryLeaf) }

            var shouldRemoveTemporary = true
            defer {
                _ = lane2Close(fd)
                if shouldRemoveTemporary {
                    _ = temporaryLeaf.withCString { pointer in
                        lane2UnlinkAt(parentFD, pointer, 0)
                    }
                }
            }

            try data.withUnsafeBytes { rawBuffer in
                var offset = 0
                while offset < rawBuffer.count {
                    guard let baseAddress = rawBuffer.baseAddress else { break }
                    let written = lane2Write(
                        fd,
                        baseAddress.advanced(by: offset),
                        rawBuffer.count - offset
                    )
                    guard written > 0 else {
                        if written < 0, errno == EINTR { continue }
                        throw Failure.writeFailed(leaf)
                    }
                    offset += written
                }
            }

            guard lane2Fsync(fd) == 0 else { throw Failure.syncFailed(leaf) }
            let renameResult = temporaryLeaf.withCString { temporaryPointer in
                leaf.withCString { leafPointer in
                    lane2RenameAt(parentFD, temporaryPointer, parentFD, leafPointer)
                }
            }
            guard renameResult == 0 else { throw Failure.renameFailed(leaf) }
            shouldRemoveTemporary = false
            guard lane2Fsync(parentFD) == 0 else { throw Failure.syncFailed(leaf) }
        }
    }

    /// Removes the current directory entry without following a symlink leaf.
    ///
    /// A same-parent regular-file replacement can still change which inode occupies the name;
    /// this API therefore proves no symlink escape, not exact-inode identity preservation.
    func removeLeaf(at url: URL) throws {
        let relative = try relativeComponents(for: url)
        try withPinnedParent(relativeComponents: relative) { parentFD, leaf in
            let result = leaf.withCString { pointer in
                lane2UnlinkAt(parentFD, pointer, 0)
            }
            guard result == 0 else { throw Failure.removeFailed(leaf) }
            guard lane2Fsync(parentFD) == 0 else { throw Failure.syncFailed(leaf) }
        }
    }

    /// Removes a leaf only after opening that leaf through the pinned parent with `O_NOFOLLOW`
    /// and verifying that the opened object is a regular file.
    ///
    /// This is the deletion primitive for managed orphan artifacts. A symlink swapped in after
    /// higher-level validation is rejected before unlink, so an external target cannot provide
    /// deletion authority. As with `removeLeaf`, this does not claim exact-inode preservation
    /// against a same-parent regular-file replacement between `openat`/`fstat` and `unlinkat`.
    func removeRegularFile(at url: URL) throws {
        let relative = try relativeComponents(for: url)
        try withPinnedParent(relativeComponents: relative) { parentFD, leaf in
            let fd = leaf.withCString { pointer in
                lane2OpenAt(parentFD, pointer, lane2ReadOnlyNoFollowFlags, 0)
            }
            guard fd >= 0 else { throw Failure.openFailed(leaf) }
            defer { _ = lane2Close(fd) }
            try requireRegularFile(fd: fd, label: leaf)

            let result = leaf.withCString { pointer in
                lane2UnlinkAt(parentFD, pointer, 0)
            }
            guard result == 0 else { throw Failure.removeFailed(leaf) }
            guard lane2Fsync(parentFD) == 0 else { throw Failure.syncFailed(leaf) }
        }
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

    private func withPinnedParent<T>(
        relativeComponents: [String],
        _ body: (Int32, String) throws -> T
    ) throws -> T {
        guard let leaf = relativeComponents.last, relativeComponents.count >= 1 else {
            throw Failure.invalidManagedPath(rootURL.path)
        }

        let rootFD = rootURL.path.withCString { pointer in
            lane2Open(pointer, lane2DirectoryNoFollowFlags, 0)
        }
        guard rootFD >= 0 else { throw Failure.openFailed(rootURL.lastPathComponent) }
        var currentFD = rootFD
        defer { _ = lane2Close(currentFD) }

        for component in relativeComponents.dropLast() {
            let nextFD = component.withCString { pointer in
                lane2OpenAt(currentFD, pointer, lane2DirectoryNoFollowFlags, 0)
            }
            guard nextFD >= 0 else { throw Failure.openFailed(component) }
            _ = lane2Close(currentFD)
            currentFD = nextFD
        }

        return try body(currentFD, leaf)
    }

    private func regularFileStatus(fd: Int32, label: String) throws -> stat {
        var status = stat()
        guard lane2Fstat(fd, &status) == 0 else { throw Failure.openFailed(label) }
        let fileType = status.st_mode & mode_t(S_IFMT)
        guard fileType == mode_t(S_IFREG) else { throw Failure.notRegularFile(label) }
        return status
    }

    private func requireRegularFile(fd: Int32, label: String) throws {
        _ = try regularFileStatus(fd: fd, label: label)
    }
}

#if canImport(Darwin)
private let lane2DirectoryNoFollowFlags = O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
private let lane2ReadOnlyNoFollowFlags = O_RDONLY | O_NOFOLLOW | O_CLOEXEC
private let lane2CreateExclusiveNoFollowFlags = O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC

@inline(__always) private func lane2ModificationTimeSince1970(_ status: stat) -> TimeInterval {
    TimeInterval(status.st_mtimespec.tv_sec) + TimeInterval(status.st_mtimespec.tv_nsec) / 1_000_000_000
}
@inline(__always) private func lane2Open(_ path: UnsafePointer<CChar>, _ flags: Int32, _ mode: mode_t) -> Int32 {
    Darwin.open(path, flags, mode)
}
@inline(__always) private func lane2OpenAt(_ fd: Int32, _ path: UnsafePointer<CChar>, _ flags: Int32, _ mode: mode_t) -> Int32 {
    Darwin.openat(fd, path, flags, mode)
}
@inline(__always) private func lane2Close(_ fd: Int32) -> Int32 { Darwin.close(fd) }
@inline(__always) private func lane2Read(_ fd: Int32, _ buffer: UnsafeMutableRawPointer, _ count: Int) -> Int { Darwin.read(fd, buffer, count) }
@inline(__always) private func lane2Write(_ fd: Int32, _ buffer: UnsafeRawPointer, _ count: Int) -> Int { Darwin.write(fd, buffer, count) }
@inline(__always) private func lane2Fsync(_ fd: Int32) -> Int32 { Darwin.fsync(fd) }
@inline(__always) private func lane2Fstat(_ fd: Int32, _ status: UnsafeMutablePointer<stat>) -> Int32 { Darwin.fstat(fd, status) }
@inline(__always) private func lane2RenameAt(_ oldFD: Int32, _ oldPath: UnsafePointer<CChar>, _ newFD: Int32, _ newPath: UnsafePointer<CChar>) -> Int32 { Darwin.renameat(oldFD, oldPath, newFD, newPath) }
@inline(__always) private func lane2UnlinkAt(_ fd: Int32, _ path: UnsafePointer<CChar>, _ flags: Int32) -> Int32 { Darwin.unlinkat(fd, path, flags) }
#elseif canImport(Glibc)
private let lane2DirectoryNoFollowFlags = O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
private let lane2ReadOnlyNoFollowFlags = O_RDONLY | O_NOFOLLOW | O_CLOEXEC
private let lane2CreateExclusiveNoFollowFlags = O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC

@inline(__always) private func lane2ModificationTimeSince1970(_ status: stat) -> TimeInterval {
    TimeInterval(status.st_mtim.tv_sec) + TimeInterval(status.st_mtim.tv_nsec) / 1_000_000_000
}
@inline(__always) private func lane2Open(_ path: UnsafePointer<CChar>, _ flags: Int32, _ mode: mode_t) -> Int32 {
    Glibc.open(path, flags, mode)
}
@inline(__always) private func lane2OpenAt(_ fd: Int32, _ path: UnsafePointer<CChar>, _ flags: Int32, _ mode: mode_t) -> Int32 {
    Glibc.openat(fd, path, flags, mode)
}
@inline(__always) private func lane2Close(_ fd: Int32) -> Int32 { Glibc.close(fd) }
@inline(__always) private func lane2Read(_ fd: Int32, _ buffer: UnsafeMutableRawPointer, _ count: Int) -> Int { Glibc.read(fd, buffer, count) }
@inline(__always) private func lane2Write(_ fd: Int32, _ buffer: UnsafeRawPointer, _ count: Int) -> Int { Glibc.write(fd, buffer, count) }
@inline(__always) private func lane2Fsync(_ fd: Int32) -> Int32 { Glibc.fsync(fd) }
@inline(__always) private func lane2Fstat(_ fd: Int32, _ status: UnsafeMutablePointer<stat>) -> Int32 { Glibc.fstat(fd, status) }
@inline(__always) private func lane2RenameAt(_ oldFD: Int32, _ oldPath: UnsafePointer<CChar>, _ newFD: Int32, _ newPath: UnsafePointer<CChar>) -> Int32 { Glibc.renameat(oldFD, oldPath, newFD, newPath) }
@inline(__always) private func lane2UnlinkAt(_ fd: Int32, _ path: UnsafePointer<CChar>, _ flags: Int32) -> Int32 { Glibc.unlinkat(fd, path, flags) }
#endif
