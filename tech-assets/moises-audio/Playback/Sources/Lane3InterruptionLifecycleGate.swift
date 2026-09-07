import Foundation

public actor Lane3InterruptionLifecycleGate {
    let authority: Lane3UnifiedProductionTransportAuthority
    var phase: Lane3InterruptionLifecyclePhase = .idle
    var episodeSerial: UInt64 = 0
    var lifecycleRevision: UInt64 = 0
    var commandedPlaying = false
    var resumeArmed = false
    var pendingEndShouldResume = false
    var lastBeginPlaybackGeneration: UInt64?
    var lastEndPlaybackGeneration: UInt64?
    var intentOrderSerial: UInt64 = 0
    var pendingPlayingIntents: [UInt64: Bool] = [:]

    struct PlayingIntentWaiter {
        let beforeSerial: UInt64
        let continuation: CheckedContinuation<Void, Never>
    }
    var playingIntentWaiters: [PlayingIntentWaiter] = []
    var resumeSuppressedForEpisode = false

    public init(authority: Lane3UnifiedProductionTransportAuthority) {
        self.authority = authority
    }

    public func snapshot() async -> Lane3InterruptionLifecycleSnapshot {
        let authoritySnapshot = await authority.snapshot()
        return Lane3InterruptionLifecycleSnapshot(
            phase: phase,
            episodeSerial: episodeSerial,
            lifecycleRevision: lifecycleRevision,
            commandedPlaying: commandedPlaying,
            resumeArmed: resumeArmed,
            pendingEndShouldResume: pendingEndShouldResume,
            lastBeginPlaybackGeneration: lastBeginPlaybackGeneration,
            lastEndPlaybackGeneration: lastEndPlaybackGeneration,
            authorityRecoveryBlocked: authoritySnapshot.recoveryBlocked
        )
    }

    public func submitSeek(to positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?) async -> Lane3InterruptionGuardedOutcome {
        guard phase == .idle else { return blocked(kind: .seek) }
        guard let serial = beginPlayingIntent(desiredPlaying: resume) else {
            return .rejectedBeforeTransport(kind: .seek, reason: .intentOrderSerialOverflow)
        }
        let outcome = await authority.submitSeek(to: positionSeconds, resume: resume, loop: loop)
        completePlayingIntent(serial: serial, desiredPlaying: resume, outcome: outcome)
        return .transport(outcome)
    }

    public func submitLoop(_ loop: PlaybackLoopRange?) async -> Lane3InterruptionGuardedOutcome {
        guard phase == .idle else { return blocked(kind: .loop) }
        return .transport(await authority.submitLoop(loop))
    }

    public func submitTempoRatio(_ ratio: Double) async -> Lane3InterruptionGuardedOutcome {
        guard phase == .idle else { return blocked(kind: .tempo) }
        return .transport(await authority.submitTempoRatio(ratio))
    }

    public func submitMediaLoad(_ asset: LocalAudioAsset) async -> Lane3InterruptionGuardedOutcome {
        guard phase == .idle else { return blocked(kind: .mediaLoad) }
        guard let serial = beginPlayingIntent(desiredPlaying: false) else {
            return .rejectedBeforeTransport(kind: .mediaLoad, reason: .intentOrderSerialOverflow)
        }
        let outcome = await authority.submitMediaLoad(asset)
        completePlayingIntent(serial: serial, desiredPlaying: false, outcome: outcome)
        return .transport(outcome)
    }

    public func submitMediaReplacement(
        stems: [StemArtifact], positionSeconds: Double, resume: Bool, loop: PlaybackLoopRange?
    ) async -> Lane3InterruptionGuardedOutcome {
        guard phase == .idle else { return blocked(kind: .mediaReplacement) }
        guard let serial = beginPlayingIntent(desiredPlaying: resume) else {
            return .rejectedBeforeTransport(kind: .mediaReplacement, reason: .intentOrderSerialOverflow)
        }
        let outcome = await authority.submitMediaReplacement(
            stems: stems, positionSeconds: positionSeconds, resume: resume, loop: loop
        )
        completePlayingIntent(serial: serial, desiredPlaying: resume, outcome: outcome)
        return .transport(outcome)
    }

    public func submitPlay() async -> Lane3InterruptionGuardedOutcome {
        guard phase == .idle else { return blocked(kind: .play) }
        guard let serial = beginPlayingIntent(desiredPlaying: true) else {
            return .rejectedBeforeTransport(kind: .play, reason: .intentOrderSerialOverflow)
        }
        let outcome = await authority.submitPlay()
        completePlayingIntent(serial: serial, desiredPlaying: true, outcome: outcome)
        return .transport(outcome)
    }

    public func submitPause() async -> Lane3InterruptionGuardedOutcome {
        guard phase == .idle else {
            resumeArmed = false
            resumeSuppressedForEpisode = true
            pendingEndShouldResume = false
            commandedPlaying = false
            return .resumeSuppressedWithoutToken(episodeSerial: episodeSerial)
        }
        guard let serial = beginPlayingIntent(desiredPlaying: false) else {
            return .rejectedBeforeTransport(kind: .pause, reason: .intentOrderSerialOverflow)
        }
        let outcome = await authority.submitPause()
        completePlayingIntent(serial: serial, desiredPlaying: false, outcome: outcome)
        return .transport(outcome)
    }

    public func submitRecovery() async -> Lane3InterruptionGuardedOutcome {
        if phase == .endedRecoveryRequired {
            return .rejectedBeforeTransport(kind: .recovery, reason: .recoveryRequiredAfterInterruptionEnd)
        }
        return .transport(await authority.submitRecovery())
    }
}
