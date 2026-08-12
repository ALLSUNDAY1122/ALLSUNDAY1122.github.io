import XCTest
@testable import HokenshiSprintFeature
import LearningSprintCore

final class HokenshiSprintFeatureTests: XCTestCase {
    func testLatestVerifiedExamStructure() {
        let blueprint = HokenshiExamBlueprint.current
        XCTAssertEqual(blueprint.referenceRound, 112)
        XCTAssertEqual(blueprint.morningQuestions, 55)
        XCTAssertEqual(blueprint.afternoonQuestions, 55)
        XCTAssertEqual(blueprint.totalQuestions, 110)
        XCTAssertEqual(blueprint.generalQuestions, 75)
        XCTAssertEqual(blueprint.situationalQuestions, 35)
        XCTAssertEqual(blueprint.situationalPoints, 70)
        XCTAssertEqual(blueprint.generalQuestions + blueprint.situationalQuestions, blueprint.totalQuestions)
    }

    func testCurrentStandardHasTenTopLevelSubjects() {
        let expected = [
            "公衆衛生看護学概論",
            "公衆衛生看護方法論I",
            "公衆衛生看護方法論II",
            "対象別公衆衛生看護活動論",
            "学校保健・産業保健",
            "健康危機管理",
            "公衆衛生看護管理論",
            "疫学",
            "保健統計",
            "保健医療福祉行政論"
        ]
        XCTAssertEqual(HokenshiExamBlueprint.current.subjects, expected)
    }

    func testGoldenMasterSprintCounts() {
        XCTAssertEqual(HokenshiSprintConfiguration.standardSprintCount, 8)
        XCTAssertEqual(HokenshiSprintConfiguration.selectableSprintCounts, [4, 8, 16])
        XCTAssertEqual(HokenshiSprintConfiguration.plannedMockExamCount, 3)
        XCTAssertEqual(HokenshiSprintConfiguration.questionsPerMockExam, 110)
        XCTAssertEqual(HokenshiSprintConfiguration.plannedIndependentQuestionCount, 330)
        XCTAssertEqual(HokenshiSprintConfiguration.plannedQuestionsPerSubjectPerMock, 11)
        XCTAssertEqual(
            HokenshiSprintConfiguration.plannedQuestionsPerSubjectPerMock * HokenshiExamBlueprint.current.subjects.count,
            HokenshiSprintConfiguration.questionsPerMockExam
        )
    }

    func test2026ImprovementReportKeepsCurrentFramework() {
        XCTAssertEqual(HokenshiExamPolicy2026.evidenceDate, "2026-03-19")
        XCTAssertFalse(HokenshiExamPolicy2026.standardRevisionRequired)
        XCTAssertTrue(HokenshiExamPolicy2026.keepCurrentQuestionCount)
        XCTAssertTrue(HokenshiExamPolicy2026.keepCurrentExamTime)
        XCTAssertTrue(HokenshiExamPolicy2026.latestLawAndStatisticsShouldBeTested)
        XCTAssertTrue(HokenshiExamPolicy2026.visualMaterialShouldContinue)
        XCTAssertTrue(HokenshiExamPolicy2026.communityDiagnosisShouldUseData)
    }

    func testSituationalQuestionPlanReproducesThirtyFiveQuestions() {
        XCTAssertEqual(HokenshiExamPolicy2026.situationalScenarioGroupSizes.count, 12)
        XCTAssertEqual(HokenshiExamPolicy2026.situationalScenarioGroupSizes.filter { $0 == 3 }.count, 11)
        XCTAssertEqual(HokenshiExamPolicy2026.situationalScenarioGroupSizes.filter { $0 == 2 }.count, 1)
        XCTAssertEqual(HokenshiExamPolicy2026.plannedSituationalQuestionCount, 35)
        XCTAssertEqual(
            HokenshiExamPolicy2026.plannedSituationalQuestionCount,
            HokenshiExamBlueprint.current.situationalQuestions
        )
    }

    func testTaxonomyPolicyMatchesImprovementReport() {
        XCTAssertEqual(HokenshiExamPolicy2026.generalTaxonomies, ["I", "I-prime", "II"])
        XCTAssertEqual(HokenshiExamPolicy2026.situationalTaxonomies, ["II", "III"])
    }

    func testSupportedOfficialAnswerPatternsMapToCore() {
        XCTAssertEqual(
            HokenshiSprintConfiguration.supportedAnswerTypes,
            [.singleChoice, .multiChoice, .numeric]
        )
    }

    func testThirdPartyMaterialWithoutClearanceIsBlocked() {
        let decision = HokenshiRightsPolicy.decision(
            for: .thirdPartyMaterial,
            thirdPartyRightsCleared: false
        )
        guard case .blocked = decision else {
            return XCTFail("第三者権利未処理素材はblockedでなければならない")
        }
    }

    func testMHLWProblemReuseRequiresPerItemAudit() {
        XCTAssertEqual(
            HokenshiRightsPolicy.decision(for: .officialMHLWUnmodified),
            .requiresPerItemAudit
        )
        XCTAssertEqual(
            HokenshiRightsPolicy.decision(for: .officialMHLWAdapted),
            .requiresPerItemAudit
        )
    }

    func testOriginalPrimarySourceQuestionCanProceedToStandardAudit() {
        XCTAssertEqual(
            HokenshiRightsPolicy.decision(for: .originalFromPrimarySource),
            .allowedAfterStandardAudit
        )
    }
}
