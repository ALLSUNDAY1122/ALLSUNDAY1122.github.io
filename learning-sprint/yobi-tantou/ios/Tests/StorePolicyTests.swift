import XCTest
@testable import YobiTantouSprint

final class StorePolicyTests: XCTestCase {
    func testProductIDPolicyRejectsMissingAndBuildPlaceholders() {
        XCTAssertNil(StoreProductIDPolicy.normalized(nil))
        XCTAssertNil(StoreProductIDPolicy.normalized(""))
        XCTAssertNil(StoreProductIDPolicy.normalized("   "))
        XCTAssertNil(StoreProductIDPolicy.normalized("$(YOBI_IAP_PRODUCT_ID)"))
        XCTAssertNil(StoreProductIDPolicy.normalized("UNSET.YOBI.IAP"))
    }

    func testProductIDPolicyTrimsExplicitConfiguredValue() {
        XCTAssertEqual(StoreProductIDPolicy.normalized("  jp.example.explicit.premium  "), "jp.example.explicit.premium")
    }
}
