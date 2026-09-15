import Foundation
import XCTest

final class TsukanshiNativeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func capture(_ name: String) throws {
        let directory = URL(fileURLWithPath: "/tmp/tsukanshi-visual", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let screenshot = XCUIScreen.main.screenshot()
        try screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @discardableResult
    private func makeHittable(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) -> Bool {
        guard element.waitForExistence(timeout: 5) else { return false }
        if element.isHittable { return true }
        for _ in 0..<maxSwipes {
            app.swipeUp()
            if element.isHittable { return true }
        }
        return element.isHittable
    }

    func testHomeFourTabsAndSprintFlow() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["通関士"].waitForExistence(timeout: 10))
        for tab in ["ホーム", "模試", "記録", "設定"] {
            XCTAssertTrue(app.tabBars.buttons[tab].exists, "missing tab \(tab)")
        }
        try capture("01-home")

        let sprint = app.buttons["今日のスプリント"]
        XCTAssertTrue(makeHittable(sprint, in: app), "today sprint must remain reachable, including accessibility text sizes")
        sprint.tap()

        let unknown = app.buttons["わからない"]
        XCTAssertTrue(makeHittable(unknown, in: app), "unknown action must remain reachable, including accessibility text sizes")
        try capture("02-question")
        unknown.tap()
        XCTAssertTrue(app.staticTexts["ここだけ覚える"].waitForExistence(timeout: 5))
        let next = app.buttons["次の問題"]
        let result = app.buttons["結果を見る"]
        XCTAssertTrue(next.exists || result.exists)
        if next.exists { XCTAssertTrue(makeHittable(next, in: app)) }
        if result.exists { XCTAssertTrue(makeHittable(result, in: app)) }
        try capture("03-feedback")
    }

    func testMockTabHasPracticalTrainingAndNineRoundSubjectCards() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["模試"].waitForExistence(timeout: 10))
        app.tabBars.buttons["模試"].tap()
        XCTAssertTrue(app.staticTexts["通関実務トレーニング"].waitForExistence(timeout: 5))
        XCTAssertTrue(makeHittable(app.buttons["計算"], in: app))
        XCTAssertTrue(app.buttons["申告書演習"].exists)
        XCTAssertTrue(makeHittable(app.buttons["第59回 通関業法 模擬試験"], in: app))
        try capture("04-mock")
    }

    func testSettingsBackupAndGoalControlsExist() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["設定"].waitForExistence(timeout: 10))
        app.tabBars.buttons["設定"].tap()
        XCTAssertTrue(app.staticTexts["学習"].waitForExistence(timeout: 5))
        XCTAssertTrue(makeHittable(app.buttons["JSONを書き出す"], in: app))
        XCTAssertTrue(app.buttons["JSONから復元"].exists)
        XCTAssertTrue(makeHittable(app.buttons["購入を復元"], in: app))
        try capture("05-settings")
    }
}
