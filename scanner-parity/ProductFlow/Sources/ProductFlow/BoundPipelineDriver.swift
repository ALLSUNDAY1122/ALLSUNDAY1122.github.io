import Foundation

public struct ProductPipelineStageBinding: Sendable {
    public let stage: ProductProcessingStage
    public let execute: @Sendable (
        ProductPipelineRequest,
        [ProductStageArtifact],
        @escaping ProductStageProgressHandler
    ) async throws -> ProductStageArtifact

    public init(
        stage: ProductProcessingStage,
        execute: @escaping @Sendable (
            ProductPipelineRequest,
            [ProductStageArtifact],
            @escaping ProductStageProgressHandler
        ) async throws -> ProductStageArtifact
    ) {
        self.stage = stage
        self.execute = execute
    }
}

public actor BoundProductPipelineDriver: ProductPipelineDriving {
    private let bindings: [ProductProcessingStage: ProductPipelineStageBinding]
    private var cancelRequested = false

    public init(bindings: [ProductPipelineStageBinding]) {
        self.bindings = Dictionary(uniqueKeysWithValues: bindings.map { ($0.stage, $0) })
    }

    public func cancel() async { cancelRequested = true }

    public func run(
        request: ProductPipelineRequest,
        resume: ProductPipelineCheckpoint?,
        progress: @escaping ProductStageProgressHandler,
        checkpoint: @escaping ProductCheckpointHandler
    ) async throws -> ProductPipelineCompletion {
        cancelRequested = false
        let runID: String
        var artifacts: [ProductStageArtifact]
        if let resume {
            guard resume.bookID == request.bookID,
                  resume.inputAssetIDs == request.inputs.map(\.id),
                  resume.hasCanonicalExistingArtifacts else {
                throw ProductPipelineDriverError.invalidResumeCheckpoint
            }
            runID = resume.runID
            artifacts = resume.completedArtifacts
        } else {
            runID = UUID().uuidString
            artifacts = []
        }

        let completedStages = Set(artifacts.map(\.stage))
        for stage in ProductProcessingStage.allCases where !completedStages.contains(stage) {
            try checkCancellation()
            guard let binding = bindings[stage] else { throw ProductPipelineDriverError.missingStageBinding(stage) }
            await progress(ProductProgress(stage: stage, fraction: 0, completedUnits: 0, totalUnits: nil))
            let artifact: ProductStageArtifact
            do {
                artifact = try await binding.execute(request, artifacts) { update in await progress(update) }
            } catch is CancellationError {
                throw ProductPipelineDriverError.cancelled
            } catch let error as ProductPipelineDriverError {
                throw error
            } catch {
                throw ProductPipelineDriverError.stageFailed(stage: stage, detail: error.localizedDescription)
            }
            try checkCancellation()
            guard artifact.stage == stage, FileManager.default.fileExists(atPath: artifact.outputURL.path) else {
                throw ProductPipelineDriverError.stageFailed(stage: stage, detail: "binding returned a mismatched or missing artifact")
            }
            artifacts.append(artifact)
            let stageProgress = ProductProgress(stage: stage, fraction: 1, completedUnits: artifact.pageCount, totalUnits: artifact.pageCount)
            await progress(stageProgress)
            await checkpoint(ProductPipelineCheckpoint(
                runID: runID,
                bookID: request.bookID,
                inputAssetIDs: request.inputs.map(\.id),
                inputAssets: request.inputs,
                completedArtifacts: artifacts,
                lastProgress: stageProgress
            ))
        }

        try checkCancellation()
        guard let package = artifacts.last(where: { $0.stage == .packageWrite }), FileManager.default.fileExists(atPath: package.outputURL.path) else {
            throw ProductPipelineDriverError.missingStageBinding(.packageWrite)
        }
        let reviews = Self.deduplicatedReviews(artifacts.flatMap(\.reviewItems))
        return ProductPipelineCompletion(bookPackageURL: package.outputURL, reviewItems: reviews, pageCount: package.pageCount)
    }

    private func checkCancellation() throws {
        if cancelRequested || Task.isCancelled { throw ProductPipelineDriverError.cancelled }
    }

    private static func deduplicatedReviews(_ items: [ProductReviewItem]) -> [ProductReviewItem] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }
    }
}
