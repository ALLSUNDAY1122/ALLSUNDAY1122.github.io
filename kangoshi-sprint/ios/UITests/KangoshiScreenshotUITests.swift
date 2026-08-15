import XCTest

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

        app.tabBars.buttons["模試"].tap()
        XCTAssertTrue(app.staticTexts["本番形式"].waitForExistence(timeout: 8))
        capture("03-mock")
        app.buttons["プレミアムを見る"].tap()
        XCTAssertTrue(app.staticTexts["学びスプリント プレミアム"].waitForExistence(timeout: 8))
        capture("04-premium")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
