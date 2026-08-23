import StoreKit
import XCTest
@testable import YobiTantouSprint

final class StoreKitPolicyTests: XCTestCase {
    func testMonthlyAutoRenewableIsTheOnlyAcceptedProductType() {
        XCTAssertTrue(StoreProductTypePolicy.accepts(.autoRenewable))
        XCTAssertFalse(StoreProductTypePolicy.accepts(.nonConsumable))
        XCTAssertFalse(StoreProductTypePolicy.accepts(.consumable))
        XCTAssertFalse(StoreProductTypePolicy.accepts(.nonRenewable))
    }

    func testProductIDPolicyRejectsRuntimePlaceholders() {
        XCTAssertNil(StoreProductIDPolicy.normalized(nil))
        XCTAssertNil(StoreProductIDPolicy.normalized(""))
        XCTAssertNil(StoreProductIDPolicy.normalized("UNSET.YOBI.IAP"))
        XCTAssertNil(StoreProductIDPolicy.normalized("$(YOBI_IAP_PRODUCT_ID)"))
        XCTAssertEqual(
            StoreProductIDPolicy.normalized(" jp.allsunday1122.yobishikentantou.monthly "),
            "jp.allsunday1122.yobishikentantou.monthly"
        )
    }
}
