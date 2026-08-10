import XCTest
@testable import LearningSprintCore

final class LearningSprintCoreTests: XCTestCase {
    func testAllowedDailyTargets() {
        XCTAssertTrue(LearningState.validTarget(4))
        XCTAssertTrue(LearningState.validTarget(8))
        XCTAssertTrue(LearningState.validTarget(16))
        XCTAssertFalse(LearningState.validTarget(12))
    }

    func testSingleChoiceImmediateEvaluation() throws {
        let q = LearningQuestion(
            id: "Q1", subject: "A", topic: "a", answerType: .singleChoice,
            prompt: "p", choices: ["A", "B"], correctIndices: [1],
            memoryPoint: "m", explanation: "e",
            sourceCheckedAt: "2026-08-10", lawBaselineDate: "2026-08-10", contentVersion: "v1"
        )
        XCTAssertTrue(try LearningEngine.evaluate(q, answer: AnswerPayload(selectedIndices: [1])).isCorrect)
        XCTAssertFalse(try LearningEngine.evaluate(q, answer: AnswerPayload(selectedIndices: [0])).isCorrect)
    }

    func testUnknownAlwaysRegistersWeak() throws {
        let q = LearningQuestion(
            id: "Q1", subject: "A", topic: "a", answerType: .singleChoice,
            prompt: "p", choices: ["A", "B"], correctIndices: [1],
            memoryPoint: "m", explanation: "e",
            sourceCheckedAt: "2026-08-10", lawBaselineDate: "2026-08-10", contentVersion: "v1"
        )
        var state = LearningState(contentVersion: "v1")
        let eval = try LearningEngine.evaluate(q, answer: .unknown)
        LearningEngine.record(question: q, evaluation: eval, state: &state)
        XCTAssertNotNil(state.weakQuestions[q.id])
        XCTAssertEqual(state.weakQuestions[q.id]?.consecutiveCorrect, 0)
    }

    func testWeakQuestionGraduatesAfterThreeConsecutiveCorrectAnswers() throws {
        let q = LearningQuestion(
            id: "Q1", subject: "A", topic: "a", answerType: .singleChoice,
            prompt: "p", choices: ["A", "B"], correctIndices: [1],
            memoryPoint: "m", explanation: "e",
            sourceCheckedAt: "2026-08-10", lawBaselineDate: "2026-08-10", contentVersion: "v1"
        )
        var state = LearningState(contentVersion: "v1")
        LearningEngine.record(question: q, evaluation: .init(isCorrect: false, isUnknown: false, message: ""), state: &state)
        for _ in 0..<2 {
            LearningEngine.record(question: q, evaluation: .init(isCorrect: true, isUnknown: false, message: ""), state: &state)
        }
        XCTAssertEqual(state.weakQuestions[q.id]?.consecutiveCorrect, 2)
        LearningEngine.record(question: q, evaluation: .init(isCorrect: true, isUnknown: false, message: ""), state: &state)
        XCTAssertNil(state.weakQuestions[q.id])
    }

    func testWrongAnswerResetsWeakStreak() throws {
        let q = LearningQuestion(
            id: "Q1", subject: "A", topic: "a", answerType: .singleChoice,
            prompt: "p", choices: ["A", "B"], correctIndices: [1],
            memoryPoint: "m", explanation: "e",
            sourceCheckedAt: "2026-08-10", lawBaselineDate: "2026-08-10", contentVersion: "v1"
        )
        var state = LearningState(contentVersion: "v1")
        state.weakQuestions[q.id] = WeakQuestionState(consecutiveCorrect: 2)
        LearningEngine.record(question: q, evaluation: .init(isCorrect: false, isUnknown: false, message: ""), state: &state)
        XCTAssertEqual(state.weakQuestions[q.id]?.consecutiveCorrect, 0)
    }

    func testMultiChoiceOrderDoesNotMatter() throws {
        let q = LearningQuestion(
            id: "M1", subject: "A", topic: "a", answerType: .multiChoice,
            prompt: "p", choices: ["A", "B", "C"], correctIndices: [0, 2],
            memoryPoint: "m", explanation: "e",
            sourceCheckedAt: "2026-08-10", lawBaselineDate: "2026-08-10", contentVersion: "v1"
        )
        XCTAssertTrue(try LearningEngine.evaluate(q, answer: AnswerPayload(selectedIndices: [2, 0])).isCorrect)
    }

    func testNumericAcceptedRange() throws {
        let q = LearningQuestion(
            id: "N1", subject: "A", topic: "a", answerType: .numeric,
            prompt: "p", correctNumber: 10, acceptedRange: 0.5,
            memoryPoint: "m", explanation: "e",
            sourceCheckedAt: "2026-08-10", lawBaselineDate: "2026-08-10", contentVersion: "v1"
        )
        XCTAssertTrue(try LearningEngine.evaluate(q, answer: AnswerPayload(numberValue: 10.4)).isCorrect)
        XCTAssertFalse(try LearningEngine.evaluate(q, answer: AnswerPayload(numberValue: 10.6)).isCorrect)
    }

    func testBlankSelectAndDeclaration() throws {
        let blank = LearningQuestion(
            id: "B1", subject: "実務", topic: "空欄", answerType: .blankSelect,
            prompt: "選択", blanks: [BlankField(key: "a", label: "A", options: ["甲", "乙"], correctValue: "甲")],
            memoryPoint: "甲", explanation: "理由",
            sourceCheckedAt: "2026-08-10", lawBaselineDate: "2026-07-01", contentVersion: "test-v1"
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
        // ISO-8601の小数秒表現で完全往復できる固定値を使い、実装不具合とテスト生成時刻の精度差を分離する。
        let fixedDate = Date(timeIntervalSince1970: 2_000_000_000.123)
        state.weakQuestions["Q1"] = WeakQuestionState(lastAnsweredAt: fixedDate)
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
