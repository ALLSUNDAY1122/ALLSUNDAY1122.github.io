import Foundation

@main
struct ReviewQueueFixture {
    static func main() throws {
        var queue = ReviewQueue()

        let lowOCR = ReviewItem(
            bookID: "book-1",
            pageID: "p-002",
            source: .ocr,
            reason: "low confidence",
            confidence: 0.41,
            originalImageRef: "pages/original/p-002.jpg",
            sourceTimeMS: 2200
        )
        let duplicateLowOCR = ReviewItem(
            bookID: "book-1",
            pageID: "p-002",
            source: .ocr,
            reason: " LOW CONFIDENCE ",
            confidence: 0.39,
            originalImageRef: "pages/original/p-002.jpg",
            sourceTimeMS: 2200
        )
        let missing = ReviewItem(
            bookID: "book-1",
            pageID: "p-005",
            source: .pageAudit,
            reason: "missing page suspicion",
            confidence: 0.22,
            sourceTimeMS: 5100
        )
        let stageFailure = ReviewItem(
            bookID: "book-1",
            pageID: "p-003",
            source: .stageFailure,
            reason: "correction failed",
            originalImageRef: "pages/original/p-003.jpg",
            sourceTimeMS: 3100
        )

        queue.enqueue(missing)
        queue.enqueue(lowOCR)
        queue.enqueue(duplicateLowOCR)
        queue.enqueue(stageFailure)

        precondition(queue.snapshot.pending.count == 3, "stable ID dedupe failed")
        precondition(queue.snapshot.pending.map(\.pageID) == ["p-002", "p-003", "p-005"], "source order not preserved")

        let resolved = queue.resolve(.init(reviewID: lowOCR.reviewID, decision: .reOCR, note: "retry accurate OCR"))
        precondition(resolved)
        precondition(queue.snapshot.pending.count == 2)
        precondition(queue.snapshot.resolutions[lowOCR.reviewID]?.decision == .reOCR)

        let duplicateResolution = queue.resolve(.init(reviewID: lowOCR.reviewID, decision: .exclude))
        precondition(!duplicateResolution, "resolution should be idempotent")

        let data = try JSONEncoder().encode(queue.snapshot)
        let restored = try JSONDecoder().decode(ReviewQueueSnapshot.self, from: data)
        let resumed = ReviewQueue(snapshot: restored)
        precondition(resumed.snapshot.pending.count == 2)
        precondition(resumed.snapshot.resolutions.count == 1)
        precondition(resumed.snapshot.pending.first?.originalImageRef == stageFailure.originalImageRef)

        print("ReviewQueueFixture PASS pending=2 resolved=1 dedupe=PASS resume=PASS")
    }
}
