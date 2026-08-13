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
        XCTAssertTrue(app.buttons["mock.edition.2026"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["mock.subject.2026.不動産に関する行政法規"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testEditionSubjectPracticeLaunches() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestReset"]
        app.launch()

        XCTAssertTrue(app.buttons["tab.mock"].waitForExistence(timeout: 10))
        app.buttons["tab.mock"].tap()
        XCTAssertTrue(app.otherElements["mock.screen"].waitForExistence(timeout: 5))

        let subject = app.buttons["mock.subject.2026.不動産に関する行政法規"]
        XCTAssertTrue(subject.waitForExistence(timeout: 5))
        scrollToHittable(subject, in: app)
        XCTAssertTrue(subject.isHittable)
        subject.tap()

        XCTAssertTrue(app.staticTexts["quiz.questionText"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["1 / 40"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["quiz.unknown"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func scrollToHittable(_ element: XCUIElement, in app: XCUIApplication) {
        var attempts = 0
        while !element.isHittable && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
    }
}
