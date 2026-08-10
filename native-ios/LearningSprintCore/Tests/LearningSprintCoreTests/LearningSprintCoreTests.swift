import XCTest
@testable import LearningSprintCore

final class LearningSprintCoreTests: XCTestCase {
    private func singleQuestion(id: String = "Q1") -> LearningQuestion {
        LearningQuestion(
            id: id,
            subject: "法令",
            topic: "許可",
            answerType: .singleChoice,
            prompt: "正しいものはどれか。",
            choices: ["正答", "誤答A", "誤答B", "誤答C"],
            correctIndices: [0],
            memoryPoint: "正答を覚える",
            explanation: "一次資料に基づく説明",
            sourceCheckedAt: "2026-08-10",
            lawBaselineDate: "2026-07-01",
            contentVersion: "test-v1"
        )
    }

    func testAllowedDailyTargets() {
        XCTAssertTrue(LearningState.validTarget(4))
        XCTAssertTrue(LearningState.validTarget(8))
        XCTAssertTrue(LearningState.validTarget(16))
        XCTAssertFalse(LearningState.validTarget(12))
        XCTAssertEqual(LearningState(dailyTarget: 12, contentVersion: "v1").dailyTarget, 8)
    }

    func testSingleChoiceImmediateEvaluation() throws {
        let question = singleQuestion()
        let correct = try LearningEngine.evaluate(question, answer: AnswerPayload(selectedIndices: [0]))
        XCTAssertTrue(correct.isCorrect)
        let wrong = try LearningEngine.evaluate(question, answer: AnswerPayload(selectedIndices: [2]))
        XCTAssertFalse(wrong.isCorrect)
    }

    func testUnknownAlwaysRegistersWeak() throws {
        let question = singleQuestion()
        let evaluation = try LearningEngine.evaluate(question, answer: .unknown)
        XCTAssertFalse(evaluation.isCorrect)
        XCTAssertTrue(evaluation.isUnknown)
        var state = LearningState(contentVersion: "test-v1")
        LearningEngine.record(question: question, evaluation: evaluation, state: &state)
        XCTAssertNotNil(state.weakQuestions[question.id])
        XCTAssertEqual(state.weakQuestions[question.id]?.consecutiveCorrect, 0)
    }

    func testWeakQuestionGraduatesAfterThreeConsecutiveCorrectAnswers() throws {
        let question = singleQuestion()
        var state = LearningState(contentVersion: "test-v1")
        let wrong = try LearningEngine.evaluate(question, answer: AnswerPayload(selectedIndices: [1]))
        LearningEngine.record(question: question, evaluation: wrong, state: &state)
        XCTAssertNotNil(state.weakQuestions[question.id])

        let correct = try LearningEngine.evaluate(question, answer: AnswerPayload(selectedIndices: [0]))
        LearningEngine.record(question: question, evaluation: correct, state: &state)
        XCTAssertEqual(state.weakQuestions[question.id]?.consecutiveCorrect, 1)
        LearningEngine.record(question: question, evaluation: correct, state: &state)
        XCTAssertEqual(state.weakQuestions[question.id]?.consecutiveCorrect, 2)
        LearningEngine.record(question: question, evaluation: correct, state: &state)
        XCTAssertNil(state.weakQuestions[question.id])
    }

    func testWrongAnswerResetsWeakStreak() throws {
        let question = singleQuestion()
        var state = LearningState(contentVersion: "test-v1")
        let wrong = try LearningEngine.evaluate(question, answer: AnswerPayload(selectedIndices: [1]))
        let correct = try LearningEngine.evaluate(question, answer: AnswerPayload(selectedIndices: [0]))
        LearningEngine.record(question: question, evaluation: wrong, state: &state)
        LearningEngine.record(question: question, evaluation: correct, state: &state)
        LearningEngine.record(question: question, evaluation: correct, state: &state)
        XCTAssertEqual(state.weakQuestions[question.id]?.consecutiveCorrect, 2)
        LearningEngine.record(question: question, evaluation: wrong, state: &state)
        XCTAssertEqual(state.weakQuestions[question.id]?.consecutiveCorrect, 0)
    }

    func testMultiChoiceOrderDoesNotMatter() throws {
        let question = LearningQuestion(
            id: "M1",
            subject: "法令",
            topic: "複数選択",
            answerType: .multiChoice,
            prompt: "2つ選べ",
            choices: ["A", "B", "C", "D"],
            correctIndices: [0, 2],
            memoryPoint: "AとC",
            explanation: "理由",
            sourceCheckedAt: "2026-08-10",
            lawBaselineDate: "2026-07-01",
            contentVersion: "test-v1"
        )
        let evaluation = try LearningEngine.evaluate(question, answer: AnswerPayload(selectedIndices: [2, 0]))
        XCTAssertTrue(evaluation.isCorrect)
    }

    func testNumericAcceptedRange() throws {
        let question = LearningQuestion(
            id: "N1",
            subject: "実務",
            topic: "計算",
            answerType: .numeric,
            prompt: "計算せよ",
            correctNumber: 100,
            acceptedRange: 0.5,
            unit: "円",
            memoryPoint: "計算式",
            explanation: "理由",
            sourceCheckedAt: "2026-08-10",
            lawBaselineDate: "2026-07-01",
            contentVersion: "test-v1"
        )
        XCTAssertTrue(try LearningEngine.evaluate(question, answer: AnswerPayload(numberValue: 100.4)).isCorrect)
        XCTAssertFalse(try LearningEngine.evaluate(question, answer: AnswerPayload(numberValue: 100.6)).isCorrect)
    }

    func testBlankSelectAndDeclaration() throws {
        let blank = LearningQuestion(
            id: "B1",
            subject: "実務",
            topic: "空欄",
            answerType: .blankSelect,
            prompt: "空欄",
            blanks: [BlankField(key: "a", label: "A", options: ["甲", "乙"], correctValue: "甲")],
            memoryPoint: "甲",
            explanation: "理由",
            sourceCheckedAt: "2026-08-10",
            lawBaselineDate: "2026-07-01",
            contentVersion: "test-v1"
        )
        XCTAssertTrue(try LearningEngine.evaluate(blank, answer: AnswerPayload(blankValues: ["a": "甲"])).isCorrect)

        let declaration = LearningQuestion(
            id: "D1",
            subject: "実務",
            topic: "申告書",
            answerType: .declaration,
            prompt: "入力",
            declarationFields: [DeclarationField(key: "code", label: "コード", correctValue: "ABC")],
            memoryPoint: "コード",
            explanation: "理由",
            sourceCheckedAt: "2026-08-10",
            lawBaselineDate: "2026-07-01",
            contentVersion: "test-v1"
        )
        XCTAssertTrue(try LearningEngine.evaluate(declaration, answer: AnswerPayload(declarationValues: ["code": " abc "])).isCorrect)
    }

    func testBackupRoundTripAndCrossAppGuard() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let store = LearningStateStore(bundleID: "jp.example.a", contentVersion: "v1", directoryURL: temp)
        var state = LearningState(contentVersion: "v1")
        state.dailyTarget = 16
        state.weakQuestions["Q1"] = WeakQuestionState()
        try store.save(state)
        XCTAssertEqual(try store.load().dailyTarget, 16)

        let data = try store.exportBackup(state)
        XCTAssertEqual(try store.importBackup(data), state)

        let other = LearningStateStore(bundleID: "jp.example.b", contentVersion: "v1", directoryURL: temp)
        XCTAssertThrowsError(try other.importBackup(data))
    }

    func testHeatmapReturnsOnlyLast35Days() {
        var state = LearningState(contentVersion: "v1")
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let recent = calendar.date(byAdding: .day, value: -2, to: now)!
        let old = calendar.date(byAdding: .day, value: -40, to: now)!
        state.attempts = [
            LearningAttempt(questionID: "Q1", answeredAt: recent, isCorrect: true, isUnknown: false, subject: "A", topic: "a"),
            LearningAttempt(questionID: "Q2", answeredAt: old, isCorrect: true, isUnknown: false, subject: "A", topic: "a")
        ]
        let heatmap = LearningEngine.heatmap35Days(state: state, endingAt: now, calendar: calendar)
        XCTAssertEqual(heatmap.values.reduce(0, +), 1)
    }
}
