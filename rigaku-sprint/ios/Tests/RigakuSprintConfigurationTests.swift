import XCTest
@testable import RigakuSprint

final class RigakuSprintConfigurationTests: XCTestCase {
    func testDailyTargetsFollowGoldenMasterV21() {
        XCTAssertEqual(RigakuAppConfiguration.defaultDailyTarget, 8)
        XCTAssertEqual(RigakuAppConfiguration.allowedDailyTargets, [4, 8, 16])
    }

    func testExamRoundsDoNotGuessUnverifiedQuestionCounts() {
        XCTAssertEqual(RigakuAppConfiguration.examRounds.map(\.round), [60, 59, 58])
        XCTAssertEqual(RigakuAppConfiguration.examRounds[0].officialQuestionCount, 200)
        XCTAssertNil(RigakuAppConfiguration.examRounds[1].officialQuestionCount)
        XCTAssertNil(RigakuAppConfiguration.examRounds[2].officialQuestionCount)
    }

    func testOfficialSubjectListsMatchCurrentExamNotice() {
        XCTAssertEqual(RigakuAppConfiguration.generalSubjects.count, 8)
        XCTAssertEqual(RigakuAppConfiguration.practicalSubjects.count, 5)
        XCTAssertTrue(RigakuAppConfiguration.generalSubjects.contains("理学療法"))
        XCTAssertTrue(RigakuAppConfiguration.practicalSubjects.contains("運動学"))
    }
}
