import Foundation

struct MeshDurabilityProtectedResult: Equatable, Sendable {
    let projectURL: URL
    let resultURL: URL
}

struct MeshDurabilityRecoveryReport: Equatable, Sendable {
    let recoveredCount: Int
    let remainingCount: Int
    let lastErrorDescription: String?
}

enum MeshDurabilityRecoveryError: LocalizedError {
    case invalidResult
    case invalidProject
    case movedResultMissing

    var errorDescription: String? {
        switch self {
        case .invalidResult:
            return "保護するMesh結果を確認できません。"
        case .invalidProject:
            return "Mesh working projectをRecovery領域へ退避できません。"
        case .movedResultMissing:
            return "Recovery領域へ移動したMesh結果を確認できません。"
        }
    }
}

/// Fail-closed shelter for finished working Mesh projects.
///
/// A durable library snapshot can fail under low-storage or filesystem pressure. Moving the whole
/// `.meshproject` into a sibling Recovery directory is a metadata-only rename on the same Documents
/// volume, so `MeshScanModel.reset()` can no longer delete it through the stale working-project URL.
/// Pending recovery projects are retried on a later app entry and removed only after library archive
/// plus integrity verification both succeed.
struct MeshDurabilityRecoveryStore: Sendable {
    static let recoveryDirectoryName = "MeshRecovery"

    let appRootURL: URL

    init(appRootURL: URL? = nil) {
        self.appRootURL = appRootURL ?? MeshProjectStore().appRootURL
    }

    var recoveryURL: URL {
        appRootURL.appendingPathComponent(Self.recoveryDirectoryName, isDirectory: true)
    }

    func protect(resultURL: URL) throws -> MeshDurabilityProtectedResult {
        let fileManager = FileManager.default
        guard resultURL.isFileURL,
              fileManager.fileExists(atPath: resultURL.path) else {
            throw MeshDurabilityRecoveryError.invalidResult
        }

        let sourceProjectURL = resultURL.deletingLastPathComponent().standardizedFileURL
        guard sourceProjectURL.pathExtension.lowercased() == MeshProjectStore.projectExtension else {
            throw MeshDurabilityRecoveryError.invalidProject
        }

        try fileManager.createDirectory(at: recoveryURL, withIntermediateDirectories: true)

        if sourceProjectURL.deletingLastPathComponent().standardizedFileURL == recoveryURL.standardizedFileURL {
            return MeshDurabilityProtectedResult(projectURL: sourceProjectURL, resultURL: resultURL)
        }

        let sourcePrefix = sourceProjectURL.path.hasSuffix("/") ? sourceProjectURL.path : sourceProjectURL.path + "/"
        let standardizedResult = resultURL.standardizedFileURL
        guard standardizedResult.path.hasPrefix(sourcePrefix) else {
            throw MeshDurabilityRecoveryError.invalidResult
        }
        let relativeResultPath = String(standardizedResult.path.dropFirst(sourcePrefix.count))
        guard !relativeResultPath.isEmpty else {
            throw MeshDurabilityRecoveryError.invalidResult
        }

        var destinationURL = recoveryURL.appendingPathComponent(sourceProjectURL.lastPathComponent, isDirectory: true)
        if fileManager.fileExists(atPath: destinationURL.path) {
            let base = sourceProjectURL.deletingPathExtension().lastPathComponent
            destinationURL = recoveryURL
                .appendingPathComponent("\(base)-\(UUID().uuidString)", isDirectory: true)
                .appendingPathExtension(MeshProjectStore.projectExtension)
        }

        // Same-volume rename deliberately avoids allocating another copy when storage is exhausted.
        try fileManager.moveItem(at: sourceProjectURL, to: destinationURL)
        let movedResultURL = destinationURL.appendingPathComponent(relativeResultPath)
        guard fileManager.fileExists(atPath: movedResultURL.path) else {
            throw MeshDurabilityRecoveryError.movedResultMissing
        }

        return MeshDurabilityProtectedResult(projectURL: destinationURL, resultURL: movedResultURL)
    }

    func cleanupProtectedResult(containing resultURL: URL) {
        guard isProtected(resultURL: resultURL) else { return }
        try? FileManager.default.removeItem(at: resultURL.deletingLastPathComponent())
    }

    func isProtected(resultURL: URL) -> Bool {
        resultURL.deletingLastPathComponent().deletingLastPathComponent().standardizedFileURL == recoveryURL.standardizedFileURL
    }

    func recoverPendingArchives() -> MeshDurabilityRecoveryReport {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: recoveryURL, withIntermediateDirectories: true)

        let protectedProjects = projectDirectories(in: recoveryURL)
        let orphanedWorkingProjects = projectDirectories(in: appRootURL)
            .filter { bestFinishedResult(in: $0) != nil }
        let projects = protectedProjects + orphanedWorkingProjects

        var recoveredCount = 0
        var lastErrorDescription: String?
        let libraryStore = MeshProjectStore(appRootURL: appRootURL)

        for projectURL in projects {
            guard let resultURL = bestFinishedResult(in: projectURL) else {
                if projectURL.deletingLastPathComponent().standardizedFileURL == recoveryURL.standardizedFileURL {
                    lastErrorDescription = "Recovery内に完成Meshを確認できないprojectがあります。"
                }
                continue
            }
            do {
                let summary = try libraryStore.archiveFinishedProject(resultURL: resultURL)
                _ = try MeshProjectIntegrity.verifyOrSeal(summary: summary)
                try fileManager.removeItem(at: projectURL)
                recoveredCount += 1
            } catch {
                lastErrorDescription = error.localizedDescription
            }
        }

        let protectedRemaining = projectDirectories(in: recoveryURL).count
        let orphanedRemaining = projectDirectories(in: appRootURL)
            .filter { bestFinishedResult(in: $0) != nil }
            .count

        return MeshDurabilityRecoveryReport(
            recoveredCount: recoveredCount,
            remainingCount: protectedRemaining + orphanedRemaining,
            lastErrorDescription: lastErrorDescription
        )
    }

    private func projectDirectories(in directoryURL: URL) -> [URL] {
        let fileManager = FileManager.default
        return ((try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []).filter { url in
            guard url.pathExtension.lowercased() == MeshProjectStore.projectExtension else { return false }
            return (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
    }

    private func bestFinishedResult(in projectURL: URL) -> URL? {
        let fileManager = FileManager.default
        for name in ["mesh-cropped.obj", "mesh-textured.usdz", "mesh.obj"] {
            let candidate = projectURL.appendingPathComponent(name)
            if isNonEmptyRegularFile(candidate) { return candidate }
        }

        let reprocessed = ((try? fileManager.contentsOfDirectory(
            at: projectURL,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? [])
            .filter {
                $0.lastPathComponent.hasPrefix("mesh-reprocessed-") &&
                $0.pathExtension.lowercased() == "usdz" &&
                isNonEmptyRegularFile($0)
            }
            .sorted {
                let lhs = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhs = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhs > rhs
            }
        return reprocessed.first
    }

    private func isNonEmptyRegularFile(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true else { return false }
        return (values.fileSize ?? 0) > 0
    }
}
