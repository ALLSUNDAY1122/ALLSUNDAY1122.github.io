import XCTest
@testable import YobiTantouSprint

@MainActor
final class YobiTantouSprintTests: XCTestCase {
    private func freshModel() -> AppModel {
        let model = AppModel(bundle: .main)
        model.state = PersistentState()
        model.activeSession = nil
        model.lastResult = nil
        return model
    }

    func testPreviewBankHasEightNonReleaseQuestions() {
        let model = freshModel()
        XCTAssertNil(model.startupError)
        XCTAssertEqual(model.questions.count, 8)
        XCTAssertTrue(model.questions.allSatisfy { !$0.releaseEligible && $0.originType == "original_preview" })
        XCTAssertTrue(model.isPreviewBank)
    }

    func testWeakQuestionClearsAfterThreeConsecutiveCorrectAnswers() {
        let model = freshModel()
        guard let question = model.questions.first else { return XCTFail("preview question missing") }
        model.state.attempts[question.id] = AttemptState(answered: 1, correct: 0, consecutiveCorrect: 0, weak: true, unknown: false)

        for expected in 1...3 {
            XCTAssertTrue(model.start(.weak, premium: true))
            XCTAssertEqual(model.currentQuestion?.id, question.id)
            model.answer(selectedIndices: Set(question.correctIndices))
            XCTAssertEqual(model.state.attempts[question.id]?.consecutiveCorrect, expected)
        }
        XCTAssertEqual(model.state.attempts[question.id]?.weak, false)
    }

    func testResumePreservesCorrectCount() {
        let model = freshModel()
        XCTAssertTrue(model.start(.daily, premium: true))
        guard let question = model.currentQuestion else { return XCTFail("question missing") }
        model.answer(selectedIndices: Set(question.correctIndices))
        XCTAssertEqual(model.state.resume?.correct, 1)

        model.activeSession = nil
        XCTAssertTrue(model.resume(premium: true))
        XCTAssertEqual(model.activeSession?.correct, 1)
        XCTAssertEqual(model.activeSession?.index, 1)
    }

    func testBackupCannotRestoreConsumedFreeSprint() throws {
        let model = freshModel()
        model.state.freeSprintConsumed = false
        let oldBackup = try model.backupData()
        model.state.freeSprintConsumed = true

        try model.importBackup(oldBackup)
        XCTAssertTrue(model.state.freeSprintConsumed)
    }

    func testResetCannotRestoreConsumedFreeSprint() {
        let model = freshModel()
        model.state.freeSprintConsumed = true
        model.state.totalAnswered = 50
        model.resetLearningData()
        XCTAssertTrue(model.state.freeSprintConsumed)
        XCTAssertEqual(model.state.totalAnswered, 0)
    }

    func testBackupRejectsImpossibleCounts() throws {
        let model = freshModel()
        var invalid = PersistentState()
        invalid.totalAnswered = 1
        invalid.totalCorrect = 2
        let payload = BackupPayload(schemaVersion: 1, exportedAt: Date(), state: invalid)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        XCTAssertThrowsError(try model.importBackup(data))
    }

    func testBackupRejectsOversizedPayload() {
        let model = freshModel()
        XCTAssertThrowsError(try model.importBackup(Data(repeating: 0x20, count: 5 * 1024 * 1024 + 1)))
    }
}
