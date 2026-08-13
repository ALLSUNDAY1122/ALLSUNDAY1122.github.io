import XCTest
@testable import RigakuSprint

final class RigakuSprintConfigurationTests: XCTestCase {
    func testDailyTargetsFollowGoldenMasterV21() {
        XCTAssertEqual(RigakuAppConfiguration.defaultDailyTarget, 8)
        XCTAssertEqual(RigakuAppConfiguration.allowedDailyTargets, [4, 8, 16])
    }

    func testThreeOfficialRoundsHaveVerifiedQuestionCounts() {
        XCTAssertEqual(RigakuAppConfiguration.examRounds.map(\.round), [60, 59, 58])
        XCTAssertEqual(RigakuAppConfiguration.examRounds.map(\.officialQuestionCount), [200, 200, 200])
        XCTAssertEqual(RigakuAppConfiguration.totalOfficialQuestionSlots, 600)
        XCTAssertTrue(RigakuAppConfiguration.examRounds.allSatisfy { $0.publicationStatus == .verifiedPublished })
    }

    func testOfficialSubjectListsMatchCurrentExamNotice() {
        XCTAssertEqual(RigakuAppConfiguration.generalSubjects.count, 8)
        XCTAssertEqual(RigakuAppConfiguration.practicalSubjects.count, 5)
        XCTAssertTrue(RigakuAppConfiguration.generalSubjects.contains("理学療法"))
        XCTAssertTrue(RigakuAppConfiguration.practicalSubjects.contains("運動学"))
    }

    func testMockRouteRequiresCompleteAuditedRound() {
        XCTAssertFalse(RigakuRouteGate.isComplete(audited: 0, expected: 200))
        XCTAssertFalse(RigakuRouteGate.isComplete(audited: 199, expected: 200))
        XCTAssertTrue(RigakuRouteGate.isComplete(audited: 200, expected: 200))
        XCTAssertFalse(RigakuRouteGate.isComplete(audited: 201, expected: 200))
        XCTAssertFalse(RigakuRouteGate.isComplete(audited: 200, expected: nil))
    }
}
