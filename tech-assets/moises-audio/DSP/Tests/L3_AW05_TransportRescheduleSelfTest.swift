import Foundation

@main
struct L3AW05TransportRescheduleSelfTest {
    static func main() throws {
        try deterministicOrderingAndStaleRejection()
        try failurePoisonsUntilDualGenerationRecovery()
        try monotonicityAndOverflowEdges()
        try stressDiscontinuities(iterations: 1_000_000)
        print("L3-AW05 transport reschedule self-test PASS")
    }

    static func deterministicOrderingAndStaleRejection() throws {
        var playback = PlaybackTransportRescheduleFence(activeGeneration: 40)
        let staleAudio = PlaybackTransportRescheduleToken(generation: 40, reason: .play)
        let seek = try playback.invalidate(for: .seek)
        precondition(seek.generation == 41)
        precondition(!playback.acceptsCompletion(token: staleAudio))
        precondition(playback.acceptsCompletion(token: seek))

        var dsp = PracticeDSPTransportRescheduleGate(
            lastPlaybackGeneration: 40,
            lastClickGeneration: 7,
            activeBinding: PracticeDSPTransportGenerationBinding(
                playbackGeneration: 40,
                clickGeneration: 7,
                reason: .play
            )
        )
        let intent = try dsp.begin(playbackGeneration: seek.generation, reason: .seek)
        precondition(!dsp.acceptsPlaybackGeneration(40))
        precondition(!dsp.acceptsClickGeneration(7))
        let binding = try dsp.commit(intent: intent, clickGeneration: 8)
        try dsp.validateReplacement(binding: binding)
        precondition(dsp.acceptsPlaybackGeneration(41))
        precondition(dsp.acceptsClickGeneration(8))
    }

    static func failurePoisonsUntilDualGenerationRecovery() throws {
        var playback = PlaybackTransportRescheduleFence(activeGeneration: 100)
        var dsp = PracticeDSPTransportRescheduleGate(
            lastPlaybackGeneration: 100,
            lastClickGeneration: 50,
            activeBinding: PracticeDSPTransportGenerationBinding(
                playbackGeneration: 100,
                clickGeneration: 50,
                reason: .play
            )
        )

        let loop = try playback.invalidate(for: .loopChange)
        let failedIntent = try dsp.begin(playbackGeneration: loop.generation, reason: .loopChange)
        try dsp.fail(intent: failedIntent)
        precondition(dsp.isPoisoned)
        precondition(!dsp.acceptsPlaybackGeneration(loop.generation))
        precondition(!dsp.acceptsClickGeneration(51))

        do {
            _ = try dsp.recover(
                playbackGeneration: 100,
                clickGeneration: 51
            )
            preconditionFailure("recovery must advance playback")
        } catch PracticeDSPTransportRescheduleError.recoveryDidNotAdvancePlayback {
        }

        let recoveryPlayback = try playback.invalidate(for: .recovery)
        let recovered = try dsp.recover(
            playbackGeneration: recoveryPlayback.generation,
            clickGeneration: 52
        )
        precondition(!dsp.isPoisoned)
        try dsp.validateReplacement(binding: recovered)
        precondition(recovered.playbackGeneration == 102)
        precondition(recovered.clickGeneration == 52)

        do {
            _ = try dsp.commit(intent: failedIntent, clickGeneration: 53)
            preconditionFailure("failed intent cannot be replayed")
        } catch PracticeDSPTransportRescheduleError.noPendingIntent {
        }
    }

    static func monotonicityAndOverflowEdges() throws {
        var dsp = PracticeDSPTransportRescheduleGate(
            lastPlaybackGeneration: 10,
            lastClickGeneration: 20,
            activeBinding: PracticeDSPTransportGenerationBinding(
                playbackGeneration: 10,
                clickGeneration: 20,
                reason: .play
            )
        )
        do {
            _ = try dsp.begin(playbackGeneration: 10, reason: .seek)
            preconditionFailure("same playback generation must be rejected")
        } catch PracticeDSPTransportRescheduleError.playbackGenerationNotAdvanced {
        }
        do {
            _ = try dsp.begin(playbackGeneration: 9, reason: .seek)
            preconditionFailure("playback generation regression must be rejected")
        } catch PracticeDSPTransportRescheduleError.playbackGenerationRegression {
        }

        let intent = try dsp.begin(playbackGeneration: 11, reason: .seek)
        do {
            _ = try dsp.commit(intent: intent, clickGeneration: 20)
            preconditionFailure("same click generation must be rejected")
        } catch PracticeDSPTransportRescheduleError.clickGenerationNotAdvanced {
        }
        let binding = try dsp.commit(intent: intent, clickGeneration: 21)
        try dsp.validateReplacement(binding: binding)

        var overflowFence = PlaybackTransportRescheduleFence(
            activeGeneration: UInt64.max
        )
        do {
            _ = try overflowFence.invalidate(for: .seek)
            preconditionFailure("generation overflow must fail")
        } catch PlaybackTransportRescheduleError.generationOverflow {
            precondition(overflowFence.isPoisoned)
        }
        precondition(
            !overflowFence.acceptsCompletion(
                token: PlaybackTransportRescheduleToken(
                    generation: UInt64.max,
                    reason: .play
                )
            )
        )

        var serialOverflow = PracticeDSPTransportRescheduleGate(
            transactionSerial: UInt64.max
        )
        do {
            _ = try serialOverflow.begin(playbackGeneration: 1, reason: .seek)
            preconditionFailure("transaction serial overflow must fail")
        } catch PracticeDSPTransportRescheduleError.transactionSerialOverflow {
            precondition(serialOverflow.isPoisoned)
        }
    }

    static func stressDiscontinuities(iterations: Int) throws {
        var playback = PlaybackTransportRescheduleFence()
        var dsp = PracticeDSPTransportRescheduleGate()
        var clickGeneration: UInt64 = 0
        var previousAudioToken: PlaybackTransportRescheduleToken?
        var previousClickGeneration: UInt64?
        let playbackReasons = PlaybackTransportDiscontinuityReason.allCases
        let dspReasons = PracticeDSPTransportDiscontinuityReason.allCases

        for index in 0..<iterations {
            let playbackReason = playbackReasons[index % playbackReasons.count]
            let dspReason = dspReasons[index % dspReasons.count]
            let token = try playback.invalidate(for: playbackReason)
            if let previousAudioToken {
                precondition(!playback.acceptsCompletion(token: previousAudioToken))
            }

            let intent = try dsp.begin(
                playbackGeneration: token.generation,
                reason: dspReason
            )
            clickGeneration += 1
            let binding = try dsp.commit(
                intent: intent,
                clickGeneration: clickGeneration
            )
            try dsp.validateReplacement(binding: binding)
            if let previousClickGeneration {
                precondition(!dsp.acceptsClickGeneration(previousClickGeneration))
            }
            precondition(dsp.acceptsPlaybackGeneration(token.generation))
            precondition(dsp.acceptsClickGeneration(clickGeneration))
            previousAudioToken = token
            previousClickGeneration = clickGeneration
        }
    }
}
