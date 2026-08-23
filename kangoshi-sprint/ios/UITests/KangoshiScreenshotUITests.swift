import XCTest

// APP2-009 submission capture: app screens plus priced premium review screen.
final class KangoshiScreenshotUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testCaptureAppStoreScreens() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()

        XCTAssertTrue(app.staticTexts["看護師国家試験"].waitForExistence(timeout: 8))
        capture("01-home")

        app.buttons["今日のスプリント"].tap()
        XCTAssertTrue(app.buttons["閉じる"].waitForExistence(timeout: 8))
        capture("02-question")
        app.buttons["閉じる"].tap()
        XCTAssertTrue(app.buttons["閉じる"].waitForNonExistence(timeout: 10))
        XCTAssertEqual(app.state, .runningForeground)

        app.tabBars.buttons["模試"].tap()
        XCTAssertTrue(app.staticTexts["本番形式"].waitForExistence(timeout: 8))
        capture("03-mock")

        app.buttons["プレミアムを見る"].tap()
        XCTAssertTrue(app.staticTexts["学びスプリント プレミアム"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["月額プラン"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["買い切りプラン"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "200")).firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "800")).firstMatch.waitForExistence(timeout: 8))
        capture("04-premium")
        app.buttons["閉じる"].tap()
        XCTAssertTrue(app.staticTexts["学びスプリント プレミアム"].waitForNonExistence(timeout: 8))

        app.tabBars.buttons["設定"].tap()
        XCTAssertTrue(app.staticTexts["学びかた"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["購入を復元"].exists)
        capture("05-settings")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
