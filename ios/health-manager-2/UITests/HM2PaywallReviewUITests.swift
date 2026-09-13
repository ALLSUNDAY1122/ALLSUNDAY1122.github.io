import XCTest

final class HM2PaywallReviewUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func attachDiagnostics(_ app: XCUIApplication, stage: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let image = XCTAttachment(screenshot: screenshot)
        image.name = "HM2-Diagnostic-\(stage)"
        image.lifetime = .keepAlways
        add(image)

        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "HM2-Accessibility-\(stage)"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }

    private func require(
        _ element: XCUIElement,
        timeout: TimeInterval,
        message: String,
        stage: String,
        app: XCUIApplication
    ) {
        guard element.waitForExistence(timeout: timeout) else {
            attachDiagnostics(app, stage: stage)
            XCTFail(message)
            return
        }
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
        require(
            unlock,
            timeout: 12,
            message: "Premium entry was not visible",
            stage: "home-premium-entry",
            app: app
        )
        guard unlock.exists else { return }
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

        require(monthly, timeout: 8, message: "Monthly plan was not visible", stage: "paywall-monthly", app: app)
        require(lifetime, timeout: 3, message: "Lifetime plan was not visible", stage: "paywall-lifetime", app: app)
        require(restore, timeout: 3, message: "Restore purchase was not visible", stage: "paywall-restore", app: app)
        require(monthlyPrice, timeout: 3, message: "Canonical monthly price was not visible", stage: "paywall-monthly-price", app: app)
        require(lifetimePrice, timeout: 3, message: "Canonical lifetime price was not visible", stage: "paywall-lifetime-price", app: app)

        guard monthly.exists, lifetime.exists, restore.exists, monthlyPrice.exists, lifetimePrice.exists else { return }
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "HM2-IAP-Review-Paywall"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
