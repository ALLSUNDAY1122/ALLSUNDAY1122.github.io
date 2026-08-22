#if canImport(AVFAudio)
import AVFAudio
import Darwin
import Foundation

public enum ApplePlaybackBackendError: Error, Equatable, Sendable {
    case appOwnedPathEscape
    case noAudioLoaded
    case projectMismatch
    case invalidGain
    case frameRangeOverflow
    case engineStartFailed
}

/// AVAudioEngine implementation for the Playback logical resource.
/// One project is active at a time, matching the app's single visible player. All stem nodes are
/// scheduled against one host-time anchor so start/seek/loop reschedules do not accumulate per-node drift.
public actor AppleMultiTrackPlaybackBackend: PlaybackBackendDriving {
    private struct LoadedStem {
        let artifact: StemArtifact
        let file: AVAudioFile
        let player: AVAudioPlayerNode
    }

    private enum LoadedMode {
        case none
        case source(
            asset: LocalAudioAsset,
            file: AVAudioFile,
            player: AVAudioPlayerNode
        )
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

    public init(appOwnedRoot: URL) {
        self.appOwnedRoot = appOwnedRoot
            .standardizedFileURL
            .resolvingSymlinksInPath()
    }

    public func loadSource(
        projectID: ProjectID,
        asset: LocalAudioAsset
    ) async throws {
        let file = try AVAudioFile(
            forReading: resolve(relativePath: asset.relativePath)
        )
        try clearGraph()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(
            player,
            to: engine.mainMixerNode,
            format: file.processingFormat
        )
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
        try clearGraph()
        var loaded: [StemID: LoadedStem] = [:]
        loaded.reserveCapacity(stems.count)

        for artifact in stems {
            guard artifact.projectID == projectID else {
                throw ApplePlaybackBackendError.projectMismatch
            }
            let file = try AVAudioFile(
                forReading: resolve(relativePath: artifact.relativePath)
            )
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(
                player,
                to: engine.mainMixerNode,
                format: file.processingFormat
            )
            loaded[artifact.id] = LoadedStem(
                artifact: artifact,
                file: file,
                player: player
            )
        }

        activeProjectID = projectID
        mode = .stems(loaded)
        self.positionSeconds = positionSeconds
        self.loop = loop
        self.isPlaying = false
        scheduleGeneration &+= 1
        applyStoredGains()

        if resume {
            try startScheduledPlayback(projectID: projectID)
        }
    }

    public func setEffectiveGains(
        projectID: ProjectID,
        gains: [StemID: Double]
    ) async throws {
        try requireProject(projectID)
        guard gains.values.allSatisfy({
            $0.isFinite && (0...1).contains($0)
        }) else {
            throw ApplePlaybackBackendError.invalidGain
        }
        self.gains = gains
        applyStoredGains()
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
        if resume {
            try startScheduledPlayback(projectID: projectID)
        }
    }

    public func setLoop(
        projectID: ProjectID,
        loop: PlaybackLoopRange?
    ) async throws {
        try requireProject(projectID)
        let resume = isPlaying
        if resume {
            positionSeconds = currentPositionValue()
        }
        stopPlayers()
        self.loop = loop
        if let loop, positionSeconds >= loop.endSeconds {
            positionSeconds = loop.startSeconds
        }
        scheduleGeneration &+= 1
        isPlaying = false
        if resume {
            try startScheduledPlayback(projectID: projectID)
        }
    }

    public func play(projectID: ProjectID) async throws {
        try requireProject(projectID)
        guard !isPlaying else { return }
        try startScheduledPlayback(projectID: projectID)
    }

    public func pause(projectID: ProjectID) async {
        guard activeProjectID == projectID else { return }
        if isPlaying {
            positionSeconds = currentPositionValue()
        }
        pausePlayers()
        isPlaying = false
        scheduleGeneration &+= 1
    }

    public func currentPositionSeconds(
        projectID: ProjectID
    ) async -> Double? {
        guard activeProjectID == projectID else { return nil }
        return isPlaying ? currentPositionValue() : positionSeconds
    }

    private func startScheduledPlayback(
        projectID: ProjectID
    ) throws {
        try requireProject(projectID)

        switch mode {
        case .none:
            throw ApplePlaybackBackendError.noAudioLoaded

        case .source(_, let file, let player):
            try ensureEngineRunning()
            let frame = try sourceFrame(
                positionSeconds: positionSeconds,
                file: file
            )
            let remaining = file.length - frame
            guard remaining > 0 else { return }
            player.stop()
            player.scheduleSegment(
                file,
                startingFrame: frame,
                frameCount: try frameCount(remaining),
                at: nil
            )
            player.play()
            beginClock(at: positionSeconds, leadSeconds: 0)

        case .stems(let tracks):
            try ensureEngineRunning()
            let generation = scheduleGeneration &+ 1
            scheduleGeneration = generation
            stopPlayers()
            let commonHost = mach_absolute_time()
                &+ AVAudioTime.hostTime(forSeconds: startLeadSeconds)
            try scheduleStemCycle(
                tracks: tracks,
                projectPosition: positionSeconds,
                commonHostTime: commonHost,
                generation: generation,
                startPlayers: true
            )
            beginClock(
                at: positionSeconds,
                leadSeconds: startLeadSeconds
            )
        }

        isPlaying = true
    }

    private func scheduleStemCycle(
        tracks: [StemID: LoadedStem],
        projectPosition: Double,
        commonHostTime: UInt64,
        generation: UInt64,
        startPlayers: Bool
    ) throws {
        let ordered = tracks.values.sorted {
            $0.artifact.id.rawValue.uuidString
                < $1.artifact.id.rawValue.uuidString
        }

        var plans: [(
            track: LoadedStem,
            plan: StemSchedulePlan,
            frames: Int64
        )] = []
        plans.reserveCapacity(ordered.count)

        for track in ordered {
            let plan = try PlaybackTimelinePlanner.planStem(
                track.artifact,
                projectPositionSeconds: projectPosition
            )
            var frames = plan.availableFrameCount

            if let loop {
                let remainingSeconds = max(
                    0,
                    loop.endSeconds
                        - max(
                            projectPosition,
                            track.artifact.startTimeSeconds
                        )
                )
                let loopFrames = Int64(
                    (remainingSeconds * track.artifact.sampleRate)
                        .rounded(.down)
                )
                frames = min(frames, max(0, loopFrames))
            }

            guard frames >= 0 else {
                throw ApplePlaybackBackendError.frameRangeOverflow
            }
            guard frames <= Int64(UInt32.max) else {
                throw ApplePlaybackBackendError.frameRangeOverflow
            }
            if frames > 0 {
                plans.append((track, plan, frames))
            }
        }

        let leaderID = plans.max(by: {
            $0.frames < $1.frames
        })?.track.artifact.id

        for entry in plans {
            let delayHost = AVAudioTime.hostTime(
                forSeconds: entry.plan.delayedStartSeconds
            )
            let when = AVAudioTime(
                hostTime: commonHostTime &+ delayHost
            )
            let isLeader = entry.track.artifact.id == leaderID

            entry.track.player.scheduleSegment(
                entry.track.file,
                startingFrame: entry.plan.sourceStartFrame,
                frameCount: AVAudioFrameCount(entry.frames),
                at: when,
                completionCallbackType: .dataConsumed
            ) { [weak self] _ in
                guard let self, isLeader else { return }
                Task {
                    await self.handleCycleConsumed(
                        generation: generation,
                        previousStartHostTime: commonHostTime,
                        previousProjectPosition: projectPosition
                    )
                }
            }
        }

        applyStoredGains()
        if startPlayers {
            for track in ordered {
                track.player.play(
                    at: AVAudioTime(hostTime: commonHostTime)
                )
            }
        }
    }

    private func handleCycleConsumed(
        generation: UInt64,
        previousStartHostTime: UInt64,
        previousProjectPosition: Double
    ) async {
        guard isPlaying,
              scheduleGeneration == generation,
              activeProjectID != nil,
              let loop else {
            return
        }
        guard case .stems(let tracks) = mode else { return }

        let firstDuration = max(
            0,
            loop.endSeconds - previousProjectPosition
        )
        let nextHost = previousStartHostTime
            &+ AVAudioTime.hostTime(forSeconds: firstDuration)

        do {
            try scheduleStemCycle(
                tracks: tracks,
                projectPosition: loop.startSeconds,
                commonHostTime: nextHost,
                generation: generation,
                startPlayers: false
            )
        } catch {
            stopPlayers()
            isPlaying = false
            positionSeconds = loop.startSeconds
        }
    }

    private func beginClock(
        at projectPosition: Double,
        leadSeconds: Double
    ) {
        anchorPositionSeconds = projectPosition
        anchorUptimeSeconds = ProcessInfo.processInfo.systemUptime
            + leadSeconds
    }

    private func currentPositionValue() -> Double {
        let elapsed = max(
            0,
            ProcessInfo.processInfo.systemUptime
                - anchorUptimeSeconds
        )
        let raw = anchorPositionSeconds + elapsed
        guard let loop else { return raw }
        if raw < loop.endSeconds { return raw }
        let repeated = raw - loop.endSeconds
        return loop.startSeconds
            + repeated.truncatingRemainder(
                dividingBy: loop.durationSeconds
            )
    }

    private func applyStoredGains() {
        guard case .stems(let tracks) = mode else { return }
        for (id, track) in tracks {
            track.player.volume = Float(gains[id] ?? 1)
        }
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
            for track in tracks.values {
                track.player.stop()
            }
        }
    }

    private func pausePlayers() {
        switch mode {
        case .none:
            break
        case .source(_, _, let player):
            player.pause()
        case .stems(let tracks):
            for track in tracks.values {
                track.player.pause()
            }
        }
    }

    private func clearGraph() throws {
        stopPlayers()
        switch mode {
        case .none:
            break
        case .source(_, _, let player):
            engine.detach(player)
        case .stems(let tracks):
            for track in tracks.values {
                engine.detach(track.player)
            }
        }
        mode = .none
        isPlaying = false
    }

    private func requireProject(
        _ projectID: ProjectID
    ) throws {
        guard activeProjectID == projectID else {
            throw ApplePlaybackBackendError.projectMismatch
        }
    }

    private func resolve(
        relativePath: String
    ) throws -> URL {
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
        return min(
            AVAudioFramePosition(value),
            file.length
        )
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
