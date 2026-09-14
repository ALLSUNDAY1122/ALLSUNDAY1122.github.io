import XCTest

final class NetworkSpecialistUITests: XCTestCase {
    private func launch(premium: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestReset", "-UITestFree"]
        if premium {
            app.launchArguments += ["-UITestPremium"]
        }
        app.launch()
        return app
    }

    private func launchStoreKitReview() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestReset"]
        app.launch()
        return app
    }

    func testCoreLearningFlowAndFourTabs() {
        let app = launch()
        XCTAssertTrue(app.otherElements["home.title"].waitForExistence(timeout: 5) || app.staticTexts["home.title"].exists)
        XCTAssertTrue(app.buttons["tab.home"].exists)
        XCTAssertTrue(app.buttons["tab.mock"].exists)
        XCTAssertTrue(app.buttons["tab.history"].exists)
        XCTAssertTrue(app.buttons["tab.settings"].exists)

        app.buttons["home.startToday"].tap()
        XCTAssertTrue(app.staticTexts["quiz.questionText"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["quiz.choice.0"].exists)
        XCTAssertTrue(app.buttons["quiz.unknown"].exists)

        app.buttons["quiz.unknown"].tap()
        XCTAssertTrue(app.buttons["quiz.next"].waitForExistence(timeout: 2))
        app.buttons["quiz.home"].tap()
        XCTAssertTrue(app.buttons["home.resume"].waitForExistence(timeout: 2))
    }

    func testLearningCycleReachesResultReviewAndRetry() {
        let app = launch()
        XCTAssertTrue(app.buttons["home.startToday"].waitForExistence(timeout: 5))
        app.buttons["home.startToday"].tap()
        XCTAssertTrue(app.staticTexts["quiz.questionText"].waitForExistence(timeout: 3))

        var answered = 0
        while answered < 20 {
            let unknown = app.buttons["quiz.unknown"]
            guard unknown.waitForExistence(timeout: 2) else { break }
            unknown.tap()
            answered += 1

            if answered == 1 {
                XCTAssertTrue(app.staticTexts["ここだけ覚える"].waitForExistence(timeout: 2))
            }

            let next = app.buttons["quiz.next"]
            XCTAssertTrue(next.waitForExistence(timeout: 2))
            next.tap()
            if app.otherElements["result.score"].waitForExistence(timeout: 1) || app.staticTexts["result.score"].exists {
                break
            }
        }

        XCTAssertGreaterThan(answered, 0)
        XCTAssertTrue(app.otherElements["result.score"].waitForExistence(timeout: 3) || app.staticTexts["result.score"].exists)
        let retry = app.buttons["result.retryMissed"]
        XCTAssertTrue(retry.waitForExistence(timeout: 3))
        retry.tap()
        XCTAssertTrue(app.staticTexts["quiz.questionText"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["quiz.unknown"].exists)
    }

    func testFreeUserCannotEnterPremiumTabs() {
        let app = launch()
        app.buttons["tab.mock"].tap()
        XCTAssertTrue(app.staticTexts["プレミアム機能"].waitForExistence(timeout: 5))
        let premiumCTA = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "プレミアムを見る")).firstMatch
        XCTAssertTrue(premiumCTA.waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["mock.year.2025"].exists)

        app.buttons["tab.history"].tap()
        XCTAssertTrue(app.staticTexts["プレミアム機能"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["history.screen"].exists)
    }

    func testPremiumMockHidesImmediateCorrectness() {
        let app = launch(premium: true)
        app.buttons["tab.mock"].tap()
        XCTAssertTrue(app.buttons["mock.year.2025"].waitForExistence(timeout: 3))
        app.buttons["mock.year.2025"].tap()
        XCTAssertTrue(app.buttons["quiz.choice.0"].waitForExistence(timeout: 3))
        app.buttons["quiz.choice.0"].tap()
        XCTAssertTrue(app.buttons["quiz.next"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["正解"].exists)
        XCTAssertFalse(app.staticTexts["不正解"].exists)
        XCTAssertFalse(app.staticTexts["わからないとして記録"].exists)
    }

    func testPremiumHistorySettingsAndLargeTextStayInsidePhoneWidth() {
        let app = launch(premium: true)
        app.buttons["tab.history"].tap()
        XCTAssertTrue(app.otherElements["history.screen"].waitForExistence(timeout: 2))

        app.buttons["tab.settings"].tap()
        XCTAssertTrue(app.otherElements["settings.screen"].waitForExistence(timeout: 2))
        let goalControl = app.segmentedControls["settings.dailyGoal"]
        XCTAssertTrue(goalControl.exists || app.otherElements["settings.dailyGoal"].exists)

        let fontControl = app.segmentedControls["settings.fontSize"]
        if fontControl.exists && fontControl.buttons["特大"].exists {
            fontControl.buttons["特大"].tap()
        }
        app.buttons["tab.home"].tap()
        XCTAssertTrue(app.buttons["home.startToday"].waitForExistence(timeout: 2))
        let window = app.windows.firstMatch
        let start = app.buttons["home.startToday"]
        XCTAssertLessThanOrEqual(start.frame.maxX, window.frame.maxX + 1)
    }

    func testCapturePremiumReviewScreenshotWithResolvedPrice() {
        let app = launchStoreKitReview()
        XCTAssertTrue(app.buttons["tab.settings"].waitForExistence(timeout: 5))
        app.buttons["tab.settings"].tap()
        XCTAssertTrue(app.otherElements["settings.screen"].waitForExistence(timeout: 3))

        let purchase = app.buttons["プレミアムを購入"]
        for _ in 0..<8 where !purchase.exists {
            app.swipeUp()
        }
        XCTAssertTrue(purchase.waitForExistence(timeout: 8), "StoreKit review purchase CTA must be visible")
        XCTAssertTrue(app.staticTexts["買い切り"].exists)
        let price = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "800")).firstMatch
        XCTAssertTrue(price.waitForExistence(timeout: 5), "StoreKit JPN price must resolve before review capture")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "取得")).firstMatch.exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "NetworkSpecialist-IAP-Review"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
