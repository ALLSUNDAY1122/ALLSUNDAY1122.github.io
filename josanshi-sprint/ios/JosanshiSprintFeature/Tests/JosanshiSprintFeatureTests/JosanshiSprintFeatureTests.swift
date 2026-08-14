import XCTest
import LearningSprintCore
@testable import JosanshiSprintFeature

final class JosanshiSprintFeatureTests: XCTestCase {
    func testGoldenMasterSprintTargetsAreFixed() {
        XCTAssertEqual(JosanshiExamConfiguration.standardSprintCount, 8)
        XCTAssertEqual(JosanshiExamConfiguration.selectableDailyTargets, [4, 8, 16])
    }

    func testOfficialSubjectsAreExactlyTheCurrentFour() {
        XCTAssertEqual(
            JosanshiExamConfiguration.subjects,
            ["基礎助産学", "助産診断・技術学", "地域母子保健", "助産管理"]
        )
    }

    func testLatestConfirmedStructureAndThreeMockTarget() {
        XCTAssertEqual(JosanshiExamConfiguration.latestConfirmedExamRound, 109)
        XCTAssertEqual(JosanshiExamConfiguration.morningQuestionCount, 55)
        XCTAssertEqual(JosanshiExamConfiguration.afternoonQuestionCount, 55)
        XCTAssertEqual(JosanshiExamConfiguration.latestConfirmedQuestionCount, 110)
        XCTAssertEqual(JosanshiExamConfiguration.generalQuestionCountPerMock, 75)
        XCTAssertEqual(JosanshiExamConfiguration.situationQuestionCountPerMock, 35)
        XCTAssertEqual(JosanshiExamConfiguration.scenarioCaseCountPerMock, 12)
        XCTAssertEqual(JosanshiExamConfiguration.originalProductionQuestionTarget, 330)
        XCTAssertEqual(JosanshiExamConfiguration.originalGeneralQuestionTarget, 225)
        XCTAssertEqual(JosanshiExamConfiguration.originalSituationQuestionTarget, 105)
        XCTAssertEqual(JosanshiExamConfiguration.originalScenarioCaseTarget, 36)
    }

    func testApprovedProductionIdentifiersAreCanonicalWhileAppleNumericIDRemainsUnset() {
        let ids = JosanshiExamConfiguration.productionIdentifiers
        XCTAssertEqual(ids.bundleID, "jp.allsunday1122.josanshi")
        XCTAssertNil(ids.appStoreConnectAppID)
        XCTAssertEqual(ids.codemagicProfile, "josanshi_appstore")
        XCTAssertEqual(ids.productID, "jp.allsunday1122.josanshi.premium")
        XCTAssertTrue(ids.isSignedBuildIdentityReady)
        XCTAssertTrue(ids.isStoreKitReady)
        XCTAssertFalse(ids.isAppStoreRecordReady)
        XCTAssertFalse(ids.isReleaseIdentityReady)
        XCTAssertFalse(JosanshiLocalPersistenceConfiguration.storageNamespace.contains("jp.allsunday1122"))
    }

    func testBundledProductionBankIsExactlyFullAuditedContent() throws {
        let bank = try JosanshiQuestionBankLoader.bundled()
        XCTAssertEqual(bank.status, "audited")
        XCTAssertEqual(bank.questions.count, 330)
        XCTAssertEqual(bank.scenarios.count, 36)
        XCTAssertTrue(bank.questions.allSatisfy { $0.auditStatus == "pass" })
        XCTAssertTrue(bank.scenarios.allSatisfy { $0.auditStatus == "pass" })
        XCTAssertEqual(bank.questions.filter { $0.questionType == "general" }.count, 225)
        XCTAssertEqual(bank.questions.filter { $0.questionType == "situation" }.count, 105)
        XCTAssertEqual(Set(bank.questions.map(\.id)).count, 330)
        XCTAssertEqual(Set(bank.scenarios.map(\.scenarioId)).count, 36)

        for round in 1...3 {
            XCTAssertEqual(bank.questions.filter { $0.mockRound == round }.count, 110)
            XCTAssertEqual(bank.scenarios.filter { $0.mockRound == round }.count, 12)
        }

        let subjectCounts = Dictionary(grouping: bank.questions, by: \.subject).mapValues(\.count)
        XCTAssertEqual(subjectCounts["基礎助産学"], 100)
        XCTAssertEqual(subjectCounts["助産診断・技術学"], 185)
        XCTAssertEqual(subjectCounts["地域母子保健"], 20)
        XCTAssertEqual(subjectCounts["助産管理"], 25)
    }

    func testAuditedBankDerivesExactly60BalancedFreeGeneralQuestions() throws {
        let bank = try JosanshiQuestionBankLoader.bundled()
        let learning = try bank.learningQuestions()
        let free = learning.filter { !$0.premium }
        let premium = learning.filter(\.premium)

        XCTAssertEqual(free.count, 60)
        XCTAssertEqual(premium.count, 270)
        XCTAssertEqual(free.count, JosanshiMonetizationConfiguration.freeQuestionTarget)

        let freeIDs = Set(free.map(\.id))
        XCTAssertEqual(freeIDs, JosanshiMonetizationConfiguration.freeQuestionIDs(in: bank.questions))
        XCTAssertTrue(bank.questions.filter { freeIDs.contains($0.id) }.allSatisfy { $0.questionType == "general" })

        let freeSubjectCounts = Dictionary(grouping: free, by: \.subject).mapValues(\.count)
        for subject in JosanshiExamConfiguration.subjects {
            XCTAssertEqual(freeSubjectCounts[subject], 15)
        }
    }

    @MainActor
    func testInvalidDailyTargetIsRejected() {
        let model = JosanshiDashboardModel(usePersistentStore: false)
        model.setDailyTarget(16)
        XCTAssertEqual(model.dailyTarget, 16)

        model.setDailyTarget(12)
        XCTAssertEqual(model.dailyTarget, 16)
    }

    @MainActor
    func testFreeStandardSprintUsesOnlyFreeQuestions() throws {
        let model = JosanshiDashboardModel(
            usePersistentStore: false,
            premiumEntitlementOverride: false
        )
        XCTAssertEqual(model.freeQuestionCount, 60)
        XCTAssertEqual(model.premiumQuestionCount, 270)

        model.requestStandardSprint()
        let session = try XCTUnwrap(model.coordinator.activeSession)
        XCTAssertEqual(session.questionIDs.count, model.dailyTarget)
        let freeIDs = Set(model.coordinator.questions.filter { !$0.premium }.map(\.id))
        XCTAssertTrue(session.questionIDs.allSatisfy(freeIDs.contains))
        XCTAssertFalse(model.isPaywallPresented)
    }

    @MainActor
    func testFreePremiumRoutesOpenPaywallWithoutStartingSession() {
        let model = JosanshiDashboardModel(
            usePersistentStore: false,
            premiumEntitlementOverride: false
        )

        model.requestSubjectPractice("助産管理")
        XCTAssertTrue(model.isPaywallPresented)
        XCTAssertNil(model.coordinator.activeSession)

        model.dismissPaywall()
        model.requestMock(1)
        XCTAssertTrue(model.isPaywallPresented)
        XCTAssertNil(model.coordinator.activeSession)
    }

    @MainActor
    func testPremiumSubjectRequestStartsSessionOnlyForOfficialSubject() {
        let model = JosanshiDashboardModel(
            usePersistentStore: false,
            premiumEntitlementOverride: true
        )
        XCTAssertTrue(model.hasReadyContent)

        model.requestSubjectPractice("助産管理")
        XCTAssertEqual(model.selectedSubject, "助産管理")
        XCTAssertTrue(model.isSessionPresented)
        XCTAssertFalse(model.isContentGatePresented)
        XCTAssertFalse(model.isPaywallPresented)
        XCTAssertEqual(model.coordinator.activeSession?.questionIDs.count, model.dailyTarget)

        model.finishSession()
        model.coordinator.clearSession()
        model.requestSubjectPractice("未定義科目")
        XCTAssertEqual(model.selectedSubject, "助産管理")
        XCTAssertFalse(model.isSessionPresented)
        XCTAssertFalse(model.isContentGatePresented)
    }

    @MainActor
    func testPremiumBundledMockStartsWithExactly110Questions() {
        let model = JosanshiDashboardModel(
            usePersistentStore: false,
            premiumEntitlementOverride: true
        )
        model.requestMock(2)
        XCTAssertTrue(model.isSessionPresented)
        XCTAssertFalse(model.isPaywallPresented)
        XCTAssertEqual(model.coordinator.activeSession?.questionIDs.count, 110)
    }

    @MainActor
    func testStandardSprintUnknownCreatesWeakAndResumeIsMaintained() throws {
        let questions = makeQuestions(count: 8)
        let coordinator = JosanshiLearningCoordinator(questions: questions, loadPersistedState: false)
        let session = try coordinator.startStandardSprint(seed: 1)
        XCTAssertEqual(session.questionIDs.count, 8)
        XCTAssertNotNil(coordinator.state.resumeSession)

        let firstID = try XCTUnwrap(coordinator.currentQuestion?.id)
        let evaluation = try coordinator.markUnknown()
        XCTAssertTrue(evaluation.isUnknown)
        XCTAssertNotNil(coordinator.state.weakQuestions[firstID])
        XCTAssertEqual(coordinator.state.attempts.count, 1)
        XCTAssertEqual(coordinator.activeSession?.currentIndex, 1)
        XCTAssertNotNil(coordinator.state.resumeSession)
    }

    @MainActor
    func testWeakQuestionLeavesQueueAfterThreeConsecutiveCorrectAnswers() throws {
        let question = makeQuestion(id: "Q-WEAK", subject: "基礎助産学", examRound: "1")
        let coordinator = JosanshiLearningCoordinator(questions: [question], loadPersistedState: false)

        for _ in 0..<3 {
            _ = try coordinator.startStandardSprint(seed: 1)
            if coordinator.state.weakQuestions[question.id] == nil {
                _ = try coordinator.markUnknown()
            } else {
                _ = try coordinator.submit(AnswerPayload(selectedIndices: [0]))
            }
        }

        XCTAssertEqual(coordinator.state.weakQuestions[question.id]?.consecutiveCorrect, 2)
        _ = try coordinator.startWeakReview()
        _ = try coordinator.submit(AnswerPayload(selectedIndices: [0]))
        XCTAssertNil(coordinator.state.weakQuestions[question.id])
    }

    @MainActor
    func testLocalPersistenceRestoresResumeAndBackupRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = JosanshiLearningCoordinator.defaultPersistentStore(directoryURL: directory)
        let questions = makeQuestions(count: 8)
        let first = JosanshiLearningCoordinator(questions: questions, store: store)
        first.setDailyTarget(4)
        _ = try first.startStandardSprint(seed: 3)
        _ = try first.markUnknown()
        let backup = try first.exportBackup()

        let second = JosanshiLearningCoordinator(questions: questions, store: store)
        XCTAssertEqual(second.state.dailyTarget, 4)
        XCTAssertEqual(second.state.attempts.count, 1)
        XCTAssertEqual(second.activeSession?.currentIndex, 1)
        XCTAssertTrue(second.resumePersistedSession())

        second.clearSession()
        XCTAssertNil(second.state.resumeSession)
        try second.importBackup(backup)
        XCTAssertEqual(second.state.dailyTarget, 4)
        XCTAssertEqual(second.state.attempts.count, 1)
        XCTAssertNotNil(second.state.resumeSession)
    }

    @MainActor
    func testSubjectAndMockSelectionUseContentMetadata() throws {
        let questions = [
            makeQuestion(id: "B1", subject: "基礎助産学", examRound: "1"),
            makeQuestion(id: "M1", subject: "助産管理", examRound: "2"),
            makeQuestion(id: "M2", subject: "助産管理", examRound: "2"),
        ]
        let coordinator = JosanshiLearningCoordinator(questions: questions, loadPersistedState: false)

        let subject = try coordinator.startSubject("助産管理")
        XCTAssertEqual(subject.questionIDs, ["M1", "M2"])
        coordinator.clearSession()

        let mock = try coordinator.startMock(2)
        XCTAssertEqual(mock.questionIDs, ["M1", "M2"])
    }

    func testQuestionBankDecodeConvertsAuditedRecordToLearningQuestion() throws {
        let question = makeProductionQuestion(id: "JOS-R1-AM-Q01")
        let document = JosanshiQuestionBankDocument(
            status: "draft",
            questions: [question],
            scenarios: []
        )
        let data = try JSONEncoder().encode(document)
        let decoded = try JosanshiQuestionBankLoader.decode(data)
        let learning = try decoded.learningQuestions()

        XCTAssertEqual(decoded.questions.count, 1)
        XCTAssertEqual(learning.count, 1)
        XCTAssertEqual(learning[0].id, question.id)
        XCTAssertEqual(learning[0].answerType, .singleChoice)
        XCTAssertEqual(learning[0].sourceRefs, ["EGOV-PHN-MIDWIFE-NURSE-ACT"])
        XCTAssertEqual(learning[0].examRound, "1")
        XCTAssertFalse(learning[0].premium)
    }

    func testQuestionBankRejectsSituationQuestionWithoutScenarioRecord() throws {
        let question = JosanshiProductionQuestion(
            id: "JOS-R1-AM-Q39",
            mockRound: 1,
            session: "AM",
            slotNumber: 39,
            questionType: "situation",
            scenarioId: "JOS-R1-AM-SC01",
            scenarioIndex: 1,
            scenarioTotal: 3,
            subject: "助産診断・技術学",
            topicId: "DIAGNOSIS-05",
            intentId: "DIAGNOSIS-05-I1",
            intentFocus: "妊娠成立の徴候と検査",
            answerType: "singleChoice",
            prompt: "症例連結検証用のテスト問題本文です。",
            choices: ["A", "B", "C", "D"],
            correctIndices: [0],
            explanation: "症例レコード欠損時にデコードを拒否するためのテスト用解説です。",
            memoryPoint: "症例連結を必須化",
            sourceIds: ["JSOG-OB-GUIDELINE-2026"],
            sourceCheckedAt: "2026-08-13",
            lawBaselineDate: "2026-08-13",
            rightsBasis: "original test wording; no direct reproduction",
            originType: "original_from_primary_source",
            contentVersion: JosanshiLocalPersistenceConfiguration.contentVersion,
            auditStatus: "draft"
        )
        let document = JosanshiQuestionBankDocument(
            status: "draft",
            questions: [question],
            scenarios: []
        )
        let data = try JSONEncoder().encode(document)

        XCTAssertThrowsError(try JosanshiQuestionBankLoader.decode(data)) { error in
            XCTAssertEqual(error as? JosanshiQuestionBankError, .brokenScenarioReference(question.id))
        }
    }

    private func makeQuestions(count: Int) -> [LearningQuestion] {
        var result: [LearningQuestion] = []
        result.reserveCapacity(count)
        for index in 1...count {
            let subjectIndex = (index - 1) % JosanshiExamConfiguration.subjects.count
            let subject = JosanshiExamConfiguration.subjects[subjectIndex]
            let examRound = String(((index - 1) % 3) + 1)
            result.append(
                makeQuestion(
                    id: "Q-\(index)",
                    subject: subject,
                    examRound: examRound
                )
            )
        }
        return result
    }

    private func makeQuestion(id: String, subject: String, examRound: String) -> LearningQuestion {
        LearningQuestion(
            id: id,
            subject: subject,
            topic: "test-topic",
            answerType: .singleChoice,
            prompt: "テスト問題 \(id)",
            choices: ["正解", "誤りA", "誤りB", "誤りC"],
            correctIndices: [0],
            memoryPoint: "テスト用",
            explanation: "テスト用解説",
            sourceTitle: "test",
            sourceURL: "https://example.com/test",
            sourceRefs: ["TEST"],
            sourceCheckedAt: "2026-08-13",
            lawBaselineDate: "2026-08-13",
            contentVersion: JosanshiLocalPersistenceConfiguration.contentVersion,
            premium: false,
            examRound: examRound,
            questionNumber: id,
            rightsBasis: "test-only"
        )
    }

    private func makeProductionQuestion(id: String) -> JosanshiProductionQuestion {
        JosanshiProductionQuestion(
            id: id,
            mockRound: 1,
            session: "AM",
            slotNumber: 1,
            questionType: "general",
            subject: "基礎助産学",
            topicId: "BASIC-01",
            intentId: "BASIC-01-I1",
            intentFocus: "助産・助産師の定義と法的位置付け",
            answerType: "singleChoice",
            prompt: "助産師の定義について確認するテスト問題本文です。",
            choices: ["正解", "誤りA", "誤りB", "誤りC"],
            correctIndices: [0],
            explanation: "本番問題バンクからLearningQuestionへの変換を確認するテスト用の独自解説です。",
            memoryPoint: "変換テスト",
            sourceIds: ["EGOV-PHN-MIDWIFE-NURSE-ACT"],
            sourceCheckedAt: "2026-08-13",
            lawBaselineDate: "2026-08-13",
            rightsBasis: "original test wording; no direct reproduction",
            originType: "original_from_primary_source",
            contentVersion: JosanshiLocalPersistenceConfiguration.contentVersion,
            auditStatus: "draft"
        )
    }
}
