import XCTest
@testable import KanteishiCore

final class KanteishiCoreTests: XCTestCase {
    func testThreeOfficialEditionsFixQuestionTargetAt240() {
        XCTAssertEqual(LearningEngine.targetOfficialQuestionCount, 240)
    }

    func testStandardSprintAlwaysCapsAtEight() {
        let questions = (0..<12).map(makeQuestion)
        XCTAssertEqual(LearningEngine.standardSprint(from: questions).count, 8)
    }

    func testStandardSprintDoesNotPadWhenFewerThanEightExist() {
        let questions = (0..<5).map(makeQuestion)
        XCTAssertEqual(LearningEngine.standardSprint(from: questions).count, 5)
    }

    func testWeakQuestionClearsOnlyAfterThreeConsecutiveCorrectAnswers() {
        let t0 = Date(timeIntervalSince1970: 1)
        let attempts = [
            AttemptRecord(questionID: "q1", isCorrect: false, isUncertain: false, answeredAt: t0),
            AttemptRecord(questionID: "q1", isCorrect: true, isUncertain: false, answeredAt: t0.addingTimeInterval(1)),
            AttemptRecord(questionID: "q1", isCorrect: true, isUncertain: false, answeredAt: t0.addingTimeInterval(2))
        ]
        XCTAssertTrue(LearningEngine.weakQuestionIDs(from: attempts).contains("q1"))

        let cleared = attempts + [AttemptRecord(questionID: "q1", isCorrect: true, isUncertain: false, answeredAt: t0.addingTimeInterval(3))]
        XCTAssertFalse(LearningEngine.weakQuestionIDs(from: cleared).contains("q1"))
    }

    func testUncertainFlagIsRecoverableFromHistory() {
        let attempts = [AttemptRecord(questionID: "q1", isCorrect: true, isUncertain: true)]
        XCTAssertEqual(LearningEngine.uncertainQuestionIDs(from: attempts), ["q1"])
    }

    func testResumeAndHistoryRoundTripThroughJSONBackup() throws {
        let snapshot = ProgressSnapshot(
            attempts: [AttemptRecord(questionID: "q1", isCorrect: false, isUncertain: true, answeredAt: Date(timeIntervalSince1970: 100))],
            resumeState: ResumeState(
                mode: .standardSprint,
                questionIDs: ["q1", "q2"],
                currentIndex: 1,
                selectedAnswers: ["q1": 2],
                uncertainQuestionIDs: ["q1"]
            )
        )
        let data = try BackupStore.export(snapshot)
        let restored = try BackupStore.importSnapshot(from: data)
        XCTAssertEqual(restored, snapshot)
    }

    func testStoreKitProductIDsRemainUnsetUntilConfirmed() {
        XCTAssertTrue(StoreKitProductCatalog.productIDs.isEmpty)
        XCTAssertFalse(StoreKitProductCatalog.isConfigured)
    }

    func testQuestionAuditRejectsEvidenceMissingFixture() {
        let invalid = Question(
            id: "invalid",
            edition: .reiwa8,
            subject: .valuationTheory,
            domain: "fixture",
            prompt: "fixture",
            choices: ["A", "B"],
            correctChoiceIndex: 0,
            explanation: "fixture",
            memoryPoint: "fixture",
            evidence: []
        )
        XCTAssertEqual(LearningEngine.auditProductionQuestions([invalid]), ["notProductionReady:invalid"])
    }

    private func makeQuestion(_ index: Int) -> Question {
        Question(
            id: "fixture-\(index)",
            edition: .reiwa8,
            subject: index.isMultiple(of: 2) ? .administrativeLaw : .valuationTheory,
            domain: "test",
            prompt: "test \(index)",
            choices: ["A", "B"],
            correctChoiceIndex: 0,
            explanation: "test only",
            memoryPoint: "test only",
            evidence: [EvidenceSource(
                title: "test",
                url: URL(string: "https://example.invalid/test")!,
                checkedDate: "2026-08-12"
            )]
        )
    }
}
