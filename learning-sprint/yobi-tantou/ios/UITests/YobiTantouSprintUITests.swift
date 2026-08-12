import XCTest

final class YobiTantouSprintUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testGoldenMasterHomeContract() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["司法試験予備試験・短答式"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["ホーム"].exists)
        XCTAssertTrue(app.buttons["模試"].exists)
        XCTAssertTrue(app.buttons["記録"].exists)
        XCTAssertTrue(app.buttons["設定"].exists)
        XCTAssertTrue(app.staticTexts["8問UIプレビュー"].exists)
        XCTAssertTrue(app.staticTexts["分野から解く"].exists)
    }

    func testTabsRemainNativeAndNavigable() throws {
        let app = XCUIApplication()
        app.launch()

        let mock = app.buttons["模試"]
        XCTAssertTrue(mock.waitForExistence(timeout: 8))
        mock.tap()
        XCTAssertTrue(app.staticTexts["模擬試験"].waitForExistence(timeout: 3))

        app.buttons["記録"].tap()
        XCTAssertTrue(app.staticTexts["学習記録"].waitForExistence(timeout: 3))

        app.buttons["設定"].tap()
        XCTAssertTrue(app.staticTexts["設定"].waitForExistence(timeout: 3))
    }
}
