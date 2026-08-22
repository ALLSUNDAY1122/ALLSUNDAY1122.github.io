import Foundation

actor ProbeBackend: PlaybackBackendDriving {
    var position: Double = 0
    var gains: [StemID: Double] = [:]
    var loadedStems: [StemArtifact] = []
    var playing = false
    var loop: PlaybackLoopRange?

    func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws { position = 0 }

    func loadStems(
        projectID: ProjectID,
        stems: [StemArtifact],
        positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws {
        loadedStems = stems
        position = positionSeconds
        playing = resume
        self.loop = loop
    }

    func setEffectiveGains(projectID: ProjectID, gains: [StemID: Double]) async throws { self.gains = gains }

    func seek(
        projectID: ProjectID,
        to positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws {
        position = positionSeconds
        playing = resume
        self.loop = loop
    }

    func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws { self.loop = loop }
    func play(projectID: ProjectID) async throws { playing = true }
    func pause(projectID: ProjectID) async { playing = false }
    func currentPositionSeconds(projectID: ProjectID) async -> Double? { position }
    func setPosition(_ value: Double) { position = value }
}

@main
struct MOIPLAY001PortableSelfTest {
    static func main() async throws {
        try testPlannerOffsets()
        try testEffectiveGains()
        try testLongTimelineMath()
        try testLoopNormalizationNoAccumulation()
        try await testControllerTransitionAndMixer()
        print("MOI-PLAY-001 portable self-test: PASS")
    }

    static func makeStem(
        project: ProjectID,
        role: StemRole,
        seconds: Double,
        start: Double = 0,
        rate: Double = 48_000
    ) -> StemArtifact {
        StemArtifact(
            id: StemID(),
            projectID: project,
            role: role,
            relativePath: role.rawValue + ".wav",
            sampleRate: rate,
            channels: 2,
            frameCount: Int64((seconds * rate).rounded()),
            startTimeSeconds: start
        )
    }

    static func testPlannerOffsets() throws {
        let project = ProjectID()
        let delayed = makeStem(project: project, role: .vocals, seconds: 20, start: 2)
        let before = try PlaybackTimelinePlanner.planStem(delayed, projectPositionSeconds: 0.5)
        precondition(before.sourceStartFrame == 0)
        precondition(abs(before.delayedStartSeconds - 1.5) < 1e-12)
        let inside = try PlaybackTimelinePlanner.planStem(delayed, projectPositionSeconds: 7)
        precondition(inside.sourceStartFrame == 240_000)
        precondition(inside.delayedStartSeconds == 0)
    }

    static func testEffectiveGains() throws {
        let a = StemID(), b = StemID(), c = StemID()
        var mixes = [
            PlaybackTrackMix(stemID: a, role: .vocals, volume: 0.7),
            PlaybackTrackMix(stemID: b, role: .drums, volume: 0.5),
            PlaybackTrackMix(stemID: c, role: StemRole(rawValue: "bass"), volume: 0.9, muted: true)
        ]
        var gains = PlaybackTimelinePlanner.effectiveGains(for: mixes)
        precondition(gains[a] == 0.7 && gains[b] == 0.5 && gains[c] == 0)
        mixes[1].soloed = true
        gains = PlaybackTimelinePlanner.effectiveGains(for: mixes)
        precondition(gains[a] == 0 && gains[b] == 0.5 && gains[c] == 0)
        mixes[1].muted = true
        gains = PlaybackTimelinePlanner.effectiveGains(for: mixes)
        precondition(gains[a] == 0 && gains[b] == 0 && gains[c] == 0)
    }

    static func testLongTimelineMath() throws {
        let project = ProjectID()
        let threeHours = makeStem(project: project, role: .vocals, seconds: 3 * 60 * 60)
        for second in stride(from: 0.0, through: 10_799.0, by: 17.0) {
            let plan = try PlaybackTimelinePlanner.planStem(threeHours, projectPositionSeconds: second)
            let expected = Int64((second * 48_000).rounded(.down))
            precondition(plan.sourceStartFrame == expected)
        }
        let duration = try PlaybackTimelinePlanner.projectDuration(stems: [threeHours], sourceDurationSeconds: nil)
        precondition(abs((duration ?? 0) - 10_800) < 1e-9)
    }

    static func testLoopNormalizationNoAccumulation() throws {
        let loop = PlaybackLoopRange(startSeconds: 55, endSeconds: 65)
        for repetition in stride(from: 0, through: 100_000, by: 137) {
            let raw = 65 + Double(repetition) * 10 + 2.25
            let normalized = try PlaybackTimelinePlanner.normalizedProjectPosition(
                rawPositionSeconds: raw,
                loop: loop
            )
            precondition(abs(normalized - 57.25) < 1e-9)
        }
    }

    static func testControllerTransitionAndMixer() async throws {
        let backend = ProbeBackend()
        let controller = MultiTrackPlaybackController(backend: backend)
        let project = ProjectID()
        let source = LocalAudioAsset(
            id: AssetID(),
            relativePath: "source.m4a",
            mediaKind: .audio,
            durationSeconds: 120
        )
        try await controller.prepareSource(projectID: project, asset: source)
        try await controller.play(projectID: project)
        await backend.setPosition(31.25)

        let vocals = makeStem(project: project, role: .vocals, seconds: 120)
        let drums = makeStem(project: project, role: .drums, seconds: 120)
        try await controller.replaceWithStems(projectID: project, stems: [vocals, drums])

        var snapshot = try await controller.snapshot(projectID: project)
        precondition(abs(snapshot.positionSeconds - 31.25) < 1e-12)
        precondition(snapshot.isPlaying)

        try await controller.setVolume(0.42, stemID: vocals.id, projectID: project)
        try await controller.setSoloed(true, stemID: vocals.id, projectID: project)
        var gains = await backend.gains
        precondition(gains[vocals.id] == 0.42 && gains[drums.id] == 0)

        try await controller.setMuted(true, stemID: vocals.id, projectID: project)
        gains = await backend.gains
        precondition(gains[vocals.id] == 0 && gains[drums.id] == 0)

        try await controller.seek(to: 60.5, projectID: project)
        try await controller.setLoop(startSeconds: 55, endSeconds: 65, projectID: project)
        snapshot = try await controller.snapshot(projectID: project)
        precondition(snapshot.loop == PlaybackLoopRange(startSeconds: 55, endSeconds: 65))
        precondition(snapshot.scheduleGeneration >= 4)
    }
}
