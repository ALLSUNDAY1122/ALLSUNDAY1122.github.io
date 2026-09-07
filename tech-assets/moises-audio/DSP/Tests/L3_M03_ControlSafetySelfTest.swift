import Foundation

private enum ProbeError: Error { case rejected }

private final class RecordingBackend: PracticeDSPBackendApplying, @unchecked Sendable {
    var reject = false
    var calls: [(Double, Double)] = []
    func apply(tempoRatio: Double, pitchSemitones: Double) throws {
        if reject { throw ProbeError.rejected }
        calls.append((tempoRatio, pitchSemitones))
    }
}

@main
struct L3M03ControlSafetySelfTest {
    static func main() async throws {
        try testGainPrecedenceAndRamp()
        try testGainValidation()
        try await testPracticeValidationAndAtomicRestore()
        try await testBackendUnavailableAndFailureSafety()
        try testClickSchedulingEdges()
        print("L3-M03 control safety self-test: PASS")
    }

    static func testGainPrecedenceAndRamp() throws {
        let a = StemID(); let b = StemID(); let c = StemID()
        let role = StemRole(rawValue: "test")
        let previous = [
            PlaybackTrackMix(stemID: a, role: role, volume: 0.8),
            PlaybackTrackMix(stemID: b, role: role, volume: 0.6),
            PlaybackTrackMix(stemID: c, role: role, volume: 0.4)
        ]
        let next = [
            PlaybackTrackMix(stemID: a, role: role, volume: 0.8, muted: false, soloed: true),
            PlaybackTrackMix(stemID: b, role: role, volume: 0.6, muted: true, soloed: true),
            PlaybackTrackMix(stemID: c, role: role, volume: 0.4, muted: false, soloed: false)
        ]
        let plan = try PlaybackControlSafety.planGainTransition(from: previous, to: next, sampleRate: 48_000)
        precondition(plan.targetEffectiveGains[a] == 0.8)
        precondition(plan.targetEffectiveGains[b] == 0.0, "mute must win even when soloed")
        precondition(plan.targetEffectiveGains[c] == 0.0, "active solo must suppress non-solo")
        precondition(plan.segments.allSatisfy { $0.frameCount == 576 })
        for segment in plan.segments {
            precondition(segment.gain(atFrame: 0) == segment.startGain)
            precondition(segment.gain(atFrame: segment.frameCount) == segment.endGain)
            let midpoint = segment.gain(atFrame: segment.frameCount / 2)
            precondition(midpoint >= min(segment.startGain, segment.endGain))
            precondition(midpoint <= max(segment.startGain, segment.endGain))
        }

        for bits in 0..<16 {
            let am = bits & 1 != 0
            let asolo = bits & 2 != 0
            let bm = bits & 4 != 0
            let bsolo = bits & 8 != 0
            let mixes = [
                PlaybackTrackMix(stemID: a, role: role, volume: 0.75, muted: am, soloed: asolo),
                PlaybackTrackMix(stemID: b, role: role, volume: 0.50, muted: bm, soloed: bsolo)
            ]
            let gains = PlaybackTimelinePlanner.effectiveGains(for: mixes)
            let soloActive = asolo || bsolo
            let expectedA = (!am && (!soloActive || asolo)) ? 0.75 : 0
            let expectedB = (!bm && (!soloActive || bsolo)) ? 0.50 : 0
            precondition(gains[a] == expectedA)
            precondition(gains[b] == expectedB)
        }
    }

    static func testGainValidation() throws {
        let id = StemID(); let role = StemRole(rawValue: "test")
        do {
            _ = try PlaybackControlSafety.planGainTransition(
                from: [PlaybackTrackMix(stemID: id, role: role)],
                to: [PlaybackTrackMix(stemID: id, role: role, volume: .nan)],
                sampleRate: 48_000
            )
            preconditionFailure("NaN gain must fail")
        } catch PlaybackGainRampError.invalidGain { }

        do {
            let duplicate = PlaybackTrackMix(stemID: id, role: role)
            _ = try PlaybackControlSafety.planGainTransition(from: [], to: [duplicate, duplicate], sampleRate: 48_000)
            preconditionFailure("duplicate stem must fail")
        } catch PlaybackGainRampError.duplicateStemID { }

        do {
            _ = try PlaybackControlSafety.planGainTransition(from: [], to: [], sampleRate: 0)
            preconditionFailure("zero sample rate must fail")
        } catch PlaybackGainRampError.invalidSampleRate { }
    }

    static func testPracticeValidationAndAtomicRestore() async throws {
        let controller = PracticeDSPController()
        let project = ProjectID()
        try await controller.setTempoRatio(0.03125, projectID: project)
        try await controller.setPitchSemitones(24, projectID: project)
        try await controller.setMetronomeEnabled(true, projectID: project)
        try await controller.scheduleCountIn(clicks: 32, projectID: project)
        let baseline = await controller.snapshot(projectID: project)
        precondition(baseline.scheduleGeneration == 3)

        do {
            try await controller.setTempoRatio(.infinity, projectID: project)
            preconditionFailure("nonfinite tempo must fail")
        } catch PracticeDSPConfigurationError.nonFiniteTempoRatio { }
        let afterRejectedTempo = await controller.snapshot(projectID: project)
        precondition(afterRejectedTempo == baseline)

        let restoredCandidate = PracticeDSPState(
            tempoRatio: 1.5,
            pitchSemitones: -7,
            metronomeEnabled: false,
            pendingCountInClicks: 4,
            scheduleGeneration: 41
        )
        try await controller.restoreState(restoredCandidate, projectID: project)
        let restored = await controller.snapshot(projectID: project)
        precondition(restored.tempoRatio == 1.5)
        precondition(restored.pitchSemitones == -7)
        precondition(restored.pendingCountInClicks == 4)
        precondition(restored.scheduleGeneration == 42)

        let beforeInvalidRestore = restored
        do {
            try await controller.restoreState(
                PracticeDSPState(tempoRatio: 1, pitchSemitones: 99, scheduleGeneration: 50),
                projectID: project
            )
            preconditionFailure("invalid restored pitch must fail")
        } catch PracticeDSPConfigurationError.pitchOutOfBackendRange { }
        let afterInvalidRestore = await controller.snapshot(projectID: project)
        precondition(afterInvalidRestore == beforeInvalidRestore)

        do {
            try await controller.restoreState(
                PracticeDSPState(scheduleGeneration: UInt64.max),
                projectID: project
            )
            preconditionFailure("generation wrap must fail")
        } catch PracticeDSPConfigurationError.scheduleGenerationOverflow { }
        let afterOverflowRestore = await controller.snapshot(projectID: project)
        precondition(afterOverflowRestore == beforeInvalidRestore)
    }

    static func testBackendUnavailableAndFailureSafety() async throws {
        let initial = PracticeDSPState(tempoRatio: 1, pitchSemitones: 0)
        let unavailable = try PracticeDSPApplicationGate(backend: nil, initialState: initial)
        let candidate = PracticeDSPState(tempoRatio: 1.25, pitchSemitones: 2)
        do {
            _ = try await unavailable.apply(candidate)
            preconditionFailure("missing backend must fail closed")
        } catch PracticeDSPApplicationError.backendUnavailable { }
        let unavailableState = await unavailable.lastAppliedState()
        precondition(unavailableState == initial)

        let backend = RecordingBackend()
        let gate = try PracticeDSPApplicationGate(backend: backend, initialState: initial)
        _ = try await gate.apply(candidate)
        let appliedCandidate = await gate.lastAppliedState()
        precondition(appliedCandidate == candidate)
        precondition(backend.calls.count == 1)

        backend.reject = true
        let rejected = PracticeDSPState(tempoRatio: 0.75, pitchSemitones: -3)
        do {
            _ = try await gate.apply(rejected)
            preconditionFailure("backend rejection must not commit")
        } catch PracticeDSPApplicationError.backendRejected { }
        let afterBackendReject = await gate.lastAppliedState()
        precondition(afterBackendReject == candidate)
    }

    static func testClickSchedulingEdges() throws {
        do {
            _ = try SampleTimelinePlanner.planClicks(
                beatTimesSeconds: [0, 0.5, 0.5], sourceStartSeconds: 0,
                renderStartSampleTime: 0, tempoRatio: 1, sampleRate: 48_000, generation: 1
            )
            preconditionFailure("duplicate beat times must fail")
        } catch DSPTimelinePlanningError.nonIncreasingBeatSequence { }

        do {
            _ = try SampleTimelinePlanner.planClicks(
                beatTimesSeconds: [0, 0.01], sourceStartSeconds: 0,
                renderStartSampleTime: 0, tempoRatio: 32, sampleRate: 1, generation: 1
            )
            preconditionFailure("two beats mapping to one render sample must fail")
        } catch DSPTimelinePlanningError.nonIncreasingRenderSample { }

        do {
            _ = try SampleTimelinePlanner.mapSourceTimeToRenderSample(
                sourceTimeSeconds: 0, sourceOriginSeconds: 1,
                renderOriginSampleTime: 0, tempoRatio: 1, sampleRate: 48_000
            )
            preconditionFailure("negative render sample must fail")
        } catch DSPTimelinePlanningError.insufficientPreroll { }

        do {
            _ = try SampleTimelinePlanner.planCountIn(
                clicks: 4, sourceBeatIntervalSeconds: 0.5,
                musicStartSampleTime: 10, tempoRatio: 1, sampleRate: 48_000, generation: 1
            )
            preconditionFailure("insufficient count-in preroll must fail")
        } catch DSPTimelinePlanningError.insufficientPreroll { }

        let valid = try SampleTimelinePlanner.planCountIn(
            clicks: 4, sourceBeatIntervalSeconds: 0.5,
            musicStartSampleTime: 96_000, tempoRatio: 1, sampleRate: 48_000, generation: 7
        )
        precondition(valid.clicks.map(\.sampleTime) == [0, 24_000, 48_000, 72_000])
    }
}
