import Foundation

public enum LibraryUncommittedExportRecoveryFailure: Error, Equatable, Sendable {
    case unsafeLocation(String)
    case directoryCandidate(String)
}

public struct LibraryUncommittedExportRecoveryReport: Equatable, Sendable {
    public let removed: [String]
    public let alreadyMissing: [String]
    public let failed: [String]

    public init(removed: [String], alreadyMissing: [String], failed: [String]) {
        self.removed = removed.sorted()
        self.alreadyMissing = alreadyMissing.sorted()
        self.failed = failed.sorted()
    }

    public var isComplete: Bool { failed.isEmpty }
}

public extension LibraryArtifactLifecycle {
    /// Best-effort compensation for artifacts produced by an export attempt that failed before
    /// lifecycle metadata could commit. Every candidate is validated before any deletion occurs.
    /// Only regular files strictly below `Exports/` are eligible; directories and other managed
    /// roots fail closed so recovery can never recursively delete user source/stem content.
    func discardUncommittedExportArtifacts(
        relativePaths: [String],
        fileManager: FileManager = .default
    ) throws -> LibraryUncommittedExportRecoveryReport {
        let uniquePaths = Array(Set(relativePaths)).sorted()
        guard !uniquePaths.isEmpty else {
            return LibraryUncommittedExportRecoveryReport(removed: [], alreadyMissing: [], failed: [])
        }

        let exportRoot = try absoluteURL(for: "Exports").standardizedFileURL
        let exportRootPrefix = exportRoot.path.hasSuffix("/") ? exportRoot.path : exportRoot.path + "/"

        struct Candidate {
            let relativePath: String
            let url: URL
            let exists: Bool
        }

        var candidates: [Candidate] = []
        candidates.reserveCapacity(uniquePaths.count)

        // Validate the complete set first. One unsafe candidate means zero deletions.
        for relativePath in uniquePaths {
            let url = try absoluteURL(for: relativePath).standardizedFileURL
            guard url.path.hasPrefix(exportRootPrefix) else {
                throw LibraryUncommittedExportRecoveryFailure.unsafeLocation(relativePath)
            }

            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
            if exists && isDirectory.boolValue {
                throw LibraryUncommittedExportRecoveryFailure.directoryCandidate(relativePath)
            }
            if exists {
                let values = try url.resourceValues(forKeys: [.isRegularFileKey])
                guard values.isRegularFile == true else {
                    throw LibraryUncommittedExportRecoveryFailure.directoryCandidate(relativePath)
                }
            }
            candidates.append(Candidate(relativePath: relativePath, url: url, exists: exists))
        }

        var removed: [String] = []
        var missing: [String] = []
        var failed: [String] = []

        for candidate in candidates {
            guard candidate.exists else {
                missing.append(candidate.relativePath)
                continue
            }

            // Re-check immediately before deletion to avoid recursively removing a path that was
            // swapped to a directory after validation.
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: candidate.url.path, isDirectory: &isDirectory) else {
                missing.append(candidate.relativePath)
                continue
            }
            guard !isDirectory.boolValue else {
                failed.append(candidate.relativePath)
                continue
            }

            do {
                try fileManager.removeItem(at: candidate.url)
                removed.append(candidate.relativePath)
                pruneEmptyExportParents(
                    startingAt: candidate.url.deletingLastPathComponent(),
                    exportRoot: exportRoot,
                    fileManager: fileManager
                )
            } catch {
                failed.append(candidate.relativePath)
            }
        }

        return LibraryUncommittedExportRecoveryReport(
            removed: removed,
            alreadyMissing: missing,
            failed: failed
        )
    }

    private func pruneEmptyExportParents(startingAt start: URL, exportRoot: URL, fileManager: FileManager) {
        var current = start.standardizedFileURL
        let root = exportRoot.standardizedFileURL
        while current != root {
            guard current.path.hasPrefix(root.path + "/") else { return }
            guard let children = try? fileManager.contentsOfDirectory(
                at: current,
                includingPropertiesForKeys: nil
            ), children.isEmpty else { return }
            guard (try? fileManager.removeItem(at: current)) != nil else { return }
            current = current.deletingLastPathComponent().standardizedFileURL
        }
    }
}
