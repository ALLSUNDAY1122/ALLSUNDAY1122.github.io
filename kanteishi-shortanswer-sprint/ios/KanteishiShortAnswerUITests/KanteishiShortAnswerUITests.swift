import XCTest

final class KanteishiShortAnswerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCoreLearningFlowAndTabs() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestReset"]
        app.launch()

        let title = app.staticTexts["不動産鑑定士試験・短答式"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))

        let start = app.buttons["home.startToday"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        let question = app.staticTexts["quiz.questionText"]
        XCTAssertTrue(question.waitForExistence(timeout: 10))

        let unknown = app.buttons["quiz.unknown"]
        XCTAssertTrue(unknown.waitForExistence(timeout: 5))
        unknown.tap()

        let feedback = app.staticTexts["わからないとして記録"]
        XCTAssertTrue(feedback.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["quiz.next"].waitForExistence(timeout: 5))

        app.buttons["quiz.home"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5))

        app.buttons["tab.settings"].tap()
        XCTAssertTrue(app.otherElements["settings.screen"].waitForExistence(timeout: 5))

        app.buttons["tab.history"].tap()
        XCTAssertTrue(app.otherElements["history.screen"].waitForExistence(timeout: 5))

        app.buttons["tab.mock"].tap()
        XCTAssertTrue(app.otherElements["mock.screen"].waitForExistence(timeout: 5))
    }
}
