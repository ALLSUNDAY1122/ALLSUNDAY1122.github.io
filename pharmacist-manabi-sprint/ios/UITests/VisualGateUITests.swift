import XCTest

final class PharmacistVisualGateUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
    }

    private func keepScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testVisualLearningJourneyAndCoreTabs() throws {
        XCTAssertTrue(app.staticTexts["薬剤師国家試験"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["dailySprintButton"].exists)
        keepScreenshot("01-home")

        app.buttons["dailySprintButton"].tap()
        XCTAssertTrue(app.buttons["unknownButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "choice_")).firstMatch.exists)
        keepScreenshot("02-question")

        app.buttons["unknownButton"].tap()
        XCTAssertTrue(app.staticTexts["ここだけ覚える"].waitForExistence(timeout: 10))
        keepScreenshot("03-feedback")

        let close = app.buttons["問題を閉じる"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(app.buttons["resumeButton"].waitForExistence(timeout: 10))
        keepScreenshot("04-resume")

        XCTAssertTrue(app.buttons["tab.模試"].exists)
        app.buttons["tab.模試"].tap()
        XCTAssertTrue(app.otherElements["mockScreen"].waitForExistence(timeout: 10) || app.scrollViews["mockScreen"].exists)
        keepScreenshot("05-mock")

        app.buttons["tab.記録"].tap()
        XCTAssertTrue(app.otherElements["historyScreen"].waitForExistence(timeout: 10) || app.scrollViews["historyScreen"].exists)
        keepScreenshot("06-history")

        app.buttons["tab.設定"].tap()
        XCTAssertTrue(app.staticTexts["設定"].waitForExistence(timeout: 10))
        keepScreenshot("07-settings")
    }
}
