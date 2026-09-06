#if canImport(AVFAudio)
import AVFAudio
import Darwin
import Foundation

public enum AppleTempoAwarePlaybackBackendError: Error, Equatable, Sendable {
    case gainStageMissing(StemID)
    case tempoBoundaryPoisoned
}

/// Selected Apple Playback backend for AW31. One persistent transport mixer and the exact
/// `AVAudioUnitTimePitch` configured by DSP share one AVAudioEngine graph:
/// player(s) -> per-stem gain -> transport mixer -> shared time/pitch -> main mixer.
/// Transport/loop clocks are expressed in project/source seconds and converted to host seconds by
/// the current tempo ratio, so tempo changes do not silently turn the Playback clock back into 1x.
public actor AppleTempoAwareRampedMultiTrackPlaybackBackend: PlaybackBackendDriving, PlaybackTempoBoundaryRescheduling {
    private struct LoadedStem {
        let artifact: StemArtifact
        let file: AVAudioFile
        let player: AVAudioPlayerNode
        let gainStage: AppleTransactionalStemGainRampStage
    }

    private struct StagedStem {
        let artifact: StemArtifact
        let file: AVAudioFile
        let player: AVAudioPlayerNode
        let mixer: AVAudioMixerNode
        let gainStage: AppleTransactionalStemGainRampStage
    }

    private enum LoadedMode {
        case none
        case source(asset: LocalAudioAsset, file: AVAudioFile, player: AVAudioPlayerNode)
        case stems([StemID: LoadedStem])
    }

    private let appOwnedRoot: URL
    private let engine: AVAudioEngine
    private let sharedTimePitchNode: AVAudioUnitTimePitch
    private let transportMixer: AVAudioMixerNode
    private var activeProjectID: ProjectID?
    private var mode: LoadedMode = .none
    private var gains: [StemID: Double] = [:]
    private var positionSeconds: Double = 0
    private var loop: PlaybackLoopRange?
    private var isPlaying = false
    private var anchorPositionSeconds: Double = 0
    private var anchorUptimeSeconds: TimeInterval = 0
    private var scheduleGeneration: UInt64 = 0
    private var tempoBoundarySerial: UInt64 = 0
    private var tempoRatio: Double = 1
    private var pendingTempoBoundary: PlaybackTempoBoundaryReceipt?
    private var tempoBoundaryPoisoned = false
    private let startLeadSeconds: Double
    private let gainRampPolicy: PlaybackGainRampPolicy
    private let tempoRatioRange: ClosedRange<Double>

    public init(
        appOwnedRoot: URL,
        engine: AVAudioEngine,
        sharedTimePitchNode: AVAudioUnitTimePitch,
        gainRampPolicy: PlaybackGainRampPolicy = PlaybackGainRampPolicy(),
        tempoRatioRange: ClosedRange<Double> = PracticeDSPCapabilities.appleTimePitchBaseline.tempoRatioRange,
        initialTempoRatio: Double = 1,
        startLeadSeconds: Double = 0.075
    ) throws {
        guard initialTempoRatio.isFinite, tempoRatioRange.contains(initialTempoRatio) else {
            throw PlaybackTempoBoundaryError.invalidTempoRatio(initialTempoRatio)
        }
        guard startLeadSeconds.isFinite, startLeadSeconds >= 0 else {
            throw PlaybackTempoBoundaryError.invalidClockInput
        }
        self.appOwnedRoot = appOwnedRoot.standardizedFileURL.resolvingSymlinksInPath()
        self.engine = engine
        self.sharedTimePitchNode = sharedTimePitchNode
        self.transportMixer = AVAudioMixerNode()
        self.gainRampPolicy = gainRampPolicy
        self.tempoRatioRange = tempoRatioRange
        self.tempoRatio = initialTempoRatio
        self.startLeadSeconds = startLeadSeconds

        engine.attach(transportMixer)
        engine.attach(sharedTimePitchNode)
        engine.connect(transportMixer, to: sharedTimePitchNode, format: nil)
        engine.connect(sharedTimePitchNode, to: engine.mainMixerNode, format: nil)
    }

    public func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {
        try requireBoundaryIdle()
        let file = try AVAudioFile(forReading: resolve(relativePath: asset.relativePath))
        clearDynamicGraph()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: transportMixer, format: file.processingFormat)
        activeProjectID = projectID
        mode = .source(asset: asset, file: file, player: player)
        gains = [:]
        positionSeconds = 0
        loop = nil
        isPlaying = false
        try advanceScheduleGeneration()
    }

    public func loadStems(
        projectID: ProjectID,
        stems: [StemArtifact],
        positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws {
        try requireBoundaryIdle()
        var staged: [StagedStem] = []
        staged.reserveCapacity(stems.count)
        for artifact in stems {
            guard artifact.projectID == projectID else { throw ApplePlaybackBackendError.projectMismatch }
            let file = try AVAudioFile(forReading: resolve(relativePath: artifact.relativePath))
            try validate(file: file, against: artifact)
            let player = AVAudioPlayerNode()
            let mixer = AVAudioMixerNode()
            let stage = try AppleTransactionalStemGainRampStage(mixerNode: mixer)
            staged.append(.init(artifact: artifact, file: file, player: player, mixer: mixer, gainStage: stage))
        }

        clearDynamicGraph()
        var loaded: [StemID: LoadedStem] = [:]
        loaded.reserveCapacity(staged.count)
        for item in staged {
            engine.attach(item.player)
            engine.attach(item.mixer)
            engine.connect(item.player, to: item.mixer, format: item.file.processingFormat)
            engine.connect(item.mixer, to: transportMixer, format: item.file.processingFormat)
            loaded[item.artifact.id] = .init(
                artifact: item.artifact,
                file: item.file,
                player: item.player,
                gainStage: item.gainStage
            )
        }
        activeProjectID = projectID
        mode = .stems(loaded)
        self.positionSeconds = positionSeconds
        self.loop = loop
        self.isPlaying = false
        try advanceScheduleGeneration()
        try applyStoredGainsImmediately()
        if resume { try startScheduledPlayback(projectID: projectID) }
    }

    public func setEffectiveGains(projectID: ProjectID, gains requested: [StemID: Double]) async throws {
        try requireProject(projectID)
        try requireBoundaryIdle()
        guard requested.values.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
            throw ApplePlaybackBackendError.invalidGain
        }
        guard case .stems(let tracks) = mode else {
            gains = requested
            return
        }
        let renderRates = Dictionary(uniqueKeysWithValues: tracks.map { ($0.key, $0.value.gainStage.renderSampleRate) })
        let plan = try PlaybackBackendGainApplicationPlanner.plan(
            loadedStemIDs: Array(tracks.keys),
            committedGains: gains,
            requestedGains: requested,
            renderSampleRates: renderRates,
            isPlaying: isPlaying,
            policy: gainRampPolicy
        )
        switch plan.mode {
        case .immediate:
            for (id, target) in plan.normalizedTargetGains {
                guard let track = tracks[id] else { throw AppleTempoAwarePlaybackBackendError.gainStageMissing(id) }
                try track.gainStage.validateImmediate(target)
            }
            for (id, target) in plan.normalizedTargetGains {
                tracks[id]!.gainStage.setImmediateValidated(target)
            }
        case .ramped:
            for step in plan.execution.steps {
                guard let track = tracks[step.stemID] else { throw AppleTempoAwarePlaybackBackendError.gainStageMissing(step.stemID) }
                try track.gainStage.validateRamp(to: step.targetGain, frameCount: step.frameCount)
            }
            for step in plan.execution.steps {
                tracks[step.stemID]!.gainStage.scheduleValidatedRamp(to: step.targetGain, frameCount: step.frameCount)
            }
        }
        gains = plan.normalizedTargetGains
    }

    public func seek(
        projectID: ProjectID,
        to positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws {
        try requireProject(projectID)
        try requireBoundaryIdle()
        stopPlayers()
        self.positionSeconds = positionSeconds
        self.loop = loop
        isPlaying = false
        try advanceScheduleGeneration()
        if resume { try startScheduledPlayback(projectID: projectID) }
    }

    public func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws {
        try requireProject(projectID)
        try requireBoundaryIdle()
        let resume = isPlaying
        if resume { positionSeconds = try currentPositionValue() }
        try advanceScheduleGeneration()
        stopPlayers()
        self.loop = loop
        if let loop, positionSeconds >= loop.endSeconds {
            positionSeconds = try PlaybackSchedulingSafety.normalizedSeekPosition(
                requestedSeconds: positionSeconds,
                durationSeconds: activeDurationSeconds(),
                loop: loop
            )
        }
        isPlaying = false
        if resume { try startScheduledPlayback(projectID: projectID) }
    }

    public func play(projectID: ProjectID) async throws {
        try requireProject(projectID)
        try requireBoundaryIdle()
        guard !isPlaying else { return }
        try startScheduledPlayback(projectID: projectID)
    }

    public func pause(projectID: ProjectID) async {
        guard activeProjectID == projectID, pendingTempoBoundary == nil else { return }
        if isPlaying, let current = try? currentPositionValue() { positionSeconds = current }
        pausePlayers()
        isPlaying = false
        try? advanceScheduleGeneration()
    }

    public func currentPositionSeconds(projectID: ProjectID) async -> Double? {
        guard activeProjectID == projectID else { return nil }
        if isPlaying { return try? currentPositionValue() }
        return positionSeconds
    }

    public func prepareTempoBoundary(
        projectID: ProjectID,
        toTempoRatio: Double
    ) async throws -> PlaybackTempoBoundaryReceipt {
        try requireProject(projectID)
        guard !tempoBoundaryPoisoned else { throw AppleTempoAwarePlaybackBackendError.tempoBoundaryPoisoned }
        guard pendingTempoBoundary == nil else { throw PlaybackTempoBoundaryError.transactionAlreadyInFlight }
        guard toTempoRatio.isFinite, tempoRatioRange.contains(toTempoRatio) else {
            throw PlaybackTempoBoundaryError.invalidTempoRatio(toTempoRatio)
        }
        let resume = isPlaying
        if resume { positionSeconds = try currentPositionValue() }
        let serial = try nextTempoBoundarySerial()
        try advanceScheduleGeneration()
        stopPlayers()
        isPlaying = false
        let receipt = PlaybackTempoBoundaryReceipt(
            serial: serial,
            fromTempoRatio: tempoRatio,
            toTempoRatio: toTempoRatio,
            capturedProjectPositionSeconds: positionSeconds,
            loop: loop,
            resumeWasPlaying: resume,
            backendScheduleGeneration: scheduleGeneration
        )
        tempoRatio = toTempoRatio
        pendingTempoBoundary = receipt
        return receipt
    }

    public func commitTempoBoundary(
        projectID: ProjectID,
        receipt: PlaybackTempoBoundaryReceipt
    ) async throws {
        try requireProject(projectID)
        try validatePending(receipt)
        guard !tempoBoundaryPoisoned else { throw AppleTempoAwarePlaybackBackendError.tempoBoundaryPoisoned }
        if receipt.resumeWasPlaying {
            do {
                try startScheduledPlayback(projectID: projectID)
            } catch {
                tempoBoundaryPoisoned = true
                throw error
            }
        }
        pendingTempoBoundary = nil
    }

    public func cancelTempoBoundary(
        projectID: ProjectID,
        receipt: PlaybackTempoBoundaryReceipt
    ) async throws {
        try requireProject(projectID)
        try validatePending(receipt)
        tempoRatio = receipt.fromTempoRatio
        positionSeconds = receipt.capturedProjectPositionSeconds
        loop = receipt.loop
        if receipt.resumeWasPlaying {
            do {
                try startScheduledPlayback(projectID: projectID)
            } catch {
                tempoBoundaryPoisoned = true
                throw error
            }
        }
        pendingTempoBoundary = nil
    }

    private func validatePending(_ receipt: PlaybackTempoBoundaryReceipt) throws {
        guard let pendingTempoBoundary else { throw PlaybackTempoBoundaryError.noTransactionInFlight }
        guard pendingTempoBoundary.serial == receipt.serial else {
            throw PlaybackTempoBoundaryError.staleTransaction(
                expectedSerial: pendingTempoBoundary.serial,
                actualSerial: receipt.serial
            )
        }
        guard pendingTempoBoundary == receipt else {
            throw PlaybackTempoBoundaryError.staleTransaction(
                expectedSerial: pendingTempoBoundary.serial,
                actualSerial: receipt.serial
            )
        }
    }

    private func requireBoundaryIdle() throws {
        guard !tempoBoundaryPoisoned else { throw AppleTempoAwarePlaybackBackendError.tempoBoundaryPoisoned }
        guard pendingTempoBoundary == nil else { throw PlaybackTempoBoundaryError.transactionAlreadyInFlight }
    }

    private func nextTempoBoundarySerial() throws -> UInt64 {
        let next = tempoBoundarySerial.addingReportingOverflow(1)
        guard !next.overflow else {
            tempoBoundaryPoisoned = true
            throw PlaybackTempoBoundaryError.transactionSerialOverflow
        }
        tempoBoundarySerial = next.partialValue
        return tempoBoundarySerial
    }

    private func advanceScheduleGeneration() throws {
        let next = scheduleGeneration.addingReportingOverflow(1)
        guard !next.overflow else {
            tempoBoundaryPoisoned = true
            throw PlaybackTempoBoundaryError.scheduleGenerationOverflow
        }
        scheduleGeneration = next.partialValue
    }

    private func startScheduledPlayback(projectID: ProjectID) throws {
        try requireProject(projectID)
        switch mode {
        case .none:
            throw ApplePlaybackBackendError.noAudioLoaded
        case .source(_, let file, let player):
            try ensureEngineRunning()
            try advanceScheduleGeneration()
            let generation = scheduleGeneration
            player.stop()
            let commonHost = mach_absolute_time() &+ AVAudioTime.hostTime(forSeconds: startLeadSeconds)
            guard try scheduleSourceCycle(
                file: file,
                player: player,
                projectPosition: positionSeconds,
                commonHostTime: commonHost,
                generation: generation,
                startPlayer: true
            ) else {
                positionSeconds = activeDurationSeconds() ?? positionSeconds
                isPlaying = false
                return
            }
            beginClock(at: positionSeconds, leadSeconds: startLeadSeconds)
            isPlaying = true
        case .stems(let tracks):
            try ensureEngineRunning()
            try advanceScheduleGeneration()
            let generation = scheduleGeneration
            stopPlayers()
            let commonHost = mach_absolute_time() &+ AVAudioTime.hostTime(forSeconds: startLeadSeconds)
            guard try scheduleStemCycle(
                tracks: tracks,
                projectPosition: positionSeconds,
                commonHostTime: commonHost,
                generation: generation,
                startPlayers: true
            ) else {
                positionSeconds = activeDurationSeconds() ?? positionSeconds
                isPlaying = false
                return
            }
            beginClock(at: positionSeconds, leadSeconds: startLeadSeconds)
            isPlaying = true
        }
    }

    @discardableResult
    private func scheduleSourceCycle(
        file: AVAudioFile,
        player: AVAudioPlayerNode,
        projectPosition: Double,
        commonHostTime: UInt64,
        generation: UInt64,
        startPlayer: Bool
    ) throws -> Bool {
        let startFrame = try sourceFrame(positionSeconds: projectPosition, file: file)
        var frames = file.length - startFrame
        if let loop {
            let remaining = max(0, loop.endSeconds - projectPosition)
            let loopFramesDouble = (remaining * file.processingFormat.sampleRate).rounded(.down)
            guard loopFramesDouble.isFinite, loopFramesDouble >= 0, loopFramesDouble <= Double(Int64.max) else {
                throw ApplePlaybackBackendError.frameRangeOverflow
            }
            frames = min(frames, AVAudioFramePosition(loopFramesDouble))
        }
        guard frames > 0 else { return false }
        let callbackType: AVAudioPlayerNodeCompletionCallbackType = loop == nil ? .dataPlayedBack : .dataConsumed
        player.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: try frameCount(frames),
            at: AVAudioTime(hostTime: commonHostTime),
            completionCallbackType: callbackType
        ) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.handleSourceCycleCompletion(
                    generation: generation,
                    previousStartHostTime: commonHostTime,
                    previousProjectPosition: projectPosition
                )
            }
        }
        if startPlayer { player.play(at: AVAudioTime(hostTime: commonHostTime)) }
        return true
    }

    private func handleSourceCycleCompletion(
        generation: UInt64,
        previousStartHostTime: UInt64,
        previousProjectPosition: Double
    ) async {
        guard isPlaying, scheduleGeneration == generation,
              case .source(_, let file, let player) = mode else { return }
        guard let loop else {
            positionSeconds = Double(file.length) / file.processingFormat.sampleRate
            isPlaying = false
            return
        }
        do {
            let projectDuration = max(0, loop.endSeconds - previousProjectPosition)
            let hostDuration = try PlaybackTempoClockMath.hostDuration(
                forProjectDuration: projectDuration,
                tempoRatio: tempoRatio
            )
            let nextHost = previousStartHostTime &+ AVAudioTime.hostTime(forSeconds: hostDuration)
            if try !scheduleSourceCycle(
                file: file,
                player: player,
                projectPosition: loop.startSeconds,
                commonHostTime: nextHost,
                generation: generation,
                startPlayer: false
            ) {
                player.stop()
                positionSeconds = loop.startSeconds
                isPlaying = false
            }
        } catch {
            player.stop()
            positionSeconds = loop.startSeconds
            isPlaying = false
        }
    }

    @discardableResult
    private func scheduleStemCycle(
        tracks: [StemID: LoadedStem],
        projectPosition: Double,
        commonHostTime: UInt64,
        generation: UInt64,
        startPlayers: Bool
    ) throws -> Bool {
        let ordered = tracks.values.sorted {
            $0.artifact.id.rawValue.uuidString < $1.artifact.id.rawValue.uuidString
        }
        var plans: [(track: LoadedStem, plan: StemSchedulePlan, sourceStartFrame: Int64, frames: Int64)] = []
        for track in ordered {
            let plan = try PlaybackTimelinePlanner.planStem(
                track.artifact,
                projectPositionSeconds: projectPosition
            )
            let sourceStart = min(plan.sourceStartFrame, track.file.length)
            var frames = min(plan.availableFrameCount, max(0, track.file.length - sourceStart))
            if let loop {
                let remaining = max(0, loop.endSeconds - max(projectPosition, track.artifact.startTimeSeconds))
                let loopFramesDouble = (remaining * track.file.processingFormat.sampleRate).rounded(.down)
                guard loopFramesDouble.isFinite, loopFramesDouble >= 0, loopFramesDouble <= Double(Int64.max) else {
                    throw ApplePlaybackBackendError.frameRangeOverflow
                }
                frames = min(frames, Int64(loopFramesDouble))
            }
            guard frames >= 0, frames <= Int64(UInt32.max) else {
                throw ApplePlaybackBackendError.frameRangeOverflow
            }
            if frames > 0 { plans.append((track, plan, sourceStart, frames)) }
        }
        guard !plans.isEmpty else { return false }
        let leaderID = try PlaybackSchedulingSafety.latestEndingStemID(windows: plans.map {
            PlaybackScheduledTrackWindow(
                stemID: $0.track.artifact.id,
                delayedStartSeconds: $0.plan.delayedStartSeconds,
                frameCount: $0.frames,
                sampleRate: $0.track.file.processingFormat.sampleRate
            )
        })
        for entry in plans {
            let hostDelay = try PlaybackTempoClockMath.hostDuration(
                forProjectDuration: entry.plan.delayedStartSeconds,
                tempoRatio: tempoRatio
            )
            let when = AVAudioTime(
                hostTime: commonHostTime &+ AVAudioTime.hostTime(forSeconds: hostDelay)
            )
            let isLeader = entry.track.artifact.id == leaderID
            let callbackType: AVAudioPlayerNodeCompletionCallbackType = loop == nil ? .dataPlayedBack : .dataConsumed
            entry.track.player.scheduleSegment(
                entry.track.file,
                startingFrame: entry.sourceStartFrame,
                frameCount: AVAudioFrameCount(entry.frames),
                at: when,
                completionCallbackType: callbackType
            ) { [weak self] _ in
                guard let self, isLeader else { return }
                Task {
                    await self.handleStemCycleCompletion(
                        generation: generation,
                        previousStartHostTime: commonHostTime,
                        previousProjectPosition: projectPosition
                    )
                }
            }
        }
        if startPlayers {
            for track in ordered { track.player.play(at: AVAudioTime(hostTime: commonHostTime)) }
        }
        return true
    }

    private func handleStemCycleCompletion(
        generation: UInt64,
        previousStartHostTime: UInt64,
        previousProjectPosition: Double
    ) async {
        guard isPlaying, scheduleGeneration == generation, case .stems(let tracks) = mode else { return }
        guard let loop else {
            positionSeconds = activeDurationSeconds() ?? previousProjectPosition
            isPlaying = false
            return
        }
        do {
            let projectDuration = max(0, loop.endSeconds - previousProjectPosition)
            let hostDuration = try PlaybackTempoClockMath.hostDuration(
                forProjectDuration: projectDuration,
                tempoRatio: tempoRatio
            )
            let nextHost = previousStartHostTime &+ AVAudioTime.hostTime(forSeconds: hostDuration)
            if try !scheduleStemCycle(
                tracks: tracks,
                projectPosition: loop.startSeconds,
                commonHostTime: nextHost,
                generation: generation,
                startPlayers: false
            ) {
                stopPlayers()
                positionSeconds = loop.startSeconds
                isPlaying = false
            }
        } catch {
            stopPlayers()
            positionSeconds = loop.startSeconds
            isPlaying = false
        }
    }

    private func beginClock(at projectPosition: Double, leadSeconds: Double) {
        anchorPositionSeconds = projectPosition
        anchorUptimeSeconds = ProcessInfo.processInfo.systemUptime + leadSeconds
    }

    private func currentPositionValue() throws -> Double {
        let elapsed = max(0, ProcessInfo.processInfo.systemUptime - anchorUptimeSeconds)
        return try PlaybackTempoClockMath.projectPosition(
            anchorProjectSeconds: anchorPositionSeconds,
            elapsedHostSeconds: elapsed,
            tempoRatio: tempoRatio,
            durationSeconds: activeDurationSeconds(),
            loop: loop
        )
    }

    private func activeDurationSeconds() -> Double? {
        switch mode {
        case .none:
            return nil
        case .source(_, let file, _):
            let rate = file.processingFormat.sampleRate
            return rate.isFinite && rate > 0 ? Double(file.length) / rate : nil
        case .stems(let tracks):
            return tracks.values.map {
                $0.artifact.startTimeSeconds
                    + Double($0.file.length) / $0.file.processingFormat.sampleRate
            }.max()
        }
    }

    private func applyStoredGainsImmediately() throws {
        guard case .stems(let tracks) = mode else { return }
        var normalized: [StemID: Double] = [:]
        for id in tracks.keys { normalized[id] = gains[id] ?? 1 }
        for (id, target) in normalized {
            guard let track = tracks[id] else { throw AppleTempoAwarePlaybackBackendError.gainStageMissing(id) }
            try track.gainStage.validateImmediate(target)
        }
        for (id, target) in normalized { tracks[id]!.gainStage.setImmediateValidated(target) }
        gains = normalized
    }

    private func ensureEngineRunning() throws {
        if !engine.isRunning {
            engine.prepare()
            do { try engine.start() } catch { throw ApplePlaybackBackendError.engineStartFailed }
        }
    }

    private func stopPlayers() {
        switch mode {
        case .none:
            break
        case .source(_, _, let player):
            player.stop()
        case .stems(let tracks):
            for track in tracks.values { track.player.stop() }
        }
    }

    private func pausePlayers() {
        switch mode {
        case .none:
            break
        case .source(_, _, let player):
            player.pause()
        case .stems(let tracks):
            for track in tracks.values { track.player.pause() }
        }
    }

    private func clearDynamicGraph() {
        stopPlayers()
        engine.stop()
        switch mode {
        case .none:
            break
        case .source(_, _, let player):
            engine.detach(player)
        case .stems(let tracks):
            for track in tracks.values {
                engine.detach(track.player)
                engine.detach(track.gainStage.mixerNode)
            }
        }
        mode = .none
        isPlaying = false
    }

    private func requireProject(_ projectID: ProjectID) throws {
        guard activeProjectID == projectID else { throw ApplePlaybackBackendError.projectMismatch }
    }

    private func resolve(relativePath: String) throws -> URL {
        let candidate = appOwnedRoot
            .appendingPathComponent(relativePath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let rootPath = appOwnedRoot.path.hasSuffix("/") ? appOwnedRoot.path : appOwnedRoot.path + "/"
        guard candidate.path == appOwnedRoot.path || candidate.path.hasPrefix(rootPath) else {
            throw ApplePlaybackBackendError.appOwnedPathEscape
        }
        return candidate
    }

    private func validate(file: AVAudioFile, against artifact: StemArtifact) throws {
        let format = file.processingFormat
        guard format.sampleRate.isFinite,
              format.sampleRate > 0,
              abs(format.sampleRate - artifact.sampleRate) <= 0.5,
              Int(format.channelCount) == artifact.channels,
              file.length >= 0 else {
            throw ApplePlaybackBackendError.artifactFileMismatch(artifact.id)
        }
        let difference = abs(file.length - artifact.frameCount)
        guard difference <= 2_048 else {
            throw ApplePlaybackBackendError.artifactFileMismatch(artifact.id)
        }
    }

    private func sourceFrame(positionSeconds: Double, file: AVAudioFile) throws -> AVAudioFramePosition {
        let value = (positionSeconds * file.processingFormat.sampleRate).rounded(.down)
        guard value.isFinite, value >= 0, value <= Double(Int64.max) else {
            throw ApplePlaybackBackendError.frameRangeOverflow
        }
        return min(AVAudioFramePosition(value), file.length)
    }

    private func frameCount(_ frames: AVAudioFramePosition) throws -> AVAudioFrameCount {
        guard frames >= 0, frames <= AVAudioFramePosition(UInt32.max) else {
            throw ApplePlaybackBackendError.frameRangeOverflow
        }
        return AVAudioFrameCount(frames)
    }
}
#endif
