import Foundation

public struct ProductReviewItem: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let pageIDs: [String]
    public let reason: String
    public let detail: String

    public init(id: String, pageIDs: [String], reason: String, detail: String) {
        self.id = id
        self.pageIDs = pageIDs
        self.reason = reason
        self.detail = detail
    }
}

public struct ProductPipelineRequest: Sendable, Equatable {
    public let bookID: String
    public let inputs: [ProductInputAsset]
    public let workspaceURL: URL

    public init(bookID: String, inputs: [ProductInputAsset], workspaceURL: URL) {
        self.bookID = bookID
        self.inputs = inputs
        self.workspaceURL = workspaceURL
    }
}

public struct ProductStageArtifact: Codable, Sendable, Equatable {
    public let stage: ProductProcessingStage
    public let outputURL: URL
    public let pageCount: Int
    public let reviewItems: [ProductReviewItem]

    public init(stage: ProductProcessingStage, outputURL: URL, pageCount: Int, reviewItems: [ProductReviewItem] = []) {
        self.stage = stage
        self.outputURL = outputURL
        self.pageCount = max(0, pageCount)
        self.reviewItems = reviewItems
    }
}

public struct ProductPipelineCheckpoint: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let runID: String
    public let bookID: String
    public let inputAssetIDs: [String]
    /// Durable imported input descriptors used to restore a processing run after app relaunch.
    /// Optional preserves decode compatibility with schema-v1 checkpoints created before
    /// relaunch input restoration was added.
    public let inputAssets: [ProductInputAsset]?
    public let completedArtifacts: [ProductStageArtifact]
    public let lastProgress: ProductProgress?
    public let updatedAt: Date

    public init(
        schemaVersion: Int = 2,
        runID: String,
        bookID: String,
        inputAssetIDs: [String],
        inputAssets: [ProductInputAsset]? = nil,
        completedArtifacts: [ProductStageArtifact],
        lastProgress: ProductProgress?,
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.bookID = bookID
        self.inputAssetIDs = inputAssetIDs
        self.inputAssets = inputAssets
        self.completedArtifacts = completedArtifacts
        self.lastProgress = lastProgress
        self.updatedAt = updatedAt
    }

    public var hasCanonicalExistingArtifacts: Bool {
        guard completedArtifacts.count <= ProductProcessingStage.allCases.count else { return false }
        let expected = Array(ProductProcessingStage.allCases.prefix(completedArtifacts.count))
        guard completedArtifacts.map(\.stage) == expected else { return false }
        return completedArtifacts.allSatisfy { FileManager.default.fileExists(atPath: $0.outputURL.path) }
    }

    public var isCompletedPackageCheckpoint: Bool {
        hasCanonicalExistingArtifacts
            && completedArtifacts.count == ProductProcessingStage.allCases.count
            && completedArtifacts.last?.stage == .packageWrite
    }
}

public struct ProductPipelineCompletion: Sendable, Equatable {
    public let bookPackageURL: URL
    public let reviewItems: [ProductReviewItem]
    public let pageCount: Int

    public init(bookPackageURL: URL, reviewItems: [ProductReviewItem], pageCount: Int) {
        self.bookPackageURL = bookPackageURL
        self.reviewItems = reviewItems
        self.pageCount = max(0, pageCount)
    }
}

public enum ProductPipelineDriverError: Error, LocalizedError, Equatable {
    case missingStageBinding(ProductProcessingStage)
    case invalidResumeCheckpoint
    case cancelled
    case stageFailed(stage: ProductProcessingStage, detail: String)

    public var errorDescription: String? {
        switch self {
        case .missingStageBinding(let stage): return "Pipeline stage is not connected: \(stage.rawValue)"
        case .invalidResumeCheckpoint: return "Saved processing state does not match the selected input."
        case .cancelled: return "Processing was cancelled."
        case .stageFailed(let stage, let detail): return "\(stage.rawValue) failed: \(detail)"
        }
    }
}

public typealias ProductStageProgressHandler = @Sendable (ProductProgress) async -> Void
public typealias ProductCheckpointHandler = @Sendable (ProductPipelineCheckpoint) async -> Void

public protocol ProductPipelineDriving: Sendable {
    func run(
        request: ProductPipelineRequest,
        resume: ProductPipelineCheckpoint?,
        progress: @escaping ProductStageProgressHandler,
        checkpoint: @escaping ProductCheckpointHandler
    ) async throws -> ProductPipelineCompletion

    func cancel() async
}
