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

    func testReleaseReadyContentStoreAcceptsExact330Structure() throws {
        let store = try HokenshiContentStore(records: makeRecords(status: .releaseReady))
        XCTAssertEqual(store.allRecords.count, 330)
        XCTAssertEqual(store.questions(round: 1).count, 110)
        XCTAssertEqual(store.questions(subject: HokenshiExamBlueprint.current.subjects[0]).count, 33)
        XCTAssertEqual(store.productQuestions.count, 330)
    }

    func testDraftContentIsBlockedFromProductStore() {
        XCTAssertThrowsError(try HokenshiContentStore(records: makeRecords(status: .drafted))) { error in
            guard case HokenshiContentStoreError.unreleasedContent = error else {
                return XCTFail("draft content must be blocked: \(error)")
            }
        }
    }

    func testDraftContentCanBeLoadedForAuditOnly() throws {
        let store = try HokenshiContentStore(
            records: makeRecords(status: .drafted),
            requireReleaseReady: false
        )
        XCTAssertEqual(store.allRecords.count, 330)
    }

    func testInvalidAnswerShapeIsBlocked() {
        var records = makeRecords(status: .releaseReady)
        let broken = records[0]
        records[0] = makeRecord(
            id: broken.id,
            round: broken.round,
            questionNumber: broken.questionNumber,
            subject: broken.subject,
            questionType: broken.questionType,
            scenarioID: broken.scenarioID,
            scenarioIndex: broken.scenarioIndex,
            scenarioTotal: broken.scenarioTotal,
            status: .releaseReady,
            choices: ["A", "B", "C", "D"],
            correctIndices: []
        )

        XCTAssertThrowsError(try HokenshiContentStore(records: records)) { error in
            XCTAssertEqual(error as? HokenshiContentStoreError, .invalidAnswer(broken.id))
        }
    }

    private func makeRecords(status: HokenshiAuditStatus) -> [HokenshiQuestionRecord] {
        var records: [HokenshiQuestionRecord] = []
        for round in 1...3 {
            var situationalOffset = 0
            for questionNumber in 1...110 {
                let subjectIndex = (questionNumber - 1) / 11
                let subject = HokenshiExamBlueprint.current.subjects[subjectIndex]
                let isSituational = questionNumber > 75

                var scenarioID: String?
                var scenarioIndex: Int?
                var scenarioTotal: Int?
                if isSituational {
                    let position = situationalOffset
                    if position < 33 {
                        let group = position / 3
                        scenarioID = "TEST-R\(round)-SC-\(group + 1)"
                        scenarioIndex = position % 3 + 1
                        scenarioTotal = 3
                    } else {
                        scenarioID = "TEST-R\(round)-SC-12"
                        scenarioIndex = position - 33 + 1
                        scenarioTotal = 2
                    }
                    situationalOffset += 1
                }

                records.append(
                    makeRecord(
                        id: "TEST-R\(round)-Q\(questionNumber)",
                        round: round,
                        questionNumber: questionNumber,
                        subject: subject,
                        questionType: isSituational ? .situational : .general,
                        scenarioID: scenarioID,
                        scenarioIndex: scenarioIndex,
                        scenarioTotal: scenarioTotal,
                        status: status
                    )
                )
            }
        }
        return records
    }

    private func makeRecord(
        id: String,
        round: Int,
        questionNumber: Int,
        subject: String,
        questionType: HokenshiQuestionType,
        scenarioID: String?,
        scenarioIndex: Int?,
        scenarioTotal: Int?,
        status: HokenshiAuditStatus,
        choices: [String] = ["A", "B", "C", "D"],
        correctIndices: [Int] = [0]
    ) -> HokenshiQuestionRecord {
        HokenshiQuestionRecord(
            id: id,
            round: round,
            questionNumber: questionNumber,
            subject: subject,
            topic: "テスト論点\(questionNumber)",
            questionType: questionType,
            taxonomy: questionType == .situational ? "II" : "I",
            scenarioID: scenarioID,
            scenarioIndex: scenarioIndex,
            scenarioTotal: scenarioTotal,
            scenarioText: scenarioIndex == 1 ? "テスト状況" : nil,
            answerType: .singleChoice,
            prompt: "固有のテスト問題 \(id)",
            choices: choices,
            correctIndices: correctIndices,
            explanation: "一次資料に基づく説明",
            memoryPoint: "要点",
            sourceTitle: "一次資料",
            sourceURL: "https://example.go.jp/primary",
            sourceRefs: ["S01"],
            sourceCheckedAt: "2026-08-13",
            lawBaselineDate: "2026-08-13",
            contentVersion: "test",
            rightsBasis: "一次資料に基づく独自作問",
            auditStatus: status
        )
    }
}
