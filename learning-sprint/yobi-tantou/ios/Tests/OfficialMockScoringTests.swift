import XCTest
@testable import YobiTantouSprint

final class OfficialMockScoringTests: XCTestCase {
    private func scoring(
        maxPoints: Int = 3,
        bands: [OfficialScoreBand] = [
            .init(minimumCorrect: 3, points: 3),
            .init(minimumCorrect: 2, points: 1)
        ]
    ) -> OfficialMockQuestionScoring {
        OfficialMockQuestionScoring(
            id: "2025-CON-001",
            examYear: 2025,
            subject: "憲法",
            questionNumber: 1,
            maxPoints: maxPoints,
            responseSlots: [
                .init(id: "No.1", correctOption: 1),
                .init(id: "No.2", correctOption: 2),
                .init(id: "No.3", correctOption: 1)
            ],
            scoreBands: bands,
            sourceURL: "https://www.moj.go.jp/content/example.pdf",
            verifiedAt: "2026-08-13"
        )
    }

    func testFullCreditForAllRequiredSlots() {
        let question = scoring()
        XCTAssertTrue(question.isStructurallyValid)
        XCTAssertEqual(question.score(responses: ["No.1":1, "No.2":2, "No.3":1]), 3)
    }

    func testPartialCreditBand() {
        let question = scoring()
        XCTAssertEqual(question.score(responses: ["No.1":1, "No.2":2, "No.3":2]), 1)
    }

    func testBelowLowestBandScoresZero() {
        let question = scoring()
        XCTAssertEqual(question.score(responses: ["No.1":1, "No.2":5, "No.3":5]), 0)
    }

    func testAllOrNothingQuestionIsRepresentable() {
        let question = scoring(maxPoints: 3, bands: [.init(minimumCorrect: 2, points: 3)])
        XCTAssertEqual(question.score(responses: ["No.1":1, "No.2":2]), 3)
        XCTAssertEqual(question.score(responses: ["No.1":1]), 0)
    }

    func testAggregateScorerUsesPointsNotBinaryAccuracy() {
        let question = scoring()
        let result = OfficialMockScorer.score(
            questions: [question],
            responses: [question.id: ["No.1":1, "No.2":2, "No.3":2]]
        )
        XCTAssertEqual(result.earnedPoints, 1)
        XCTAssertEqual(result.maxPoints, 3)
        XCTAssertEqual(result.answeredQuestions, 1)
    }

    func testInvalidScoringRuleIsRejected() {
        let invalid = scoring(bands: [.init(minimumCorrect: 4, points: 3)])
        XCTAssertFalse(invalid.isStructurallyValid)
    }
}
