import Foundation

private actor AW38PlaybackBackend: PlaybackBackendDriving {
    private var position = 0.0
    private var loop: PlaybackLoopRange?

    func loadSource(projectID: ProjectID, asset: LocalAudioAsset) async throws {}
    func loadStems(
        projectID: ProjectID,
        stems: [StemArtifact],
        positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws {
        position = positionSeconds
        self.loop = loop
    }
    func setEffectiveGains(projectID: ProjectID, gains: [StemID: Double]) async throws {}
    func seek(
        projectID: ProjectID,
        to positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws {
        position = positionSeconds
        self.loop = loop
    }
    func setLoop(projectID: ProjectID, loop: PlaybackLoopRange?) async throws {
        self.loop = loop
    }
    func play(projectID: ProjectID) async throws {}
    func pause(projectID: ProjectID) async {}
    func currentPositionSeconds(projectID: ProjectID) async -> Double? { position }
}

private final class AW38Clock: Lane3UptimeNanosecondClock, @unchecked Sendable {
    private let lock = NSLock()
    private var now: UInt64 = 1_000_000

    func nowUptimeNanoseconds() -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        let value = now
        now += 1_000
        return value
    }
}

private func aw38CoordinatorReceipt(playbackGeneration: UInt64) throws -> PracticeDSPGenerationCoordinatorReceipt {
    let json = """
    {
      "schemaVersion": 1,
      "evidenceScope": "L3-AW38-TEST",
      "operationSerial": 1,
      "mutationKind": "transportDiscontinuity",
      "playbackGeneration": \(playbackGeneration),
      "clickGeneration": 1,
      "reason": "seek",
      "replacementBindingActive": true,
      "parityPromotionAllowed": false
    }
    """
    return try JSONDecoder().decode(PracticeDSPGenerationCoordinatorReceipt.self, from: Data(json.utf8))
}

private func aw38ExecutionReceipt(
    ticket: UInt64,
    kind: Lane3UnifiedTransportKind,
    playbackGeneration: UInt64
) throws -> Lane3UnifiedTransportExecutionReceipt {
    Lane3UnifiedTransportExecutionReceipt(
        ticket: ticket,
        kind: kind,
        coalescedPredecessorCount: 0,
        playbackGeneration: playbackGeneration,
        coordinatorReceipt: try aw38CoordinatorReceipt(playbackGeneration: playbackGeneration),
        callerCancellationObservedAfterDispatch: false
    )
}

@main
struct L3AW38InteractiveContinuityInstrumentationSelfTest {
    static func main() async throws {
        let project = ProjectID()
        let backend = AW38PlaybackBackend()
        let playback = RescheduleFencedPlaybackBackend(
            backend: backend,
            timingClock: AW38Clock(),
            timingCapacity: 64
        )
        let adapter = Lane3SelectedInteractiveContinuityInstrumentationAdapter(
            projectID: project,
            playback: playback
        )

        let seekToken = try await playback.seekAndReturnToken(
            projectID: project,
            to: 42.25,
            resume: false,
            loop: nil
        )
        let seekTiming = await playback.rescheduleTokenTiming(
            projectID: project,
            generation: seekToken.generation
        )!
        let seekResult = await adapter.correlateExecuted(
            sampleID: 1,
            receipt: try aw38ExecutionReceipt(ticket: 10, kind: .seek, playbackGeneration: seekToken.generation),
            slotGenerationAtIntent: 7,
            slotGenerationAtCompletion: 7,
            firstIntentUptimeNanoseconds: seekTiming.issuedUptimeNanoseconds - 500,
            requestedTarget: .seek(positionSeconds: 42.25),
            audibleResultUptimeNanoseconds: seekTiming.backendCompletedUptimeNanoseconds! + 2_000,
            audibleTimestampSource: "physical-loopback-marker"
        )
        precondition(seekResult.issues.isEmpty)
        precondition(seekResult.exactTokenCorrelated)
        precondition(seekResult.backendAppliedTargetCorrelated)
        precondition(seekResult.externalAudibleMarkerPresent)
        precondition(seekResult.legacyAW35ObservationAvailable)
        precondition(seekResult.observation?.appliedTarget == .seek(positionSeconds: 42.25))
        precondition(!seekResult.parityPromotionAllowed)

        let loopToken = try await playback.setLoopAndReturnToken(projectID: project, loop: nil)
        let loopTiming = await playback.rescheduleTokenTiming(
            projectID: project,
            generation: loopToken.generation
        )!
        let loopResult = await adapter.correlateExecuted(
            sampleID: 2,
            receipt: try aw38ExecutionReceipt(ticket: 11, kind: .loop, playbackGeneration: loopToken.generation),
            slotGenerationAtIntent: 7,
            slotGenerationAtCompletion: 7,
            firstIntentUptimeNanoseconds: loopTiming.issuedUptimeNanoseconds - 500,
            requestedTarget: .loopDisabled,
            audibleResultUptimeNanoseconds: loopTiming.backendCompletedUptimeNanoseconds! + 2_000,
            audibleTimestampSource: "physical-loopback-marker"
        )
        precondition(loopResult.observation?.appliedTarget == .loopDisabled)
        precondition(loopResult.issues.contains { $0.kind == .legacyAW35CannotRepresentLoopDisabled })
        precondition(!loopResult.legacyAW35ObservationAvailable)
        precondition(loopResult.exactTokenCorrelated)
        precondition(loopResult.backendAppliedTargetCorrelated)

        let reversedAudible = await adapter.correlateExecuted(
            sampleID: 3,
            receipt: try aw38ExecutionReceipt(ticket: 12, kind: .seek, playbackGeneration: seekToken.generation),
            slotGenerationAtIntent: 7,
            slotGenerationAtCompletion: 7,
            firstIntentUptimeNanoseconds: seekTiming.issuedUptimeNanoseconds - 500,
            requestedTarget: .seek(positionSeconds: 42.25),
            audibleResultUptimeNanoseconds: seekTiming.issuedUptimeNanoseconds - 1,
            audibleTimestampSource: "invalid-test-marker"
        )
        precondition(reversedAudible.issues.contains { $0.kind == .audibleBeforeToken })

        let missingTiming = await adapter.correlateExecuted(
            sampleID: 4,
            receipt: try aw38ExecutionReceipt(ticket: 13, kind: .seek, playbackGeneration: 999_999),
            slotGenerationAtIntent: 7,
            slotGenerationAtCompletion: 7,
            firstIntentUptimeNanoseconds: 1,
            requestedTarget: .seek(positionSeconds: 1),
            audibleResultUptimeNanoseconds: nil,
            audibleTimestampSource: nil
        )
        precondition(missingTiming.observation == nil)
        precondition(missingTiming.issues == [
            Lane3InteractiveContinuityInstrumentationIssue(
                kind: .missingTokenTiming,
                detail: "generation 999999 is not retained in the bounded timing ledger"
            )
        ])

        print("L3-AW38 interactive continuity instrumentation self-test PASS")
    }
}
