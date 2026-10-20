import XCTest

final class ScanLabAuthStatePolicyTests: XCTestCase {
    func testInitialSessionWithoutSessionResolvesSignedOut() {
        XCTAssertEqual(
            ScanLabAuthStatePolicy.reduce(
                current: .resolving,
                signal: .sessionResolved(hasSession: false)
            ),
            .signedOut
        )
    }

    func testInitialSessionWithSessionResolvesSignedIn() {
        XCTAssertEqual(
            ScanLabAuthStatePolicy.reduce(
                current: .resolving,
                signal: .sessionResolved(hasSession: true)
            ),
            .signedIn
        )
    }

    func testRefreshWithoutSessionFailsClosedToSignedOut() {
        XCTAssertEqual(
            ScanLabAuthStatePolicy.reduce(
                current: .signedIn,
                signal: .sessionResolved(hasSession: false)
            ),
            .signedOut
        )
    }

    func testRecoveredSessionReturnsToSignedIn() {
        XCTAssertEqual(
            ScanLabAuthStatePolicy.reduce(
                current: .signedOut,
                signal: .sessionResolved(hasSession: true)
            ),
            .signedIn
        )
    }

    func testExplicitSignOutAlwaysWins() {
        XCTAssertEqual(
            ScanLabAuthStatePolicy.reduce(
                current: .signedIn,
                signal: .signedOut
            ),
            .signedOut
        )
    }
}
