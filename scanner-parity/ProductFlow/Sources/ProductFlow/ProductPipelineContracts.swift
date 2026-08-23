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

/// Minimal durable state retained after the processing workspace is purged.
/// It contains only the final local BookPackage staging URL and review metadata;
/// raw source media and intermediate page/OCR artifacts are intentionally absent.
public struct ProductCompletionSnapshot: Codable, Sendable, Equatable {
    public let bookPackageURL: URL
    public let reviewItems: [ProductReviewItem]
    public let pageCount: Int
    public let completedAt: Date

    public init(
        bookPackageURL: URL,
        reviewItems: [ProductReviewItem],
        pageCount: Int,
        completedAt: Date = Date()
    ) {
        self.bookPackageURL = bookPackageURL
        self.reviewItems = reviewItems
        self.pageCount = max(0, pageCount)
        self.completedAt = completedAt
    }
}

public struct ProductPipelineCheckpoint: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let runID: String
    public let bookID: String
    public let inputAssetIDs: [String]
    /// Durable imported input descriptors used only while an interrupted run may resume.
    /// Optional preserves decode compatibility with schema-v1 checkpoints.
    public let inputAssets: [ProductInputAsset]?
    public let completedArtifacts: [ProductStageArtifact]
    public let lastProgress: ProductProgress?
    /// Present for terminal schema-v3 checkpoints after raw/intermediate cleanup.
    public let completion: ProductCompletionSnapshot?
    public let updatedAt: Date

    public init(
        schemaVersion: Int = 3,
        runID: String,
        bookID: String,
        inputAssetIDs: [String],
        inputAssets: [ProductInputAsset]? = nil,
        completedArtifacts: [ProductStageArtifact],
        lastProgress: ProductProgress?,
        completion: ProductCompletionSnapshot? = nil,
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.bookID = bookID
        self.inputAssetIDs = inputAssetIDs
        self.inputAssets = inputAssets
        self.completedArtifacts = completedArtifacts
        self.lastProgress = lastProgress
        self.completion = completion
        self.updatedAt = updatedAt
    }

    /// Active-run resume state must be an exact canonical prefix with every output still present.
    public var hasCanonicalExistingArtifacts: Bool {
        guard completion == nil else { return false }
        guard completedArtifacts.count <= ProductProcessingStage.allCases.count else { return false }
        let expected = Array(ProductProcessingStage.allCases.prefix(completedArtifacts.count))
        guard completedArtifacts.map(\.stage) == expected else { return false }
        return completedArtifacts.allSatisfy { FileManager.default.fileExists(atPath: $0.outputURL.path) }
    }

    /// Terminal completion may be schema-v3 lightweight state, or a legacy v2 five-stage checkpoint.
    public var terminalCompletion: ProductCompletionSnapshot? {
        if let completion,
           FileManager.default.fileExists(atPath: completion.bookPackageURL.path) {
            return completion
        }

        guard completion == nil,
              completedArtifacts.count == ProductProcessingStage.allCases.count else { return nil }
        let expected = ProductProcessingStage.allCases
        guard completedArtifacts.map(\.stage) == expected,
              completedArtifacts.allSatisfy({ FileManager.default.fileExists(atPath: $0.outputURL.path) }),
              let package = completedArtifacts.last,
              package.stage == .packageWrite else { return nil }

        var seen = Set<String>()
        let reviews = completedArtifacts
            .flatMap(\.reviewItems)
            .filter { seen.insert($0.id).inserted }
        return ProductCompletionSnapshot(
            bookPackageURL: package.outputURL,
            reviewItems: reviews,
            pageCount: package.pageCount,
            completedAt: updatedAt
        )
    }

    public var isCompletedPackageCheckpoint: Bool { terminalCompletion != nil }
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
