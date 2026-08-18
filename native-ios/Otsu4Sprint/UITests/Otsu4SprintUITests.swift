import XCTest

final class Otsu4SprintUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCoreFreeFlowAndFourTabNavigationFitCurrentIPhoneWidth() throws {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["危険物 乙4"].waitForExistence(timeout: 20))

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        for tab in ["ホーム", "模試", "記録", "設定"] {
            XCTAssertTrue(tabBar.buttons[tab].exists, "4タブのうち \(tab) が存在する")
        }
        assertVisibleContentFitsHorizontally(in: app)
        assertButtonsHaveAccessibilityLabels(in: app)

        let start = app.buttons["始める"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        let unknown = app.buttons["わからない"]
        XCTAssertTrue(unknown.waitForExistence(timeout: 10))
        assertVisibleContentFitsHorizontally(in: app)
        assertButtonsHaveAccessibilityLabels(in: app)

        unknown.tap()
        XCTAssertTrue(app.otherElements["memoryBlock"].waitForExistence(timeout: 5))
        let next = app.buttons["次の問題へ"]
        let result = app.buttons["結果を見る"]
        XCTAssertTrue(next.waitForExistence(timeout: 3) || result.exists)
        assertVisibleContentFitsHorizontally(in: app)
    }

    func testEachSubjectRowIsFullyTappableAndStartsFreeStudyFlow() throws {
        let app = makeApp()

        for subject in ["法令", "物理・化学", "性質・消火"] {
            app.launch()
            XCTAssertTrue(app.staticTexts["危険物 乙4"].waitForExistence(timeout: 20))

            let button = app.buttons["subject-\(subject)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "\(subject)の分野別ボタンが存在する")
            if !button.isHittable {
                app.scrollViews.firstMatch.swipeUp()
            }
            XCTAssertTrue(button.isHittable, "\(subject)の分野別ボタンがタップ可能")
            XCTAssertGreaterThanOrEqual(button.frame.height, 44, "\(subject)のタップ領域は44pt以上")

            button.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.5)).tap()
            XCTAssertTrue(
                app.buttons["わからない"].waitForExistence(timeout: 10),
                "\(subject)をタップすると無料版でも学習画面へ遷移する"
            )
            app.terminate()
        }
    }

    func testHistoryMatchesGoldenMasterStructure() throws {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["危険物 乙4"].waitForExistence(timeout: 20))
        let history = app.tabBars.buttons["記録"]
        XCTAssertTrue(history.exists)
        history.tap()

        XCTAssertTrue(app.staticTexts["学習記録"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["達成度"].exists)
        XCTAssertTrue(app.staticTexts["5週間の学習"].exists)
        XCTAssertTrue(app.staticTexts["科目別"].exists)
        XCTAssertTrue(app.staticTexts["苦手一覧"].exists)
        XCTAssertTrue(app.otherElements["全体達成度"].exists)
        assertVisibleContentFitsHorizontally(in: app)
        assertButtonsHaveAccessibilityLabels(in: app)
    }

    func testSettingsExposeGoalBackupRestoreAndPurchaseRestore() throws {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["危険物 乙4"].waitForExistence(timeout: 20))
        let settings = app.tabBars.buttons["設定"]
        XCTAssertTrue(settings.exists)
        settings.tap()

        XCTAssertTrue(app.staticTexts["設定"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1日の目標"].exists)
        XCTAssertTrue(app.buttons["JSONを書き出す"].exists)
        XCTAssertTrue(app.buttons["JSONを読み込む"].exists)
        XCTAssertTrue(app.buttons["購入を復元"].exists)
        assertVisibleContentFitsHorizontally(in: app)
        assertButtonsHaveAccessibilityLabels(in: app)
    }

    func testAccessibility3DynamicTypeHasNoHorizontalOverflow() throws {
        let app = makeApp(accessibilityText: true)
        app.launch()

        XCTAssertTrue(app.staticTexts["危険物 乙4"].waitForExistence(timeout: 20))
        assertVisibleContentFitsHorizontally(in: app)
        assertButtonsHaveAccessibilityLabels(in: app)

        let start = app.buttons["始める"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        XCTAssertTrue(app.buttons["わからない"].waitForExistence(timeout: 10))
        assertVisibleContentFitsHorizontally(in: app)
        assertButtonsHaveAccessibilityLabels(in: app)
    }

    private func makeApp(accessibilityText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        if accessibilityText {
            app.launchArguments.append("OTS4_UI_TEST_ACCESSIBILITY3")
        }
        return app
    }

    private func assertButtonsHaveAccessibilityLabels(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        for button in app.buttons.allElementsBoundByIndex where button.exists && !button.frame.isEmpty {
            XCTAssertFalse(button.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "操作要素にVoiceOverラベルが必要: \(button)", file: file, line: line)
        }
    }

    private func assertVisibleContentFitsHorizontally(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists, file: file, line: line)
        let bounds = window.frame.insetBy(dx: -1, dy: 0)
        let candidates = app.buttons.allElementsBoundByIndex + app.staticTexts.allElementsBoundByIndex

        for element in candidates where element.exists && !element.frame.isEmpty {
            let frame = element.frame
            guard frame.intersects(window.frame) else { continue }
            XCTAssertGreaterThanOrEqual(frame.minX, bounds.minX, "左方向へ横スクロール/はみ出し: \(element.label)", file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxX, bounds.maxX, "右方向へ横スクロール/はみ出し: \(element.label)", file: file, line: line)
        }
    }
}