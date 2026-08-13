import XCTest
@testable import KanteishiShortAnswer

final class KanteishiShortAnswerTests: XCTestCase {
    func testProductionPayloadContract() throws {
        let repository = try QuestionRepository.load()
        XCTAssertEqual(repository.questions.count, 240)
        XCTAssertEqual(repository.payload.productionTargetCount, 240)
        XCTAssertTrue(repository.payload.contentVersion.hasPrefix("official-240-"))
        XCTAssertEqual(repository.editions, [2026, 2025, 2024])
        XCTAssertEqual(repository.questions(edition: 2026).count, 80)
        XCTAssertEqual(repository.questions(edition: 2025).count, 80)
        XCTAssertEqual(repository.questions(edition: 2024).count, 80)
        XCTAssertEqual(Set(repository.questions.map(\.id)).count, 240)
        XCTAssertTrue(repository.questions.allSatisfy { $0.choices.count == 5 })
        for round in 1...3 {
            XCTAssertEqual(repository.questions.filter { $0.round == round && $0.subject == "不動産に関する行政法規" }.count, 40)
            XCTAssertEqual(repository.questions.filter { $0.round == round && $0.subject == "不動産の鑑定評価に関する理論" }.count, 40)
        }
    }

    @MainActor
    func testUnknownRegistersWeakAndThreeCorrectAnswersReleaseIt() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let store = LearningStore(persistenceURL: url)
        guard let question = store.repository.questions.first else {
            XCTFail("No production question")
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
    func testProductionMockUsesEightyQuestionsPerEdition() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let store = LearningStore(persistenceURL: url)
        store.startMock(edition: 2026)
        XCTAssertEqual(store.session?.total, 80)
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
