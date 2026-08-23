import Foundation

public enum ProductReviewDecision: String, Codable, Sendable, Equatable {
    case accept
    case reprocess
    case reocr
    case retake
    case exclude
    case deferDecision
}

public protocol ProductReviewWorkflow: Sendable {
    func unresolvedItems() async -> [ProductReviewItem]
    func apply(decision: ProductReviewDecision, to itemID: String) async throws
}

/// Type-erased boundary for the Review/Recovery lane. The product shell can
/// present review items now and swap in ReviewCore later without changing its
/// navigation or shared scanner contract.
public struct AnyProductReviewWorkflow: ProductReviewWorkflow, Sendable {
    private let unresolvedBlock: @Sendable () async -> [ProductReviewItem]
    private let applyBlock: @Sendable (ProductReviewDecision, String) async throws -> Void

    public init(
        unresolved: @escaping @Sendable () async -> [ProductReviewItem],
        apply: @escaping @Sendable (ProductReviewDecision, String) async throws -> Void
    ) {
        self.unresolvedBlock = unresolved
        self.applyBlock = apply
    }

    public func unresolvedItems() async -> [ProductReviewItem] {
        await unresolvedBlock()
    }

    public func apply(decision: ProductReviewDecision, to itemID: String) async throws {
        try await applyBlock(decision, itemID)
    }
}

public actor InMemoryProductReviewWorkflow: ProductReviewWorkflow {
    private var items: [ProductReviewItem]

    public init(items: [ProductReviewItem]) {
        self.items = items
    }

    public func unresolvedItems() async -> [ProductReviewItem] { items }

    public func apply(decision: ProductReviewDecision, to itemID: String) async throws {
        // Decisions that require actual recovery stay unresolved until the
        // ReviewCore adapter performs that recovery. Safe terminal decisions
        // can remove the item in the shell fixture/reference implementation.
        switch decision {
        case .accept, .exclude:
            items.removeAll { $0.id == itemID }
        case .reprocess, .reocr, .retake, .deferDecision:
            break
        }
    }
}
