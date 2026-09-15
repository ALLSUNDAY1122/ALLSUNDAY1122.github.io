import XCTest

final class YobiTantouSprintUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testGoldenMasterHomeContractWithFormalPracticeBank() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["司法試験予備試験・短答式"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["ホーム"].exists)
        XCTAssertTrue(app.buttons["模試"].exists)
        XCTAssertTrue(app.buttons["記録"].exists)
        XCTAssertTrue(app.buttons["設定"].exists)
        XCTAssertTrue(app.staticTexts["今日のスプリント"].exists)
        XCTAssertFalse(app.staticTexts["8問UIプレビュー"].exists)
        XCTAssertTrue(app.staticTexts["分野から解く"].exists)
        XCTAssertTrue(app.staticTexts["憲法"].exists)
    }

    func testVerifiedScoringIsVisibleWhileOfficialMockRemainsLocked() throws {
        let app = XCUIApplication()
        app.launch()

        let mock = app.buttons["模試"]
        XCTAssertTrue(mock.waitForExistence(timeout: 8))
        mock.tap()

        XCTAssertTrue(app.staticTexts["模擬試験"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["確認済みの公式採点構造"].exists)
        XCTAssertTrue(app.staticTexts["令和7年"].exists)

        let r6 = app.staticTexts["令和6年"]
        if !r6.exists {
            app.swipeUp()
        }
        XCTAssertTrue(r6.waitForExistence(timeout: 3))

        let locked = app.staticTexts["採点構造は確認済みです。正式教材問題の権利・内容監査が完了するまで、年度模試の開始だけをロックしています。"]
        if !locked.exists {
            app.swipeUp()
        }
        XCTAssertTrue(locked.waitForExistence(timeout: 3))
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
