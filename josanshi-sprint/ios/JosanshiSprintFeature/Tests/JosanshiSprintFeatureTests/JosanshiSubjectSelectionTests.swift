import XCTest
import LearningSprintCore
@testable import JosanshiSprintFeature

@MainActor
final class JosanshiSubjectSelectionTests: XCTestCase {
    func testSubjectPracticeUsesSeededShuffleInsteadOfFixedPrefix() throws {
        let questions = (0..<20).map { index in
            LearningQuestion(
                id: "q-\(index)",
                subject: JosanshiExamConfiguration.subjects[0],
                topic: "topic",
                answerType: .singleChoice,
                prompt: "Q\(index)",
                choices: ["A", "B"],
                correctIndices: [0],
                memoryPoint: "M",
                explanation: "E",
                sourceCheckedAt: "2026-08-14",
                lawBaselineDate: "2026-08-14",
                contentVersion: JosanshiLocalPersistenceConfiguration.contentVersion
            )
        }
        let coordinator = JosanshiLearningCoordinator(questions: questions, loadPersistedState: false)
        coordinator.setDailyTarget(8)

        let first = try coordinator.startSubject(JosanshiExamConfiguration.subjects[0], seed: 1)
        coordinator.clearSession()
        let second = try coordinator.startSubject(JosanshiExamConfiguration.subjects[0], seed: 2)

        XCTAssertEqual(first.questionIDs.count, 8)
        XCTAssertEqual(second.questionIDs.count, 8)
        XCTAssertNotEqual(first.questionIDs, Array(questions.prefix(8).map(\.id)))
        XCTAssertNotEqual(first.questionIDs, second.questionIDs)
    }
}
