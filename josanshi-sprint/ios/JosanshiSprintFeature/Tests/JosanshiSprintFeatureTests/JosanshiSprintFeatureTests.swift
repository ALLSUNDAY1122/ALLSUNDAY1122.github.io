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

    func testProductionIdentifiersRemainUnsetUntilCanonicalValuesExist() {
        let ids = JosanshiExamConfiguration.productionIdentifiers
        XCTAssertNil(ids.bundleID)
        XCTAssertNil(ids.appStoreConnectAppID)
        XCTAssertNil(ids.productID)
        XCTAssertFalse(ids.isReleaseIdentityReady)
        XCTAssertFalse(ids.isStoreKitReady)
        XCTAssertFalse(JosanshiLocalPersistenceConfiguration.storageNamespace.contains("jp.allsunday1122"))
    }

    @MainActor
    func testInvalidDailyTargetIsRejected() {
        let model = JosanshiDashboardModel()
        model.setDailyTarget(16)
        XCTAssertEqual(model.dailyTarget, 16)

        model.setDailyTarget(12)
        XCTAssertEqual(model.dailyTarget, 16)
    }

    @MainActor
    func testSubjectRequestOnlyAcceptsOfficialSubject() {
        let model = JosanshiDashboardModel()
        model.requestSubjectPractice("助産管理")
        XCTAssertEqual(model.selectedSubject, "助産管理")
        XCTAssertTrue(model.isContentGatePresented)

        model.isContentGatePresented = false
        model.requestSubjectPractice("未定義科目")
        XCTAssertEqual(model.selectedSubject, "助産管理")
        XCTAssertFalse(model.isContentGatePresented)
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
}
