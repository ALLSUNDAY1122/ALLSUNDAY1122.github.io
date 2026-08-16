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
}
