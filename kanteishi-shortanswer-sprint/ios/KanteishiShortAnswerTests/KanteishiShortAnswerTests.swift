import XCTest
@testable import KanteishiShortAnswer

final class KanteishiShortAnswerTests: XCTestCase {
    func testPrototypePayloadAndProductionContract() throws {
        let repository = try QuestionRepository.load()
        XCTAssertEqual(repository.questions.count, 12)
        XCTAssertEqual(repository.payload.productionTargetCount, 240)
        XCTAssertEqual(repository.editions, [2026, 2025, 2024])
        XCTAssertEqual(repository.questions(edition: 2026).count, 4)
        XCTAssertEqual(repository.questions(edition: 2025).count, 4)
        XCTAssertEqual(repository.questions(edition: 2024).count, 4)
    }

    @MainActor
    func testUnknownRegistersWeakAndThreeCorrectAnswersReleaseIt() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let store = LearningStore(persistenceURL: url)
        guard let question = store.repository.questions.first else {
            XCTFail("No prototype question")
            return
        }

        store.retryQuestions([question.id], title: "test")
        store.submitAnswer(nil)
        XCTAssertEqual(store.state.weak[question.id]?.streak, 0)
        store.advanceSession()

        for expectedStreak in 1...2 {
            store.retryQuestions([question.id], title: "test")
            store.submitAnswer(question.correctIndex)
            XCTAssertEqual(store.state.weak[question.id]?.streak, expectedStreak)
            store.advanceSession()
        }

        store.retryQuestions([question.id], title: "test")
        store.submitAnswer(question.correctIndex)
        XCTAssertNil(store.state.weak[question.id])
    }

    @MainActor
    func testBackupRoundTripAndSanitization() throws {
        let firstURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let secondURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let first = LearningStore(persistenceURL: firstURL)
        first.setDailyGoal(16)
        first.setFontSize(.large)
        let data = try first.exportBackup()

        let second = LearningStore(persistenceURL: secondURL)
        try second.importBackup(data)
        XCTAssertEqual(second.settings.dailyGoal, 16)
        XCTAssertEqual(second.settings.fontSize, .large)
        XCTAssertEqual(second.state.contentVersion, first.state.contentVersion)
    }

    @MainActor
    func testPrototypeMockUsesFourQuestionsPerEdition() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let store = LearningStore(persistenceURL: url)
        store.startMock(edition: 2026)
        XCTAssertEqual(store.session?.total, 4)
        XCTAssertEqual(store.session?.mode, .mock)
    }

    func testStoreKitAccessPolicyNeverUnlocksUnverifiedStates() {
        XCTAssertTrue(PremiumAccessPolicy.grantsAccess(for: .verifiedActive))
        XCTAssertFalse(PremiumAccessPolicy.grantsAccess(for: .verifiedRevoked))
        XCTAssertFalse(PremiumAccessPolicy.grantsAccess(for: .unverified))
        XCTAssertFalse(PremiumAccessPolicy.grantsAccess(for: .pending))
        XCTAssertFalse(PremiumAccessPolicy.grantsAccess(for: .cancelled))
    }
}
