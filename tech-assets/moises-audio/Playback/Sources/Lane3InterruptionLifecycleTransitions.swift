import Foundation

public extension Lane3InterruptionLifecycleGate {
    func submitInterruptionBegan() async -> Lane3InterruptionBeginResult {
        switch phase {
        case .active, .beginning:
            return .rejected(reason: .duplicateInterruptionBegan)
        case .poisoned:
            return .rejected(reason: .lifecycleRevisionOverflow)
        case .idle, .ending, .resuming, .endedRecoveryRequired:
            break
        }

        let (nextEpisode, episodeOverflow) = episodeSerial.addingReportingOverflow(1)
        guard !episodeOverflow else { return .rejected(reason: .episodeSerialOverflow) }
        guard let boundaryOrderSerial = allocateIntentOrderSerial() else {
            phase = .poisoned
            return .rejected(reason: .intentOrderSerialOverflow)
        }
        guard let revision = advanceLifecycleRevision() else {
            phase = .poisoned
            return .rejected(reason: .lifecycleRevisionOverflow)
        }

        episodeSerial = nextEpisode
        let inheritedResume = resumeArmed
        pendingEndShouldResume = false
        phase = .beginning

        await waitForPlayingIntents(before: boundaryOrderSerial)
        resumeArmed = resumeSuppressedForEpisode ? false : (commandedPlaying || inheritedResume)
        commandedPlaying = false

        let preRecovery = await recoverAuthorityIfNeeded()
        let boundary: Lane3UnifiedTransportOutcome?
        if Self.recoveryAttemptFailed(preRecovery) {
            boundary = nil
        } else {
            boundary = await authority.submitInterruptionBegan()
        }
        let safe = boundary.map(Self.boundarySafe) ?? false
        let superseded = lifecycleRevision != revision
        if !superseded {
            phase = .active
            if let generation = boundary.flatMap(Self.bestSafeGeneration) {
                lastBeginPlaybackGeneration = generation
            }
        }
        return .began(Lane3InterruptionBeginReceipt(
            episodeSerial: nextEpisode,
            lifecycleRevision: revision,
            resumeArmed: resumeArmed,
            preBoundaryRecovery: preRecovery,
            boundaryOutcome: boundary,
            boundarySafe: safe,
            supersededByNewerLifecycleEvent: superseded
        ))
    }

    func submitInterruptionEnded(shouldResume osShouldResume: Bool) async -> Lane3InterruptionEndResult {
        guard phase == .active else {
            return .rejected(reason: phase == .endedRecoveryRequired
                ? .recoveryRequiredAfterInterruptionEnd
                : .noActiveInterruption)
        }
        guard let revision = advanceLifecycleRevision() else {
            phase = .poisoned
            return .rejected(reason: .lifecycleRevisionOverflow)
        }
        let episode = episodeSerial
        let armedAtStart = resumeArmed
        pendingEndShouldResume = osShouldResume
        phase = .ending

        let preRecovery = await recoverAuthorityIfNeeded()
        let boundary: Lane3UnifiedTransportOutcome?
        if Self.recoveryAttemptFailed(preRecovery) {
            boundary = nil
        } else {
            boundary = await authority.submitInterruptionEnded()
        }
        let safe = boundary.map(Self.boundarySafe) ?? false

        guard lifecycleRevision == revision else {
            return .ended(makeEndReceipt(
                episode: episode, revision: revision, osShouldResume: osShouldResume,
                armedAtStart: armedAtStart, preRecovery: preRecovery, boundary: boundary,
                boundarySafe: safe, resume: nil, compensatingPause: nil,
                resumed: false, superseded: true, recoveryRequired: false
            ))
        }
        guard safe else {
            phase = .endedRecoveryRequired
            return .ended(makeEndReceipt(
                episode: episode, revision: revision, osShouldResume: osShouldResume,
                armedAtStart: armedAtStart, preRecovery: preRecovery, boundary: boundary,
                boundarySafe: false, resume: nil, compensatingPause: nil,
                resumed: false, superseded: false, recoveryRequired: true
            ))
        }
        if let generation = boundary.flatMap(Self.bestSafeGeneration) {
            lastEndPlaybackGeneration = generation
        }
        return await finishSafeInterruptionEnd(
            episode: episode, revision: revision, osShouldResume: osShouldResume,
            armedAtStart: armedAtStart, preRecovery: preRecovery, boundary: boundary
        )
    }

    func retryEndedInterruptionRecovery() async -> Lane3InterruptionEndResult {
        guard phase == .endedRecoveryRequired else {
            return .rejected(reason: .noActiveInterruption)
        }
        guard let revision = advanceLifecycleRevision() else {
            phase = .poisoned
            return .rejected(reason: .lifecycleRevisionOverflow)
        }
        let episode = episodeSerial
        let osShouldResume = pendingEndShouldResume
        let armedAtStart = resumeArmed
        phase = .ending
        let recovery = await authority.submitRecovery()

        guard lifecycleRevision == revision else {
            return .ended(makeEndReceipt(
                episode: episode, revision: revision, osShouldResume: osShouldResume,
                armedAtStart: armedAtStart, preRecovery: recovery, boundary: nil,
                boundarySafe: Self.executed(recovery), resume: nil, compensatingPause: nil,
                resumed: false, superseded: true, recoveryRequired: false
            ))
        }
        guard Self.executed(recovery) else {
            phase = .endedRecoveryRequired
            return .ended(makeEndReceipt(
                episode: episode, revision: revision, osShouldResume: osShouldResume,
                armedAtStart: armedAtStart, preRecovery: recovery, boundary: nil,
                boundarySafe: false, resume: nil, compensatingPause: nil,
                resumed: false, superseded: false, recoveryRequired: true
            ))
        }
        if let generation = Self.bestSafeGeneration(recovery) {
            lastEndPlaybackGeneration = generation
        }
        return await finishSafeInterruptionEnd(
            episode: episode, revision: revision, osShouldResume: osShouldResume,
            armedAtStart: armedAtStart, preRecovery: recovery, boundary: nil
        )
    }

    func finishSafeInterruptionEnd(
        episode: UInt64,
        revision: UInt64,
        osShouldResume: Bool,
        armedAtStart: Bool,
        preRecovery: Lane3UnifiedTransportOutcome?,
        boundary: Lane3UnifiedTransportOutcome?
    ) async -> Lane3InterruptionEndResult {
        guard osShouldResume && resumeArmed else {
            commandedPlaying = false
            resumeArmed = false
            resumeSuppressedForEpisode = false
            pendingEndShouldResume = false
            phase = .idle
            return .ended(makeEndReceipt(
                episode: episode, revision: revision, osShouldResume: osShouldResume,
                armedAtStart: armedAtStart, preRecovery: preRecovery, boundary: boundary,
                boundarySafe: true, resume: nil, compensatingPause: nil,
                resumed: false, superseded: false, recoveryRequired: false
            ))
        }

        phase = .resuming
        guard let resumeSerial = beginPlayingIntent(desiredPlaying: true) else {
            phase = .poisoned
            return .rejected(reason: .intentOrderSerialOverflow)
        }
        let resume = await authority.submitPlay()
        completePlayingIntent(serial: resumeSerial, desiredPlaying: true, outcome: resume)

        guard lifecycleRevision == revision else {
            return .ended(makeEndReceipt(
                episode: episode, revision: revision, osShouldResume: osShouldResume,
                armedAtStart: armedAtStart, preRecovery: preRecovery, boundary: boundary,
                boundarySafe: true, resume: resume, compensatingPause: nil,
                resumed: false, superseded: true, recoveryRequired: false
            ))
        }

        var compensatingPause: Lane3UnifiedTransportOutcome?
        var resumed = Self.executed(resume)
        if !resumeArmed && resumed {
            if let pauseSerial = beginPlayingIntent(desiredPlaying: false) {
                let pause = await authority.submitPause()
                completePlayingIntent(serial: pauseSerial, desiredPlaying: false, outcome: pause)
                compensatingPause = pause
            } else {
                phase = .poisoned
            }
            resumed = false
        }
        commandedPlaying = resumed
        resumeArmed = false
        resumeSuppressedForEpisode = false
        pendingEndShouldResume = false
        if phase != .poisoned { phase = .idle }
        return .ended(makeEndReceipt(
            episode: episode, revision: revision, osShouldResume: osShouldResume,
            armedAtStart: armedAtStart, preRecovery: preRecovery, boundary: boundary,
            boundarySafe: true, resume: resume, compensatingPause: compensatingPause,
            resumed: resumed, superseded: false, recoveryRequired: false
        ))
    }

    func makeEndReceipt(
        episode: UInt64, revision: UInt64, osShouldResume: Bool, armedAtStart: Bool,
        preRecovery: Lane3UnifiedTransportOutcome?, boundary: Lane3UnifiedTransportOutcome?,
        boundarySafe: Bool, resume: Lane3UnifiedTransportOutcome?,
        compensatingPause: Lane3UnifiedTransportOutcome?, resumed: Bool,
        superseded: Bool, recoveryRequired: Bool
    ) -> Lane3InterruptionEndReceipt {
        Lane3InterruptionEndReceipt(
            episodeSerial: episode,
            lifecycleRevision: revision,
            osShouldResume: osShouldResume,
            resumeWasArmed: armedAtStart,
            preBoundaryRecovery: preRecovery,
            boundaryOutcome: boundary,
            boundarySafe: boundarySafe,
            resumeOutcome: resume,
            compensatingPauseOutcome: compensatingPause,
            resumedPlayback: resumed,
            supersededByNewerLifecycleEvent: superseded,
            recoveryRequired: recoveryRequired
        )
    }
}
