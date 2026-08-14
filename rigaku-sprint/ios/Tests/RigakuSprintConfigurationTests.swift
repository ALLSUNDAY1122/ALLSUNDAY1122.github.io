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

    func testExternalIdentifiersRejectMissingOrUnexpandedValues() {
        XCTAssertNil(RigakuAppConfiguration.normalizedExternalIdentifier(nil))
        XCTAssertNil(RigakuAppConfiguration.normalizedExternalIdentifier(""))
        XCTAssertNil(RigakuAppConfiguration.normalizedExternalIdentifier("   "))
        XCTAssertNil(RigakuAppConfiguration.normalizedExternalIdentifier("$(RIGAKU_IAP_PRODUCT_ID)"))
        XCTAssertNil(RigakuAppConfiguration.normalizedExternalIdentifier("${RIGAKU_BUNDLE_ID}"))
    }

    func testExternalIdentifiersPreserveCanonicalInjectedValues() {
        XCTAssertEqual(
            RigakuAppConfiguration.normalizedExternalIdentifier("  jp.example.rigaku.premium  "),
            "jp.example.rigaku.premium"
        )
        XCTAssertEqual(
            RigakuAppConfiguration.normalizedExternalIdentifier("jp.example.rigaku"),
            "jp.example.rigaku"
        )
    }

    func testMockRouteRequiresCompleteAuditedRound() {
        XCTAssertFalse(RigakuRouteGate.isComplete(audited: 0, expected: 200))
        XCTAssertFalse(RigakuRouteGate.isComplete(audited: 199, expected: 200))
        XCTAssertTrue(RigakuRouteGate.isComplete(audited: 200, expected: 200))
        XCTAssertFalse(RigakuRouteGate.isComplete(audited: 201, expected: 200))
        XCTAssertFalse(RigakuRouteGate.isComplete(audited: 200, expected: nil))
    }

    func testAppBundleLoadsAllThreeCompleteAuditedRoundsWithoutDuplicateIDs() throws {
        let questions = try RigakuQuestionRepository.loadBundled(bundle: Bundle.main)
        let ids = questions.map(\.id)

        XCTAssertEqual(questions.count, 600)
        XCTAssertEqual(Set(ids).count, ids.count)

        for round in ["60", "59", "58"] {
            let roundQuestions = questions.filter { $0.examRound == round }
            XCTAssertEqual(roundQuestions.count, 200, "R\(round) must contain exactly 200 bundled questions")
            XCTAssertEqual(roundQuestions.filter { $0.id.contains("-AM-") }.count, 100, "R\(round) AM must contain exactly 100 questions")
            XCTAssertEqual(roundQuestions.filter { $0.id.contains("-PM-") }.count, 100, "R\(round) PM must contain exactly 100 questions")
            XCTAssertTrue(
                RigakuRouteGate.isComplete(audited: roundQuestions.count, expected: 200),
                "R\(round) mock must unlock only when the full audited round is bundled"
            )
        }
    }

    func testAllThreeMockScoringCanonsLoadFromAppBundle() throws {
        let repository = try RigakuExamScoringRepository.loadBundled(bundle: Bundle.main)
        let expected: [String: (general: Int, practical: Int, total: Int)] = [
            "60": (159, 114, 273),
            "59": (159, 120, 279),
            "58": (158, 120, 278),
        ]

        for (round, maxima) in expected {
            guard let config = repository.examConfig.roundConfig[round] else {
                XCTFail("R\(round) scoring configuration missing")
                continue
            }
            XCTAssertEqual(config.officialScoring.generalMax, maxima.general)
            XCTAssertEqual(config.officialScoring.practicalMax, maxima.practical)
            XCTAssertEqual(config.officialScoring.totalMax, maxima.total)
            XCTAssertGreaterThan(config.officialScoring.passTotal, 0)
            XCTAssertGreaterThan(config.officialScoring.passPractical, 0)
        }
    }
}
