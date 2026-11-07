import Foundation
import XCTest

final class ScanLabAuthCallbackPolicyTests: XCTestCase {
    func testCanonicalRedirectURL() {
        XCTAssertEqual(
            ScanLabAuthCallbackPolicy.redirectURL.absoluteString,
            "jp.allsunday1122.splatlab://auth-callback"
        )
    }

    func testAcceptsPkceCallbackWithCode() {
        let url = URL(string: "jp.allsunday1122.splatlab://auth-callback?code=abc123")!
        XCTAssertTrue(ScanLabAuthCallbackPolicy.accepts(url))
    }

    func testAcceptsCallbackWithTrailingSlash() {
        let url = URL(string: "jp.allsunday1122.splatlab://auth-callback/?code=abc123")!
        XCTAssertTrue(ScanLabAuthCallbackPolicy.accepts(url))
    }

    func testRejectsWrongScheme() {
        let url = URL(string: "https://auth-callback?code=abc123")!
        XCTAssertFalse(ScanLabAuthCallbackPolicy.accepts(url))
    }

    func testRejectsWrongHost() {
        let url = URL(string: "jp.allsunday1122.splatlab://evil-host?code=abc123")!
        XCTAssertFalse(ScanLabAuthCallbackPolicy.accepts(url))
    }

    func testRejectsUnexpectedPath() {
        let url = URL(string: "jp.allsunday1122.splatlab://auth-callback/other?code=abc123")!
        XCTAssertFalse(ScanLabAuthCallbackPolicy.accepts(url))
    }

    func testRejectsUserInfoOrPort() {
        XCTAssertFalse(
            ScanLabAuthCallbackPolicy.accepts(
                URL(string: "jp.allsunday1122.splatlab://user@auth-callback?code=abc123")!
            )
        )
        XCTAssertFalse(
            ScanLabAuthCallbackPolicy.accepts(
                URL(string: "jp.allsunday1122.splatlab://auth-callback:1234?code=abc123")!
            )
        )
    }

    func testEmailConfirmationAllowsFirstSend() {
        let now = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(ScanLabEmailConfirmationPolicy.canResend(lastSentAt: nil, now: now))
        XCTAssertEqual(ScanLabEmailConfirmationPolicy.remainingSeconds(lastSentAt: nil, now: now), 0)
    }

    func testEmailConfirmationEnforcesSixtySecondMinimum() {
        let sent = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(
            ScanLabEmailConfirmationPolicy.remainingSeconds(
                lastSentAt: sent,
                now: Date(timeIntervalSince1970: 1_030)
            ),
            30
        )
        XCTAssertEqual(
            ScanLabEmailConfirmationPolicy.remainingSeconds(
                lastSentAt: sent,
                now: Date(timeIntervalSince1970: 1_059.2)
            ),
            1
        )
        XCTAssertTrue(
            ScanLabEmailConfirmationPolicy.canResend(
                lastSentAt: sent,
                now: Date(timeIntervalSince1970: 1_060)
            )
        )
    }

    func testEmailConfirmationClockRollbackCannotCreateUnboundedLockout() {
        let sent = Date(timeIntervalSince1970: 2_000)
        XCTAssertEqual(
            ScanLabEmailConfirmationPolicy.remainingSeconds(
                lastSentAt: sent,
                now: Date(timeIntervalSince1970: 1_900)
            ),
            60
        )
    }

    func testEmailConfirmationStorePersistsOnlyTimestamp() {
        let suiteName = "ScanLabAuthCallbackPolicyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let sent = Date(timeIntervalSince1970: 1_234.5)
        ScanLabEmailConfirmationStore.save(sent, to: defaults)
        XCTAssertEqual(
            ScanLabEmailConfirmationStore.load(from: defaults)?.timeIntervalSince1970,
            sent.timeIntervalSince1970
        )

        ScanLabEmailConfirmationStore.clear(from: defaults)
        XCTAssertNil(ScanLabEmailConfirmationStore.load(from: defaults))
    }
}
