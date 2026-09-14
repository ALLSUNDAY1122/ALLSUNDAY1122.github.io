import XCTest
@testable import TsukanshiNative
import LearningSprintCore

final class TsukanshiSessionRoutingTests: XCTestCase {
    @MainActor
    func testFinalMockUnknownRunsGradingAndCompletionRoute() throws {
        let model = TsukanshiAppModel()
        XCTAssertNil(model.loadError)

        let question = LearningQuestion(
            id: "route-final-unknown",
            subject: "通関業法",
            topic: "テスト",
            answerType: .singleChoice,
            prompt: "正しいものはどれか",
            choices: ["A", "B"],
            correctIndices: [0],
            memoryPoint: "A",
            explanation: "test",
            sourceCheckedAt: "2026-08-10",
            lawBaselineDate: "2026-07-01",
            contentVersion: "test"
        )
        let kind = SessionKind.mock("第59回|通関業法")
        let session = TsukanshiStudySession(kind: kind, questions: [question])
        let attemptsBefore = model.state.attempts.count
        let completionsBefore = model.completionCount(for: kind)

        model.submit(.unknown, in: session)
        model.advance(session)

        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(session.evaluations[question.id]?.isUnknown, true)
        XCTAssertEqual(model.state.attempts.count, attemptsBefore + 1)
        XCTAssertEqual(model.completionCount(for: kind), completionsBefore + 1)
    }
}
