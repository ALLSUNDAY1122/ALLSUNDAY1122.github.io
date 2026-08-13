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

    func testAppBundleLoadsCompleteAuditedRound60WithoutDuplicateIDs() throws {
        let questions = try RigakuQuestionRepository.loadBundled(bundle: Bundle.main)
        let ids = questions.map(\.id)
        let round60 = questions.filter { $0.examRound == "60" }

        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(round60.count, 200)
        XCTAssertEqual(round60.filter { $0.id.contains("-AM-") }.count, 100)
        XCTAssertEqual(round60.filter { $0.id.contains("-PM-") }.count, 100)
    }

    func testRound60MockScoringCanonLoadsFromAppBundle() throws {
        let repository = try RigakuExamScoringRepository.loadBundled(bundle: Bundle.main)
        guard let config = repository.examConfig.roundConfig["60"] else {
            return XCTFail("R60 scoring configuration missing")
        }
        XCTAssertEqual(config.officialScoring.generalMax, 159)
        XCTAssertEqual(config.officialScoring.practicalMax, 114)
        XCTAssertEqual(config.officialScoring.totalMax, 273)
        XCTAssertEqual(config.officialScoring.passTotal, 164)
        XCTAssertEqual(config.officialScoring.passPractical, 40)
    }
}
