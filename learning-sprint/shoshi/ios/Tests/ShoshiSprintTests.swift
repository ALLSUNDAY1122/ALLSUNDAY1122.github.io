import XCTest
@testable import ShoshiSprint

final class ShoshiSprintTests: XCTestCase {
    private func question(id: String = "Q1", answer: Int? = 2, allCorrect: Bool = false, subject: String = "民法") -> Question {
        Question(
            id: id,
            round: 1,
            sourceYear: 2025,
            session: "AM",
            sourceQuestionNo: 1,
            subject: subject,
            topic: "test",
            question: "test",
            choices: ["1","2","3","4","5"],
            officialAnswerNo: answer,
            scoringStatus: allCorrect ? "all_correct" : "normal",
            shortExplanation: "explanation",
            memoryLine: "memory",
            primaryBasis: "basis",
            basisURL: "https://example.com",
            lawBaseline: "2025-04-01",
            currentLawStatus: "historical"
        )
    }

    func testWrongAnswerRegistersWeakAndThreeCorrectReleaseIt() {
        var state = LearningState()
        let q = question()
        XCTAssertFalse(LearningLogic.recordAnswer(state: &state, question: q, choice: 1, dayKey: "2026-08-10"))
        XCTAssertEqual(state.attempts[q.id]?.isWeak, true)
        XCTAssertEqual(state.attempts[q.id]?.correctStreak, 0)
        for _ in 0..<2 { XCTAssertTrue(LearningLogic.recordAnswer(state: &state, question: q, choice: 2, dayKey: "2026-08-10")) }
        XCTAssertEqual(state.attempts[q.id]?.isWeak, true)
        XCTAssertTrue(LearningLogic.recordAnswer(state: &state, question: q, choice: 2, dayKey: "2026-08-10"))
        XCTAssertEqual(state.attempts[q.id]?.isWeak, false)
        XCTAssertEqual(state.attempts[q.id]?.correctStreak, 3)
    }

    func testAllCorrectQuestionAcceptsAnyChoice() {
        let q = question(answer: nil, allCorrect: true)
        for choice in 1...5 { XCTAssertTrue(LearningLogic.isCorrect(question: q, choice: choice)) }
    }

    func testDailySelectionHonorsGoalAndPrioritizesWeak() {
        var state = LearningState()
        let q1 = question(id: "Q1")
        let q2 = question(id: "Q2")
        let q3 = question(id: "Q3")
        state.attempts[q3.id] = AttemptStat(answered: 1, correct: 0, correctStreak: 0, isWeak: true)
        let selected = LearningLogic.selectQuestions(descriptor: .daily, all: [q1,q2,q3], state: state, dailyLimit: 2)
        XCTAssertEqual(selected.count, 2)
        XCTAssertEqual(selected.first?.id, "Q3")
    }

    func testResumePreservesAnsweredFeedbackState() {
        let q = question()
        let snapshot = SessionSnapshot(descriptor: .daily, questionIDs: [q.id], index: 0, correctCount: 1, answeredChoice: 2, answeredCorrect: true)
        let restored = LearningLogic.validateResume(snapshot, questionsByID: [q.id:q])
        XCTAssertEqual(restored?.answeredChoice, 2)
        XCTAssertEqual(restored?.answeredCorrect, true)
    }

    func testJSONBackupRoundTripAndDoesNotContainTrialEntitlement() throws {
        var state = LearningState()
        state.dailyGoal = 16
        state.textSize = "large"
        state.attempts["Q1"] = AttemptStat(answered: 4, correct: 3, correctStreak: 3, isWeak: false)
        let data = try LearningLogic.exportJSON(state)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(json.contains("trialCompleted"))
        XCTAssertFalse(json.contains("trialConsumed"))
        let restored = try LearningLogic.importJSON(data)
        XCTAssertEqual(restored, state)
    }

    func testBackupRejectsInvalidDailyGoal() throws {
        var state = LearningState()
        state.dailyGoal = 999
        let data = try LearningLogic.exportJSON(state)
        XCTAssertThrowsError(try LearningLogic.importJSON(data))
    }

    func testBackupRejectsImpossibleAttemptCounts() throws {
        var state = LearningState()
        state.attempts["Q1"] = AttemptStat(answered: 1, correct: 2, correctStreak: 2, isWeak: false)
        let data = try LearningLogic.exportJSON(state)
        XCTAssertThrowsError(try LearningLogic.importJSON(data))
    }

    func testBackupRejectsOversizedPayload() {
        XCTAssertThrowsError(try LearningLogic.importJSON(Data(repeating: 0x20, count: 5 * 1024 * 1024 + 1)))
    }
}
