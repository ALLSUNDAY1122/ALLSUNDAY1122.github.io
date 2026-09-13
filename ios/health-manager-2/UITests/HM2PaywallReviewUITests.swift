import XCTest

final class HM2PaywallReviewUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCapturePremiumPaywall() throws {
        let app = XCUIApplication()
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

        XCTAssertTrue(monthly.waitForExistence(timeout: 8), "Monthly plan was not visible")
        XCTAssertTrue(lifetime.waitForExistence(timeout: 3), "Lifetime plan was not visible")
        XCTAssertTrue(restore.waitForExistence(timeout: 3), "Restore purchase was not visible")

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "HM2-IAP-Review-Paywall"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
