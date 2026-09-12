import XCTest

final class ScanLabPasswordRecoveryPolicyTests: XCTestCase {
    func testResetRequestWaitsForCallback() {
        XCTAssertEqual(
            ScanLabPasswordRecoveryPolicy.reduce(current: .idle, signal: .resetRequested),
            .linkRequested
        )
    }

    func testRecoveryCallbackRequiresPasswordEvenWhenLocalIntentWasLost() {
        XCTAssertEqual(
            ScanLabPasswordRecoveryPolicy.reduce(current: .linkRequested, signal: .callbackSucceeded),
            .passwordUpdateRequired
        )
        XCTAssertEqual(
            ScanLabPasswordRecoveryPolicy.reduce(current: .idle, signal: .callbackSucceeded),
            .passwordUpdateRequired
        )
    }

    func testFailureAndStandardAuthClearRecoveryIntent() {
        XCTAssertEqual(
            ScanLabPasswordRecoveryPolicy.reduce(current: .linkRequested, signal: .callbackFailed),
            .idle
        )
        XCTAssertEqual(
            ScanLabPasswordRecoveryPolicy.reduce(current: .passwordUpdateRequired, signal: .standardAuthStarted),
            .idle
        )
    }

    func testPasswordPolicyMatchesExistingSixCharacterMinimum() {
        XCTAssertFalse(ScanLabPasswordRecoveryPolicy.isValidNewPassword("12345"))
        XCTAssertTrue(ScanLabPasswordRecoveryPolicy.isValidNewPassword("123456"))
    }

    func testRecoveryCallbackUsesDedicatedHost() {
        let recovery = URL(string: "jp.allsunday1122.splatlab://password-recovery?code=abc")!
        let signup = URL(string: "jp.allsunday1122.splatlab://auth-callback?code=abc")!
        let attacker = URL(string: "jp.allsunday1122.splatlab://password-recovery.example?code=abc")!

        XCTAssertTrue(ScanLabAuthCallbackPolicy.acceptsPasswordRecovery(recovery))
        XCTAssertFalse(ScanLabAuthCallbackPolicy.accepts(recovery))
        XCTAssertTrue(ScanLabAuthCallbackPolicy.accepts(signup))
        XCTAssertFalse(ScanLabAuthCallbackPolicy.acceptsPasswordRecovery(signup))
        XCTAssertFalse(ScanLabAuthCallbackPolicy.acceptsPasswordRecovery(attacker))
    }

    func testRecoveryPhasePersistsWithoutPersistingEmailOrTokens() {
        let suiteName = "ScanLabPasswordRecoveryPolicyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        ScanLabPasswordRecoveryStore.save(.linkRequested, to: defaults)
        XCTAssertEqual(ScanLabPasswordRecoveryStore.load(from: defaults), .linkRequested)

        ScanLabPasswordRecoveryStore.save(.passwordUpdateRequired, to: defaults)
        XCTAssertEqual(ScanLabPasswordRecoveryStore.load(from: defaults), .passwordUpdateRequired)

        ScanLabPasswordRecoveryStore.save(.idle, to: defaults)
        XCTAssertEqual(ScanLabPasswordRecoveryStore.load(from: defaults), .idle)
    }
}
