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
}
