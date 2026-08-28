import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public struct Lane2ManagedArtifactSegmentedRetirementResult: Hashable, Sendable {
    public let shardIndex: Int
    public let examinedDirectoryEntries: Int
    public let removedSegments: Int
    public let scanLimit: Int
    public let removalLimit: Int
    public let reachedScanLimit: Bool
    public let reachedRemovalLimit: Bool

    public var needsAnotherPass: Bool {
        reachedScanLimit || reachedRemovalLimit
    }
}

public enum Lane2ManagedArtifactSegmentedRetirementFailure: Error, Equatable, Sendable {
    case invalidShard(Int)
    case corruptManifest(String)
    case unsafeSegmentedDirectory(String)
    case unsafeCandidate(String)
}

private final class Lane2SegmentedRetirementFileManagerHandle: @unchecked Sendable {
    let value: FileManager
    init(_ value: FileManager) { self.value = value }
}

/// Bounded maintenance for segmented inventory generations that are no longer authoritative.
///
/// The manifest is re-read before each destructive operation so a concurrently published
/// generation is not retired merely because it was absent from the first snapshot. Deletion is
/// descriptor-relative to the pinned managed root and never follows ancestor symlinks.
///
/// The pass is intentionally bounded in both directory entries examined and segment removals.
/// Repeated passes are therefore required for a large backlog. Directory enumeration order is not
/// treated as authority, and malformed/unrecognized names are retained rather than guessed at.
///
/// This does not prove exact-inode preservation if a same-parent regular-file replacement occurs
/// between the descriptor validation and `unlinkat`. Physical APFS/File Provider/protection-class
/// and force-termination behavior remain separate evidence gates.
public struct Lane2ManagedArtifactSegmentedGenerationRetirement: Sendable {
    public static let shardCount = 256
    public static let entriesPerSegment = 512
    public static let defaultScanLimit = 256
    public static let defaultRemovalLimit = 32
    public static let maximumManifestBytes = 64 * 1024

    private struct Manifest: Codable, Sendable {
        let schemaVersion: Int
        let shardIndex: Int
        let generation: UUID
        let segmentCount: Int
        let entryCount: Int
    }

    public let rootURL: URL
    public let recoveryDirectoryName: String
    private let fileManagerHandle: Lane2SegmentedRetirementFileManagerHandle

    public init(
        rootURL: URL,
        recoveryDirectoryName: String = ".LibraryRecovery",
        fileManager: FileManager = .default
    ) {
        self.rootURL = rootURL.standardizedFileURL
        self.recoveryDirectoryName = recoveryDirectoryName
        self.fileManagerHandle = Lane2SegmentedRetirementFileManagerHandle(fileManager)
    }

    private var fileManager: FileManager { fileManagerHandle.value }

    public func retireSupersededSegments(
        shardIndex: Int,
        scanLimit: Int = Self.defaultScanLimit,
        removalLimit: Int = Self.defaultRemovalLimit
    ) throws -> Lane2ManagedArtifactSegmentedRetirementResult {
        guard (0..<Self.shardCount).contains(shardIndex) else {
            throw Lane2ManagedArtifactSegmentedRetirementFailure.invalidShard(shardIndex)
        }
        let effectiveScanLimit = max(scanLimit, 1)
        let effectiveRemovalLimit = max(removalLimit, 1)

        guard let initialManifest = try loadManifest(shardIndex) else {
            return result(
                shardIndex: shardIndex,
                examined: 0,
                removed: 0,
                scanLimit: effectiveScanLimit,
                removalLimit: effectiveRemovalLimit
            )
        }

        do {
            try LibraryManagedPathBoundary(rootURL: rootURL).requireDirectory(
                segmentedDirectoryURL,
                fileManager: fileManager
            )
        } catch {
            throw Lane2ManagedArtifactSegmentedRetirementFailure.unsafeSegmentedDirectory(
                segmentedDirectoryURL.lastPathComponent
            )
        }

        guard let enumerator = fileManager.enumerator(
            at: segmentedDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsSubdirectoryDescendants]
        ) else {
            throw Lane2ManagedArtifactSegmentedRetirementFailure.unsafeSegmentedDirectory(
                segmentedDirectoryURL.lastPathComponent
            )
        }

        var examined = 0
        var removed = 0
        while examined < effectiveScanLimit,
              removed < effectiveRemovalLimit,
              let candidateURL = enumerator.nextObject() as? URL {
            examined += 1
            let candidateName = candidateURL.lastPathComponent
            guard let candidateGeneration = segmentGeneration(
                candidateName,
                shardIndex: shardIndex
            ) else {
                continue
            }

            // Preserve every leaf that names the initially authoritative generation, including
            // unexpected extra indices. A malformed current generation is not maintenance input.
            if candidateGeneration == initialManifest.generation { continue }

            // Revalidate current authority immediately before every unlink. If another publisher
            // made this candidate generation authoritative after enumeration began, retain it.
            guard let liveManifest = try loadManifest(shardIndex) else {
                throw Lane2ManagedArtifactSegmentedRetirementFailure.corruptManifest(
                    manifestURL(shardIndex).lastPathComponent
                )
            }
            if candidateGeneration == liveManifest.generation { continue }

            do {
                let didRemove = try Lane2DescriptorRelativeRegularFileRetirement(
                    rootURL: rootURL
                ).removeRegularFile(at: candidateURL)
                if didRemove { removed += 1 }
            } catch {
                throw Lane2ManagedArtifactSegmentedRetirementFailure.unsafeCandidate(candidateName)
            }
        }

        return result(
            shardIndex: shardIndex,
            examined: examined,
            removed: removed,
            scanLimit: effectiveScanLimit,
            removalLimit: effectiveRemovalLimit
        )
    }

    private func result(
        shardIndex: Int,
        examined: Int,
        removed: Int,
        scanLimit: Int,
        removalLimit: Int
    ) -> Lane2ManagedArtifactSegmentedRetirementResult {
        Lane2ManagedArtifactSegmentedRetirementResult(
            shardIndex: shardIndex,
            examinedDirectoryEntries: examined,
            removedSegments: removed,
            scanLimit: scanLimit,
            removalLimit: removalLimit,
            reachedScanLimit: examined >= scanLimit,
            reachedRemovalLimit: removed >= removalLimit
        )
    }

    private func loadManifest(_ shardIndex: Int) throws -> Manifest? {
        let url = manifestURL(shardIndex)
        do {
            let boundary = LibraryManagedPathBoundary(rootURL: rootURL)
            guard try boundary.nodeExists(url, fileManager: fileManager) else { return nil }
            let data = try Lane2LibraryDescriptorRelativeIO(rootURL: rootURL).readRegularFile(
                at: url,
                maximumBytes: Self.maximumManifestBytes
            )
            let manifest = try JSONDecoder().decode(Manifest.self, from: data)
            guard manifest.schemaVersion == 1,
                  manifest.shardIndex == shardIndex,
                  manifest.entryCount >= 0,
                  manifest.segmentCount >= 0,
                  manifest.segmentCount == Self.segmentCount(for: manifest.entryCount) else {
                throw Lane2ManagedArtifactSegmentedRetirementFailure.corruptManifest(url.lastPathComponent)
            }
            return manifest
        } catch let failure as Lane2ManagedArtifactSegmentedRetirementFailure {
            throw failure
        } catch {
            throw Lane2ManagedArtifactSegmentedRetirementFailure.corruptManifest(url.lastPathComponent)
        }
    }

    private func segmentGeneration(_ name: String, shardIndex: Int) -> UUID? {
        let pieces = name.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count == 4,
              pieces[0] == Substring(String(format: "%02x", shardIndex)),
              pieces[3] == "json",
              pieces[2].count >= 4,
              pieces[2].allSatisfy({ $0.isNumber }),
              Int(pieces[2]) != nil,
              let generation = UUID(uuidString: String(pieces[1])) else {
            return nil
        }
        return generation
    }

    private static func segmentCount(for entryCount: Int) -> Int {
        guard entryCount > 0 else { return 0 }
        return ((entryCount - 1) / entriesPerSegment) + 1
    }

    private var segmentedDirectoryURL: URL {
        rootURL
            .appendingPathComponent(recoveryDirectoryName, isDirectory: true)
            .appendingPathComponent("ArtifactInventory", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("Segmented", isDirectory: true)
    }

    private func manifestURL(_ shardIndex: Int) -> URL {
        segmentedDirectoryURL.appendingPathComponent(
            String(format: "%02x.manifest.json", shardIndex),
            isDirectory: false
        )
    }
}

private struct Lane2DescriptorRelativeRegularFileRetirement: Sendable {
    enum Failure: Error, Sendable {
        case invalidManagedPath
        case openFailed
        case notRegularFile
        case removeFailed
        case syncFailed
    }

    let rootURL: URL

    init(rootURL: URL) {
        self.rootURL = rootURL.standardizedFileURL
    }

    /// Returns false when another cleanup pass removed the leaf first.
    func removeRegularFile(at url: URL) throws -> Bool {
        let relative = try relativeComponents(for: url)
        return try withPinnedParent(relativeComponents: relative) { parentFD, leaf in
            let leafFD = leaf.withCString { pointer in
                lane2RetirementOpenAt(parentFD, pointer, lane2RetirementReadNoFollowFlags, 0)
            }
            if leafFD < 0, errno == ENOENT { return false }
            guard leafFD >= 0 else { throw Failure.openFailed }
            defer { _ = lane2RetirementClose(leafFD) }

            var status = stat()
            guard lane2RetirementFstat(leafFD, &status) == 0 else { throw Failure.openFailed }
            guard status.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else {
                throw Failure.notRegularFile
            }

            let removeResult = leaf.withCString { pointer in
                lane2RetirementUnlinkAt(parentFD, pointer, 0)
            }
            if removeResult != 0, errno == ENOENT { return false }
            guard removeResult == 0 else { throw Failure.removeFailed }
            guard lane2RetirementFsync(parentFD) == 0 else { throw Failure.syncFailed }
            return true
        }
    }

    private func relativeComponents(for url: URL) throws -> [String] {
        let candidate = url.standardizedFileURL
        let rootComponents = rootURL.pathComponents
        let candidateComponents = candidate.pathComponents
        guard candidateComponents.count > rootComponents.count,
              Array(candidateComponents.prefix(rootComponents.count)) == rootComponents else {
            throw Failure.invalidManagedPath
        }
        let relative = Array(candidateComponents.dropFirst(rootComponents.count))
        guard relative.allSatisfy({
            !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("/")
        }) else {
            throw Failure.invalidManagedPath
        }
        return relative
    }

    private func withPinnedParent<T>(
        relativeComponents: [String],
        _ body: (Int32, String) throws -> T
    ) throws -> T {
        guard let leaf = relativeComponents.last else { throw Failure.invalidManagedPath }
        let rootFD = rootURL.path.withCString { pointer in
            lane2RetirementOpen(pointer, lane2RetirementDirectoryNoFollowFlags, 0)
        }
        guard rootFD >= 0 else { throw Failure.openFailed }
        var currentFD = rootFD
        defer { _ = lane2RetirementClose(currentFD) }

        for component in relativeComponents.dropLast() {
            let nextFD = component.withCString { pointer in
                lane2RetirementOpenAt(currentFD, pointer, lane2RetirementDirectoryNoFollowFlags, 0)
            }
            guard nextFD >= 0 else { throw Failure.openFailed }
            _ = lane2RetirementClose(currentFD)
            currentFD = nextFD
        }
        return try body(currentFD, leaf)
    }
}

#if canImport(Darwin)
private let lane2RetirementDirectoryNoFollowFlags = O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
private let lane2RetirementReadNoFollowFlags = O_RDONLY | O_NOFOLLOW | O_CLOEXEC
@inline(__always) private func lane2RetirementOpen(_ path: UnsafePointer<CChar>, _ flags: Int32, _ mode: mode_t) -> Int32 { Darwin.open(path, flags, mode) }
@inline(__always) private func lane2RetirementOpenAt(_ fd: Int32, _ path: UnsafePointer<CChar>, _ flags: Int32, _ mode: mode_t) -> Int32 { Darwin.openat(fd, path, flags, mode) }
@inline(__always) private func lane2RetirementClose(_ fd: Int32) -> Int32 { Darwin.close(fd) }
@inline(__always) private func lane2RetirementFstat(_ fd: Int32, _ status: UnsafeMutablePointer<stat>) -> Int32 { Darwin.fstat(fd, status) }
@inline(__always) private func lane2RetirementFsync(_ fd: Int32) -> Int32 { Darwin.fsync(fd) }
@inline(__always) private func lane2RetirementUnlinkAt(_ fd: Int32, _ path: UnsafePointer<CChar>, _ flags: Int32) -> Int32 { Darwin.unlinkat(fd, path, flags) }
#elseif canImport(Glibc)
private let lane2RetirementDirectoryNoFollowFlags = O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
private let lane2RetirementReadNoFollowFlags = O_RDONLY | O_NOFOLLOW | O_CLOEXEC
@inline(__always) private func lane2RetirementOpen(_ path: UnsafePointer<CChar>, _ flags: Int32, _ mode: mode_t) -> Int32 { Glibc.open(path, flags, mode) }
@inline(__always) private func lane2RetirementOpenAt(_ fd: Int32, _ path: UnsafePointer<CChar>, _ flags: Int32, _ mode: mode_t) -> Int32 { Glibc.openat(fd, path, flags, mode) }
@inline(__always) private func lane2RetirementClose(_ fd: Int32) -> Int32 { Glibc.close(fd) }
@inline(__always) private func lane2RetirementFstat(_ fd: Int32, _ status: UnsafeMutablePointer<stat>) -> Int32 { Glibc.fstat(fd, status) }
@inline(__always) private func lane2RetirementFsync(_ fd: Int32) -> Int32 { Glibc.fsync(fd) }
@inline(__always) private func lane2RetirementUnlinkAt(_ fd: Int32, _ path: UnsafePointer<CChar>, _ flags: Int32) -> Int32 { Glibc.unlinkat(fd, path, flags) }
#endif
