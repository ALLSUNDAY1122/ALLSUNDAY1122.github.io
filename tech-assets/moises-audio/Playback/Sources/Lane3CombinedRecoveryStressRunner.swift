import Foundation

public enum Lane3CombinedRecoveryStressRunner {
    public static func run(seed: UInt64, operations: Int, stemCount: Int = 4) throws -> Lane3CombinedRecoveryStressReport {
        guard operations >= 0 else { throw Lane3CombinedRecoveryError.invalidSeekPosition(Double(operations)) }
        var rng = Lane3CombinedRecoveryPRNG(seed: seed)
        var machine = try Lane3CombinedRecoveryMachine(stemCount: stemCount)
        var previousBinding: Lane3CombinedRecoveryBinding?

        for index in 0..<operations {
            if machine.state.poisoned {
                try machine.apply(.recover(resume: rng.nextBool()))
                continue
            }

            if index > 0 && index % 997 == 0 {
                try machine.apply(.forceHalfInvalidationFailure)
                continue
            }
            if index > 0 && index % 211 == 0 {
                let current = machine.state.playbackGeneration
                let stale = current == 0 ? 1 : current - 1
                try machine.apply(.staleCompletion(playbackGeneration: stale))
                continue
            }
            if index > 0 && index % 307 == 0 {
                let staleBinding: Lane3CombinedRecoveryBinding?
                if let current = machine.state.binding {
                    let stalePlayback = current.playbackGeneration == 0 ? 1 : current.playbackGeneration - 1
                    staleBinding = Lane3CombinedRecoveryBinding(
                        playbackGeneration: stalePlayback,
                        clickGeneration: current.clickGeneration,
                        reason: current.reason
                    )
                } else {
                    staleBinding = previousBinding
                }
                try machine.apply(.staleReplacement(binding: staleBinding))
                continue
            }

            previousBinding = machine.state.binding

            let selector = Int(rng.next() % 13)
            let operation: Lane3CombinedRecoveryOperation
            switch selector {
            case 0:
                operation = .setGain(stemIndex: Int(rng.next() % UInt64(stemCount)), gain: Double(rng.next() % 101) / 100)
            case 1:
                operation = .setPitch(Double(Int(rng.next() % 49) - 24))
            case 2:
                let tempos = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                operation = .setTempo(tempos[Int(rng.next() % UInt64(tempos.count))])
            case 3:
                operation = .setMetronome(rng.nextBool())
            case 4:
                operation = .scheduleCountIn(Int(rng.next() % 8) + 1)
            case 5:
                operation = .consumeCountIn
            case 6:
                operation = .seek(Double(rng.next() % 36_000) / 10)
            case 7:
                let start = Double(rng.next() % 30_000) / 10
                operation = .setLoop(start: start, end: start + Double(rng.next() % 600 + 1) / 10)
            case 8:
                operation = .clearLoop
            case 9:
                operation = machine.state.interrupted ? .pause : .play
            case 10:
                operation = .pause
            case 11:
                operation = .interruptionBegan
            default:
                operation = .interruptionEnded(resume: rng.nextBool())
            }

            do {
                try machine.apply(operation)
            } catch Lane3CombinedRecoveryError.playWhileInterrupted {
                try machine.validateInvariants()
            }
        }

        try machine.validateInvariants()
        let checksum = checksumFNV1A64(state: machine.state, counters: machine.counters)
        return Lane3CombinedRecoveryStressReport(
            schemaVersion: 1,
            evidenceScope: "LANE3_COMBINED_PLAYBACK_DSP_RECOVERY_STRESS_NON_PARITY",
            seed: seed,
            requestedOperations: operations,
            counters: machine.counters,
            finalState: machine.state,
            finalInvariantPassed: true,
            checksumFNV1A64: checksum,
            physicalDeviceEvidence: false,
            realAudioEvidence: false,
            audibleArtifactClaimAllowed: false,
            parityPromotionAllowed: false
        )
    }

    private static func checksumFNV1A64(state: Lane3CombinedRecoveryState, counters: Lane3CombinedRecoveryCounters) -> String {
        var text = "p:\(state.playbackGeneration)|c:\(state.clickGeneration)|tempo:\(state.tempoRatio.bitPattern)|pitch:\(state.pitchSemitones.bitPattern)|m:\(state.metronomeEnabled ? 1 : 0)|ci:\(state.pendingCountInClicks ?? -1)|pos:\(state.positionSeconds.bitPattern)|playing:\(state.playing ? 1 : 0)|int:\(state.interrupted ? 1 : 0)|poison:\(state.poisoned ? 1 : 0)"
        for gain in state.gains { text += "|g:\(gain.bitPattern)" }
        if let binding = state.binding { text += "|b:\(binding.playbackGeneration),\(binding.clickGeneration),\(binding.reason.rawValue)" }
        text += "|a:\(counters.applied)|r:\(counters.rejected)|f:\(counters.forcedHalfFailures)|rec:\(counters.recoveries)|sc:\(counters.staleCompletionRejected)|sr:\(counters.staleReplacementRejected)"
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }
}

struct Lane3CombinedRecoveryPRNG: Sendable {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0x9e3779b97f4a7c15 : seed }
    mutating func next() -> UInt64 {
        var x = state
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
        state = x
        return x
    }
    mutating func nextBool() -> Bool { (next() & 1) == 1 }
}
