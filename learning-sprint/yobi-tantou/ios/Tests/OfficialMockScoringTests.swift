import XCTest
@testable import YobiTantouSprint

final class OfficialMockScoringTests: XCTestCase {
    private func orderedScoring(
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
            responseGroups: [
                .init(
                    id: "ordered",
                    slotIDs: ["No.1", "No.2", "No.3"],
                    correctOptions: [1, 2, 1],
                    orderSensitive: true
                )
            ],
            scoreBands: bands,
            sourceURL: "https://www.moj.go.jp/content/example.pdf",
            verifiedAt: "2026-08-13"
        )
    }

    func testFullCreditForAllRequiredSlots() {
        let question = orderedScoring()
        XCTAssertTrue(question.isStructurallyValid)
        XCTAssertEqual(question.score(responses: ["No.1":1, "No.2":2, "No.3":1]), 3)
    }

    func testPartialCreditBand() {
        let question = orderedScoring()
        XCTAssertEqual(question.score(responses: ["No.1":1, "No.2":2, "No.3":2]), 1)
    }

    func testBelowLowestBandScoresZero() {
        let question = orderedScoring()
        XCTAssertEqual(question.score(responses: ["No.1":1, "No.2":5, "No.3":5]), 0)
    }

    func testAllOrNothingQuestionIsRepresentable() {
        let question = OfficialMockQuestionScoring(
            id: "2025-CRM-004",
            examYear: 2025,
            subject: "刑法",
            questionNumber: 4,
            maxPoints: 3,
            responseGroups: [
                .init(id: "unordered", slotIDs: ["No.4", "No.5"], correctOptions: [2, 5], orderSensitive: false)
            ],
            scoreBands: [.init(minimumCorrect: 2, points: 3)],
            sourceURL: "https://www.moj.go.jp/content/001444175.pdf",
            verifiedAt: "2026-08-13"
        )
        XCTAssertTrue(question.isStructurallyValid)
        XCTAssertEqual(question.score(responses: ["No.4":2, "No.5":5]), 3)
        XCTAssertEqual(question.score(responses: ["No.4":5, "No.5":2]), 3)
        XCTAssertEqual(question.score(responses: ["No.4":2]), 0)
    }

    func testUnorderedGroupCanAwardOneCorrectPartialCredit() {
        let question = OfficialMockQuestionScoring(
            id: "2024-CVP-032",
            examYear: 2024,
            subject: "民事訴訟法",
            questionNumber: 32,
            maxPoints: 2,
            responseGroups: [
                .init(id: "unordered", slotIDs: ["No.32", "No.33"], correctOptions: [3, 5], orderSensitive: false)
            ],
            scoreBands: [
                .init(minimumCorrect: 2, points: 2),
                .init(minimumCorrect: 1, points: 1)
            ],
            sourceURL: "https://www.moj.go.jp/content/001422570.pdf",
            verifiedAt: "2026-08-13"
        )
        XCTAssertEqual(question.score(responses: ["No.32":5, "No.33":4]), 1)
        XCTAssertEqual(question.score(responses: ["No.32":5, "No.33":3]), 2)
    }

    func testFiveSlotFourCorrectPartialCreditShape() {
        let question = OfficialMockQuestionScoring(
            id: "2025-CRM-013",
            examYear: 2025,
            subject: "刑法",
            questionNumber: 13,
            maxPoints: 4,
            responseGroups: [
                .init(
                    id: "ordered",
                    slotIDs: ["No.15", "No.16", "No.17", "No.18", "No.19"],
                    correctOptions: [2, 2, 2, 2, 2],
                    orderSensitive: true
                )
            ],
            scoreBands: [
                .init(minimumCorrect: 5, points: 4),
                .init(minimumCorrect: 4, points: 2)
            ],
            sourceURL: "https://www.moj.go.jp/content/001444175.pdf",
            verifiedAt: "2026-08-13"
        )
        XCTAssertEqual(question.score(responses: ["No.15":2,"No.16":2,"No.17":2,"No.18":2,"No.19":1]), 2)
        XCTAssertEqual(question.score(responses: ["No.15":2,"No.16":2,"No.17":2,"No.18":2,"No.19":2]), 4)
    }

    func testAggregateScorerUsesPointsNotBinaryAccuracy() {
        let question = orderedScoring()
        let result = OfficialMockScorer.score(
            questions: [question],
            responses: [question.id: ["No.1":1, "No.2":2, "No.3":2]]
        )
        XCTAssertEqual(result.earnedPoints, 1)
        XCTAssertEqual(result.maxPoints, 3)
        XCTAssertEqual(result.answeredQuestions, 1)
    }

    func testInvalidScoringRuleIsRejected() {
        let invalid = orderedScoring(bands: [.init(minimumCorrect: 4, points: 3)])
        XCTAssertFalse(invalid.isStructurallyValid)
    }

    func testDuplicateSlotAcrossGroupsIsRejected() {
        let invalid = OfficialMockQuestionScoring(
            id: "invalid",
            examYear: 2025,
            subject: "憲法",
            questionNumber: 1,
            maxPoints: 2,
            responseGroups: [
                .init(id: "a", slotIDs: ["No.1"], correctOptions: [1], orderSensitive: true),
                .init(id: "b", slotIDs: ["No.1"], correctOptions: [2], orderSensitive: true)
            ],
            scoreBands: [.init(minimumCorrect: 2, points: 2)],
            sourceURL: "https://www.moj.go.jp/content/example.pdf",
            verifiedAt: "2026-08-13"
        )
        XCTAssertFalse(invalid.isStructurallyValid)
    }
}
