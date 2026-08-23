import XCTest
@testable import PageAudit

final class PageAuditTests: XCTestCase {
    private func number(
        _ pageID: String,
        _ value: Int,
        confidence: Double = 0.995,
        score: Double = 99.5
    ) -> PageNumberObservation {
        .init(
            pageID: pageID,
            value: value,
            confidence: confidence,
            rawText: String(value),
            boundingBox: .init(x: 0.9, y: 0.03, width: 0.05, height: 0.03),
            score: score
        )
    }

    func testFooterFullwidthPageNumberBeatsBodyYear() {
        let candidates = [
            OCRPageNumberCandidate(
                text: "2026年8月",
                confidence: 0.99,
                boundingBox: .init(x: 0.3, y: 0.45, width: 0.2, height: 0.05)
            ),
            OCRPageNumberCandidate(
                text: "１２７",
                confidence: 0.94,
                boundingBox: .init(x: 0.90, y: 0.02, width: 0.06, height: 0.03)
            )
        ]

        let best = PageNumberScorer.bestObservation(pageID: "p127", candidates: candidates)
        XCTAssertEqual(best?.value, 127)
    }

    func testCandidateContainingTwoNumbersIsRejected() {
        let candidate = OCRPageNumberCandidate(
            text: "12 / 13",
            confidence: 0.99,
            boundingBox: .init(x: 0.9, y: 0.02, width: 0.08, height: 0.03)
        )
        XCTAssertNil(PageNumberScorer.observation(pageID: "p", candidate: candidate))
    }

    func testDetectsAdjacentReversalWithoutFalseMissing() {
        let pages = [
            PageAuditInput(pageID: "p10", sourceTimeMs: 1000, pageNumber: number("p10", 10)),
            PageAuditInput(pageID: "p12", sourceTimeMs: 2000, pageNumber: number("p12", 12)),
            PageAuditInput(pageID: "p11", sourceTimeMs: 3000, pageNumber: number("p11", 11)),
            PageAuditInput(pageID: "p13", sourceTimeMs: 4000, pageNumber: number("p13", 13))
        ]

        let result = PageIntegrityAuditor().audit(pages)
        XCTAssertEqual(result.orderedPageIDs, ["p10", "p11", "p12", "p13"])
        XCTAssertEqual(result.reversalEvents.count, 1)
        XCTAssertTrue(result.missingPageSuspicions.isEmpty)
        XCTAssertTrue(result.reviewRequired.allSatisfy { $0.reason != .possibleReversal })
        XCTAssertTrue(result.autoFixes.contains { $0.kind == .swapAdjacentPages })
    }

    func testDetectsRealMissingPage() {
        let pages = [
            PageAuditInput(pageID: "p10", sourceTimeMs: 1000, pageNumber: number("p10", 10)),
            PageAuditInput(pageID: "p12", sourceTimeMs: 2000, pageNumber: number("p12", 12)),
            PageAuditInput(pageID: "p13", sourceTimeMs: 3000, pageNumber: number("p13", 13))
        ]

        let result = PageIntegrityAuditor().audit(pages)
        XCTAssertEqual(result.missingPageSuspicions.first?.expectedPageNumbers, [11])
        XCTAssertTrue(result.reviewRequired.contains { $0.reason == .missingPage })
    }

    func testHighConfidenceDuplicateIsRemoved() {
        let text = "このページは同一本文です。重複判定のため十分な長さを持たせます。"
        let hash: UInt64 = 0x0F0F0F0F0F0F0F0F
        let pages = [
            PageAuditInput(
                pageID: "p20a", sourceTimeMs: 1000, pageNumber: number("p20a", 20),
                perceptualHash: hash, text: text
            ),
            PageAuditInput(
                pageID: "p20b", sourceTimeMs: 2000, pageNumber: number("p20b", 20),
                perceptualHash: hash, text: text
            ),
            PageAuditInput(
                pageID: "p21", sourceTimeMs: 3000, pageNumber: number("p21", 21),
                perceptualHash: 0xFFFFFFFFFFFFFFFF, text: "次ページの別本文です"
            )
        ]

        let result = PageIntegrityAuditor().audit(pages)
        XCTAssertEqual(result.orderedPageIDs, ["p20a", "p21"])
        XCTAssertTrue(result.autoFixes.contains { $0.kind == .removeDuplicate && $0.pageIDs == ["p20b"] })
        XCTAssertTrue(result.duplicateGroups.first?.evidence.contains(.imageSimilarity) == true)
        XCTAssertTrue(result.duplicateGroups.first?.evidence.contains(.textSimilarity) == true)
    }

    func testLowConfidenceNumberDoesNotChangeOrder() {
        let low = number("p31", 31, confidence: 0.6, score: 60)
        let pages = [
            PageAuditInput(pageID: "p32", sourceTimeMs: 1000, pageNumber: number("p32", 32)),
            PageAuditInput(pageID: "p31", sourceTimeMs: 2000, pageNumber: low)
        ]

        let result = PageIntegrityAuditor().audit(pages)
        XCTAssertEqual(result.orderedPageIDs, ["p32", "p31"])
        XCTAssertTrue(result.reviewRequired.contains { $0.reason == .lowConfidencePageNumber })
        XCTAssertFalse(result.autoFixes.contains { $0.kind == .swapAdjacentPages })
    }

    func testPerBookMarkdownReportContainsAuditSections() {
        let result = PageIntegrityAuditor().audit([
            PageAuditInput(pageID: "p1", sourceTimeMs: 1000, pageNumber: number("p1", 1))
        ])
        let markdown = PageAuditReportFormatter.markdown(bookID: "book-fixture", result: result)

        XCTAssertTrue(markdown.contains("book_id: `book-fixture`"))
        XCTAssertTrue(markdown.contains("## Final order"))
        XCTAssertTrue(markdown.contains("## Review required"))
    }
}
