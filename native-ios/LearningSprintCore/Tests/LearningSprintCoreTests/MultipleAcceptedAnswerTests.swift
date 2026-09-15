import XCTest
@testable import LearningSprintCore

final class MultipleAcceptedAnswerTests: XCTestCase {
    private func question(
        answerType: LearningAnswerType,
        correctIndices: [Int],
        acceptedIndexSets: [[Int]]? = nil
    ) -> LearningQuestion {
        LearningQuestion(
            id: "TEST-ALT",
            subject: "理学療法",
            topic: "公式訂正",
            answerType: answerType,
            prompt: "テスト問題",
            choices: ["1", "2", "3", "4", "5"],
            correctIndices: correctIndices,
            acceptedIndexSets: acceptedIndexSets,
            memoryPoint: "公式最終正答を使う",
            explanation: "複数正答の回帰テスト",
            sourceCheckedAt: "2026-08-13",
            lawBaselineDate: "2026-08-13",
            contentVersion: "test"
        )
    }

    func testSingleChoiceAcceptsAnyOfficialAlternative() throws {
        let q = question(
            answerType: .singleChoice,
            correctIndices: [0],
            acceptedIndexSets: [[0], [4]]
        )
        XCTAssertTrue(try LearningEngine.evaluate(q, answer: AnswerPayload(selectedIndices: [0])).isCorrect)
        XCTAssertTrue(try LearningEngine.evaluate(q, answer: AnswerPayload(selectedIndices: [4])).isCorrect)
        XCTAssertFalse(try LearningEngine.evaluate(q, answer: AnswerPayload(selectedIndices: [1])).isCorrect)
    }

    func testMultiChoiceAcceptsAnyOfficialPair() throws {
        let q = question(
            answerType: .multiChoice,
            correctIndices: [0, 1],
            acceptedIndexSets: [[0, 1], [0, 4], [1, 4]]
        )
        XCTAssertTrue(try LearningEngine.evaluate(q, answer: AnswerPayload(selectedIndices: [1, 0])).isCorrect)
        XCTAssertTrue(try LearningEngine.evaluate(q, answer: AnswerPayload(selectedIndices: [4, 0])).isCorrect)
        XCTAssertTrue(try LearningEngine.evaluate(q, answer: AnswerPayload(selectedIndices: [1, 4])).isCorrect)
        XCTAssertFalse(try LearningEngine.evaluate(q, answer: AnswerPayload(selectedIndices: [0, 2])).isCorrect)
    }

    func testLegacyQuestionWithoutAlternativesKeepsPreviousBehavior() throws {
        let q = question(answerType: .multiChoice, correctIndices: [1, 3])
        XCTAssertTrue(try LearningEngine.evaluate(q, answer: AnswerPayload(selectedIndices: [3, 1])).isCorrect)
        XCTAssertFalse(try LearningEngine.evaluate(q, answer: AnswerPayload(selectedIndices: [1, 4])).isCorrect)
    }

    func testDecodingLegacyJSONWithoutAcceptedIndexSets() throws {
        let json = """
        {
          "id":"LEGACY",
          "subject":"解剖学",
          "topic":"互換性",
          "answerType":"singleChoice",
          "prompt":"問題",
          "choices":["A","B"],
          "correctIndices":[1],
          "correctNumber":null,
          "acceptedRange":null,
          "unit":null,
          "roundingRule":null,
          "blanks":[],
          "declarationFields":[],
          "sourceText":null,
          "memoryPoint":"B",
          "explanation":"Bが正解",
          "sourceTitle":null,
          "sourceURL":null,
          "sourceRefs":[],
          "sourceCheckedAt":"2026-08-13",
          "lawBaselineDate":"2026-08-13",
          "contentVersion":"legacy",
          "premium":false,
          "examRound":null,
          "questionNumber":null,
          "rightsBasis":null
        }
        """
        let decoded = try JSONDecoder().decode(LearningQuestion.self, from: Data(json.utf8))
        XCTAssertNil(decoded.acceptedIndexSets)
        XCTAssertTrue(try LearningEngine.evaluate(decoded, answer: AnswerPayload(selectedIndices: [1])).isCorrect)
    }
}
