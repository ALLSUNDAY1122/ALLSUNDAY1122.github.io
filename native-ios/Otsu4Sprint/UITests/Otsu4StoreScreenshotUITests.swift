import XCTest

final class Otsu4StoreScreenshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureStoreAssets() throws {
        let app = makeApp()
        app.launch()
        XCTAssertTrue(app.staticTexts["危険物 乙4"].waitForExistence(timeout: 30))
        capture("01-home")

        let law = app.buttons["subject-法令"]
        while !law.isHittable && app.scrollViews.firstMatch.exists { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(law.waitForExistence(timeout: 10))
        law.tap()
        XCTAssertTrue(app.staticTexts["全288問"].waitForExistence(timeout: 15))
        capture("02-subject-index")

        let startAll = app.buttons["無料範囲29問を通して解く"]
        XCTAssertTrue(startAll.waitForExistence(timeout: 10))
        startAll.tap()
        XCTAssertTrue(app.buttons["わからない"].waitForExistence(timeout: 15))
        capture("03-question")
        app.buttons["わからない"].tap()
        XCTAssertTrue(app.otherElements["memoryBlock"].waitForExistence(timeout: 10))
        capture("04-explanation")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["危険物 乙4"].waitForExistence(timeout: 30))
        app.tabBars.buttons["模試"].tap()
        XCTAssertTrue(app.staticTexts["模擬試験"].waitForExistence(timeout: 10))
        capture("05-mocks")

        app.tabBars.buttons["記録"].tap()
        XCTAssertTrue(app.staticTexts["学習記録"].waitForExistence(timeout: 10))
        capture("06-history")

        app.tabBars.buttons["設定"].tap()
        XCTAssertTrue(app.staticTexts["設定"].waitForExistence(timeout: 10))
        let unlock = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "解放")).firstMatch
        if !unlock.waitForExistence(timeout: 5) {
            app.swipeUp()
        }
        XCTAssertTrue(unlock.waitForExistence(timeout: 10))
        unlock.tap()
        XCTAssertTrue(app.staticTexts["乙4 プレミアム"].waitForExistence(timeout: 15))
        sleep(3)
        capture("07-premium-review")
    }

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        return app
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
