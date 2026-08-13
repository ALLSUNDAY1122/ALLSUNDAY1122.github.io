import XCTest
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
}
