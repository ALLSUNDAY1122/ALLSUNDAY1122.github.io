import Foundation

public struct Lane2OrphanSweepBudget: Hashable, Sendable {
    public static let defaultCandidatesPerPass = 128
    public let candidatesPerPass: Int

    public init(candidatesPerPass: Int = Self.defaultCandidatesPerPass) {
        self.candidatesPerPass = max(candidatesPerPass, 1)
    }
}

public struct Lane2OrphanSweepCandidate: Hashable, Sendable {
    public let relativePath: String
    public let contentModificationDate: Date

    public init(relativePath: String, contentModificationDate: Date) {
        self.relativePath = relativePath
        self.contentModificationDate = contentModificationDate
    }
}

public struct Lane2OrphanSweepCandidateSlice: Hashable, Sendable {
    public let candidates: [Lane2OrphanSweepCandidate]
    public let managedRootNames: [String]
    public let scannedRegularFiles: Int
    public let retainedYoungDuringScan: Int
    public let wrappedToStart: Bool
    public let hasMoreEligibleCandidates: Bool
    public let limit: Int
    public let priorCursorRelativePath: String?
    public let nextCursorRelativePath: String?

    public init(
        candidates: [Lane2OrphanSweepCandidate],
        managedRootNames: [String],
        scannedRegularFiles: Int,
        retainedYoungDuringScan: Int,
        wrappedToStart: Bool,
        hasMoreEligibleCandidates: Bool,
        limit: Int,
        priorCursorRelativePath: String?,
        nextCursorRelativePath: String?
    ) {
        self.candidates = candidates
        self.managedRootNames = managedRootNames
        self.scannedRegularFiles = scannedRegularFiles
        self.retainedYoungDuringScan = retainedYoungDuringScan
        self.wrappedToStart = wrappedToStart
        self.hasMoreEligibleCandidates = hasMoreEligibleCandidates
        self.limit = max(limit, 1)
        self.priorCursorRelativePath = priorCursorRelativePath
        self.nextCursorRelativePath = nextCursorRelativePath
    }

    public var candidateRelativePaths: Set<String> {
        Set(candidates.map(\.relativePath))
    }
}

public enum Lane2BoundedOrphanSweepFailure: Error, Equatable, Sendable {
    case cursorCorrupt
    case invalidManagedRoot(String)
    case candidateEscapedManagedRoots(String)
}

private struct Lane2OrphanSweepCursorRecord: Codable, Sendable {
    static let schemaVersion = 1
    let schemaVersion: Int
    let lastRelativePath: String
}

public extension LibraryArtifactLifecycle {
    /// Scans managed roots but retains only a bounded eligible candidate window in memory. The
    /// durable lexicographic cursor advances after a successful pass so live-referenced files at
    /// the beginning of a root cannot permanently starve later orphan candidates.
    func prepareBoundedOrphanCandidateSlice(
        managedRootNames: [String] = ["Imports", "Stems", "Exports"],
        gracePeriod: TimeInterval = 3600,
        now: Date = Date(),
        limit: Int = Lane2OrphanSweepBudget.defaultCandidatesPerPass
    ) throws -> Lane2OrphanSweepCandidateSlice {
        let effectiveLimit = max(limit, 1)
        let normalizedRoots = try normalizedManagedRoots(managedRootNames)
        let cursor = try loadOrphanSweepCursor()
        let cursorPath = cursor?.lastRelativePath
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .contentModificationDateKey
        ]

        var scannedRegularFiles = 0
        var retainedYoung = 0
        var hasEligibleAtOrBeforeCursor = false
        var afterCursor: [Lane2OrphanSweepCandidate] = []
        var overall: [Lane2OrphanSweepCandidate] = []

        for rootName in normalizedRoots {
            let managedRoot = try absoluteURL(for: rootName)
            guard FileManager.default.fileExists(atPath: managedRoot.path) else { continue }
            guard let enumerator = FileManager.default.enumerator(
                at: managedRoot,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in true }
            ) else { continue }

            for case let fileURL as URL in enumerator {
                let values = try fileURL.resourceValues(forKeys: keys)
                if values.isSymbolicLink == true {
                    enumerator.skipDescendants()
                    continue
                }
                guard values.isRegularFile == true else { continue }
                scannedRegularFiles += 1
                let relativePath = try boundedOrphanRelativePath(for: fileURL)
                guard normalizedRoots.contains(firstPathComponent(relativePath)) else {
                    throw Lane2BoundedOrphanSweepFailure.candidateEscapedManagedRoots(relativePath)
                }
                let modified = values.contentModificationDate ?? .distantPast
                if now.timeIntervalSince(modified) < gracePeriod {
                    retainedYoung += 1
                    continue
                }

                let candidate = Lane2OrphanSweepCandidate(
                    relativePath: relativePath,
                    contentModificationDate: modified
                )
                insertBounded(candidate, into: &overall, capacity: effectiveLimit + 1)
                if let cursorPath, relativePath <= cursorPath {
                    hasEligibleAtOrBeforeCursor = true
                } else {
                    insertBounded(candidate, into: &afterCursor, capacity: effectiveLimit + 1)
                }
            }
        }

        let wrapped = cursorPath != nil && afterCursor.isEmpty && !overall.isEmpty
        let pool = wrapped ? overall : afterCursor
        let selected = Array(pool.prefix(effectiveLimit))
        let hasMore: Bool
        if wrapped {
            hasMore = pool.count > effectiveLimit
        } else {
            hasMore = pool.count > effectiveLimit || hasEligibleAtOrBeforeCursor
        }
        return Lane2OrphanSweepCandidateSlice(
            candidates: selected,
            managedRootNames: normalizedRoots,
            scannedRegularFiles: scannedRegularFiles,
            retainedYoungDuringScan: retainedYoung,
            wrappedToStart: wrapped,
            hasMoreEligibleCandidates: hasMore,
            limit: effectiveLimit,
            priorCursorRelativePath: cursorPath,
            nextCursorRelativePath: selected.last?.relativePath
        )
    }

    /// Revalidates every candidate immediately before deletion. Referenced, rejuvenated, symlinked,
    /// missing or non-regular paths are never removed. Missing paths are idempotently already clean.
    func applyBoundedOrphanCandidateSlice(
        _ slice: Lane2OrphanSweepCandidateSlice,
        referencedRelativePaths: Set<String>,
        gracePeriod: TimeInterval = 3600,
        now: Date = Date()
    ) throws -> LibraryOrphanSweepResult {
        let normalizedRoots = try normalizedManagedRoots(slice.managedRootNames)
        let referenced = Set(try referencedRelativePaths.map(boundedOrphanNormalize))
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .contentModificationDateKey
        ]
        var removed: [String] = []
        var retainedReferenced = 0
        var retainedYoung = slice.retainedYoungDuringScan

        for candidate in slice.candidates {
            let relativePath = try boundedOrphanNormalize(candidate.relativePath)
            guard normalizedRoots.contains(firstPathComponent(relativePath)) else {
                throw Lane2BoundedOrphanSweepFailure.candidateEscapedManagedRoots(relativePath)
            }
            if referenced.contains(relativePath) {
                retainedReferenced += 1
                continue
            }
            let url = try absoluteURL(for: relativePath)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let values = try url.resourceValues(forKeys: keys)
            guard values.isSymbolicLink != true, values.isRegularFile == true else { continue }
            let modified = values.contentModificationDate ?? .distantPast
            if now.timeIntervalSince(modified) < gracePeriod {
                retainedYoung += 1
                continue
            }
            do {
                try FileManager.default.removeItem(at: url)
                removed.append(relativePath)
            } catch {
                throw LibraryArtifactFailure.cleanupFailed(relativePath)
            }
        }

        return LibraryOrphanSweepResult(
            scanned: slice.scannedRegularFiles,
            removed: removed.sorted(),
            retainedReferenced: retainedReferenced,
            retainedYoung: retainedYoung
        )
    }

    /// Persist only after the candidate application finishes. A crash before this write repeats the
    /// same window idempotently; it never skips a candidate that may not have been removed yet.
    func persistBoundedOrphanSweepCursor(after slice: Lane2OrphanSweepCandidateSlice) throws {
        try FileManager.default.createDirectory(
            at: boundedOrphanSweepStateDirectoryURL,
            withIntermediateDirectories: true
        )
        guard let next = slice.nextCursorRelativePath else {
            if FileManager.default.fileExists(atPath: boundedOrphanSweepCursorURL.path) {
                try FileManager.default.removeItem(at: boundedOrphanSweepCursorURL)
            }
            return
        }
        let normalized = try boundedOrphanNormalize(next)
        guard try normalizedManagedRoots(slice.managedRootNames).contains(firstPathComponent(normalized)) else {
            throw Lane2BoundedOrphanSweepFailure.candidateEscapedManagedRoots(normalized)
        }
        let data = try JSONEncoder.lane2OrphanStable.encode(
            Lane2OrphanSweepCursorRecord(
                schemaVersion: Lane2OrphanSweepCursorRecord.schemaVersion,
                lastRelativePath: normalized
            )
        )
        try data.write(to: boundedOrphanSweepCursorURL, options: [.atomic])
    }

    private var boundedOrphanSweepStateDirectoryURL: URL {
        rootURL
            .appendingPathComponent(recoveryDirectoryName, isDirectory: true)
            .appendingPathComponent("OrphanSweep", isDirectory: true)
    }

    private var boundedOrphanSweepCursorURL: URL {
        boundedOrphanSweepStateDirectoryURL.appendingPathComponent("cursor-v1.json", isDirectory: false)
    }

    private func loadOrphanSweepCursor() throws -> Lane2OrphanSweepCursorRecord? {
        let url = boundedOrphanSweepCursorURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let record = try JSONDecoder().decode(
                Lane2OrphanSweepCursorRecord.self,
                from: Data(contentsOf: url)
            )
            guard record.schemaVersion == Lane2OrphanSweepCursorRecord.schemaVersion else {
                throw Lane2BoundedOrphanSweepFailure.cursorCorrupt
            }
            _ = try boundedOrphanNormalize(record.lastRelativePath)
            return record
        } catch let failure as Lane2BoundedOrphanSweepFailure {
            throw failure
        } catch {
            throw Lane2BoundedOrphanSweepFailure.cursorCorrupt
        }
    }

    private func normalizedManagedRoots(_ roots: [String]) throws -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for root in roots {
            let normalized = try boundedOrphanNormalize(root)
            let parts = normalized.split(separator: "/", omittingEmptySubsequences: false)
            guard parts.count == 1, normalized != recoveryDirectoryName else {
                throw Lane2BoundedOrphanSweepFailure.invalidManagedRoot(root)
            }
            if seen.insert(normalized).inserted { result.append(normalized) }
        }
        return result.sorted()
    }

    private func boundedOrphanRelativePath(for url: URL) throws -> String {
        let standardized = url.standardizedFileURL
        let rootPath = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        guard standardized.path.hasPrefix(rootPath) else {
            throw LibraryArtifactFailure.invalidRelativePath(url.path)
        }
        return try boundedOrphanNormalize(String(standardized.path.dropFirst(rootPath.count)))
    }
}

private func boundedOrphanNormalize(_ relativePath: String) throws -> String {
    let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
    guard !normalized.isEmpty,
          !normalized.hasPrefix("/"),
          !normalized.contains("\0"),
          !(normalized as NSString).isAbsolutePath else {
        throw LibraryArtifactFailure.invalidRelativePath(relativePath)
    }
    let parts = normalized.split(separator: "/", omittingEmptySubsequences: false)
    guard !parts.isEmpty,
          !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
        throw LibraryArtifactFailure.invalidRelativePath(relativePath)
    }
    return parts.joined(separator: "/")
}

private func firstPathComponent(_ relativePath: String) -> String {
    String(relativePath.split(separator: "/", omittingEmptySubsequences: false)[0])
}

private func insertBounded(
    _ candidate: Lane2OrphanSweepCandidate,
    into buffer: inout [Lane2OrphanSweepCandidate],
    capacity: Int
) {
    guard capacity > 0 else { return }
    let insertion = buffer.partitioningIndex { $0.relativePath >= candidate.relativePath }
    buffer.insert(candidate, at: insertion)
    if buffer.count > capacity { buffer.removeLast() }
}

private extension Array {
    func partitioningIndex(where predicate: (Element) -> Bool) -> Int {
        var low = 0
        var high = count
        while low < high {
            let mid = low + (high - low) / 2
            if predicate(self[mid]) { high = mid } else { low = mid + 1 }
        }
        return low
    }
}

private extension JSONEncoder {
    static var lane2OrphanStable: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
