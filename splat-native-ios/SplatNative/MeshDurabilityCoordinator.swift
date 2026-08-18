import Foundation
import SwiftUI

/// Serializes finished Mesh snapshots into C's durable library before later UI resets can discard
/// B's working `.meshproject`. A changed result URL (for example after crop/edit output) is archived
/// again so the library always points at the newest finished representation.
@MainActor
final class MeshDurabilityCoordinator: ObservableObject {
    @Published private(set) var warningMessage: String?

    private var archivingSourceURL: URL?
    private var pendingSourceURL: URL?
    private var archiveTask: Task<Void, Never>?

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
        archiveTask = Task { @MainActor [weak self, weak model] in
            guard let self, let model else { return }

            do {
                let durableURL = try await Task.detached(priority: .utility) {
                    let store = MeshProjectStore()
                    let summary = try store.archiveFinishedProject(resultURL: sourceURL)
                    return try MeshProjectIntegrity.verifyOrSeal(summary: summary)
                }.value

                self.archivingSourceURL = nil
                self.archiveTask = nil
                self.warningMessage = nil

                // Do not overwrite a newer edit/crop result that arrived while this snapshot ran.
                if model.resultURL == sourceURL {
                    model.resultURL = durableURL
                    model.statusMessage = "Meshをライブラリへ安全に保存しました"
                }

                self.reconcile(model: model)
                self.startNextArchiveIfNeeded(model: model)
            } catch is CancellationError {
                self.archivingSourceURL = nil
                self.archiveTask = nil
                self.startNextArchiveIfNeeded(model: model)
            } catch {
                self.archivingSourceURL = nil
                self.archiveTask = nil
                let message = "Meshをライブラリへ保存できませんでした: \(error.localizedDescription)"
                self.warningMessage = message
                model.statusMessage = message
                // Retry only after a later model/result transition or explicit app re-entry.
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
