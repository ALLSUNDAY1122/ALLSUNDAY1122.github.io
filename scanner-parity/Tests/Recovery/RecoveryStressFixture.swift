import Foundation

@main
enum RecoveryStressFixture {
    static func main() throws {
        var adapter = ReviewRecoveryAdapter()
        let bookID = "stress-book"
        var acceptedEvents = 0

        for i in 1...240 {
            let pageID = String(format: "p-%03d", i)
            let outcome: RecoveryPageEvent.Outcome
            let source: ReviewSource
            let reason: String?
            let confidence: Double?
            if i % 79 == 0 {
                outcome = .failed; source = .stageFailure; reason = "decode-failure"; confidence = nil
            } else if i % 37 == 0 {
                outcome = .lowConfidence; source = .ocr; reason = "low-ocr-confidence"; confidence = 0.42
            } else {
                outcome = .completed; source = .pageAudit; reason = nil; confidence = 0.98
            }
            if adapter.consume(.init(bookID: bookID, pageID: pageID, sourceTimeMS: i * 1000, originalImageRef: "images/\(pageID).jpg", source: source, outcome: outcome, reason: reason, confidence: confidence)) { acceptedEvents += 1 }
        }

        precondition(acceptedEvents == 240)
        let checkpoint = adapter.checkpoint(bookID: bookID)
        let pendingBefore = adapter.pendingReviewItems().count
        precondition(pendingBefore == (240 / 79) + (240 / 37))

        let store = RecoveryCheckpointStore()
        let data = try store.encode(checkpoint)
        let restored = try store.decode(data)
        var resumed = ReviewRecoveryAdapter(checkpoint: restored)

        var duplicateAccepted = 0
        for i in 1...240 {
            let pageID = String(format: "p-%03d", i)
            if resumed.consume(.init(bookID: bookID, pageID: pageID, sourceTimeMS: i * 1000, source: .pageAudit, outcome: .completed)) { duplicateAccepted += 1 }
        }

        // Completed pages must not replay; unresolved review pages may be presented again but stable IDs dedupe them.
        precondition(duplicateAccepted == pendingBefore)
        precondition(resumed.pendingReviewItems().count == pendingBefore)

        let originalOrder = resumed.pendingReviewItems().map(\.sourceTimeMS)
        precondition(originalOrder == originalOrder.sorted { ($0 ?? Int.max) < ($1 ?? Int.max) })

        let first = resumed.pendingReviewItems().first!
        precondition(resumed.apply(reviewID: first.reviewID, decision: .retry, note: "fixture retry"))
        precondition(!resumed.apply(reviewID: first.reviewID, decision: .retry))
        precondition(resumed.pendingReviewItems().count == pendingBefore - 1)

        let secondCheckpoint = resumed.checkpoint(bookID: bookID)
        let secondData = try store.encode(secondCheckpoint)
        let secondRestored = try store.decode(secondData)
        precondition(secondRestored.reviewSnapshot.pending.count == pendingBefore - 1)
        precondition(secondRestored.reviewSnapshot.resolutions.count == 1)

        print("RecoveryStressFixture PASS pages=240 pending=\(pendingBefore) duplicateAccepted=\(duplicateAccepted) resolved=1")
    }
}
