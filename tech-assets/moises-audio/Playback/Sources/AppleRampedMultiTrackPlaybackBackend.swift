#if canImport(AVFAudio)
import AVFAudio
import Darwin
import Foundation

public enum AppleRampedPlaybackBackendError: Error, Equatable, Sendable {
    case gainStageMissing(StemID)
}

/// AVAudioEngine backend that keeps the proven transport scheduling semantics while routing every
/// stem through a dedicated ramp-capable mixer gain stage. Playing-state gain changes are applied
/// as preflighted Audio Unit ramps; paused/setup changes are immediate because they are inaudible.
public actor AppleRampedMultiTrackPlaybackBackend: PlaybackBackendDriving {
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
    private let engine = AVAudioEngine()
    private var activeProjectID: ProjectID?
    private var mode: LoadedMode = .none
    private var gains: [StemID: Double] = [:]
    private var positionSeconds: Double = 0
    private var loop: PlaybackLoopRange?
    private var isPlaying = false
    private var anchorPositionSeconds: Double = 0
    private var anchorUptimeSeconds: TimeInterval = 0
    private var scheduleGeneration: UInt64 = 0
    private let startLeadSeconds: Double = 0.075
    private let gainRampPolicy: PlaybackGainRampPolicy

    public init(
        appOwnedRoot: URL,
        gainRampPolicy: PlaybackGainRampPolicy = PlaybackGainRampPolicy()
    ) {
        self.appOwnedRoot = appOwnedRoot.standardizedFileURL.resolvingSymlinksInPath()
        self.gainRampPolicy = gainRampPolicy
    }

    public func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {
        let file = try AVAudioFile(forReading: resolve(relativePath: asset.relativePath))
        try clearGraph()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)
        activeProjectID = projectID
        mode = .source(asset: asset, file: file, player: player)
        gains = [:]
        positionSeconds = 0
        loop = nil
        isPlaying = false
        scheduleGeneration &+= 1
    }

    public func loadStems(
        projectID: ProjectID,
        stems: [StemArtifact],
        positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws {
        // File validation and gain-stage capability validation happen before the current graph is
        // destroyed. A device whose mixer parameter is unavailable/non-rampable therefore fails
        // closed without losing the previously loaded playable graph.
        var staged: [StagedStem] = []
        staged.reserveCapacity(stems.count)
        for artifact in stems {
            guard artifact.projectID == projectID else {
                throw ApplePlaybackBackendError.projectMismatch
            }
            let file = try AVAudioFile(forReading: resolve(relativePath: artifact.relativePath))
            try validate(file: file, against: artifact)
            let player = AVAudioPlayerNode()
            let mixer = AVAudioMixerNode()
            let gainStage = try AppleTransactionalStemGainRampStage(mixerNode: mixer)
            staged.append(
                StagedStem(
                    artifact: artifact,
                    file: file,
                    player: player,
                    mixer: mixer,
                    gainStage: gainStage
                )
            )
        }

        try clearGraph()
        var loaded: [StemID: LoadedStem] = [:]
        loaded.reserveCapacity(staged.count)
        for item in staged {
            engine.attach(item.player)
            engine.attach(item.mixer)
            engine.connect(
                item.player,
                to: item.mixer,
                format: item.file.processingFormat
            )
            engine.connect(
                item.mixer,
                to: engine.mainMixerNode,
                format: item.file.processingFormat
            )
            loaded[item.artifact.id] = LoadedStem(
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
        scheduleGeneration &+= 1
        try applyStoredGainsImmediately()
        if resume { try startScheduledPlayback(projectID: projectID) }
    }

    public func setEffectiveGains(
        projectID: ProjectID,
        gains requestedGains: [StemID: Double]
    ) async throws {
        try requireProject(projectID)
        guard requestedGains.values.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
            throw ApplePlaybackBackendError.invalidGain
        }

        guard case .stems(let tracks) = mode else {
            self.gains = requestedGains
            return
        }

        let renderRates = Dictionary(uniqueKeysWithValues: tracks.map { id, track in
            (id, track.gainStage.renderSampleRate)
        })
        let plan = try PlaybackBackendGainApplicationPlanner.plan(
            loadedStemIDs: Array(tracks.keys),
            committedGains: self.gains,
            requestedGains: requestedGains,
            renderSampleRates: renderRates,
            isPlaying: isPlaying,
            policy: gainRampPolicy
        )

        switch plan.mode {
        case .immediate:
            // Validate every stem before assigning any parameter value.
            for (id, target) in plan.normalizedTargetGains {
                guard let track = tracks[id] else {
                    throw AppleRampedPlaybackBackendError.gainStageMissing(id)
                }
                try track.gainStage.validateImmediate(target)
            }
            for (id, target) in plan.normalizedTargetGains {
                guard let track = tracks[id] else {
                    throw AppleRampedPlaybackBackendError.gainStageMissing(id)
                }
                track.gainStage.setImmediateValidated(target)
            }

        case .ramped:
            // The entire multi-stem batch is preflighted before the first Audio Unit event is
            // scheduled. scheduleValidatedRamp itself cannot fail after this validation pass.
            for step in plan.execution.steps {
                guard let track = tracks[step.stemID] else {
                    throw AppleRampedPlaybackBackendError.gainStageMissing(step.stemID)
                }
                try track.gainStage.validateRamp(
                    to: step.targetGain,
                    frameCount: step.frameCount
                )
            }
            for step in plan.execution.steps {
                guard let track = tracks[step.stemID] else {
                    throw AppleRampedPlaybackBackendError.gainStageMissing(step.stemID)
                }
                track.gainStage.scheduleValidatedRamp(
                    to: step.targetGain,
                    frameCount: step.frameCount
                )
            }
        }

        self.gains = plan.normalizedTargetGains
    }

    public func seek(
        projectID: ProjectID,
        to positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws {
        try requireProject(projectID)
        stopPlayers()
        self.positionSeconds = positionSeconds
        self.loop = loop
        self.isPlaying = false
        scheduleGeneration &+= 1
        if resume { try startScheduledPlayback(projectID: projectID) }
    }

    public func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws {
        try requireProject(projectID)
        let resume = isPlaying
        if resume { positionSeconds = currentPositionValue() }
        stopPlayers()
        self.loop = loop
        if let loop, positionSeconds >= loop.endSeconds {
            positionSeconds = try PlaybackSchedulingSafety.normalizedSeekPosition(
                requestedSeconds: positionSeconds,
                durationSeconds: activeDurationSeconds(),
                loop: loop
            )
        }
        scheduleGeneration &+= 1
        isPlaying = false
        if resume { try startScheduledPlayback(projectID: projectID) }
    }

    public func play(projectID: ProjectID) async throws {
        try requireProject(projectID)
        guard !isPlaying else { return }
        try startScheduledPlayback(projectID: projectID)
    }

    public func pause(projectID: ProjectID) async {
        guard activeProjectID == projectID else { return }
        if isPlaying { positionSeconds = currentPositionValue() }
        pausePlayers()
        isPlaying = false
        scheduleGeneration &+= 1
    }

    public func currentPositionSeconds(projectID: ProjectID) async -> Double? {
        guard activeProjectID == projectID else { return nil }
        return isPlaying ? currentPositionValue() : positionSeconds
    }

    private func startScheduledPlayback(projectID: ProjectID) throws {
        try requireProject(projectID)
        switch mode {
        case .none:
            throw ApplePlaybackBackendError.noAudioLoaded

        case .source(_, let file, let player):
            try ensureEngineRunning()
            let generation = scheduleGeneration &+ 1
            scheduleGeneration = generation
            player.stop()
            let commonHost = mach_absolute_time()
                &+ AVAudioTime.hostTime(forSeconds: startLeadSeconds)
            let scheduled = try scheduleSourceCycle(
                file: file,
                player: player,
                projectPosition: positionSeconds,
                commonHostTime: commonHost,
                generation: generation,
                startPlayer: true
            )
            guard scheduled else {
                positionSeconds = activeDurationSeconds() ?? positionSeconds
                isPlaying = false
                return
            }
            beginClock(at: positionSeconds, leadSeconds: startLeadSeconds)
            isPlaying = true

        case .stems(let tracks):
            try ensureEngineRunning()
            let generation = scheduleGeneration &+ 1
            scheduleGeneration = generation
            stopPlayers()
            let commonHost = mach_absolute_time()
                &+ AVAudioTime.hostTime(forSeconds: startLeadSeconds)
            let scheduled = try scheduleStemCycle(
                tracks: tracks,
                projectPosition: positionSeconds,
                commonHostTime: commonHost,
                generation: generation,
                startPlayers: true
            )
            guard scheduled else {
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
            let remainingSeconds = max(0, loop.endSeconds - projectPosition)
            let loopFrameDouble = (
                remainingSeconds * file.processingFormat.sampleRate
            ).rounded(.down)
            guard loopFrameDouble.isFinite,
                  loopFrameDouble >= 0,
                  loopFrameDouble <= Double(Int64.max) else {
                throw ApplePlaybackBackendError.frameRangeOverflow
            }
            let loopFrames = AVAudioFramePosition(loopFrameDouble)
            frames = min(frames, loopFrames)
        }
        guard frames > 0 else { return false }

        let callbackType: AVAudioPlayerNodeCompletionCallbackType = loop == nil
            ? .dataPlayedBack
            : .dataConsumed
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
        if startPlayer {
            player.play(at: AVAudioTime(hostTime: commonHostTime))
        }
        return true
    }

    private func handleSourceCycleCompletion(
        generation: UInt64,
        previousStartHostTime: UInt64,
        previousProjectPosition: Double
    ) async {
        guard isPlaying, scheduleGeneration == generation else { return }
        guard case .source(_, let file, let player) = mode else { return }
        guard let loop else {
            positionSeconds = Double(file.length) / file.processingFormat.sampleRate
            isPlaying = false
            return
        }
        let firstDuration = max(0, loop.endSeconds - previousProjectPosition)
        let nextHost = previousStartHostTime
            &+ AVAudioTime.hostTime(forSeconds: firstDuration)
        do {
            let scheduled = try scheduleSourceCycle(
                file: file,
                player: player,
                projectPosition: loop.startSeconds,
                commonHostTime: nextHost,
                generation: generation,
                startPlayer: false
            )
            if !scheduled {
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
            $0.artifact.id.rawValue.uuidString
                < $1.artifact.id.rawValue.uuidString
        }
        var plans: [(
            track: LoadedStem,
            plan: StemSchedulePlan,
            sourceStartFrame: Int64,
            frames: Int64
        )] = []
        plans.reserveCapacity(ordered.count)

        for track in ordered {
            let plan = try PlaybackTimelinePlanner.planStem(
                track.artifact,
                projectPositionSeconds: projectPosition
            )
            let sourceStartFrame = min(plan.sourceStartFrame, track.file.length)
            let fileAvailableFrames = max(0, track.file.length - sourceStartFrame)
            var frames = min(plan.availableFrameCount, fileAvailableFrames)

            if let loop {
                let remainingSeconds = max(
                    0,
                    loop.endSeconds
                        - max(projectPosition, track.artifact.startTimeSeconds)
                )
                let loopFrameDouble = (
                    remainingSeconds * track.file.processingFormat.sampleRate
                ).rounded(.down)
                guard loopFrameDouble.isFinite,
                      loopFrameDouble >= 0,
                      loopFrameDouble <= Double(Int64.max) else {
                    throw ApplePlaybackBackendError.frameRangeOverflow
                }
                let loopFrames = Int64(loopFrameDouble)
                frames = min(frames, loopFrames)
            }

            guard frames >= 0,
                  frames <= Int64(UInt32.max) else {
                throw ApplePlaybackBackendError.frameRangeOverflow
            }
            if frames > 0 {
                plans.append((track, plan, sourceStartFrame, frames))
            }
        }

        guard !plans.isEmpty else { return false }
        let leaderID = try PlaybackSchedulingSafety.latestEndingStemID(
            windows: plans.map { entry in
                PlaybackScheduledTrackWindow(
                    stemID: entry.track.artifact.id,
                    delayedStartSeconds: entry.plan.delayedStartSeconds,
                    frameCount: entry.frames,
                    sampleRate: entry.track.file.processingFormat.sampleRate
                )
            }
        )

        for entry in plans {
            let delayHost = AVAudioTime.hostTime(
                forSeconds: entry.plan.delayedStartSeconds
            )
            let when = AVAudioTime(hostTime: commonHostTime &+ delayHost)
            let isLeader = entry.track.artifact.id == leaderID
            let callbackType: AVAudioPlayerNodeCompletionCallbackType = loop == nil
                ? .dataPlayedBack
                : .dataConsumed

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
            for track in ordered {
                track.player.play(at: AVAudioTime(hostTime: commonHostTime))
            }
        }
        return true
    }

    private func handleStemCycleCompletion(
        generation: UInt64,
        previousStartHostTime: UInt64,
        previousProjectPosition: Double
    ) async {
        guard isPlaying,
              scheduleGeneration == generation,
              activeProjectID != nil else {
            return
        }
        guard case .stems(let tracks) = mode else { return }
        guard let loop else {
            positionSeconds = activeDurationSeconds() ?? previousProjectPosition
            isPlaying = false
            return
        }

        let firstDuration = max(0, loop.endSeconds - previousProjectPosition)
        let nextHost = previousStartHostTime
            &+ AVAudioTime.hostTime(forSeconds: firstDuration)
        do {
            let scheduled = try scheduleStemCycle(
                tracks: tracks,
                projectPosition: loop.startSeconds,
                commonHostTime: nextHost,
                generation: generation,
                startPlayers: false
            )
            if !scheduled {
                stopPlayers()
                isPlaying = false
                positionSeconds = loop.startSeconds
            }
        } catch {
            stopPlayers()
            isPlaying = false
            positionSeconds = loop.startSeconds
        }
    }

    private func beginClock(at projectPosition: Double, leadSeconds: Double) {
        anchorPositionSeconds = projectPosition
        anchorUptimeSeconds = ProcessInfo.processInfo.systemUptime + leadSeconds
    }

    private func currentPositionValue() -> Double {
        let elapsed = max(
            0,
            ProcessInfo.processInfo.systemUptime - anchorUptimeSeconds
        )
        let raw = anchorPositionSeconds + elapsed
        guard let loop else {
            if let duration = activeDurationSeconds() {
                return min(raw, duration)
            }
            return raw
        }
        if raw < loop.endSeconds { return raw }
        let repeated = raw - loop.endSeconds
        return loop.startSeconds
            + repeated.truncatingRemainder(dividingBy: loop.durationSeconds)
    }

    private func activeDurationSeconds() -> Double? {
        switch mode {
        case .none:
            return nil
        case .source(_, let file, _):
            let rate = file.processingFormat.sampleRate
            guard rate.isFinite, rate > 0 else { return nil }
            return Double(file.length) / rate
        case .stems(let tracks):
            return tracks.values.map { track in
                track.artifact.startTimeSeconds
                    + Double(track.file.length)
                    / track.file.processingFormat.sampleRate
            }.max()
        }
    }

    private func applyStoredGainsImmediately() throws {
        guard case .stems(let tracks) = mode else { return }
        var normalized: [StemID: Double] = [:]
        normalized.reserveCapacity(tracks.count)
        for id in tracks.keys {
            normalized[id] = gains[id] ?? 1
        }

        for (id, target) in normalized {
            guard let track = tracks[id] else {
                throw AppleRampedPlaybackBackendError.gainStageMissing(id)
            }
            try track.gainStage.validateImmediate(target)
        }
        for (id, target) in normalized {
            guard let track = tracks[id] else {
                throw AppleRampedPlaybackBackendError.gainStageMissing(id)
            }
            track.gainStage.setImmediateValidated(target)
        }
        gains = normalized
    }

    private func ensureEngineRunning() throws {
        if !engine.isRunning {
            engine.prepare()
            do {
                try engine.start()
            } catch {
                throw ApplePlaybackBackendError.engineStartFailed
            }
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

    private func clearGraph() throws {
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
        guard activeProjectID == projectID else {
            throw ApplePlaybackBackendError.projectMismatch
        }
    }

    private func resolve(relativePath: String) throws -> URL {
        let candidate = appOwnedRoot
            .appendingPathComponent(relativePath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let rootPath = appOwnedRoot.path.hasSuffix("/")
            ? appOwnedRoot.path
            : appOwnedRoot.path + "/"
        guard candidate.path == appOwnedRoot.path
                || candidate.path.hasPrefix(rootPath) else {
            throw ApplePlaybackBackendError.appOwnedPathEscape
        }
        return candidate
    }

    private func validate(
        file: AVAudioFile,
        against artifact: StemArtifact
    ) throws {
        let format = file.processingFormat
        guard format.sampleRate.isFinite,
              format.sampleRate > 0,
              abs(format.sampleRate - artifact.sampleRate) <= 0.5,
              Int(format.channelCount) == artifact.channels,
              file.length >= 0 else {
            throw ApplePlaybackBackendError.artifactFileMismatch(artifact.id)
        }

        let frameDifference: Int64
        if file.length >= artifact.frameCount {
            frameDifference = file.length - artifact.frameCount
        } else {
            frameDifference = artifact.frameCount - file.length
        }
        guard frameDifference <= 2_048 else {
            throw ApplePlaybackBackendError.artifactFileMismatch(artifact.id)
        }
    }

    private func sourceFrame(
        positionSeconds: Double,
        file: AVAudioFile
    ) throws -> AVAudioFramePosition {
        let value = (
            positionSeconds * file.processingFormat.sampleRate
        ).rounded(.down)
        guard value.isFinite,
              value >= 0,
              value <= Double(Int64.max) else {
            throw ApplePlaybackBackendError.frameRangeOverflow
        }
        return min(AVAudioFramePosition(value), file.length)
    }

    private func frameCount(
        _ frames: AVAudioFramePosition
    ) throws -> AVAudioFrameCount {
        guard frames >= 0,
              frames <= AVAudioFramePosition(UInt32.max) else {
            throw ApplePlaybackBackendError.frameRangeOverflow
        }
        return AVAudioFrameCount(frames)
    }
}
#endif
