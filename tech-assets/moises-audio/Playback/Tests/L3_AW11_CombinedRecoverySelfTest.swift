import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}

func expectThrow(_ body: () throws -> Void, _ message: String) {
    do { try body(); fatalError("expected throw: \(message)") } catch { }
}

@main
struct AW11SelfTest {
    static func main() throws {
        var machine = try Lane3CombinedRecoveryMachine(stemCount: 4)

        try machine.apply(.setGain(stemIndex: 0, gain: 0.25))
        try machine.apply(.setPitch(7))
        try machine.apply(.setTempo(1.25))
        let afterTempo = machine.state.binding!
        expect(afterTempo.reason == .tempoChange, "tempo binding reason")
        expect(machine.acceptsReplacement(binding: afterTempo), "current binding must be accepted")

        try machine.apply(.setMetronome(true))
        expect(!machine.acceptsReplacement(binding: afterTempo), "old transport binding survived click-only invalidation")
        expect(machine.state.binding == nil, "click-only invalidation must clear combined binding")

        try machine.apply(.seek(12.5))
        let seekBinding = machine.state.binding!
        expect(machine.acceptsReplacement(binding: seekBinding), "seek binding")
        let stalePlayback = seekBinding.playbackGeneration
        try machine.apply(.setLoop(start: 4, end: 8))
        expect(!machine.acceptsCompletion(playbackGeneration: stalePlayback), "stale completion accepted")
        try machine.apply(.staleCompletion(playbackGeneration: stalePlayback))
        expect(machine.counters.staleCompletionRejected == 1, "stale completion counter")

        let preFailurePlayback = machine.state.playbackGeneration
        let preFailureClick = machine.state.clickGeneration
        try machine.apply(.forceHalfInvalidationFailure)
        expect(machine.state.poisoned, "half failure must poison")
        expect(machine.state.binding == nil, "poisoned state cannot retain binding")
        let poisonedSnapshot = machine.state
        expectThrow({ try machine.apply(.setPitch(-3)) }, "mutation while poisoned")
        expect(machine.state == poisonedSnapshot, "poisoned rejection mutated state")
        try machine.apply(.recover(resume: true))
        expect(!machine.state.poisoned, "recovery did not clear poison")
        expect(machine.state.playbackGeneration > preFailurePlayback, "recovery playback generation")
        expect(machine.state.clickGeneration > preFailureClick, "recovery click generation")
        expect(machine.acceptsReplacement(binding: machine.state.binding), "recovery binding invalid")

        let atomic = machine.state
        expectThrow({ try machine.apply(.setGain(stemIndex: 0, gain: .nan)) }, "NaN gain")
        expect(machine.state == atomic, "NaN gain mutated state")
        expectThrow({ try machine.apply(.setTempo(100)) }, "tempo range")
        expect(machine.state == atomic, "invalid tempo mutated state")
        expectThrow({ try machine.apply(.setPitch(25)) }, "pitch range")
        expect(machine.state == atomic, "invalid pitch mutated state")
        expectThrow({ try machine.apply(.scheduleCountIn(0)) }, "count-in range")
        expect(machine.state == atomic, "invalid count-in mutated state")
        expectThrow({ try machine.apply(.setLoop(start: 5, end: 5)) }, "loop range")
        expect(machine.state == atomic, "invalid loop mutated state")

        var overflow = try Lane3CombinedRecoveryMachine(stemCount: 1, playbackGeneration: UInt64.max, clickGeneration: 10)
        expectThrow({ try overflow.apply(.seek(1)) }, "playback generation overflow")
        expect(overflow.state.poisoned, "overflow must poison")
        expect(overflow.state.binding == nil, "overflow binding")

        var clickOverflow = try Lane3CombinedRecoveryMachine(stemCount: 1, playbackGeneration: 10, clickGeneration: UInt64.max)
        expectThrow({ try clickOverflow.apply(.setTempo(1.5)) }, "click generation overflow")
        expect(clickOverflow.state.poisoned, "click overflow must poison")
        expect(clickOverflow.state.playbackGeneration == 11, "partial playback invalidation must remain advanced")
        expect(clickOverflow.state.binding == nil, "click overflow binding")
        expectThrow({ try clickOverflow.apply(.recover(resume: false)) }, "unrecoverable click generation exhaustion")
        expect(clickOverflow.state.poisoned, "failed recovery from exhausted generation must remain poisoned")

        let report = try Lane3CombinedRecoveryStressRunner.run(seed: 0xA11A11A11, operations: 1_000_000, stemCount: 6)
        expect(report.finalInvariantPassed, "stress invariant")
        expect(report.counters.forcedHalfFailures > 900, "forced failures not exercised")
        expect(report.counters.recoveries == report.counters.forcedHalfFailures, "forced failure recovery mismatch")
        expect(report.counters.staleCompletionAttempts == report.counters.staleCompletionRejected, "stale completion accepted")
        expect(report.counters.staleReplacementAttempts == report.counters.staleReplacementRejected, "stale replacement accepted")
        expect(!report.physicalDeviceEvidence && !report.realAudioEvidence, "evidence scope leak")
        expect(!report.audibleArtifactClaimAllowed && !report.parityPromotionAllowed, "claim scope leak")

        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(Lane3CombinedRecoveryStressReport.self, from: data)
        expect(decoded == report, "Codable round-trip")

        print("L3-AW11 combined recovery self-test PASS")
        print("stress applied=\(report.counters.applied) rejected=\(report.counters.rejected) forced=\(report.counters.forcedHalfFailures) recoveries=\(report.counters.recoveries) staleCompletionRejected=\(report.counters.staleCompletionRejected) staleReplacementRejected=\(report.counters.staleReplacementRejected) checksum=\(report.checksumFNV1A64)")
    }
}
