import XCTest

final class FP3PaywallReviewUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCapturePremiumPaywall() throws {
        let app = XCUIApplication()
        app.launch()

        let lockedYear = app.buttons.matching(NSPredicate(format: "label CONTAINS '2024'" )).firstMatch
        guard lockedYear.waitForExistence(timeout: 10) else {
            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "FP3-Launch-Failure"
            attachment.lifetime = .keepAlways
            add(attachment)
            print("FP3_UI_HIERARCHY_BEGIN")
            print(app.debugDescription)
            print("FP3_UI_HIERARCHY_END")
            XCTFail("2024 premium entry was not visible")
            return
        }
        lockedYear.tap()

        let paywall = app.staticTexts["Premiumで学習範囲を広げる"]
        XCTAssertTrue(paywall.waitForExistence(timeout: 5), "Premium paywall did not appear")

        let pricedPurchase = app.buttons.matching(NSPredicate(format: "label CONTAINS '800'" )).firstMatch
        XCTAssertTrue(pricedPurchase.waitForExistence(timeout: 10), "Premium purchase price was not resolved to ¥800")
        XCTAssertFalse(app.buttons["価格を取得中…"].exists, "Review screenshot must not be captured before StoreKit price is ready")
        XCTAssertTrue(app.buttons["購入を復元"].exists)
        XCTAssertTrue(app.buttons["今はしない"].exists)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "FP3-IAP-Review-Paywall"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
