#if canImport(SwiftUI)
import Foundation
import SwiftUI
import ProductFlow

@MainActor
public final class ProductFlowStore: ObservableObject {
    @Published public private(set) var state: ProductFlowState
    @Published public private(set) var reviewItems: [ProductReviewItem] = []
    @Published public private(set) var resumeAvailable = false
    @Published public private(set) var isRunning = false

    private let driver: any ProductPipelineDriving
    private let checkpointStore: any ProductCheckpointPersisting
    private let reviewWorkflowFactory: @Sendable ([ProductReviewItem]) -> any ProductReviewWorkflow
    private var reviewWorkflow: (any ProductReviewWorkflow)?
    private var processingTask: Task<Void, Never>?
    private var savedCheckpoint: ProductPipelineCheckpoint?
    private let workspaceRoot: URL

    public init(
        state: ProductFlowState = .init(),
        driver: any ProductPipelineDriving = BoundProductPipelineDriver(bindings: []),
        checkpointStore: (any ProductCheckpointPersisting)? = nil,
        workspaceRoot: URL? = nil,
        reviewWorkflowFactory: @escaping @Sendable ([ProductReviewItem]) -> any ProductReviewWorkflow = { InMemoryProductReviewWorkflow(items: $0) }
    ) {
        self.state = state
        self.driver = driver
        self.reviewWorkflowFactory = reviewWorkflowFactory
        let base = workspaceRoot ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ScannerParity", isDirectory: true)
        self.workspaceRoot = base
        self.checkpointStore = checkpointStore ?? FileProductCheckpointStore(
            fileURL: base.appendingPathComponent("processing-checkpoint.json")
        )
    }

    deinit { processingTask?.cancel() }

    public func send(_ action: ProductFlowAction) {
        ProductFlowReducer.reduce(state: &state, action: action)
    }

    public func replaceInput(_ assets: [ProductInputAsset]) {
        guard !isRunning else { return }
        if let packageURL = state.bookPackageURL { purgeCompletedPackageIfManaged(packageURL) }
        if let bookID = savedCheckpoint?.bookID { purgeWorkspace(bookID: bookID) }
        savedCheckpoint = nil
        resumeAvailable = false
        reviewItems = []
        reviewWorkflow = nil
        send(.replaceInput(assets))
        let checkpointStore = checkpointStore
        Task { try? await checkpointStore.clear() }
    }

    public func restoreCheckpoint() {
        let checkpointStore = checkpointStore
        let reviewFactory = reviewWorkflowFactory
        Task { [weak self] in
            guard let self else { return }
            do {
                guard let checkpoint = try await checkpointStore.load() else {
                    self.savedCheckpoint = nil
                    self.resumeAvailable = false
                    return
                }

                // Schema-v3 terminal state contains only the staged final package and review metadata.
                if let completion = checkpoint.completion {
                    guard FileManager.default.fileExists(atPath: completion.bookPackageURL.path) else {
                        self.invalidateCheckpoint(checkpoint)
                        return
                    }
                    self.purgeManagedInputs(checkpoint.inputAssets ?? [])
                    self.purgeWorkspace(bookID: checkpoint.bookID)
                    self.savedCheckpoint = checkpoint
                    self.resumeAvailable = false
                    self.reviewItems = completion.reviewItems
                    self.reviewWorkflow = reviewFactory(completion.reviewItems)
                    self.send(.restoreCompleted(
                        bookPackageURL: completion.bookPackageURL,
                        reviewRequiredCount: completion.reviewItems.count
                    ))
                    return
                }

                // Migrate a legacy completed five-stage checkpoint before deleting intermediates.
                if let legacyCompletion = checkpoint.terminalCompletion {
                    let staged = try self.stageCompletedPackage(legacyCompletion, bookID: checkpoint.bookID)
                    let terminal = self.makeTerminalCheckpoint(
                        from: checkpoint,
                        completion: staged
                    )
                    try await checkpointStore.save(terminal)
                    self.purgeManagedInputs(checkpoint.inputAssets ?? [])
                    self.purgeWorkspace(bookID: checkpoint.bookID)
                    self.savedCheckpoint = terminal
                    self.resumeAvailable = false
                    self.reviewItems = staged.reviewItems
                    self.reviewWorkflow = reviewFactory(staged.reviewItems)
                    self.send(.restoreCompleted(
                        bookPackageURL: staged.bookPackageURL,
                        reviewRequiredCount: staged.reviewItems.count
                    ))
                    return
                }

                guard checkpoint.hasCanonicalExistingArtifacts else {
                    self.invalidateCheckpoint(checkpoint)
                    return
                }

                if self.state.inputAssets.isEmpty, let checkpointInputs = checkpoint.inputAssets {
                    let existing = checkpointInputs.filter {
                        FileManager.default.fileExists(atPath: $0.localURL.path)
                    }
                    if existing.count == checkpointInputs.count, !existing.isEmpty {
                        self.send(.replaceInput(existing))
                    }
                }

                let matches = !self.state.inputAssets.isEmpty
                    && checkpoint.inputAssetIDs == self.state.inputAssets.map(\.id)
                self.savedCheckpoint = matches ? checkpoint : nil
                self.resumeAvailable = matches
                if !matches { self.invalidateCheckpoint(checkpoint) }
            } catch {
                self.savedCheckpoint = nil
                self.resumeAvailable = false
            }
        }
    }

    public func startProcessing() {
        guard !isRunning else { return }
        send(.startProcessing)
        guard state.step == .processing else { return }
        launch(resume: nil)
    }

    public func resumeProcessing() {
        guard !isRunning, let checkpoint = savedCheckpoint else { return }
        send(.startProcessing)
        guard state.step == .processing else { return }
        launch(resume: checkpoint)
    }

    public func cancelProcessing() {
        processingTask?.cancel()
        let driver = driver
        Task { await driver.cancel() }
        send(.cancel)
        isRunning = false
    }

    public func resolveReviewItem(_ itemID: String, decision: ProductReviewDecision) {
        guard let workflow = reviewWorkflow else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await workflow.apply(decision: decision, to: itemID)
                let remaining = await workflow.unresolvedItems()
                self.reviewItems = remaining
                self.send(.reviewResolved(remaining: remaining.count))
                self.persistTerminalReviewState()
            } catch {
                self.send(.fail(.init(code: .processingFailed, message: error.localizedDescription, recoveryStep: .review)))
            }
        }
    }

    public func markExportFinished() {
        guard state.step == .exporting else { return }
        let packageURL = state.bookPackageURL
        send(.exportFinished)
        if let packageURL { purgeCompletedPackageIfManaged(packageURL) }
        state.bookPackageURL = nil
        savedCheckpoint = nil
        resumeAvailable = false
        let checkpointStore = checkpointStore
        Task { try? await checkpointStore.clear() }
    }

    private func launch(resume: ProductPipelineCheckpoint?) {
        isRunning = true
        let inputs = state.inputAssets
        let bookID = resume?.bookID ?? "book-\(UUID().uuidString.lowercased())"
        let workspace = workspaceRoot.appendingPathComponent(bookID, isDirectory: true)
        do {
            try prepareRecoverableDirectory(workspace)
        } catch {
            send(.fail(.init(code: .processingFailed, message: error.localizedDescription, recoveryStep: .ready)))
            isRunning = false
            return
        }

        let request = ProductPipelineRequest(bookID: bookID, inputs: inputs, workspaceURL: workspace)
        let driver = driver
        let checkpointStore = checkpointStore
        let reviewFactory = reviewWorkflowFactory

        processingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let completion = try await driver.run(
                    request: request,
                    resume: resume,
                    progress: { [weak self] progress in await self?.apply(progress: progress) },
                    checkpoint: { [weak self] checkpoint in
                        do {
                            try await checkpointStore.save(checkpoint)
                            await self?.apply(checkpoint: checkpoint)
                        } catch {
                            await self?.applyCheckpointPersistenceFailure(error)
                        }
                    }
                )

                let staged = try self.stageCompletedPackage(completion, bookID: bookID)
                let activeCheckpoint = self.savedCheckpoint
                let terminal = ProductPipelineCheckpoint(
                    schemaVersion: 3,
                    runID: activeCheckpoint?.runID ?? resume?.runID ?? UUID().uuidString,
                    bookID: bookID,
                    inputAssetIDs: inputs.map(\.id),
                    inputAssets: nil,
                    completedArtifacts: [],
                    lastProgress: ProductProgress(
                        stage: .packageWrite,
                        fraction: 1,
                        completedUnits: staged.pageCount,
                        totalUnits: staged.pageCount
                    ),
                    completion: ProductCompletionSnapshot(
                        bookPackageURL: staged.bookPackageURL,
                        reviewItems: staged.reviewItems,
                        pageCount: staged.pageCount
                    )
                )
                do {
                    try await checkpointStore.save(terminal)
                    self.savedCheckpoint = terminal
                } catch {
                    self.savedCheckpoint = nil
                    try? await checkpointStore.clear()
                }

                // Privacy boundary: after final package promotion, raw inputs and all
                // frame/correction/audit/OCR intermediates are no longer retained.
                self.purgeManagedInputs(inputs)
                self.purgeWorkspace(bookID: bookID)

                let workflow = reviewFactory(staged.reviewItems)
                self.resumeAvailable = false
                self.reviewItems = staged.reviewItems
                self.reviewWorkflow = workflow
                self.send(.processingFinished(
                    bookPackageURL: staged.bookPackageURL,
                    reviewRequiredCount: staged.reviewItems.count
                ))
                self.state.inputAssets = []
                self.isRunning = false
            } catch {
                let failure: ProductFlowFailure
                if error is CancellationError || (error as? ProductPipelineDriverError) == .cancelled {
                    failure = .init(code: .cancelled, message: "Processing was cancelled. Saved progress can be resumed when available.", recoveryStep: .ready)
                } else {
                    failure = .init(code: .processingFailed, message: error.localizedDescription, recoveryStep: .ready)
                }
                self.send(.fail(failure))
                self.isRunning = false
            }
        }
    }

    private func apply(progress: ProductProgress) { send(.updateProgress(progress)) }
    private func apply(checkpoint: ProductPipelineCheckpoint) { savedCheckpoint = checkpoint; resumeAvailable = true }
    private func applyCheckpointPersistenceFailure(_ error: Error) { savedCheckpoint = nil; resumeAvailable = false }

    private func persistTerminalReviewState() {
        guard let checkpoint = savedCheckpoint,
              let completion = checkpoint.completion,
              FileManager.default.fileExists(atPath: completion.bookPackageURL.path) else { return }
        let updatedCompletion = ProductCompletionSnapshot(
            bookPackageURL: completion.bookPackageURL,
            reviewItems: reviewItems,
            pageCount: completion.pageCount,
            completedAt: completion.completedAt
        )
        let updated = ProductPipelineCheckpoint(
            schemaVersion: 3,
            runID: checkpoint.runID,
            bookID: checkpoint.bookID,
            inputAssetIDs: checkpoint.inputAssetIDs,
            inputAssets: nil,
            completedArtifacts: [],
            lastProgress: checkpoint.lastProgress,
            completion: updatedCompletion
        )
        savedCheckpoint = updated
        let checkpointStore = checkpointStore
        Task { try? await checkpointStore.save(updated) }
    }

    private func makeTerminalCheckpoint(
        from checkpoint: ProductPipelineCheckpoint,
        completion: ProductPipelineCompletion
    ) -> ProductPipelineCheckpoint {
        ProductPipelineCheckpoint(
            schemaVersion: 3,
            runID: checkpoint.runID,
            bookID: checkpoint.bookID,
            inputAssetIDs: checkpoint.inputAssetIDs,
            inputAssets: nil,
            completedArtifacts: [],
            lastProgress: ProductProgress(
                stage: .packageWrite,
                fraction: 1,
                completedUnits: completion.pageCount,
                totalUnits: completion.pageCount
            ),
            completion: ProductCompletionSnapshot(
                bookPackageURL: completion.bookPackageURL,
                reviewItems: completion.reviewItems,
                pageCount: completion.pageCount
            )
        )
    }

    private func stageCompletedPackage(
        _ completion: ProductPipelineCompletion,
        bookID: String
    ) throws -> ProductPipelineCompletion {
        let root = workspaceRoot.appendingPathComponent("Completed", isDirectory: true)
        try prepareRecoverableDirectory(root)
        let destination = root.appendingPathComponent(bookID, isDirectory: true)
        if destination.standardizedFileURL != completion.bookPackageURL.standardizedFileURL {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: completion.bookPackageURL, to: destination)
        }
        return ProductPipelineCompletion(
            bookPackageURL: destination,
            reviewItems: completion.reviewItems,
            pageCount: completion.pageCount
        )
    }

    private func prepareRecoverableDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        var mutable = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try mutable.setResourceValues(values)
    }

    private func invalidateCheckpoint(_ checkpoint: ProductPipelineCheckpoint) {
        purgeManagedInputs(checkpoint.inputAssets ?? [])
        purgeWorkspace(bookID: checkpoint.bookID)
        savedCheckpoint = nil
        resumeAvailable = false
        let checkpointStore = checkpointStore
        Task { try? await checkpointStore.clear() }
    }

    private func purgeWorkspace(bookID: String) {
        guard bookID.hasPrefix("book-") else { return }
        let target = workspaceRoot.appendingPathComponent(bookID, isDirectory: true).standardizedFileURL
        let root = workspaceRoot.standardizedFileURL.path
        guard target.path.hasPrefix(root + "/") else { return }
        try? FileManager.default.removeItem(at: target)
    }

    private func purgeManagedInputs(_ inputs: [ProductInputAsset]) {
        let importRoot = workspaceRoot.appendingPathComponent("Imports", isDirectory: true).standardizedFileURL.path
        for input in inputs {
            let path = input.localURL.standardizedFileURL.path
            guard path.hasPrefix(importRoot + "/") else { continue }
            try? FileManager.default.removeItem(at: input.localURL)
        }
    }

    private func purgeCompletedPackageIfManaged(_ url: URL) {
        let completedRoot = workspaceRoot.appendingPathComponent("Completed", isDirectory: true).standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(completedRoot + "/") else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
#endif
