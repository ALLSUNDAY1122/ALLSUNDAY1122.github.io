import Foundation

public struct LongRunPage: Codable, Sendable, Hashable {
    public let index: Int
    public let pageID: String
    public let estimatedBytes: Int
    public init(index: Int, pageID: String, estimatedBytes: Int = 1_500_000) {
        self.index = index; self.pageID = pageID; self.estimatedBytes = estimatedBytes
    }
}

public struct LongRunReviewItem: Codable, Sendable, Hashable {
    public let index: Int
    public let pageID: String
    public let reason: String
}

public struct LongRunCheckpoint: Codable, Sendable {
    public var completedIndices: Set<Int>
    public var reviewItems: [LongRunReviewItem]
    public var lastAttemptedIndex: Int?
    public init(completedIndices: Set<Int> = [], reviewItems: [LongRunReviewItem] = [], lastAttemptedIndex: Int? = nil) {
        self.completedIndices = completedIndices
        self.reviewItems = reviewItems
        self.lastAttemptedIndex = lastAttemptedIndex
    }
}

public struct LongRunReport: Codable, Sendable {
    public let totalInput: Int
    public let processedThisRun: Int
    public let skippedAsCompleted: Int
    public let completedTotal: Int
    public let reviewTotal: Int
    public let elapsedMilliseconds: Int
    public let peakInFlightPages: Int
    public let peakEstimatedWorkingSetBytes: Int
    public let resumed: Bool
}

public enum LongRunHarnessError: Error { case interrupted }

public final class LongRunHarness {
    public typealias Processor = (LongRunPage) throws -> Void
    private let checkpointURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(checkpointURL: URL) { self.checkpointURL = checkpointURL }

    public func loadCheckpoint() throws -> LongRunCheckpoint {
        guard FileManager.default.fileExists(atPath: checkpointURL.path) else { return LongRunCheckpoint() }
        return try decoder.decode(LongRunCheckpoint.self, from: Data(contentsOf: checkpointURL))
    }

    private func save(_ checkpoint: LongRunCheckpoint) throws {
        let data = try encoder.encode(checkpoint)
        let dir = checkpointURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: checkpointURL, options: .atomic)
    }

    public func run<S: Sequence>(pages: S, interruptAfterNewAttempts: Int? = nil, processor: Processor) throws -> LongRunReport where S.Element == LongRunPage {
        var checkpoint = try loadCheckpoint()
        let resumed = !checkpoint.completedIndices.isEmpty || !checkpoint.reviewItems.isEmpty
        let started = DispatchTime.now().uptimeNanoseconds
        var totalInput = 0, processed = 0, skipped = 0, attempts = 0
        var peakPages = 0, peakBytes = 0
        let knownReview = Set(checkpoint.reviewItems.map(\.index))

        for page in pages {
            totalInput += 1
            if checkpoint.completedIndices.contains(page.index) || knownReview.contains(page.index) {
                skipped += 1
                continue
            }
            if let limit = interruptAfterNewAttempts, attempts >= limit {
                try save(checkpoint)
                throw LongRunHarnessError.interrupted
            }
            attempts += 1
            peakPages = max(peakPages, 1)
            peakBytes = max(peakBytes, page.estimatedBytes)
            checkpoint.lastAttemptedIndex = page.index
            do {
                try processor(page)
                checkpoint.completedIndices.insert(page.index)
                processed += 1
            } catch {
                checkpoint.reviewItems.append(.init(index: page.index, pageID: page.pageID, reason: String(describing: error)))
            }
            try save(checkpoint)
        }

        let elapsed = Int((DispatchTime.now().uptimeNanoseconds - started) / 1_000_000)
        return LongRunReport(totalInput: totalInput, processedThisRun: processed, skippedAsCompleted: skipped, completedTotal: checkpoint.completedIndices.count, reviewTotal: checkpoint.reviewItems.count, elapsedMilliseconds: elapsed, peakInFlightPages: peakPages, peakEstimatedWorkingSetBytes: peakBytes, resumed: resumed)
    }
}
