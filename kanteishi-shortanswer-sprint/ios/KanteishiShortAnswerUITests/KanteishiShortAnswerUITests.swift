import XCTest

final class KanteishiShortAnswerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCoreLearningFlowAndTabs() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["不動産鑑定士試験・短答式"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["home.startToday"].exists)

        app.buttons["home.startToday"].tap()
        XCTAssertTrue(app.staticTexts["quiz.questionText"].waitForExistence(timeout: 10))

        app.buttons["quiz.unknown"].tap()
        XCTAssertTrue(app.staticTexts["わからないとして記録"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["quiz.next"].exists)

        app.buttons["quiz.home"].tap()
        XCTAssertTrue(app.staticTexts["不動産鑑定士試験・短答式"].waitForExistence(timeout: 5))

        app.buttons["tab.settings"].tap()
        XCTAssertTrue(app.otherElements["settings.screen"].waitForExistence(timeout: 5))

        app.buttons["tab.history"].tap()
        XCTAssertTrue(app.otherElements["history.screen"].waitForExistence(timeout: 5))

        app.buttons["tab.mock"].tap()
        XCTAssertTrue(app.otherElements["mock.screen"].waitForExistence(timeout: 5))
    }
}
