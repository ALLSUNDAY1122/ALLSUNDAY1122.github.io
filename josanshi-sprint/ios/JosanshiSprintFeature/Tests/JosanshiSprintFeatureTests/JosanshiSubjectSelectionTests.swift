import XCTest
import LearningSprintCore
@testable import JosanshiSprintFeature

@MainActor
final class JosanshiSubjectSelectionTests: XCTestCase {
    func testSubjectPracticeUsesSeededShuffleInsteadOfFixedPrefix() throws {
        let questions = makeQuestions()
        let coordinator = JosanshiLearningCoordinator(questions: questions, loadPersistedState: false)
        coordinator.setDailyTarget(8)

        let first = try coordinator.startSubject(JosanshiExamConfiguration.subjects[0], seed: 1)
        coordinator.clearSession()
        let second = try coordinator.startSubject(JosanshiExamConfiguration.subjects[0], seed: 2)

        XCTAssertEqual(first.questionIDs.count, 8)
        XCTAssertEqual(second.questionIDs.count, 8)
        XCTAssertNotEqual(first.questionIDs, Array(questions.prefix(8).map(\.id)))
        XCTAssertNotEqual(first.questionIDs, second.questionIDs)
    }

    func testSubjectPracticeCanPreserveOrderWhenShuffleIsDisabled() throws {
        let questions = makeQuestions()
        let coordinator = JosanshiLearningCoordinator(questions: questions, loadPersistedState: false)
        coordinator.setDailyTarget(8)
        coordinator.setShuffleQuestions(false)

        let session = try coordinator.startSubject(JosanshiExamConfiguration.subjects[0], seed: 99)

        XCTAssertEqual(session.questionIDs, Array(questions.prefix(8).map(\.id)))
    }

    func testNewRequestDoesNotOverwriteIncompleteSession() throws {
        let coordinator = JosanshiLearningCoordinator(questions: makeQuestions(), loadPersistedState: false)
        coordinator.setDailyTarget(8)

        let original = try coordinator.startSubject(JosanshiExamConfiguration.subjects[0], seed: 1)
        let attemptedReplacement = try coordinator.startStandardSprint(seed: 2)

        XCTAssertEqual(attemptedReplacement, original)
        XCTAssertEqual(coordinator.activeSession, original)
        XCTAssertEqual(coordinator.state.resumeSession, original)
    }

    func testGoldenMasterPreferencesRoundTripInsideBackup() throws {
        let source = JosanshiLearningCoordinator(questions: makeQuestions(), loadPersistedState: false)
        source.setShuffleQuestions(false)
        source.setShuffleChoices(false)
        source.setTextSizeStep(2)
        source.setExamDate(Date(timeIntervalSince1970: 1_800_000_000))

        let data = try source.exportBackup()
        let restored = JosanshiLearningCoordinator(questions: makeQuestions(), loadPersistedState: false)
        try restored.importBackup(data)

        XCTAssertFalse(restored.preferences.shuffleQuestions)
        XCTAssertFalse(restored.preferences.shuffleChoices)
        XCTAssertEqual(restored.preferences.resolvedTextSizeStep, 2)
        XCTAssertNotNil(restored.state.examDate)
    }

    func testCompletedSessionCreatesResultAndRecentHistory() throws {
        let coordinator = JosanshiLearningCoordinator(questions: makeQuestions(), loadPersistedState: false)
        coordinator.setDailyTarget(4)
        coordinator.setShuffleQuestions(false)
        let session = try coordinator.startSubject(JosanshiExamConfiguration.subjects[0])

        for _ in session.questionIDs {
            _ = try coordinator.submit(AnswerPayload(selectedIndices: [0]))
        }

        XCTAssertNil(coordinator.activeSession)
        XCTAssertEqual(coordinator.lastCompletedSession?.correctCount, 4)
        XCTAssertEqual(coordinator.lastCompletedSession?.totalCount, 4)
        XCTAssertEqual(coordinator.recentSessions.first?.title, JosanshiExamConfiguration.subjects[0])
        XCTAssertEqual(coordinator.recentSessions.count, 1)
    }

    func testResetClearsHistoryButKeepsGoldenMasterPreferences() throws {
        let coordinator = JosanshiLearningCoordinator(questions: makeQuestions(), loadPersistedState: false)
        coordinator.setDailyTarget(4)
        coordinator.setTextSizeStep(2)
        coordinator.setShuffleChoices(false)
        let session = try coordinator.startSubject(JosanshiExamConfiguration.subjects[0], seed: 1)
        for _ in session.questionIDs {
            _ = try coordinator.submit(AnswerPayload(selectedIndices: [0]))
        }

        coordinator.resetLearningHistory()

        XCTAssertEqual(coordinator.totalAnsweredCount, 0)
        XCTAssertTrue(coordinator.recentSessions.isEmpty)
        XCTAssertEqual(coordinator.preferences.resolvedTextSizeStep, 2)
        XCTAssertFalse(coordinator.preferences.shuffleChoices)
        XCTAssertEqual(coordinator.state.dailyTarget, 4)
    }

    private func makeQuestions() -> [LearningQuestion] {
        (0..<20).map { index in
            LearningQuestion(
                id: "q-\(index)",
                subject: JosanshiExamConfiguration.subjects[0],
                topic: "topic",
                answerType: .singleChoice,
                prompt: "Q\(index)",
                choices: ["A", "B"],
                correctIndices: [0],
                memoryPoint: "M",
                explanation: "E",
                sourceCheckedAt: "2026-08-14",
                lawBaselineDate: "2026-08-14",
                contentVersion: JosanshiLocalPersistenceConfiguration.contentVersion
            )
        }
    }
}
