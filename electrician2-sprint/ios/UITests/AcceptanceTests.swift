import XCTest

final class AcceptanceTests: XCTestCase {
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }

    func testLaunchQuizGradeHistoryAndBackupControls() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["第二種電気工事士"].waitForExistence(timeout: 30))
        app.buttons.containing(.staticText, identifier: "今日のスプリント").firstMatch.tap()
        XCTAssertTrue(app.navigationBars["学習"].waitForExistence(timeout: 15))
        let firstChoice = app.buttons["quiz-choice-0"]
        reveal(firstChoice, in: app)
        firstChoice.tap()
        let next = app.buttons["次の問題へ"]
        reveal(next, in: app)
        XCTAssertTrue(app.staticTexts["正解"].exists || app.staticTexts["惜しい"].exists)
        next.tap()
        XCTAssertTrue(app.buttons["閉じる"].waitForExistence(timeout: 10))
        app.buttons["閉じる"].tap()
        app.tabBars.buttons["記録"].tap()
        XCTAssertTrue(app.staticTexts["積み上げ"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["のべ回答"].exists)
        app.tabBars.buttons["設定"].tap()
        let export = app.buttons["学習データをJSONで書き出す"]
        reveal(export, in: app)
        XCTAssertTrue(export.exists)
        let importButton = app.buttons["JSONから学習データを読み込む"]
        reveal(importButton, in: app)
        importButton.tap()
        let cancelImport = app.buttons["キャンセル"]
        XCTAssertTrue(cancelImport.waitForExistence(timeout: 10))
        cancelImport.tap()
        XCTAssertTrue(app.buttons["JSONから学習データを読み込む"].exists)
    }
}
