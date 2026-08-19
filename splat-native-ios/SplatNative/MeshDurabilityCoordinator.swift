import Foundation
import SwiftUI

/// Serializes finished Mesh snapshots into C's durable library and shelters working projects until
/// the durable copy is trusted. Low-storage/archive failures move the whole `.meshproject` into a
/// same-volume Recovery directory before destructive UI can return. If even that rename fails, the
/// production shell enters a fail-closed blocking state until retry succeeds.
@MainActor
final class MeshDurabilityCoordinator: ObservableObject {
    typealias ArchiveFinishedProject = (URL) throws -> MeshProjectSummary
    typealias VerifyArchive = @Sendable (MeshProjectSummary) throws -> URL
    typealias ProtectWorkingResult = (URL) throws -> MeshDurabilityProtectedResult
    typealias CleanupProtectedResult = (URL) -> Void

    @Published private(set) var warningMessage: String?
    @Published private(set) var blockingMessage: String?

    private var archivingSourceURL: URL?
    private var pendingSourceURL: URL?
    private var verificationSourceURL: URL?
    private var failedSourceURL: URL?
    private var verificationTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?
    private let archiveFinishedProject: ArchiveFinishedProject
    private let verifyArchive: VerifyArchive
    private let protectWorkingResult: ProtectWorkingResult
    private let cleanupProtectedResult: CleanupProtectedResult

    init(
        archiveFinishedProject: @escaping ArchiveFinishedProject = { sourceURL in
            try MeshProjectStore().archiveFinishedProject(resultURL: sourceURL)
        },
        verifyArchive: @escaping VerifyArchive = { summary in
            try MeshProjectIntegrity.verifyOrSeal(summary: summary)
        },
        protectWorkingResult: @escaping ProtectWorkingResult = { sourceURL in
            try MeshDurabilityRecoveryStore().protect(resultURL: sourceURL)
        },
        cleanupProtectedResult: @escaping CleanupProtectedResult = { resultURL in
            MeshDurabilityRecoveryStore().cleanupProtectedResult(containing: resultURL)
        }
    ) {
        self.archiveFinishedProject = archiveFinishedProject
        self.verifyArchive = verifyArchive
        self.protectWorkingResult = protectWorkingResult
        self.cleanupProtectedResult = cleanupProtectedResult
    }

    func reconcile(model: MeshScanModel) {
        guard let sourceURL = model.resultURL,
              model.phase == .finished || model.phase == .reconstructing else {
            return
        }

        if isInsideDurableLibrary(sourceURL) {
            warningMessage = nil
            blockingMessage = nil
            pendingSourceURL = nil
            failedSourceURL = nil
            return
        }

        guard failedSourceURL != sourceURL,
              verificationSourceURL != sourceURL,
              archivingSourceURL != sourceURL,
              pendingSourceURL != sourceURL else {
            return
        }

        pendingSourceURL = sourceURL
        startNextArchiveIfNeeded(model: model)
    }

    func retry(model: MeshScanModel) {
        guard verificationTask == nil, recoveryTask == nil else { return }
        warningMessage = nil
        blockingMessage = nil
        failedSourceURL = nil

        if model.resultURL != nil {
            reconcile(model: model)
        } else {
            recoverPendingProjects()
        }
    }

    func recoverPendingProjects() {
        guard recoveryTask == nil else { return }
        recoveryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let report = await Task.detached(priority: .utility) {
                MeshDurabilityRecoveryStore().recoverPendingArchives()
            }.value
            self.recoveryTask = nil

            if report.remainingCount > 0 {
                let suffix = report.lastErrorDescription.map { ": \($0)" } ?? ""
                self.warningMessage = "未収容のMeshがRecoveryに\(report.remainingCount)件あります。空き容量を確保して保存を再試行してください\(suffix)"
            } else if report.recoveredCount > 0 {
                self.warningMessage = nil
            }
        }
    }

    private func startNextArchiveIfNeeded(model: MeshScanModel) {
        guard archivingSourceURL == nil,
              let sourceURL = pendingSourceURL else {
            return
        }

        pendingSourceURL = nil
        archivingSourceURL = sourceURL

        let summary: MeshProjectSummary
        do {
            // Critical durability boundary: finish the hard-link/capacity-checked snapshot before
            // returning control to SwiftUI. A reset immediately after this point cannot race the
            // initial library snapshot.
            summary = try archiveFinishedProject(sourceURL)
            warningMessage = nil
            model.statusMessage = "Meshを安全に保存しました。整合性を確認しています…"
        } catch {
            archivingSourceURL = nil
            preserveAfterFailure(sourceURL: sourceURL, error: error, model: model)
            return
        }

        // Keep an independent working-project name alive until integrity verification succeeds.
        // Because this is a same-volume rename, even low-storage conditions do not require another
        // physical copy. MeshScanModel still holds the stale pre-move project URL, so reset cannot
        // delete the protected Recovery project.
        var protectedSourceURL = sourceURL
        do {
            let protected = try protectWorkingResult(sourceURL)
            protectedSourceURL = protected.resultURL
            verificationSourceURL = protectedSourceURL
            archivingSourceURL = protectedSourceURL
            if model.resultURL == sourceURL {
                model.resultURL = protectedSourceURL
            }
        } catch {
            // The durable snapshot already exists, but until it is verified we cannot safely permit
            // destructive interaction if the working copy could not be moved out of reset's reach.
            verificationSourceURL = sourceURL
            blockingMessage = "Meshの保存済みコピーを確認中ですが、working projectをRecoveryへ保護できませんでした。整合性確認が終わるまで操作を停止します。"
        }

        let sourceBeingVerified = protectedSourceURL
        verificationTask = Task { @MainActor [weak self, weak model] in
            guard let self, let model else { return }

            do {
                let verifier = self.verifyArchive
                let durableURL = try await Task.detached(priority: .utility) {
                    try verifier(summary)
                }.value

                self.archivingSourceURL = nil
                self.verificationSourceURL = nil
                self.failedSourceURL = nil
                self.verificationTask = nil
                self.warningMessage = nil
                self.blockingMessage = nil

                let currentResult = model.resultURL
                self.cleanupProtectedResult(sourceBeingVerified)
                if currentResult == sourceURL || currentResult == sourceBeingVerified {
                    model.resultURL = durableURL
                    model.statusMessage = "Meshをライブラリへ安全に保存しました"
                    MeshRawProjectBridge.cleanupDerivedWorkingProject(containing: sourceURL)
                } else if currentResult == nil {
                    MeshRawProjectBridge.cleanupDerivedWorkingProject(containing: sourceURL)
                }

                self.reconcile(model: model)
                self.startNextArchiveIfNeeded(model: model)
            } catch is CancellationError {
                self.archivingSourceURL = nil
                self.verificationSourceURL = nil
                self.verificationTask = nil
                self.failedSourceURL = sourceBeingVerified
                self.warningMessage = "Mesh整合性確認が中断されました。Recoveryのworking projectは保持されています。"
            } catch {
                self.archivingSourceURL = nil
                self.verificationSourceURL = nil
                self.verificationTask = nil
                self.preserveAfterFailure(sourceURL: sourceBeingVerified, error: error, model: model)
            }
        }
    }

    private func preserveAfterFailure(sourceURL: URL, error: Error, model: MeshScanModel) {
        let baseMessage = "Meshを安全に保存できませんでした: \(error.localizedDescription)"

        if MeshDurabilityRecoveryStore().isProtected(resultURL: sourceURL) {
            failedSourceURL = sourceURL
            warningMessage = baseMessage + "。working projectはRecoveryに保持されています。空き容量を確保して保存を再試行してください。"
            blockingMessage = nil
            model.statusMessage = warningMessage ?? baseMessage
            return
        }

        do {
            let protected = try protectWorkingResult(sourceURL)
            failedSourceURL = protected.resultURL
            warningMessage = baseMessage + "。working projectはRecoveryへ退避したため失われません。空き容量を確保して保存を再試行してください。"
            blockingMessage = nil
            if model.resultURL == sourceURL {
                model.resultURL = protected.resultURL
            }
            model.statusMessage = warningMessage ?? baseMessage
        } catch {
            failedSourceURL = sourceURL
            warningMessage = baseMessage
            blockingMessage = baseMessage + "。さらにRecoveryへの退避にも失敗したため、データ消失を防ぐため操作を停止しています。空き容量・ファイル状態を確認して保存を再試行してください。"
            model.statusMessage = blockingMessage ?? baseMessage
        }
    }

    private func isInsideDurableLibrary(_ url: URL) -> Bool {
        let library = MeshProjectStore().libraryURL.standardizedFileURL.resolvingSymlinksInPath()
        let candidate = url.standardizedFileURL.resolvingSymlinksInPath()
        let prefix = library.path.hasSuffix("/") ? library.path : library.path + "/"
        return candidate.path.hasPrefix(prefix)
    }
}
