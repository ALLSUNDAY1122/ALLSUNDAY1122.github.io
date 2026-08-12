import XCTest
@testable import YobiTantouSprint

final class MockSelectionPolicyTests: XCTestCase {
    private func question(id: String, subject: String) -> StudyQuestion {
        StudyQuestion(
            id: id,
            examYear: 2026,
            subject: subject,
            topic: "mock policy test",
            stem: "test",
            choices: ["A", "B"],
            correctIndices: [0],
            explanation: "test explanation",
            memory: "test memory",
            sourceTitle: "test",
            sourceURL: "https://example.invalid/test",
            evidenceCheckedDate: "2026-08-13",
            lawBasisDate: subject == "一般教養" ? nil : "2026-01-01",
            originType: "original_from_primary_source",
            releaseEligible: true
        )
    }

    func testMockSelectsAllLegalAndOnlyTwentyGeneralEducationQuestions() {
        let legal = (1...3).map { question(id: "L\($0)", subject: "憲法") }
        let general = (1...25).map { question(id: "G\($0)", subject: "一般教養") }
        let selected = MockSelectionPolicy.select(from: legal + general, shuffleGeneralEducation: false)

        XCTAssertEqual(selected.filter { $0.subject != "一般教養" }.count, 3)
        XCTAssertEqual(selected.filter { $0.subject == "一般教養" }.count, 20)
        XCTAssertEqual(selected.count, 23)
        XCTAssertEqual(selected.filter { $0.subject == "一般教養" }.map(\.id), (1...20).map { "G\($0)" })
    }

    func testMockUsesAllGeneralEducationQuestionsWhenFewerThanTwentyExist() {
        let general = (1...15).map { question(id: "G\($0)", subject: "一般教養") }
        let selected = MockSelectionPolicy.select(from: general, shuffleGeneralEducation: false)
        XCTAssertEqual(selected.count, 15)
    }

    func testMockSummaryReportsScoredQuestionCount() {
        let legal = (1...7).map { question(id: "L\($0)", subject: "民法") }
        let general = (1...40).map { question(id: "G\($0)", subject: "一般教養") }
        let summary = MockSelectionPolicy.summary(for: legal + general)

        XCTAssertEqual(summary.legalCount, 7)
        XCTAssertEqual(summary.generalEducationAvailable, 40)
        XCTAssertEqual(summary.generalEducationSelected, 20)
        XCTAssertEqual(summary.totalScoredQuestions, 27)
    }
}
