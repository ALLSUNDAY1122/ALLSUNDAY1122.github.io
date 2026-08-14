import XCTest
@testable import HokenshiSprintFeature

final class HokenshiReleaseResourceTests: XCTestCase {
    func testBundledReleaseBankLoadsExactly330Questions() throws {
        let store = try HokenshiReleaseContentStore.load()
        XCTAssertEqual(store.allRecords.count, 330)
        XCTAssertEqual(store.productQuestions.count, 330)
        for round in 1...3 {
            XCTAssertEqual(store.questions(round: round).count, 110)
        }
    }

    func testBundledReleaseBankKeepsTenSubjectsAtThirtyThreeEach() throws {
        let store = try HokenshiReleaseContentStore.load()
        for subject in HokenshiExamBlueprint.current.subjects {
            XCTAssertEqual(store.questions(subject: subject).count, 33, subject)
        }
    }

    func testBundledReleaseBankIsReleaseReadyAndUsesHttpsSources() throws {
        let store = try HokenshiReleaseContentStore.load()
        for row in store.allRecords {
            XCTAssertEqual(row.auditStatus, .releaseReady, row.id)
            XCTAssertEqual(row.originType, "original_from_primary_source", row.id)
            XCTAssertTrue(row.sourceURL.hasPrefix("https://"), row.id)
            XCTAssertEqual(row.sourceCheckedAt, "2026-08-13", row.id)
            XCTAssertEqual(row.lawBaselineDate, "2026-08-13", row.id)
        }
    }

    func testEachMockCanSplitIntoMorningAndAfternoonFiftyFive() throws {
        let store = try HokenshiReleaseContentStore.load()
        for round in 1...3 {
            let rows = store.questions(round: round)
            XCTAssertEqual(Array(rows.prefix(55)).count, 55)
            XCTAssertEqual(Array(rows.suffix(55)).count, 55)
            XCTAssertEqual(rows.first?.questionNumber, 1)
            XCTAssertEqual(rows.last?.questionNumber, 110)
        }
    }
}
