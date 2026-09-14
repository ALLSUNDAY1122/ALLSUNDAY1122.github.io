import XCTest

final class TsukanshiNativeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHomeFourTabsAndSprintFlow() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["通関士"].waitForExistence(timeout: 10))
        for tab in ["ホーム", "模試", "記録", "設定"] {
            XCTAssertTrue(app.tabBars.buttons[tab].exists, "missing tab \(tab)")
        }

        let sprint = app.buttons["今日のスプリント"]
        XCTAssertTrue(sprint.waitForExistence(timeout: 5))
        sprint.tap()

        let unknown = app.buttons["わからない"]
        XCTAssertTrue(unknown.waitForExistence(timeout: 5))
        unknown.tap()
        XCTAssertTrue(app.staticTexts["ここだけ覚える"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["次の問題"].exists || app.buttons["結果を見る"].exists)
    }

    func testMockTabHasPracticalTrainingAndNineRoundSubjectCards() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["模試"].waitForExistence(timeout: 10))
        app.tabBars.buttons["模試"].tap()
        XCTAssertTrue(app.staticTexts["通関実務トレーニング"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["計算"].exists)
        XCTAssertTrue(app.buttons["申告書演習"].exists)
        XCTAssertTrue(app.buttons["第59回 通関業法 模擬試験"].exists)
    }

    func testSettingsBackupAndGoalControlsExist() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["設定"].waitForExistence(timeout: 10))
        app.tabBars.buttons["設定"].tap()
        XCTAssertTrue(app.staticTexts["学習"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["JSONを書き出す"].exists)
        XCTAssertTrue(app.buttons["JSONから復元"].exists)
        XCTAssertTrue(app.buttons["購入を復元"].exists)
    }
}
