import XCTest

final class KangoshiSprintUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        XCTAssertTrue(app.staticTexts["看護師国家試験"].waitForExistence(timeout: 8))
        return app
    }

    // Regression: quiz dismissal must restore the home content, not a fragile tab-bar query.
    func testHomeFreeSprintAndClose() throws {
        let app = launchApp()

        XCTAssertTrue(app.buttons["今日のスプリント"].exists)
        app.buttons["今日のスプリント"].tap()
        let close = app.buttons["閉じる"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "今日のスプリント must open a free quiz for a non-premium launch")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '1/'")).firstMatch.exists)
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 10))
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(app.staticTexts["今日の学習"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["今日のスプリント"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["学習を開始できません"].exists)
    }

    func testFreeMockGateAndRestoreEntry() throws {
        let app = launchApp()

        app.tabBars.buttons["模試"].tap()
        XCTAssertTrue(app.staticTexts["本番形式"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["本番形式はプレミアム"].exists)
        XCTAssertTrue(app.buttons["プレミアムを見る"].exists)

        app.tabBars.buttons["設定"].tap()
        XCTAssertTrue(app.staticTexts["学びかた"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["購入を復元"].exists)
    }

    func testFreeCategorySamplesStartAQuiz() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["無料お試し"].waitForExistence(timeout: 5))

        for category in ["必修", "一般", "状況設定"] {
            let button = app.buttons["free-sample-\(category)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "\(category) free sample button must be visible")
            XCTAssertTrue(button.isEnabled, "\(category) free sample must not be disabled (empty pool)")
            button.tap()
            let close = app.buttons["閉じる"]
            XCTAssertTrue(close.waitForExistence(timeout: 5), "\(category) お試し must open a quiz, not fail silently")
            XCTAssertTrue(app.staticTexts["\(category) お試し"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '1/'")).firstMatch.exists)
            close.tap()
            XCTAssertTrue(close.waitForNonExistence(timeout: 10))
            XCTAssertTrue(app.staticTexts["無料お試し"].waitForExistence(timeout: 10))
        }
    }

    func testPaywallShowsLegalLinks() throws {
        let app = launchApp()
        app.tabBars.buttons["模試"].tap()
        let openPaywall = app.buttons["プレミアムを見る"]
        XCTAssertTrue(openPaywall.waitForExistence(timeout: 5))
        openPaywall.tap()

        XCTAssertTrue(app.staticTexts["学びスプリント プレミアム"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '1か月ごとの自動更新'")).firstMatch.exists, "Subscription period and auto-renewal must be disclosed on the paywall")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'サブスクリプション'")).firstMatch.exists, "Cancellation path must be disclosed")

        let privacy = app.descendants(matching: .any)["privacy-policy-link"]
        let terms = app.descendants(matching: .any)["terms-of-use-link"]
        XCTAssertTrue(privacy.waitForExistence(timeout: 5), "Guideline 3.1.2 requires a tappable Privacy Policy link")
        XCTAssertTrue(terms.waitForExistence(timeout: 5), "Guideline 3.1.2 requires a tappable Terms of Use (EULA) link")
        XCTAssertTrue(privacy.isHittable)
        XCTAssertTrue(terms.isHittable)
    }

    // Guideline 1.4.1: sources must be reachable from Settings and from the explanation screen.
    func testReferencesReachableFromSettingsAndExplanation() throws {
        let app = launchApp()

        app.tabBars.buttons["設定"].tap()
        XCTAssertTrue(app.staticTexts["学びかた"].waitForExistence(timeout: 5))
        let settingsLink = app.buttons["settings-references-link"]
        XCTAssertTrue(settingsLink.waitForExistence(timeout: 5), "Settings must contain 出典・参考資料")
        var swipes = 0
        while !settingsLink.isHittable && swipes < 6 { app.swipeUp(); swipes += 1 }
        settingsLink.tap()
        XCTAssertTrue(app.staticTexts["国家試験の原典（問題・正答）"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["references-exam-115"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["settings-disclaimer-link"].waitForExistence(timeout: 5), "Settings must contain the disclaimer")

        app.tabBars.buttons["ホーム"].tap()
        XCTAssertTrue(app.buttons["今日のスプリント"].waitForExistence(timeout: 5))
        app.buttons["今日のスプリント"].tap()
        let close = app.buttons["閉じる"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        let questionSource = app.descendants(matching: .any)["question-source-link"]
        XCTAssertTrue(questionSource.waitForExistence(timeout: 5), "Each question must link to the official MHLW source")
        let questionSourceURL = (questionSource.value as? String) ?? ""
        XCTAssertTrue(questionSourceURL.hasPrefix("https://www.mhlw.go.jp/") && questionSourceURL.hasSuffix("-03_04_05.html"), "Question link must open the MHLW 問題および正答 page, got \(questionSourceURL)")
        XCTAssertFalse(questionSourceURL.hasSuffix(".pdf"), "Question link must not open the answer PDF")

        let unknown = app.buttons["わからない（答えを見る）"]
        XCTAssertTrue(unknown.waitForExistence(timeout: 5))
        swipes = 0
        while !unknown.isHittable && swipes < 6 { app.swipeUp(); swipes += 1 }
        unknown.tap()
        let unknownHeading = app.staticTexts["わからない（答えを確認）"]
        let excludedHeading = app.staticTexts["採点対象外"]
        XCTAssertTrue(unknownHeading.waitForExistence(timeout: 5) || excludedHeading.exists, "Unknown answers must not be labelled 惜しい")
        XCTAssertFalse(app.staticTexts["惜しい"].exists)

        let examLink = app.descendants(matching: .any)["explanation-exam-link"]
        let answerLink = app.descendants(matching: .any)["explanation-answer-link"]
        XCTAssertTrue(examLink.waitForExistence(timeout: 5))
        XCTAssertTrue(((examLink.value as? String) ?? "").hasSuffix("-03_04_05.html"), "Explanation exam link must open the MHLW page")
        XCTAssertTrue(((answerLink.value as? String) ?? "").hasSuffix("-05seitou.pdf"), "Explanation answer link must open the answer-key PDF")
        XCTAssertEqual(examLink.value as? String, questionSource.value as? String)

        let refsButton = app.buttons["explanation-references-button"]
        XCTAssertTrue(refsButton.waitForExistence(timeout: 5), "Explanation must offer the references list")
        swipes = 0
        while !refsButton.isHittable && swipes < 8 { app.swipeUp(); swipes += 1 }
        refsButton.tap()
        XCTAssertTrue(app.staticTexts["国家試験の原典（問題・正答）"].waitForExistence(timeout: 5))
        app.buttons["references-close"].tap()
        XCTAssertTrue(refsButton.waitForExistence(timeout: 5))
    }
}
