import XCTest
@testable import SplatNative

final class ScanLabSessionPolicyTests: XCTestCase {
    func testInitialPersistedValidSessionRestoresAndReloadsPrivateData() {
        let event = ScanLabSessionEvent.initialSession(hasSession: true, isExpired: false)
        XCTAssertTrue(ScanLabSessionPolicy.isAuthenticated(after: event))
        XCTAssertTrue(ScanLabSessionPolicy.shouldReloadPrivateData(after: event))
        XCTAssertFalse(ScanLabSessionPolicy.needsRefreshBeforePrivateData(after: event))
    }

    func testInitialPersistedExpiredSessionWaitsForRefreshBeforePrivateData() {
        let event = ScanLabSessionEvent.initialSession(hasSession: true, isExpired: true)
        XCTAssertTrue(ScanLabSessionPolicy.isAuthenticated(after: event))
        XCTAssertFalse(ScanLabSessionPolicy.shouldReloadPrivateData(after: event))
        XCTAssertTrue(ScanLabSessionPolicy.needsRefreshBeforePrivateData(after: event))
    }

    func testInitialMissingSessionIsSignedOut() {
        let event = ScanLabSessionEvent.initialSession(hasSession: false, isExpired: false)
        XCTAssertFalse(ScanLabSessionPolicy.isAuthenticated(after: event))
        XCTAssertFalse(ScanLabSessionPolicy.shouldReloadPrivateData(after: event))
        XCTAssertFalse(ScanLabSessionPolicy.needsRefreshBeforePrivateData(after: event))
    }

    func testTokenRefreshKeepsAuthenticatedStateWithoutPeriodicReloadStorm() {
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
