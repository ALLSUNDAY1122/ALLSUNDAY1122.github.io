import XCTest

final class KanriEiyoushiSprintUITests: XCTestCase {
    private func launch()->XCUIApplication{let app=XCUIApplication();app.launchArguments=["-UITestPremium"];app.launch();return app}
    func testFourTabsAndDailySprintImmediateScoring(){
        let app=launch()
        XCTAssertTrue(app.otherElements["homeView"].waitForExistence(timeout:15))
        XCTAssertTrue(app.buttons["todaySprintButton"].exists)
        XCTAssertTrue(app.tabBars.buttons["ホーム"].exists)
        XCTAssertTrue(app.tabBars.buttons["模試"].exists)
        XCTAssertTrue(app.tabBars.buttons["記録"].exists)
        XCTAssertTrue(app.tabBars.buttons["設定"].exists)
        app.buttons["todaySprintButton"].tap()
        let quiz=app.descendants(matching:.any)["quizView"]
        XCTAssertTrue(quiz.waitForExistence(timeout:15))
        XCTAssertTrue(app.staticTexts["questionPrompt"].waitForExistence(timeout:10))
        XCTAssertTrue(app.buttons["unknownButton"].exists)
        XCTAssertTrue(app.buttons["choice0"].exists)
        app.buttons["choice0"].tap()
        let next=app.descendants(matching:.any)["nextButton"]
        XCTAssertTrue(next.waitForExistence(timeout:15))
    }
    func testSettingsExposeGoldenMasterControls(){let app=launch();XCTAssertTrue(app.otherElements["homeView"].waitForExistence(timeout:10));app.tabBars.buttons["設定"].tap();XCTAssertTrue(app.otherElements["settingsView"].waitForExistence(timeout:5));XCTAssertTrue(app.buttons["goal4Button"].exists);XCTAssertTrue(app.buttons["goal8Button"].exists);XCTAssertTrue(app.buttons["goal16Button"].exists);XCTAssertTrue(app.switches["shuffleQuestionsToggle"].exists);XCTAssertTrue(app.switches["shuffleChoicesToggle"].exists);XCTAssertTrue(app.buttons["jsonExportButton"].exists);XCTAssertTrue(app.buttons["jsonImportButton"].exists);XCTAssertTrue(app.buttons["restoreButton"].exists)}
    func testPremiumMockAndHistoryRoutes(){let app=launch();XCTAssertTrue(app.otherElements["homeView"].waitForExistence(timeout:10));app.tabBars.buttons["模試"].tap();XCTAssertTrue(app.otherElements["mockView"].waitForExistence(timeout:5));XCTAssertTrue(app.buttons["mockRound1Button"].exists);XCTAssertTrue(app.buttons["mockRound2Button"].exists);XCTAssertTrue(app.buttons["mockRound3Button"].exists);app.tabBars.buttons["記録"].tap();XCTAssertTrue(app.otherElements["historyView"].waitForExistence(timeout:5));XCTAssertTrue(app.staticTexts["学習記録"].exists)}
}
