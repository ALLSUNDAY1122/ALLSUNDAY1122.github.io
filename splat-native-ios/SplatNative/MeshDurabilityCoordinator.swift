import Foundation
import SwiftUI

/// Serializes finished Mesh snapshots into C's durable library before later UI resets can discard
/// B's working `.meshproject`. The durable snapshot itself is committed synchronously on the main
/// actor before `reconcile` returns; only integrity verification remains asynchronous. This closes
/// the reset race without forcing the potentially more expensive verification work onto the UI path.
@MainActor
final class MeshDurabilityCoordinator: ObservableObject {
    typealias ArchiveFinishedProject = (URL) throws -> MeshProjectSummary
    typealias VerifyArchive = @Sendable (MeshProjectSummary) throws -> URL

    @Published private(set) var warningMessage: String?

    private var archivingSourceURL: URL?
    private var pendingSourceURL: URL?
    private var verificationTask: Task<Void, Never>?
    private let archiveFinishedProject: ArchiveFinishedProject
    private let verifyArchive: VerifyArchive

    init(
        archiveFinishedProject: @escaping ArchiveFinishedProject = { sourceURL in
            try MeshProjectStore().archiveFinishedProject(resultURL: sourceURL)
        },
        verifyArchive: @escaping VerifyArchive = { summary in
            try MeshProjectIntegrity.verifyOrSeal(summary: summary)
        }
    ) {
        self.archiveFinishedProject = archiveFinishedProject
        self.verifyArchive = verifyArchive
    }

    func reconcile(model: MeshScanModel) {
        guard let sourceURL = model.resultURL,
              model.phase == .finished || model.phase == .reconstructing else {
            return
        }

        if isInsideDurableLibrary(sourceURL) {
            warningMessage = nil
            pendingSourceURL = nil
            return
        }

        if archivingSourceURL == sourceURL || pendingSourceURL == sourceURL {
            return
        }

        pendingSourceURL = sourceURL
        startNextArchiveIfNeeded(model: model)
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
            // returning control to SwiftUI. A reset immediately after this point can remove B's
            // working directory without destroying the archived bytes.
            summary = try archiveFinishedProject(sourceURL)
            warningMessage = nil
            model.statusMessage = "Meshを安全に保存しました。整合性を確認しています…"
        } catch {
            archivingSourceURL = nil
            let message = "Meshをライブラリへ保存できませんでした: \(error.localizedDescription)"
            warningMessage = message
            model.statusMessage = message
            return
        }

        verificationTask = Task { @MainActor [weak self, weak model] in
            guard let self, let model else { return }

            do {
                let verifier = self.verifyArchive
                let durableURL = try await Task.detached(priority: .utility) {
                    try verifier(summary)
                }.value

                self.archivingSourceURL = nil
                self.verificationTask = nil
                self.warningMessage = nil

                // Do not overwrite or remove a newer edit/crop result that arrived while this snapshot ran.
                let currentResult = model.resultURL
                if currentResult == sourceURL {
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
                self.verificationTask = nil
                self.startNextArchiveIfNeeded(model: model)
            } catch {
                self.archivingSourceURL = nil
                self.verificationTask = nil
                let message = "保存済みMeshの整合性を確認できませんでした: \(error.localizedDescription)"
                self.warningMessage = message
                model.statusMessage = message
                // The snapshot itself already exists durably. Retry verification only after a later
                // model/result transition or explicit app re-entry.
            }
        }
    }

    private func isInsideDurableLibrary(_ url: URL) -> Bool {
        let library = MeshProjectStore().libraryURL.standardizedFileURL.resolvingSymlinksInPath()
        let candidate = url.standardizedFileURL.resolvingSymlinksInPath()
        let prefix = library.path.hasSuffix("/") ? library.path : library.path + "/"
        return candidate.path.hasPrefix(prefix)
    }
}
