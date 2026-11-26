import XCTest
@testable import EnprintGuard

final class ExtractionServiceTests: XCTestCase {
    func testFullYearDateIsParsed() {
        let service = ExtractionService()
        let candidates = service.parseCandidates(from: ["11月30日までに提出してください", "2026年12月3日に遠足を行います"])
        XCTAssertEqual(candidates.count, 2)
        XCTAssertNil(candidates[0].dueDate)
        XCTAssertNotNil(candidates[1].dueDate)
    }

    func testAmbiguousYearIsNotInvented() {
        let service = ExtractionService()
        let candidates = service.parseCandidates(from: ["11月30日までに提出してください"])
        XCTAssertEqual(candidates.first?.rawDateText, "11月30日")
        XCTAssertNil(candidates.first?.dueDate)
    }

    func testOneLineCanProduceEventAndItemCandidates() {
        let service = ExtractionService()
        let line = "遠足には水筒とレジャーシートを持参してください"
        let candidates = service.parseCandidates(from: [line])
        XCTAssertEqual(Set(candidates.map(\.category)), Set([.event, .item]))
        XCTAssertTrue(candidates.allSatisfy { $0.sourceExcerpt == line })
    }
}
