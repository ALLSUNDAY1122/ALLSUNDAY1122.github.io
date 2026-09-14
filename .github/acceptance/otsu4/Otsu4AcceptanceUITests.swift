import XCTest

final class Otsu4AcceptanceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLearningCycleResultReviewAndRetry() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()

        let start = app.buttons["始める"]
        XCTAssertTrue(start.waitForExistence(timeout: 15), "ホームから学習を開始できない")
        start.tap()

        var completed = false
        for _ in 0..<20 {
            if app.buttons["ホームへ"].exists {
                completed = true
                break
            }

            let unknown = app.buttons["わからない"]
            XCTAssertTrue(unknown.waitForExistence(timeout: 5), "学習中に『わからない』を選べない")
            unknown.tap()
            XCTAssertTrue(app.staticTexts["覚え直しポイント"].waitForExistence(timeout: 5), "回答後に理解・復習情報が表示されない")

            let result = app.buttons["結果を見る"]
            if result.exists {
                result.tap()
                completed = app.buttons["ホームへ"].waitForExistence(timeout: 5)
                break
            }

            let next = app.buttons["次の問題へ"]
            XCTAssertTrue(next.waitForExistence(timeout: 5), "回答後に次の問題へ進めない")
            next.tap()
        }

        XCTAssertTrue(completed, "学習セッションを結果画面まで完了できない")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '正答率'")).firstMatch.exists, "結果で正答率を確認できない")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'わからない'")).firstMatch.exists, "結果で要復習数を確認できない")

        app.buttons["ホームへ"].tap()

        let weakReview = app.buttons.matching(NSPredicate(format: "label CONTAINS '苦手を復習'")).firstMatch
        XCTAssertTrue(weakReview.waitForExistence(timeout: 5), "結果からホームへ戻って復習導線を確認できない")
        XCTAssertTrue(weakReview.isEnabled, "誤答・わからない問題が復習対象へ反映されていない")
        weakReview.tap()

        XCTAssertTrue(app.buttons["わからない"].waitForExistence(timeout: 5), "苦手復習から再挑戦を開始できない")
    }
}
