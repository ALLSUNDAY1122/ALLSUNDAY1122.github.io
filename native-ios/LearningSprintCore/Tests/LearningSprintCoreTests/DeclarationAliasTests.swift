import XCTest
@testable import LearningSprintCore

final class DeclarationAliasTests: XCTestCase {
    func testDeclarationAcceptsAuditedAlias() throws {
        let question = LearningQuestion(
            id: "D-ALIAS",
            subject: "実務",
            topic: "申告書",
            answerType: .declaration,
            prompt: "原産国を入力",
            declarationFields: [DeclarationField(key: "origin", label: "原産国", correctValue: "ベトナム", aliases: ["ベトナム社会主義共和国"])],
            memoryPoint: "許容表記も監査済みデータに従う",
            explanation: "別名は問題データに明示する",
            sourceCheckedAt: "2026-08-10",
            lawBaselineDate: "2026-07-01",
            contentVersion: "test-v1"
        )
        XCTAssertTrue(try LearningEngine.evaluate(question, answer: AnswerPayload(declarationValues: ["origin": " ベトナム社会主義共和国 "])).isCorrect)
    }

    func testNumericRoundingRuleMetadataIsPreserved() {
        let question = LearningQuestion(
            id: "N-RULE",
            subject: "実務",
            topic: "計算",
            answerType: .numeric,
            prompt: "計算",
            correctNumber: 100,
            acceptedRange: 0,
            unit: "円",
            roundingRule: "1円未満切捨て",
            memoryPoint: "端数処理を先に確認",
            explanation: "問題固有ルール",
            sourceCheckedAt: "2026-08-10",
            lawBaselineDate: "2026-07-01",
            contentVersion: "test-v1"
        )
        XCTAssertEqual(question.roundingRule, "1円未満切捨て")
    }
}
