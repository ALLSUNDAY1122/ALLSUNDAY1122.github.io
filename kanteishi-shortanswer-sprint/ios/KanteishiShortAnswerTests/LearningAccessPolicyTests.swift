import XCTest
@testable import KanteishiShortAnswer

final class LearningAccessPolicyTests: XCTestCase {
    func testFreeTierIsExactlyTwentyFourAndFourPerEditionSubject() throws {
        let repository = try QuestionRepository.load()
        let free = LearningAccessPolicy.freeQuestionIDs(in: repository.questions)
        XCTAssertEqual(free.count, 24)
        for edition in [2026, 2025, 2024] {
            for subject in ["不動産に関する行政法規", "不動産の鑑定評価に関する理論"] {
                let count = repository.questions.filter {
                    $0.edition == edition && $0.subject == subject && free.contains($0.id)
                }.count
                XCTAssertEqual(count, 4, "\(edition) / \(subject)")
            }
        }
    }

    @MainActor
    func testFreeTodayNeverLeavesCanonicalFreeSet() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let store = LearningStore(persistenceURL: url)
        store.setDailyGoal(16)
        XCTAssertTrue(store.startToday(isPremium: false))
        XCTAssertEqual(store.session?.total, 16)
        let free = LearningAccessPolicy.freeQuestionIDs(in: store.repository.questions)
        XCTAssertTrue(store.session?.questionIDs.allSatisfy { free.contains($0) } ?? false)
    }

    @MainActor
    func testFreeEditionSubjectHasFourQuestionsAndMockIsLocked() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let store = LearningStore(persistenceURL: url)
        XCTAssertTrue(store.startEditionSubject(
            edition: 2026,
            subject: "不動産に関する行政法規",
            isPremium: false
        ))
        XCTAssertEqual(store.session?.total, 4)
        store.exitSessionToHome()
        XCTAssertFalse(store.startMock(edition: 2026, isPremium: false))
        XCTAssertNil(store.session)
        XCTAssertTrue(store.startMock(edition: 2026, isPremium: true))
        XCTAssertEqual(store.session?.total, 80)
    }

    func testPremiumAccessPolicyIsFailClosed() {
        XCTAssertTrue(PremiumAccessPolicy.grantsAccess(for: .verifiedActive))
        XCTAssertFalse(PremiumAccessPolicy.grantsAccess(for: .verifiedRevoked))
        XCTAssertFalse(PremiumAccessPolicy.grantsAccess(for: .unverified))
        XCTAssertFalse(PremiumAccessPolicy.grantsAccess(for: .pending))
        XCTAssertFalse(PremiumAccessPolicy.grantsAccess(for: .cancelled))
        XCTAssertEqual(PremiumPurchaseStore.plannedProductID, "jp.allsunday1122.kanteishishortanswer.monthly200")
    }
}
