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

    /// Replaces the selected input and invalidates any checkpoint belonging to
    /// a previous selection so a stale run can never resume against new media.
    public func replaceInput(_ assets: [ProductInputAsset]) {
        guard !isRunning else { return }
        savedCheckpoint = nil
        resumeAvailable = false
        reviewItems = []
        reviewWorkflow = nil
        send(.replaceInput(assets))
        let checkpointStore = checkpointStore
        Task { try? await checkpointStore.clear() }
    }

    /// Restores both the processing checkpoint and its durable imported media.
    /// A schema-v1 checkpoint without input descriptors remains readable, but
    /// cannot claim relaunch-resume unless matching input is already present.
    public func restoreCheckpoint() {
        let checkpointStore = checkpointStore
        Task { [weak self] in
            guard let self else { return }
            do {
                guard let checkpoint = try await checkpointStore.load() else {
                    self.savedCheckpoint = nil
                    self.resumeAvailable = false
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
            } catch {
                self.send(.fail(.init(code: .processingFailed, message: error.localizedDescription, recoveryStep: .review)))
            }
        }
    }

    public func markExportFinished() { send(.exportFinished) }

    private func launch(resume: ProductPipelineCheckpoint?) {
        isRunning = true
        let inputs = state.inputAssets
        let bookID = resume?.bookID ?? "book-\(UUID().uuidString.lowercased())"
        let workspace = workspaceRoot.appendingPathComponent(bookID, isDirectory: true)
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
                    progress: { [weak self] progress in
                        await self?.apply(progress: progress)
                    },
                    checkpoint: { [weak self] checkpoint in
                        try? await checkpointStore.save(checkpoint)
                        await self?.apply(checkpoint: checkpoint)
                    }
                )
                try? await checkpointStore.clear()
                let workflow = reviewFactory(completion.reviewItems)
                self.savedCheckpoint = nil
                self.resumeAvailable = false
                self.reviewItems = completion.reviewItems
                self.reviewWorkflow = workflow
                self.send(.processingFinished(
                    bookPackageURL: completion.bookPackageURL,
                    reviewRequiredCount: completion.reviewItems.count
                ))
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

    private func apply(progress: ProductProgress) {
        send(.updateProgress(progress))
    }

    private func apply(checkpoint: ProductPipelineCheckpoint) {
        savedCheckpoint = checkpoint
        resumeAvailable = true
    }
}
#endif
