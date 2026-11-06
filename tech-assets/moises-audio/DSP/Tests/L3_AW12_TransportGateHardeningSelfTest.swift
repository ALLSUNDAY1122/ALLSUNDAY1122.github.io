import Foundation

@main
struct L3AW12TransportGateHardeningSelfTest {
    static func main() throws {
        try failedPlaybackGenerationBecomesRecoveryFloor()
        try clickOnlyInvalidationRevokesReplacementAuthority()
        try observedGenerationPoisonNeverRegressesFloors()
        try serialOverflowClearsBindingAndPoisons()
        print("L3-AW12 transport gate hardening self-test PASS")
    }

    static func failedPlaybackGenerationBecomesRecoveryFloor() throws {
        var gate = PracticeDSPTransportRescheduleGate(
            lastPlaybackGeneration: 10,
            lastClickGeneration: 20,
            activeBinding: PracticeDSPTransportGenerationBinding(
                playbackGeneration: 10,
                clickGeneration: 20,
                reason: .play
            )
        )
        let intent = try gate.begin(playbackGeneration: 11, reason: .seek)
        try gate.fail(intent: intent, observedClickGeneration: 21)
        precondition(gate.isPoisoned)
        precondition(gate.lastPlaybackGeneration == 11)
        precondition(gate.lastClickGeneration == 21)
        precondition(gate.activeBinding == nil)

        do {
            _ = try gate.recover(playbackGeneration: 11, clickGeneration: 22)
            preconditionFailure("failed playback generation must not be reusable")
        } catch PracticeDSPTransportRescheduleError.recoveryDidNotAdvancePlayback { }
        do {
            _ = try gate.recover(playbackGeneration: 12, clickGeneration: 21)
            preconditionFailure("already-observed click generation must not be reusable")
        } catch PracticeDSPTransportRescheduleError.recoveryDidNotAdvanceClick { }

        let recovered = try gate.recover(playbackGeneration: 12, clickGeneration: 22)
        precondition(recovered.playbackGeneration == 12)
        precondition(recovered.clickGeneration == 22)
        precondition(!gate.isPoisoned)
    }

    static func clickOnlyInvalidationRevokesReplacementAuthority() throws {
        var gate = PracticeDSPTransportRescheduleGate(
            lastPlaybackGeneration: 30,
            lastClickGeneration: 40,
            activeBinding: PracticeDSPTransportGenerationBinding(
                playbackGeneration: 30,
                clickGeneration: 40,
                reason: .seek
            )
        )
        let old = gate.activeBinding!
        try gate.validateReplacement(binding: old)
        try gate.revokeReplacementAuthorityAfterClickOnlyInvalidation(clickGeneration: 41)
        precondition(gate.lastPlaybackGeneration == 30)
        precondition(gate.lastClickGeneration == 41)
        precondition(gate.activeBinding == nil)
        do {
            try gate.validateReplacement(binding: old)
            preconditionFailure("click-only invalidation must revoke old combined binding")
        } catch PracticeDSPTransportRescheduleError.staleBinding { }
        do {
            try gate.revokeReplacementAuthorityAfterClickOnlyInvalidation(clickGeneration: 41)
            preconditionFailure("same click generation must not be reused")
        } catch PracticeDSPTransportRescheduleError.clickGenerationNotAdvanced { }
    }

    static func observedGenerationPoisonNeverRegressesFloors() throws {
        var gate = PracticeDSPTransportRescheduleGate(
            lastPlaybackGeneration: 100,
            lastClickGeneration: 200,
            activeBinding: PracticeDSPTransportGenerationBinding(
                playbackGeneration: 100,
                clickGeneration: 200,
                reason: .play
            )
        )
        gate.poisonObservedGenerations(playbackGeneration: 99, clickGeneration: 199)
        precondition(gate.lastPlaybackGeneration == 100)
        precondition(gate.lastClickGeneration == 200)
        precondition(gate.isPoisoned && gate.activeBinding == nil)
        gate.poisonObservedGenerations(playbackGeneration: 105, clickGeneration: 203)
        precondition(gate.lastPlaybackGeneration == 105)
        precondition(gate.lastClickGeneration == 203)
        do {
            _ = try gate.recover(playbackGeneration: 105, clickGeneration: 204)
            preconditionFailure("recovery must exceed max observed playback")
        } catch PracticeDSPTransportRescheduleError.recoveryDidNotAdvancePlayback { }
        let recovered = try gate.recover(playbackGeneration: 106, clickGeneration: 204)
        precondition(recovered.playbackGeneration == 106 && recovered.clickGeneration == 204)
    }

    static func serialOverflowClearsBindingAndPoisons() throws {
        var gate = PracticeDSPTransportRescheduleGate(
            lastPlaybackGeneration: 1,
            lastClickGeneration: 1,
            activeBinding: PracticeDSPTransportGenerationBinding(
                playbackGeneration: 1,
                clickGeneration: 1,
                reason: .play
            ),
            transactionSerial: UInt64.max
        )
        do {
            _ = try gate.begin(playbackGeneration: 2, reason: .seek)
            preconditionFailure("transaction serial overflow must fail")
        } catch PracticeDSPTransportRescheduleError.transactionSerialOverflow { }
        precondition(gate.isPoisoned)
        precondition(gate.activeBinding == nil)
    }
}
