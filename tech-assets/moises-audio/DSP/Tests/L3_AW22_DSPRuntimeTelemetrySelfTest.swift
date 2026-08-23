import Foundation

private final class AW22DSPBackend: PracticeDSPTransactionalBackendApplying, @unchecked Sendable {
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

private final class AW22ClickInvalidator: PracticeDSPClickScheduleInvalidating, @unchecked Sendable {
    private let lock = NSLock()
    private var generation: UInt64 = 0

    func invalidateSchedule(to generation: UInt64) throws {
        lock.lock(); defer { lock.unlock() }
        precondition(generation >= self.generation)
        self.generation = generation
    }
}

private func aw22Kind(
    _ kind: Lane3DSPRuntimeOperationKind,
    in snapshot: Lane3DSPRuntimeTelemetrySnapshot
) -> Lane3DSPRuntimeKindSnapshot {
    guard let value = snapshot.perKind.first(where: { $0.kind == kind.rawValue }) else {
        preconditionFailure("missing telemetry kind \(kind.rawValue)")
    }
    return value
}

@main
struct L3AW22DSPRuntimeTelemetrySelfTest {
    static func main() async throws {
        let project = ProjectID()
        let collector = Lane3DSPRuntimeTelemetryCollector()
        let probe = Lane3DSPRuntimeTelemetryProbe(collector: collector)
        let measuredBackend = Lane3DSPTelemetryTransactionalBackend(
            backend: AW22DSPBackend(),
            collector: collector
        )
        let measuredInvalidator = Lane3DSPTelemetryClickInvalidator(
            invalidator: AW22ClickInvalidator(),
            collector: collector
        )
        let controller = try PracticeDSPProductionController(
            projectID: project,
            backend: measuredBackend
        )
        let coordinator = PracticeDSPGenerationCoordinator(
            projectID: project,
            controller: controller,
            clickInvalidator: measuredInvalidator
        )

        let tempoToken = PlaybackTransportRescheduleToken(generation: 1, reason: .tempoChange)
        _ = try await probe.measureAsync(kind: .tempo) {
            try await coordinator.applyTempoRatio(1.25, playbackToken: tempoToken)
        }

        _ = try await probe.measureAsync(kind: .pitch) {
            try await controller.setPitchSemitones(3, projectID: project)
        }
        do {
            _ = try await probe.measureAsync(kind: .pitch) {
                try await controller.setPitchSemitones(100, projectID: project)
            }
            preconditionFailure("out-of-range pitch should fail")
        } catch {}

        _ = try await probe.measureAsync(kind: .metronomeMutation) {
            try await coordinator.setMetronomeEnabled(true)
        }

        let firstCountIn = try await probe.measureAsync(kind: .countInArm) {
            try await coordinator.scheduleCountIn(clicks: 4)
        }
        _ = try await probe.measureAsync(kind: .countInConsume) {
            try await coordinator.consumeScheduledCountIn(
                expectedClickGeneration: firstCountIn.clickGeneration,
                expectedClicks: 4
            )
        }

        let secondCountIn = try await probe.measureAsync(kind: .countInArm) {
            try await coordinator.scheduleCountIn(clicks: 3)
        }
        _ = try await probe.measureAsync(kind: .countInDiscard) {
            try await coordinator.discardCountIn(
                expectedClickGeneration: secondCountIn.clickGeneration,
                expectedClicks: 3
            )
        }

        let recoveryToken = PlaybackTransportRescheduleToken(generation: 2, reason: .recovery)
        _ = try await probe.measureAsync(kind: .recovery) {
            try await coordinator.recover(playbackToken: recoveryToken)
        }

        let snapshot = probe.snapshot()
        let tempo = aw22Kind(.tempo, in: snapshot)
        let pitch = aw22Kind(.pitch, in: snapshot)
        let metronome = aw22Kind(.metronomeMutation, in: snapshot)
        let countInArm = aw22Kind(.countInArm, in: snapshot)
        let consume = aw22Kind(.countInConsume, in: snapshot)
        let discard = aw22Kind(.countInDiscard, in: snapshot)
        let recovery = aw22Kind(.recovery, in: snapshot)

        precondition(tempo.productSubmissions == 1 && tempo.productSucceeded == 1)
        precondition(tempo.backendPrimaryEntries == 1)
        precondition(tempo.clickInvalidationPrimaryEntries == 1)
        precondition(tempo.submissionToBackendEntryLatency.samples == 1)
        precondition(tempo.submissionToClickInvalidationLatency.samples == 1)

        precondition(pitch.productSubmissions == 2)
        precondition(pitch.productSucceeded == 1 && pitch.productFailed == 1)
        precondition(pitch.backendPrimaryEntries == 1)
        precondition(pitch.clickInvalidationCalls == 0)

        precondition(metronome.backendApplyCalls == 0)
        precondition(metronome.clickInvalidationPrimaryEntries == 1)
        precondition(countInArm.productSubmissions == 2)
        precondition(countInArm.clickInvalidationPrimaryEntries == 2)
        precondition(consume.backendApplyCalls == 0 && consume.clickInvalidationCalls == 0)
        precondition(discard.clickInvalidationPrimaryEntries == 1)
        precondition(recovery.backendPrimaryEntries == 1)
        precondition(recovery.clickInvalidationPrimaryEntries == 1)

        precondition(snapshot.unscopedBackendApplyCalls == 0)
        precondition(snapshot.unscopedClickInvalidationCalls == 0)
        precondition(snapshot.privacy.aggregationOnly)
        precondition(!snapshot.privacy.rawEventLogRetained)
        precondition(!snapshot.privacy.absoluteWallClockCaptured)
        precondition(!snapshot.privacy.projectIdentifierCaptured)
        precondition(!snapshot.privacy.mediaNameOrPathCaptured)
        precondition(!snapshot.privacy.pcmOrAudioContentCaptured)
        precondition(!snapshot.privacy.ticketOrGenerationValueExported)
        precondition(!snapshot.privacy.taskLocalTracePersisted)
        precondition(snapshot.privacy.taskLocalTraceContainsOnlyOperationKindAndMonotonicStart)

        print("L3-AW22 DSP runtime telemetry self-test PASS")
    }
}
