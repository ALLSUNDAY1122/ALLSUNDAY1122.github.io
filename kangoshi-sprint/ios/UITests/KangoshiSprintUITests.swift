import XCTest

final class KangoshiSprintUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHomeFreeSprintAndClose() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()

        XCTAssertTrue(app.staticTexts["看護師国家試験"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["今日のスプリント"].exists)
        app.buttons["今日のスプリント"].tap()
        XCTAssertTrue(app.buttons["閉じる"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '1/'")).firstMatch.exists)
        app.buttons["閉じる"].tap()
        XCTAssertTrue(app.staticTexts["看護師国家試験"].waitForExistence(timeout: 5))
    }

    func testFreeMockGateAndRestoreEntry() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()

        app.tabBars.buttons["模試"].tap()
        XCTAssertTrue(app.staticTexts["本番形式"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["本番形式はプレミアム"].exists)
        XCTAssertTrue(app.buttons["プレミアムを見る"].exists)

        app.tabBars.buttons["設定"].tap()
        XCTAssertTrue(app.staticTexts["学びかた"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["購入を復元"].exists)
    }

    func testFreeCategorySamplesAreVisible() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["無料お試し"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["必修"].exists)
        XCTAssertTrue(app.buttons["一般"].exists)
        XCTAssertTrue(app.buttons["状況設定"].exists)
    }
}
