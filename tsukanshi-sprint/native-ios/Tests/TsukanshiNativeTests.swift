import XCTest
@testable import TsukanshiNative
import LearningSprintCore

final class TsukanshiNativeTests: XCTestCase {
    func testCanonicalIdentifiersDoNotDrift() {
        XCTAssertEqual(TsukanshiNativeConfig.bundleID, "jp.allsunday1122.tsukanshi")
        XCTAssertEqual(TsukanshiNativeConfig.appStoreConnectID, "6799753744")
        XCTAssertEqual(TsukanshiNativeConfig.codemagicProfile, "tsukanshi_appstore")
        XCTAssertEqual(TsukanshiNativeConfig.teamID, "MN3D2ZM44N")
        XCTAssertEqual(TsukanshiNativeConfig.version, "1.0.0")
    }

    func testAuditedNativeContentCountsAndTypes() throws {
        let store = try TsukanshiContentStore()
        XCTAssertEqual(store.bank.studyQuestionCount, 480)
        XCTAssertEqual(store.bank.declarationCount, 12)
        XCTAssertEqual(store.questions.count, 492)
        XCTAssertEqual(store.bank.lawBaselineDate, "2026-07-01")
        XCTAssertEqual(Set(store.questions.map(\.id)).count, 492)
        XCTAssertTrue(Set(store.questions.map(\.answerType)).isSuperset(of: [.singleChoice, .multiChoice, .numeric, .blankSelect, .declaration]))
        XCTAssertTrue(store.questions.allSatisfy { !$0.sourceCheckedAt.isEmpty && !$0.lawBaselineDate.isEmpty })
    }

    func testMockSetsHaveExpectedCountsAndNoDuplicateIDsWithinSet() throws {
        let store = try TsukanshiContentStore()
        for round in TsukanshiNativeConfig.examRounds {
            for subject in TsukanshiNativeConfig.subjects {
                let expected = TsukanshiNativeConfig.mockQuestionCountBySubject[subject]!
                let questions = store.mockQuestions(round: round, subject: subject, premium: true)
                XCTAssertEqual(questions.count, expected, "\(round) \(subject)")
                XCTAssertEqual(Set(questions.map(\.id)).count, questions.count, "duplicate in \(round) \(subject)")
                XCTAssertTrue(questions.allSatisfy { $0.subject == subject })
            }
        }
    }

    func testThreeRoundsDoNotProduceIdenticalSubjectOrder() throws {
        let store = try TsukanshiContentStore()
        for subject in TsukanshiNativeConfig.subjects {
            let orders = TsukanshiNativeConfig.examRounds.map { round in
                store.mockQuestions(round: round, subject: subject, premium: true).map(\.id)
            }
            XCTAssertEqual(Set(orders.map { $0.joined(separator: ",") }).count, 3, "all rounds identical for \(subject)")
        }
    }

    @MainActor
    func testMockMultiChoiceIsStoredOnlyAtRequiredSelectionCount() throws {
        let question = LearningQuestion(
            id: "mock-multi",
            subject: "関税法等",
            topic: "複数選択",
            answerType: .multiChoice,
            prompt: "二つ選べ",
            choices: ["A", "B", "C", "D"],
            correctIndices: [0, 2],
            memoryPoint: "A/C",
            explanation: "test",
            sourceCheckedAt: "2026-08-10",
            lawBaselineDate: "2026-07-01",
            contentVersion: "test"
        )
        let session = TsukanshiStudySession(kind: .mock("第59回|関税法等"), questions: [question])
        _ = try session.answer(AnswerPayload(selectedIndices: [0]))
        XCTAssertNil(session.answers[question.id])
        _ = try session.answer(AnswerPayload(selectedIndices: [0, 2]))
        XCTAssertEqual(session.answers[question.id]?.selectedIndices, [0, 2])
        _ = try session.answer(AnswerPayload(selectedIndices: [0, 1, 2]))
        XCTAssertNil(session.answers[question.id])
    }

    @MainActor
    func testMockBlankSelectRequiresEveryBlank() throws {
        let question = LearningQuestion(
            id: "mock-blank",
            subject: "通関実務",
            topic: "空欄",
            answerType: .blankSelect,
            prompt: "空欄を埋めよ",
            blanks: [
                BlankField(key: "a", label: "A", options: ["甲", "乙"], correctValue: "甲"),
                BlankField(key: "b", label: "B", options: ["丙", "丁"], correctValue: "丙")
            ],
            memoryPoint: "甲/丙",
            explanation: "test",
            sourceCheckedAt: "2026-08-10",
            lawBaselineDate: "2026-07-01",
            contentVersion: "test"
        )
        let session = TsukanshiStudySession(kind: .mock("第59回|通関実務"), questions: [question])
        _ = try session.answer(AnswerPayload(blankValues: ["a": "甲"]))
        XCTAssertNil(session.answers[question.id])
        _ = try session.answer(AnswerPayload(blankValues: ["a": "甲", "b": "丙"]))
        XCTAssertEqual(session.answers[question.id]?.blankValues.count, 2)
    }
}
