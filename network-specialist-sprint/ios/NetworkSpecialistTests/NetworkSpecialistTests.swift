import XCTest
@testable import NetworkSpecialist

final class NetworkSpecialistTests: XCTestCase {
    func testQuestionPayloadMatchesCanonicalCounts() throws {
        let repository = try QuestionRepository.load()
        XCTAssertEqual(repository.occurrences.count, 75)
        XCTAssertEqual(repository.uniqueQuestions.count, 68)
        XCTAssertEqual(repository.questions(forYear: 2025).count, 25)
        XCTAssertEqual(repository.questions(forYear: 2024).count, 25)
        XCTAssertEqual(repository.questions(forYear: 2023).count, 25)
        XCTAssertEqual(repository.payload.contentVersion, "nw-a2-2026-08-v1")
    }

    @MainActor
    func testUnknownRegistersWeakAndThreeCorrectReleasesIt() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let store = LearningStore(persistenceURL: url)
        guard let question = store.repository.uniqueQuestions.first else {
            XCTFail("No questions")
            return
        }

        store.retryQuestions([question.id])
        store.submitAnswer(nil)
        XCTAssertNotNil(store.state.weak[question.id])
        XCTAssertEqual(store.state.weak[question.id]?.streak, 0)
        store.advanceSession()

        for expectedStreak in 1...2 {
            store.retryQuestions([question.id])
            store.submitAnswer(question.answerIndex)
            XCTAssertEqual(store.state.weak[question.id]?.streak, expectedStreak)
            store.advanceSession()
        }

        store.retryQuestions([question.id])
        store.submitAnswer(question.answerIndex)
        XCTAssertNil(store.state.weak[question.id])
    }

    @MainActor
    func testBackupRoundTrip() throws {
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
    func testMockUsesTwentyFiveQuestions() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let store = LearningStore(persistenceURL: url)
        store.startMock(year: 2025)
        XCTAssertEqual(store.session?.total, 25)
        XCTAssertEqual(store.session?.mode, .mock)
    }
}
