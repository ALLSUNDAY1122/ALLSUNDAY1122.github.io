import Foundation

@main
enum RecoveryStressFixture {
    static func makeEvent(_ i: Int, bookID: String) -> RecoveryPageEvent {
        let pageID = String(format: "p-%03d", i)
        if i % 79 == 0 {
            return .init(bookID: bookID, pageID: pageID, sourceTimeMS: i * 1000, originalImageRef: "images/\(pageID).jpg", source: .stageFailure, outcome: .failed, reason: "decode-failure")
        }
        if i % 37 == 0 {
            return .init(bookID: bookID, pageID: pageID, sourceTimeMS: i * 1000, originalImageRef: "images/\(pageID).jpg", source: .ocr, outcome: .lowConfidence, reason: "low-ocr-confidence", confidence: 0.42)
        }
        return .init(bookID: bookID, pageID: pageID, sourceTimeMS: i * 1000, originalImageRef: "images/\(pageID).jpg", source: .pageAudit, outcome: .completed, confidence: 0.98)
    }

    static func main() throws {
        let bookID = "stress-book"
        let store = RecoveryCheckpointStore()
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("scanner-parity-recovery-fixture-\(UUID().uuidString)")
        let checkpointURL = tempRoot.appendingPathComponent("checkpoint.json")
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        var app = AppShellReviewAdapter()
        for i in 1...123 {
            precondition(app.ingest(makeEvent(i, bookID: bookID)))
        }

        try store.write(app.checkpoint(bookID: bookID), to: checkpointURL)
        let restoredCheckpoint = try store.read(from: checkpointURL)
        var resumed = AppShellReviewAdapter(checkpoint: restoredCheckpoint)

        var replayAccepted = 0
        for i in 1...123 {
            if resumed.ingest(makeEvent(i, bookID: bookID)) { replayAccepted += 1 }
        }
        precondition(replayAccepted == 0, "completed/review-pending pages must not replay after checkpoint")

        for i in 124...240 {
            precondition(resumed.ingest(makeEvent(i, bookID: bookID)))
        }

        let expectedPending = (240 / 79) + (240 / 37)
        precondition(resumed.viewState.pendingCount == expectedPending)
        precondition(resumed.viewState.completedPageCount == 240 - expectedPending)
        precondition(resumed.viewState.lastSourceTimeMS == 240_000)

        let orderedTimes = resumed.core.pendingReviewItems().map(\.sourceTimeMS)
        precondition(orderedTimes == orderedTimes.sorted { ($0 ?? Int.max) < ($1 ?? Int.max) })

        let first = resumed.core.pendingReviewItems().first!
        let action = resumed.decide(reviewID: first.reviewID, decision: .retry, note: "retry fixture")
        precondition(action == .retryStage(pageID: first.pageID))
        precondition(resumed.ingest(.init(bookID: bookID, pageID: first.pageID, sourceTimeMS: first.sourceTimeMS, originalImageRef: first.originalImageRef, source: .pageAudit, outcome: .completed)))
        precondition(resumed.viewState.pendingCount == expectedPending - 1)
        precondition(resumed.viewState.completedPageCount == 240 - expectedPending + 1)

        try store.write(resumed.checkpoint(bookID: bookID), to: checkpointURL)
        let secondRestore = AppShellReviewAdapter(checkpoint: try store.read(from: checkpointURL))
        precondition(secondRestore.viewState.pendingCount == expectedPending - 1)
        precondition(secondRestore.viewState.completedPageCount == 240 - expectedPending + 1)

        print("RecoveryStressFixture PASS pages=240 interruptedAt=123 pending=\(secondRestore.viewState.pendingCount) completed=\(secondRestore.viewState.completedPageCount) replayAccepted=\(replayAccepted)")
    }
}
