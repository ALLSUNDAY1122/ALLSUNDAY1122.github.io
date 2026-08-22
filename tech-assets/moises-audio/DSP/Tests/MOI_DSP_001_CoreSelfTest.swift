import Foundation

@main
struct MOIDSP001CoreSelfTest {
    static func main() async throws {
        try testTimelineMapping()
        try testCountIn()
        try testTenMinuteClickGateMath()
        try testLoopNoDriftMath()
        try testBoundaryValidation()
        try await testController()
        print("MOI-DSP-001 core self-test: PASS")
    }

    static func testTimelineMapping() throws {
        let slow = try SampleTimelinePlanner.mapSourceTimeToRenderSample(
            sourceTimeSeconds: 10,
            sourceOriginSeconds: 0,
            renderOriginSampleTime: 0,
            tempoRatio: 0.5,
            sampleRate: 48_000
        )
        precondition(slow == 960_000)

        let fast = try SampleTimelinePlanner.mapSourceTimeToRenderSample(
            sourceTimeSeconds: 10,
            sourceOriginSeconds: 0,
            renderOriginSampleTime: 0,
            tempoRatio: 2.0,
            sampleRate: 48_000
        )
        precondition(fast == 240_000)
    }

    static func testCountIn() throws {
        let plan = try SampleTimelinePlanner.planCountIn(
            clicks: 4,
            sourceBeatIntervalSeconds: 0.5,
            musicStartSampleTime: 96_000,
            tempoRatio: 1.0,
            sampleRate: 48_000,
            generation: 7
        )
        precondition(plan.clicks.map(\.sampleTime) == [0, 24_000, 48_000, 72_000])
        precondition(plan.musicStartSampleTime == 96_000)
        precondition(plan.clicks.allSatisfy { $0.generation == 7 })
    }

    static func testTenMinuteClickGateMath() throws {
        let beatTimes = (0..<1200).map { Double($0) * 0.5 }
        let events = try SampleTimelinePlanner.planClicks(
            beatTimesSeconds: beatTimes,
            sourceStartSeconds: 0,
            renderStartSampleTime: 0,
            tempoRatio: 1.25,
            sampleRate: 48_000,
            generation: 1
        )
        precondition(events.count == beatTimes.count)
        var maxFrameError: Int64 = 0
        for (event, sourceBeat) in zip(events, beatTimes) {
            let expected = Int64((sourceBeat / 1.25 * 48_000).rounded())
            maxFrameError = max(maxFrameError, abs(event.sampleTime - expected))
        }
        precondition(maxFrameError <= 1)
    }

    static func testLoopNoDriftMath() throws {
        let sourceLoopSeconds = 3.7
        let ratio = 0.9
        let sampleRate = 48_000.0
        let expectedLoopFrames = Int64((sourceLoopSeconds / ratio * sampleRate).rounded())
        var origin: Int64 = 0
        for _ in 0..<100 {
            let mappedEnd = try SampleTimelinePlanner.mapSourceTimeToRenderSample(
                sourceTimeSeconds: sourceLoopSeconds,
                sourceOriginSeconds: 0,
                renderOriginSampleTime: origin,
                tempoRatio: ratio,
                sampleRate: sampleRate
            )
            precondition(mappedEnd - origin == expectedLoopFrames)
            origin = mappedEnd
        }
        precondition(origin == expectedLoopFrames * 100)
    }

    static func testBoundaryValidation() throws {
        do {
            _ = try SampleTimelinePlanner.mapSourceTimeToRenderSample(
                sourceTimeSeconds: 1,
                sourceOriginSeconds: 0,
                renderOriginSampleTime: Int64.max,
                tempoRatio: 1,
                sampleRate: 48_000
            )
            preconditionFailure("render-origin overflow must fail")
        } catch DSPTimelinePlanningError.timelineOverflow {
            // expected
        }

        do {
            _ = try SampleTimelinePlanner.planClicks(
                beatTimesSeconds: [0, 0.5],
                sourceStartSeconds: .nan,
                renderStartSampleTime: 0,
                tempoRatio: 1,
                sampleRate: 48_000,
                generation: 1
            )
            preconditionFailure("non-finite source start must fail")
        } catch DSPTimelinePlanningError.invalidSourceOrigin {
            // expected
        }

        do {
            _ = try SampleTimelinePlanner.planClicks(
                beatTimesSeconds: [0, 0.5],
                sourceStartSeconds: 0,
                renderStartSampleTime: 0,
                tempoRatio: 1,
                sampleRate: 48_000,
                generation: 1,
                sourceEndSeconds: -.infinity
            )
            preconditionFailure("invalid source end must fail")
        } catch DSPTimelinePlanningError.invalidSourceEnd {
            // expected
        }

        do {
            _ = try SampleTimelinePlanner.planCountIn(
                clicks: Int.max,
                sourceBeatIntervalSeconds: 1,
                musicStartSampleTime: Int64.max,
                tempoRatio: 1,
                sampleRate: 48_000,
                generation: 1
            )
            preconditionFailure("count-in multiplication overflow must fail")
        } catch DSPTimelinePlanningError.timelineOverflow {
            // expected
        }

        do {
            _ = try SampleTimelinePlanner.planCountIn(
                clicks: 4,
                sourceBeatIntervalSeconds: 0.5,
                musicStartSampleTime: 96_000,
                tempoRatio: 1,
                sampleRate: 48_000,
                generation: 1,
                downbeatStride: 0
            )
            preconditionFailure("invalid downbeat stride must fail")
        } catch DSPTimelinePlanningError.invalidDownbeatStride {
            // expected
        }
    }

    static func testController() async throws {
        let controller = PracticeDSPController()
        let project = ProjectID()
        try await controller.setTempoRatio(1.25, projectID: project)
        try await controller.setPitchSemitones(3, projectID: project)
        try await controller.setMetronomeEnabled(true, projectID: project)
        try await controller.scheduleCountIn(clicks: 4, projectID: project)
        let state = await controller.snapshot(projectID: project)
        precondition(state.tempoRatio == 1.25)
        precondition(state.pitchSemitones == 3)
        precondition(state.metronomeEnabled)
        precondition(state.pendingCountInClicks == 4)
        precondition(state.scheduleGeneration == 3)
        precondition(PracticeDSPMath.cents(forSemitones: -7) == -700)
        precondition(abs(PracticeDSPMath.outputDurationSeconds(sourceDurationSeconds: 60, tempoRatio: 1.5) - 40) < 1e-12)
    }
}
