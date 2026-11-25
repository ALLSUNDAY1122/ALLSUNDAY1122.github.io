import XCTest
import StoreKitTest

// Captures App Store (6.9" iPhone) and IAP Review screenshots with StoreKit Review.storekit prices resolved.
final class KangoshiScreenshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureAppStoreScreens() throws {
        // StoreKit configuration attached to the scheme's Run action is not automatically
        // active when launched from XCUITest. Start an explicit session from Review.storekit.
        let storeKitSession = try SKTestSession(configurationFileNamed: "Review")
        storeKitSession.disableDialogs = true
        storeKitSession.clearTransactions()
        storeKitSession.locale = Locale(identifier: "ja_JP")
        storeKitSession.storefront = "JPN"

        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()

        // 01. Home
        XCTAssertTrue(app.staticTexts["看護師国家試験"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["今日のスプリント"].waitForExistence(timeout: 5))
        capture("01-home")

        // 02. Quiz (question screen)
        app.buttons["今日のスプリント"].tap()
        let closeQuiz = app.buttons["閉じる"]
        XCTAssertTrue(closeQuiz.waitForExistence(timeout: 8))
        let unknownButton = app.buttons["わからない（答えを見る）"]
        XCTAssertTrue(unknownButton.waitForExistence(timeout: 5))
        capture("02-quiz")

        // 03. Explanation (answer feedback + point + expanded detail)
        let firstChoice = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '1'")).firstMatch
        XCTAssertTrue(firstChoice.waitForExistence(timeout: 5))
        firstChoice.tap()

        XCTAssertTrue(app.staticTexts["ここだけ覚える"].waitForExistence(timeout: 5))
        let detailToggle = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'もう少し詳しく'"))
            .firstMatch
        if detailToggle.waitForExistence(timeout: 3) {
            if !detailToggle.isHittable {
                app.swipeUp()
            }
            if detailToggle.isHittable {
                detailToggle.tap()
            }
        }
        let nextButton = app.buttons["次の問題へ"]
        if nextButton.waitForExistence(timeout: 3), !nextButton.isHittable {
            app.swipeUp()
        }
        capture("03-explanation")

        closeQuiz.tap()
        XCTAssertTrue(closeQuiz.waitForNonExistence(timeout: 10))
        XCTAssertEqual(app.state, .runningForeground)

        // 04. Mock tab
        app.tabBars.buttons["模試"].tap()
        XCTAssertTrue(app.staticTexts["本番形式"].waitForExistence(timeout: 8))
        capture("04-mock")

        // 05. Record tab (shows 1 answered question from step 02/03)
        app.tabBars.buttons["記録"].tap()
        XCTAssertTrue(app.staticTexts["積み上げ"].waitForExistence(timeout: 8))
        capture("05-record")

        // 06. Paywall (used for App Store screenshot + Monthly & Lifetime IAP review screenshots)
        let openPaywall = app.buttons["プレミアムを見る"]
        XCTAssertTrue(openPaywall.waitForExistence(timeout: 5))
        openPaywall.tap()

        XCTAssertTrue(app.staticTexts["学びスプリント プレミアム"].waitForExistence(timeout: 8))
        let monthlyButton = app.buttons
            .matching(NSPredicate(format: "label CONTAINS '月額プラン' AND label CONTAINS '200'"))
            .firstMatch
        let lifetimeButton = app.buttons
            .matching(NSPredicate(format: "label CONTAINS '買い切りプラン' AND label CONTAINS '800'"))
            .firstMatch
        XCTAssertTrue(monthlyButton.waitForExistence(timeout: 10), "Monthly plan must resolve to ¥200")
        XCTAssertTrue(lifetimeButton.waitForExistence(timeout: 10), "Lifetime plan must resolve to ¥800")
        XCTAssertFalse(
            app.buttons.matching(NSPredicate(format: "label CONTAINS '価格を取得中'")).firstMatch.exists,
            "Paywall must not be captured before StoreKit prices finish loading"
        )
        XCTAssertTrue(app.buttons["購入を復元"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["privacy-policy-link"].isHittable)
        XCTAssertTrue(app.descendants(matching: .any)["terms-of-use-link"].isHittable)
        capture("06-paywall")

        app.buttons["閉じる"].tap()
        XCTAssertTrue(app.staticTexts["学びスプリント プレミアム"].waitForNonExistence(timeout: 8))

        // 07. Settings tab (optional extra screen)
        app.tabBars.buttons["設定"].tap()
        XCTAssertTrue(app.staticTexts["学びかた"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["購入を復元"].exists)
        capture("07-settings")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
