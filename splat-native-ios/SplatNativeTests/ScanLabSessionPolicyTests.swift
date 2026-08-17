import XCTest
@testable import SplatNative

final class ScanLabSessionPolicyTests: XCTestCase {
    func testInitialPersistedSessionRestoresAuthenticatedState() {
        XCTAssertTrue(ScanLabSessionPolicy.isAuthenticated(after: .initialSession(hasSession: true)))
        XCTAssertTrue(ScanLabSessionPolicy.shouldReloadPrivateData(after: .initialSession(hasSession: true)))
    }

    func testInitialMissingSessionIsSignedOut() {
        XCTAssertFalse(ScanLabSessionPolicy.isAuthenticated(after: .initialSession(hasSession: false)))
        XCTAssertFalse(ScanLabSessionPolicy.shouldReloadPrivateData(after: .initialSession(hasSession: false)))
    }

    func testTokenRefreshKeepsAuthenticatedStateWithoutReloadStorm() {
        XCTAssertTrue(ScanLabSessionPolicy.isAuthenticated(after: .tokenRefreshed))
        XCTAssertFalse(ScanLabSessionPolicy.shouldReloadPrivateData(after: .tokenRefreshed))
    }

    func testPasswordRecoveryAndUserUpdateKeepAuthenticatedState() {
        XCTAssertTrue(ScanLabSessionPolicy.isAuthenticated(after: .passwordRecovery))
        XCTAssertTrue(ScanLabSessionPolicy.isAuthenticated(after: .userUpdated))
        XCTAssertTrue(ScanLabSessionPolicy.shouldReloadPrivateData(after: .passwordRecovery))
        XCTAssertTrue(ScanLabSessionPolicy.shouldReloadPrivateData(after: .userUpdated))
    }

    func testSignedOutClearsAuthenticatedState() {
        XCTAssertFalse(ScanLabSessionPolicy.isAuthenticated(after: .signedOut))
        XCTAssertFalse(ScanLabSessionPolicy.shouldReloadPrivateData(after: .signedOut))
    }

    func testTransientRefreshFailureKeepsAuthenticatedContextWhenCachedSessionSurvives() {
        XCTAssertEqual(
            ScanLabSessionPolicy.recoveryDecision(hasCachedSessionAfterFailure: true),
            .keepAuthenticatedAndRetry
        )
    }

    func testMissingCachedSessionAfterRefreshFailureRequiresSignIn() {
        XCTAssertEqual(
            ScanLabSessionPolicy.recoveryDecision(hasCachedSessionAfterFailure: false),
            .requireSignIn
        )
    }
}
