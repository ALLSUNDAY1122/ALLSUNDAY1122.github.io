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
    private var processingTask: Task<Void, Never>?
    private var savedCheckpoint: ProductPipelineCheckpoint?
    private let workspaceRoot: URL

    public init(
        state: ProductFlowState = .init(),
        driver: any ProductPipelineDriving = BoundProductPipelineDriver(bindings: []),
        checkpointStore: (any ProductCheckpointPersisting)? = nil,
        workspaceRoot: URL? = nil
    ) {
        self.state = state
        self.driver = driver
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

    public func restoreCheckpoint() {
        Task {
            do {
                let checkpoint = try await checkpointStore.load()
                await MainActor.run {
                    self.savedCheckpoint = checkpoint
                    self.resumeAvailable = checkpoint != nil
                }
            } catch {
                await MainActor.run { self.resumeAvailable = false }
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
        Task { await driver.cancel() }
        send(.cancel)
        isRunning = false
    }

    public func resolveReviewItem(_ itemID: String, decision: ProductReviewDecision, workflow: any ProductReviewWorkflow) {
        Task {
            do {
                try await workflow.apply(decision: decision, to: itemID)
                let remaining = await workflow.unresolvedItems()
                await MainActor.run {
                    self.reviewItems = remaining
                    self.send(.reviewResolved(remaining: remaining.count))
                }
            } catch {
                await MainActor.run {
                    self.send(.fail(.init(code: .processingFailed, message: error.localizedDescription, recoveryStep: .review)))
                }
            }
        }
    }

    private func launch(resume: ProductPipelineCheckpoint?) {
        isRunning = true
        let inputs = state.inputAssets
        let bookID = resume?.bookID ?? "book-\(UUID().uuidString.lowercased())"
        let workspace = workspaceRoot.appendingPathComponent(bookID, isDirectory: true)
        let request = ProductPipelineRequest(bookID: bookID, inputs: inputs, workspaceURL: workspace)

        processingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let completion = try await self.driver.run(
                    request: request,
                    resume: resume,
                    progress: { progress in
                        await MainActor.run { self.send(.updateProgress(progress)) }
                    },
                    checkpoint: { checkpoint in
                        try? await self.checkpointStore.save(checkpoint)
                        await MainActor.run {
                            self.savedCheckpoint = checkpoint
                            self.resumeAvailable = true
                        }
                    }
                )
                try? await self.checkpointStore.clear()
                await MainActor.run {
                    self.savedCheckpoint = nil
                    self.resumeAvailable = false
                    self.reviewItems = completion.reviewItems
                    self.send(.processingFinished(
                        bookPackageURL: completion.bookPackageURL,
                        reviewRequiredCount: completion.reviewItems.count
                    ))
                    self.isRunning = false
                }
            } catch {
                await MainActor.run {
                    let failure: ProductFlowFailure
                    if error is CancellationError || error as? ProductPipelineDriverError == .cancelled {
                        failure = .init(code: .cancelled, message: "Processing was cancelled. Saved progress can be resumed when available.", recoveryStep: .ready)
                    } else {
                        failure = .init(code: .processingFailed, message: error.localizedDescription, recoveryStep: .ready)
                    }
                    self.send(.fail(failure))
                    self.isRunning = false
                }
            }
        }
    }
}
#endif
