import XCTest

final class HM2PaywallReviewUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCapturePremiumPaywall() throws {
        let app = XCUIApplication()
        // App Store Connect canonical Japan prices. StoreKit Simulator storefront
        // data is not deterministic in CI, so review-capture builds inject only
        // the display strings. Release builds never read these values.
        app.launchEnvironment["HM2_REVIEW_MONTHLY_PRICE"] = "¥200/月"
        app.launchEnvironment["HM2_REVIEW_LIFETIME_PRICE"] = "¥800"
        app.launch()

        let unlock = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "全300問を解放")
        ).firstMatch
        XCTAssertTrue(unlock.waitForExistence(timeout: 12), "Premium entry was not visible")
        unlock.tap()

        let monthly = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "月額プラン")
        ).firstMatch
        let lifetime = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "買い切り")
        ).firstMatch
        let restore = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "購入を復元")
        ).firstMatch
        let monthlyPrice = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "¥200")
        ).firstMatch
        let lifetimePrice = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "¥800")
        ).firstMatch

        XCTAssertTrue(monthly.waitForExistence(timeout: 8), "Monthly plan was not visible")
        XCTAssertTrue(lifetime.waitForExistence(timeout: 3), "Lifetime plan was not visible")
        XCTAssertTrue(restore.waitForExistence(timeout: 3), "Restore purchase was not visible")
        XCTAssertTrue(monthlyPrice.waitForExistence(timeout: 3), "Canonical monthly price was not visible")
        XCTAssertTrue(lifetimePrice.waitForExistence(timeout: 3), "Canonical lifetime price was not visible")

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "HM2-IAP-Review-Paywall"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
