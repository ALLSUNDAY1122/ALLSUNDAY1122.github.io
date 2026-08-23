import Foundation

private final class AW14StableBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
    private let lock = NSLock()
    private var tempo = 1.0
    private var pitch = 0.0
    func apply(tempoRatio: Double, pitchSemitones: Double) throws {
        lock.lock(); defer { lock.unlock() }
        tempo = tempoRatio
        pitch = pitchSemitones
    }
    func snapshotAppliedDSP() throws -> PracticeDSPBackendSnapshot {
        lock.lock(); defer { lock.unlock() }
        return PracticeDSPBackendSnapshot(tempoRatio: tempo, pitchSemitones: pitch)
    }
}

private final class AW14FaultClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    private struct Forced: Error {}
    private let lock = NSLock()
    private var failures: Set<UInt64> = []
    private var accepted = 0
    func fail(on generation: UInt64) { lock.lock(); defer { lock.unlock() }; failures.insert(generation) }
    func invalidateSchedule(to generation: UInt64) throws {
        lock.lock(); defer { lock.unlock() }
        if failures.remove(generation) != nil { throw Forced() }
        accepted += 1
    }
    func acceptedCount() -> Int { lock.lock(); defer { lock.unlock() }; return accepted }
}

private struct AW14PRNG {
    var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9e3779b97f4a7c15 : seed }
    mutating func next() -> UInt64 {
        var x = state
        x ^= x << 13; x ^= x >> 7; x ^= x << 17
        state = x
        return x
    }
    mutating func bool() -> Bool { (next() & 1) == 1 }
}

private struct AW14Counters {
    var successfulTransport = 0
    var successfulTempo = 0
    var clickOnly = 0
    var forcedTransportFailure = 0
    var forcedClickOnlyFailure = 0
    var invalidControl = 0
    var staleRejected = 0
    var wrongRouteNewToken = 0
    var poisonedNewTokenRejected = 0
    var reusedRecoveryRejected = 0
    var recoveries = 0
}

@main
struct L3AW14ModelProductionDifferentialSelfTest {
    static let normalReasons: [PlaybackTransportDiscontinuityReason] = [
        .mediaLoad, .mediaReplacement, .play, .pause, .seek, .loopChange,
        .interruptionBegan, .interruptionEnded
    ]

    static func main() async throws {
        let iterations = 200_000
        var rng = AW14PRNG(seed: 0xA14D1FF3E2)
        var oracle = Lane3GenerationDifferentialOracle()
        var counters = AW14Counters()
        let project = ProjectID()
        let controller = try PracticeDSPProductionController(projectID: project, backend: AW14StableBackend())
        let invalidator = AW14FaultClickInvalidator()
        let coordinator = PracticeDSPGenerationCoordinator(
            projectID: project,
            controller: controller,
            clickInvalidator: invalidator
        )

        for _ in 0..<iterations {
            if oracle.state.poisoned {
                switch Int(rng.next() % 3) {
                case 0:
                    let reason = normalReasons[Int(rng.next() % UInt64(normalReasons.count))]
                    let token = try oracle.rejectedNewPlaybackWhilePoisoned(reason: reason)
                    do {
                        _ = try await coordinator.bindTransportDiscontinuity(playbackToken: token)
                        preconditionFailure("poisoned coordinator accepted new Playback token")
                    } catch PracticeDSPGenerationCoordinatorError.coordinatorPoisoned { }
                    counters.poisonedNewTokenRejected += 1
                case 1:
                    let currentPlayback = oracle.state.playbackGeneration
                    try oracle.failedRecoveryUsingCurrentPlaybackGeneration()
                    do {
                        _ = try await coordinator.recover(
                            playbackToken: PlaybackTransportRescheduleToken(
                                generation: currentPlayback,
                                reason: .recovery
                            )
                        )
                        preconditionFailure("recovery reused failed/rejected Playback generation")
                    } catch PracticeDSPGenerationCoordinatorError.recoveryFailed { }
                    counters.reusedRecoveryRejected += 1
                default:
                    let token = try oracle.successfulRecovery()
                    _ = try await coordinator.recover(playbackToken: token)
                    counters.recoveries += 1
                }
                try await oracle.validate(production: coordinator.snapshot())
                continue
            }

            let selector = Int(rng.next() % 15)
            switch selector {
            case 0...4:
                let reason = normalReasons[Int(rng.next() % UInt64(normalReasons.count))]
                let token = try oracle.successfulTransport(reason: reason)
                _ = try await coordinator.bindTransportDiscontinuity(playbackToken: token)
                counters.successfulTransport += 1
            case 5:
                let ratios = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                let ratio = ratios[Int(rng.next() % UInt64(ratios.count))]
                let token = try oracle.successfulTempo(ratio)
                _ = try await coordinator.applyTempoRatio(ratio, playbackToken: token)
                counters.successfulTempo += 1
            case 6:
                let enabled = rng.bool()
                try oracle.successfulMetronome(enabled)
                _ = try await coordinator.setMetronomeEnabled(enabled)
                counters.clickOnly += 1
            case 7:
                let clicks = Int(rng.next() % 8) + 1
                try oracle.successfulCountIn(clicks)
                _ = try await coordinator.scheduleCountIn(clicks: clicks)
                counters.clickOnly += 1
            case 8:
                let reason = normalReasons[Int(rng.next() % UInt64(normalReasons.count))]
                invalidator.fail(on: oracle.state.clickGeneration + 1)
                let token = try oracle.failedTransportAfterClickAdvance(reason: reason)
                do {
                    _ = try await coordinator.bindTransportDiscontinuity(playbackToken: token)
                    preconditionFailure("forced transport click failure was accepted")
                } catch PracticeDSPGenerationCoordinatorError.clickInvalidationFailed { }
                counters.forcedTransportFailure += 1
            case 9:
                let enabled = rng.bool()
                invalidator.fail(on: oracle.state.clickGeneration + 1)
                try oracle.failedMetronomeAfterClickAdvance(enabled)
                do {
                    _ = try await coordinator.setMetronomeEnabled(enabled)
                    preconditionFailure("forced click-only failure was accepted")
                } catch PracticeDSPGenerationCoordinatorError.clickInvalidationFailed { }
                counters.forcedClickOnlyFailure += 1
            case 10:
                let clicks = rng.bool() ? 0 : 33
                try oracle.rejectedInvalidCountIn(clicks)
                do {
                    _ = try await coordinator.scheduleCountIn(clicks: clicks)
                    preconditionFailure("invalid count-in accepted")
                } catch PracticeDSPGenerationCoordinatorError.dspMutationFailed { }
                counters.invalidControl += 1
            case 11:
                if oracle.state.playbackGeneration == 0 {
                    let token = try oracle.successfulTransport(reason: .seek)
                    _ = try await coordinator.bindTransportDiscontinuity(playbackToken: token)
                    counters.successfulTransport += 1
                } else {
                    try oracle.rejectedStalePlaybackCall()
                    do {
                        _ = try await coordinator.bindTransportDiscontinuity(
                            playbackToken: PlaybackTransportRescheduleToken(
                                generation: oracle.state.playbackGeneration,
                                reason: .seek
                            )
                        )
                        preconditionFailure("stale Playback generation accepted")
                    } catch PracticeDSPTransportRescheduleError.playbackGenerationNotAdvanced { }
                    counters.staleRejected += 1
                }
            case 12:
                let invalidRatio = rng.bool() ? 0.0 : 40.0
                let token = try oracle.failedInvalidTempo(invalidRatio)
                do {
                    _ = try await coordinator.applyTempoRatio(invalidRatio, playbackToken: token)
                    preconditionFailure("invalid tempo accepted")
                } catch PracticeDSPGenerationCoordinatorError.dspMutationFailed { }
                counters.invalidControl += 1
            case 13:
                let token = try oracle.rejectedNewPlaybackWrongRoute(reason: .seek)
                do {
                    _ = try await coordinator.applyTempoRatio(1.1, playbackToken: token)
                    preconditionFailure("new wrong-route Playback token preserved stale authority")
                } catch PracticeDSPGenerationCoordinatorError.expectedTempoChangeToken { }
                counters.wrongRouteNewToken += 1
            default:
                if oracle.state.playbackGeneration == 0 {
                    let token = try oracle.successfulTransport(reason: .play)
                    _ = try await coordinator.bindTransportDiscontinuity(playbackToken: token)
                    counters.successfulTransport += 1
                } else {
                    try oracle.rejectedStalePlaybackCall()
                    do {
                        _ = try await coordinator.applyTempoRatio(
                            1.1,
                            playbackToken: PlaybackTransportRescheduleToken(
                                generation: oracle.state.playbackGeneration,
                                reason: .seek
                            )
                        )
                        preconditionFailure("stale wrong-route token unexpectedly accepted")
                    } catch PracticeDSPGenerationCoordinatorError.expectedTempoChangeToken { }
                    counters.staleRejected += 1
                }
            }
            try await oracle.validate(production: coordinator.snapshot())
        }

        if oracle.state.poisoned {
            let token = try oracle.successfulRecovery()
            _ = try await coordinator.recover(playbackToken: token)
            counters.recoveries += 1
            try await oracle.validate(production: coordinator.snapshot())
        }
        if let binding = oracle.state.activeBinding {
            try await coordinator.validateReplacement(binding: binding)
        }

        print("L3-AW14 model-vs-production differential PASS")
        print("iterations=\(iterations) serial=\(oracle.state.operationSerial) playback=\(oracle.state.playbackGeneration) click=\(oracle.state.clickGeneration) acceptedClicks=\(invalidator.acceptedCount())")
        print("transport=\(counters.successfulTransport) tempo=\(counters.successfulTempo) clickOnly=\(counters.clickOnly) forcedTransportFailure=\(counters.forcedTransportFailure) forcedClickOnlyFailure=\(counters.forcedClickOnlyFailure) invalid=\(counters.invalidControl) stale=\(counters.staleRejected) wrongRouteNew=\(counters.wrongRouteNewToken) poisonNew=\(counters.poisonedNewTokenRejected) reusedRecovery=\(counters.reusedRecoveryRejected) recovery=\(counters.recoveries)")
    }
}
