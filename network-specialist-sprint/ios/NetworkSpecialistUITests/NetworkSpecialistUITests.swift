import XCTest

final class NetworkSpecialistUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestReset"]
        app.launch()
        return app
    }

    func testCoreLearningFlowAndFourTabs() {
        let app = launch()
        XCTAssertTrue(app.otherElements["home.title"].waitForExistence(timeout: 5) || app.staticTexts["home.title"].exists)
        XCTAssertTrue(app.buttons["tab.home"].exists)
        XCTAssertTrue(app.buttons["tab.mock"].exists)
        XCTAssertTrue(app.buttons["tab.history"].exists)
        XCTAssertTrue(app.buttons["tab.settings"].exists)

        app.buttons["home.startToday"].tap()
        XCTAssertTrue(app.staticTexts["quiz.questionText"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["quiz.choice.0"].exists)
        XCTAssertTrue(app.buttons["quiz.unknown"].exists)

        app.buttons["quiz.unknown"].tap()
        XCTAssertTrue(app.buttons["quiz.next"].waitForExistence(timeout: 2))
        app.buttons["quiz.home"].tap()
        XCTAssertTrue(app.buttons["home.resume"].waitForExistence(timeout: 2))
    }

    func testMockHidesImmediateCorrectness() {
        let app = launch()
        app.buttons["tab.mock"].tap()
        XCTAssertTrue(app.buttons["mock.year.2025"].waitForExistence(timeout: 3))
        app.buttons["mock.year.2025"].tap()
        XCTAssertTrue(app.buttons["quiz.choice.0"].waitForExistence(timeout: 3))
        app.buttons["quiz.choice.0"].tap()
        XCTAssertTrue(app.buttons["quiz.next"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["正解"].exists)
        XCTAssertFalse(app.staticTexts["不正解"].exists)
        XCTAssertFalse(app.staticTexts["わからないとして記録"].exists)
    }

    func testHistorySettingsAndLargeTextStayInsidePhoneWidth() {
        let app = launch()
        app.buttons["tab.history"].tap()
        XCTAssertTrue(app.otherElements["history.screen"].waitForExistence(timeout: 2))

        app.buttons["tab.settings"].tap()
        XCTAssertTrue(app.otherElements["settings.screen"].waitForExistence(timeout: 2))
        let goalControl = app.segmentedControls["settings.dailyGoal"]
        XCTAssertTrue(goalControl.exists || app.otherElements["settings.dailyGoal"].exists)

        let fontControl = app.segmentedControls["settings.fontSize"]
        if fontControl.exists && fontControl.buttons["特大"].exists {
            fontControl.buttons["特大"].tap()
        }

        app.buttons["tab.home"].tap()
        let cta = app.buttons["home.startToday"]
        XCTAssertTrue(cta.waitForExistence(timeout: 2))
        let windowFrame = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(cta.frame.minX, windowFrame.minX - 1)
        XCTAssertLessThanOrEqual(cta.frame.maxX, windowFrame.maxX + 1)
    }
}
