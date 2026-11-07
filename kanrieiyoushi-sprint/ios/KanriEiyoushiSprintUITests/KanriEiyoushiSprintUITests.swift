import XCTest

final class KanriEiyoushiSprintUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestPremium"]
        app.launch()
        return app
    }

    func testFourTabsAndDailySprintImmediateScoring() {
        let app = launch()
        XCTAssertTrue(app.buttons["todaySprintButton"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.tabBars.buttons["ホーム"].exists)
        XCTAssertTrue(app.tabBars.buttons["模試"].exists)
        XCTAssertTrue(app.tabBars.buttons["記録"].exists)
        XCTAssertTrue(app.tabBars.buttons["設定"].exists)

        app.buttons["todaySprintButton"].tap()
        XCTAssertTrue(app.staticTexts["questionPrompt"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["unknownButton"].exists)
        XCTAssertTrue(app.buttons["choice0"].exists)

        app.buttons["choice0"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["nextButton"].waitForExistence(timeout: 15))
    }

    func testSettingsExposeGoldenMasterControls() {
        let app = launch()
        XCTAssertTrue(app.buttons["todaySprintButton"].waitForExistence(timeout: 15))
        app.tabBars.buttons["設定"].tap()
        XCTAssertTrue(app.buttons["goal4Button"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["goal8Button"].exists)
        XCTAssertTrue(app.buttons["goal16Button"].exists)
        XCTAssertTrue(app.switches["shuffleQuestionsToggle"].exists)
        XCTAssertTrue(app.switches["shuffleChoicesToggle"].exists)
        XCTAssertTrue(app.buttons["jsonExportButton"].exists)
        XCTAssertTrue(app.buttons["jsonImportButton"].exists)
        XCTAssertTrue(app.buttons["restoreButton"].exists)
    }

    func testPremiumMockAndHistoryRoutes() {
        let app = launch()
        XCTAssertTrue(app.buttons["todaySprintButton"].waitForExistence(timeout: 15))

        app.tabBars.buttons["模試"].tap()
        XCTAssertTrue(app.buttons["mockRound1Button"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["mockRound2Button"].exists)
        XCTAssertTrue(app.buttons["mockRound3Button"].exists)

        app.tabBars.buttons["記録"].tap()
        XCTAssertTrue(app.staticTexts["学習記録"].waitForExistence(timeout: 10))
    }
}
