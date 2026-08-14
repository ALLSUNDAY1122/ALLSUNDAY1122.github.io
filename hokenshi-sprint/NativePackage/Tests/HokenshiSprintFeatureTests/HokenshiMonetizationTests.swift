import XCTest
import LearningSprintCore
@testable import HokenshiSprintFeature

final class HokenshiMonetizationTests: XCTestCase {
    func testCanonicalPremiumIdentifiers() {
        XCTAssertEqual(HokenshiMonetization.productID, "jp.allsunday1122.hokenshi.premium")
        XCTAssertEqual(HokenshiMonetization.purchaseType, "non_consumable")
        XCTAssertEqual(HokenshiMonetization.freeQuestionCount, 30)
        XCTAssertEqual(HokenshiMonetization.premiumQuestionCount, 300)
        XCTAssertEqual(HokenshiMonetization.totalQuestionCount, 330)
    }

    func testBundledReleaseBankHasBalancedFreeTier() throws {
        let store = try HokenshiReleaseContentStore.load()
        let free = store.allRecords.filter { !$0.premium }
        let premium = store.allRecords.filter(\.premium)

        XCTAssertEqual(free.count, 30)
        XCTAssertEqual(premium.count, 300)
        XCTAssertTrue(free.allSatisfy { $0.round == 1 })

        let bySubject = Dictionary(grouping: free, by: \.subject)
        XCTAssertEqual(bySubject.count, 10)
        XCTAssertTrue(bySubject.values.allSatisfy { $0.count == 3 })
    }

    func testSubjectSprintNeverRepeatsQuestionsToFillTarget() throws {
        let store = try HokenshiReleaseContentStore.load()

        for (index, subject) in HokenshiExamBlueprint.current.subjects.enumerated() {
            let pool = store.questions(subject: subject).map(\.displayQuestion)
            XCTAssertEqual(pool.count, 33, "\(subject) should contain 33 questions")

            let freeSession = LearningEngine.selectSprint(
                from: pool,
                target: 8,
                isPremium: false,
                seed: UInt64(1300 + index)
            )
            XCTAssertEqual(freeSession.count, 3, "Free subject study must stop at the 3 unlocked questions instead of repeating them")
            XCTAssertEqual(Set(freeSession.map(\.id)).count, freeSession.count)

            let premiumSession = LearningEngine.selectSprint(
                from: pool,
                target: 8,
                isPremium: true,
                seed: UInt64(2300 + index)
            )
            XCTAssertEqual(premiumSession.count, 8)
            XCTAssertEqual(Set(premiumSession.map(\.id)).count, premiumSession.count, "Premium subject sprint must not repeat a question within one session")
        }
    }
}
