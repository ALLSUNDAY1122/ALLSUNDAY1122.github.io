import Foundation

@main
struct L3AW04ClickExecutionSelfTest {
    static func main() throws {
        try testMetronomeReplacementAndAppend()
        try testGenerationInvalidation()
        try testCountInBoundary()
        try testAppendAnchorSafety()
        try testPracticeStateBinding()
        try testLongRollingWindow()
        print("L3-AW04 click execution self-test: PASS")
    }

    static func testMetronomeReplacementAndAppend() throws {
        let generation: UInt64 = 7
        let events = try SampleTimelinePlanner.planClicks(
            beatTimesSeconds: [0, 0.5, 1.0, 1.5],
            sourceStartSeconds: 0,
            renderStartSampleTime: 96_000,
            tempoRatio: 1,
            sampleRate: 48_000,
            generation: generation
        )
        let batch = try DSPClickExecutionPlanner.preflight(
            events: events,
            activeGeneration: generation,
            renderOriginSampleTime: 96_000,
            sampleRate: 48_000,
            kind: .metronome
        )
        precondition(batch.relativeEvents.map(\.sampleTime) == [0, 24_000, 48_000, 72_000])

        var state = DSPClickExecutionState(activeGeneration: generation)
        try state.acceptReplacement(batch)
        precondition(state.queuedThroughProjectSampleTime == 168_000)

        let appended = try DSPClickExecutionPlanner.preflight(
            events: [DSPClickEvent(
                sampleTime: 192_000,
                beatIndex: 4,
                accent: true,
                generation: generation
            )],
            activeGeneration: generation,
            renderOriginSampleTime: 96_000,
            sampleRate: 48_000,
            kind: .metronome
        )
        try state.acceptAppend(appended)
        precondition(state.queuedThroughProjectSampleTime == 192_000)

        do {
            let overlap = try DSPClickExecutionPlanner.preflight(
                events: [DSPClickEvent(
                    sampleTime: 180_000,
                    beatIndex: 5,
                    accent: false,
                    generation: generation
                )],
                activeGeneration: generation,
                renderOriginSampleTime: 96_000,
                sampleRate: 48_000,
                kind: .metronome
            )
            try state.acceptAppend(overlap)
            preconditionFailure("overlapping rolling window must fail")
        } catch DSPClickExecutionError.appendOverlapsQueued { }
    }

    static func testGenerationInvalidation() throws {
        let oldGeneration: UInt64 = 10
        var state = DSPClickExecutionState(activeGeneration: oldGeneration)
        let oldBatch = try DSPClickExecutionPlanner.preflight(
            events: [DSPClickEvent(
                sampleTime: 1_000,
                beatIndex: 0,
                accent: true,
                generation: oldGeneration
            )],
            activeGeneration: oldGeneration,
            renderOriginSampleTime: 0,
            sampleRate: 48_000,
            kind: .metronome
        )
        try state.acceptReplacement(oldBatch)
        try state.invalidate(to: 11)
        precondition(state.queuedThroughProjectSampleTime == nil)
        precondition(state.activeRenderOriginSampleTime == nil)

        do {
            _ = try DSPClickExecutionPlanner.preflight(
                events: oldBatch.relativeEvents.map {
                    DSPClickEvent(
                        sampleTime: $0.sampleTime,
                        beatIndex: $0.beatIndex,
                        accent: $0.accent,
                        generation: oldGeneration
                    )
                },
                activeGeneration: 11,
                renderOriginSampleTime: 0,
                sampleRate: 48_000,
                kind: .metronome
            )
            preconditionFailure("old generation must be rejected before enqueue")
        } catch DSPClickExecutionError.staleGeneration { }

        do {
            try state.invalidate(to: 9)
            preconditionFailure("generation regression must fail")
        } catch DSPClickExecutionError.generationRegression { }
    }

    static func testCountInBoundary() throws {
        let plan = try SampleTimelinePlanner.planCountIn(
            clicks: 4,
            sourceBeatIntervalSeconds: 0.5,
            musicStartSampleTime: 120_000,
            tempoRatio: 1,
            sampleRate: 48_000,
            generation: 12
        )
        let batch = try DSPClickExecutionPlanner.preflight(
            events: plan.clicks,
            activeGeneration: 12,
            renderOriginSampleTime: 24_000,
            sampleRate: 48_000,
            kind: .countIn(musicStartSampleTime: 120_000)
        )
        precondition(batch.relativeEvents.map(\.sampleTime) == [0, 24_000, 48_000, 72_000])

        do {
            _ = try DSPClickExecutionPlanner.preflight(
                events: [DSPClickEvent(
                    sampleTime: 120_000,
                    beatIndex: 4,
                    accent: true,
                    generation: 12
                )],
                activeGeneration: 12,
                renderOriginSampleTime: 24_000,
                sampleRate: 48_000,
                kind: .countIn(musicStartSampleTime: 120_000)
            )
            preconditionFailure("count-in event at music start must fail")
        } catch DSPClickExecutionError.eventNotBeforeMusicStart { }
    }

    static func testAppendAnchorSafety() throws {
        let generation: UInt64 = 20
        let initial = try DSPClickExecutionPlanner.preflight(
            events: [DSPClickEvent(
                sampleTime: 120_000,
                beatIndex: 0,
                accent: true,
                generation: generation
            )],
            activeGeneration: generation,
            renderOriginSampleTime: 96_000,
            sampleRate: 48_000,
            kind: .metronome
        )
        var state = DSPClickExecutionState(activeGeneration: generation)
        try state.acceptReplacement(initial)

        do {
            let changedAnchor = try DSPClickExecutionPlanner.preflight(
                events: [DSPClickEvent(
                    sampleTime: 144_000,
                    beatIndex: 1,
                    accent: false,
                    generation: generation
                )],
                activeGeneration: generation,
                renderOriginSampleTime: 120_000,
                sampleRate: 48_000,
                kind: .metronome
            )
            try state.acceptAppend(changedAnchor)
            preconditionFailure("anchor change requires replacement")
        } catch DSPClickExecutionError.appendAnchorMismatch { }

        do {
            let changedRate = try DSPClickExecutionPlanner.preflight(
                events: [DSPClickEvent(
                    sampleTime: 144_000,
                    beatIndex: 1,
                    accent: false,
                    generation: generation
                )],
                activeGeneration: generation,
                renderOriginSampleTime: 96_000,
                sampleRate: 44_100,
                kind: .metronome
            )
            try state.acceptAppend(changedRate)
            preconditionFailure("sample-rate change requires replacement")
        } catch DSPClickExecutionError.appendSampleRateMismatch { }
    }

    static func testPracticeStateBinding() throws {
        let state = PracticeDSPState(
            tempoRatio: 0.5,
            metronomeEnabled: true,
            pendingCountInClicks: 4,
            scheduleGeneration: 30
        )
        let metronome = try PracticeDSPClickExecutionPlanner.metronome(
            state: state,
            beatTimesSeconds: [10, 10.5, 11],
            sourceStartSeconds: 10,
            sourceEndSeconds: nil,
            renderOriginSampleTime: 48_000,
            sampleRate: 48_000
        )
        precondition(metronome.events.map(\.sampleTime) == [48_000, 96_000, 144_000])
        precondition(metronome.events.allSatisfy { $0.generation == 30 })

        let countIn = try PracticeDSPClickExecutionPlanner.countIn(
            state: state,
            sourceBeatIntervalSeconds: 0.5,
            musicStartSampleTime: 240_000,
            renderOriginSampleTime: 48_000,
            sampleRate: 48_000
        )
        precondition(countIn.clicks.map(\.sampleTime) == [48_000, 96_000, 144_000, 192_000])
        precondition(countIn.generation == 30)

        do {
            _ = try PracticeDSPClickExecutionPlanner.metronome(
                state: PracticeDSPState(),
                beatTimesSeconds: [0],
                sourceStartSeconds: 0,
                sourceEndSeconds: nil,
                renderOriginSampleTime: 0,
                sampleRate: 48_000
            )
            preconditionFailure("disabled metronome must not plan audio")
        } catch PracticeDSPClickExecutionPlanningError.metronomeDisabled { }
    }

    static func testLongRollingWindow() throws {
        var state = DSPClickExecutionState(activeGeneration: 100)
        var lastSample: Int64 = 0
        for index in 0..<100_000 {
            let sample = Int64(index + 1) * 256
            let batch = try DSPClickExecutionPlanner.preflight(
                events: [DSPClickEvent(
                    sampleTime: sample,
                    beatIndex: index,
                    accent: index % 4 == 0,
                    generation: 100
                )],
                activeGeneration: 100,
                renderOriginSampleTime: 0,
                sampleRate: 48_000,
                kind: .metronome
            )
            try state.acceptAppend(batch)
            lastSample = sample
        }
        precondition(state.queuedThroughProjectSampleTime == lastSample)
    }
}
