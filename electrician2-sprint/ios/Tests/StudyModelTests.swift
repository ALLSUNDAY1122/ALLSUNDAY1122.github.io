import XCTest
@testable import Electrician2Sprint

final class StudyModelTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testThreeConsecutiveCorrectAnswersGraduateWeakQuestion() {
        let model = StudyModel(defaults: makeDefaults())
        model.start(1); model.answer(1)
        XCTAssertTrue(model.weakIDs.contains(1))
        for _ in 0..<3 {
            model.start(1, weakOnly: true)
            model.answer(0)
        }
        XCTAssertFalse(model.weakIDs.contains(1))
        XCTAssertTrue(model.graduatedIDs.contains(1))
        XCTAssertEqual(model.weakStreak[1], 3)
    }

    func testWrongAnswerResetsStreakAndRemovesGraduation() {
        let model = StudyModel(defaults: makeDefaults())
        model.start(1); model.answer(1)
        model.start(1, weakOnly: true); model.answer(0)
        model.start(1, weakOnly: true); model.answer(0)
        XCTAssertEqual(model.weakStreak[1], 2)
        model.start(1, weakOnly: true); model.answer(1)
        XCTAssertEqual(model.weakStreak[1], 0)
        XCTAssertTrue(model.weakIDs.contains(1))
        XCTAssertFalse(model.graduatedIDs.contains(1))
    }

    func testLearningStatePersistsAcrossModelRecreation() {
        let defaults = makeDefaults()
        let first = StudyModel(defaults: defaults)
        first.goal = 16
        first.fontScale = 2
        first.start(1); first.answer(1)
        let restored = StudyModel(defaults: defaults)
        XCTAssertEqual(restored.goal, 16)
        XCTAssertEqual(restored.fontScale, 2)
        XCTAssertEqual(restored.completed, 1)
        XCTAssertEqual(restored.correct, 0)
        XCTAssertTrue(restored.weakIDs.contains(1))
        XCTAssertEqual(restored.answeredIDs, [1])
    }

    func testWeakOnlySessionDoesNotFallbackWhenEmpty() {
        let model = StudyModel(defaults: makeDefaults())
        model.start(8, weakOnly: true)
        XCTAssertTrue(model.session.isEmpty)
        XCTAssertFalse(model.showQuestion)
    }
}
