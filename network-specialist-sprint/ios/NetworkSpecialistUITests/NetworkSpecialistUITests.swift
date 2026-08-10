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

    func testMockHistoryAndSettingsAreReachable() {
        let app = launch()
        app.buttons["tab.mock"].tap()
        XCTAssertTrue(app.otherElements["mock.screen"].waitForExistence(timeout: 2) || app.buttons["mock.year.2025"].exists)
        XCTAssertTrue(app.buttons["mock.year.2025"].exists)

        app.buttons["tab.history"].tap()
        XCTAssertTrue(app.otherElements["history.screen"].waitForExistence(timeout: 2))

        app.buttons["tab.settings"].tap()
        XCTAssertTrue(app.otherElements["settings.screen"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.segmentedControls["settings.dailyGoal"].exists || app.otherElements["settings.dailyGoal"].exists)
    }
}
