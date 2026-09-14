import XCTest
import LearningSprintCore
@testable import TsukanshiNative

final class TsukanshiLearningAcceptanceTests: XCTestCase {
    func testUnknownCreatesWeakReviewAndThreeCorrectRetriesGraduateIt() throws {
        let store = try TsukanshiContentStore()
        guard let question = store.studyQuestions.first(where: { !$0.premium }) else {
            return XCTFail("free study question missing")
        }

        var state = LearningState(contentVersion: store.bank.contentVersion)

        let miss = try LearningEngine.evaluate(question, answer: .unknown)
        XCTAssertFalse(miss.isCorrect)
        XCTAssertTrue(miss.isUnknown)
        LearningEngine.record(question: question, evaluation: miss, state: &state)
        XCTAssertNotNil(state.weakQuestions[question.id], "unknown must register a weak question")
        XCTAssertEqual(state.attempts.count, 1, "first attempt must advance progress history")

        let review = LearningEngine.selectWeak(
            from: store.questions,
            state: state,
            target: 8,
            isPremium: false
        )
        XCTAssertTrue(review.contains(where: { $0.id == question.id }), "recorded miss must be reachable from weak review")

        func correctPayload(for question: LearningQuestion) throws -> AnswerPayload {
            switch question.answerType {
            case .singleChoice, .multiChoice:
                return AnswerPayload(selectedIndices: question.correctIndices)
            case .numeric:
                guard let value = question.correctNumber else { throw LearningEngineError.invalidQuestion(question.id) }
                return AnswerPayload(numberValue: value)
            case .blankSelect:
                return AnswerPayload(blankValues: Dictionary(uniqueKeysWithValues: question.blanks.map { ($0.key, $0.correctValue) }))
            case .declaration:
                return AnswerPayload(declarationValues: Dictionary(uniqueKeysWithValues: question.declarationFields.map { ($0.key, $0.correctValue) }))
            }
        }

        for retry in 1...3 {
            let evaluation = try LearningEngine.evaluate(question, answer: correctPayload(for: question))
            XCTAssertTrue(evaluation.isCorrect, "retry \(retry) must be correct")
            LearningEngine.record(question: question, evaluation: evaluation, state: &state)
            if retry < 3 {
                XCTAssertEqual(state.weakQuestions[question.id]?.consecutiveCorrect, retry)
            }
        }

        XCTAssertNil(state.weakQuestions[question.id], "three correct retries must graduate the weak item")
        XCTAssertEqual(state.attempts.count, 4, "miss plus three retries must remain visible in progress history")
    }
}
