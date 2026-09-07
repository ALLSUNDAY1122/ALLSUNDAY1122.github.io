import Foundation

@main
struct L3M01MeasurementHarnessSelfTest {
    static func main() throws {
        try testHarnessOnlyCannotClaimParity()
        try testPhysicalDeviceEligibleWhenAllGatesExist()
        try testSyntheticFixtureFailsClosed()
        try testTimingFailures()
        try testAutomatedFailureIsVisible()
        print("L3-M01 measurement harness self-test: PASS")
    }

    static func fixture(rights: Lane3FixtureRights = .rightsCleared, real: Bool = true) -> Lane3FixtureManifest {
        Lane3FixtureManifest(
            fixtureID: "lane3-fixture-001",
            provenance: "project-controlled test fixture",
            rights: rights,
            genre: "mixed",
            durationSeconds: 180,
            sampleRate: 48_000,
            stemRoles: ["vocals", "drums", "bass", "other"],
            containsRealAudio: real
        )
    }

    static func playback(reviewed: Bool = true, humanPassed: Bool? = true) -> Lane3PlaybackMeasurementInput {
        Lane3PlaybackMeasurementInput(
            stemOnsetSeconds: ["vocals": 10.0000, "drums": 10.0008, "bass": 10.0010, "other": 10.0004],
            seekCommandSeconds: 20.000,
            firstPostSeekOutputSeconds: 20.045,
            loopTiming: Lane3TimingSeries(
                expectedSeconds: [30, 40, 50, 60],
                actualSeconds: [30.0002, 40.0004, 50.0005, 60.0006]
            ),
            gainTransitions: [
                Lane3GainTransitionObservation(
                    transitionID: "volume-1.0-to-0.5",
                    maximumAbsoluteSampleStep: 0.10,
                    localRMS: 0.05,
                    settlingMilliseconds: 8,
                    audibleArtifactReviewed: reviewed,
                    audibleArtifactPassed: humanPassed
                )
            ]
        )
    }

    static func dsp(reviewed: Bool = true, humanPassed: Bool? = true) -> Lane3DSPMeasurementInput {
        Lane3DSPMeasurementInput(
            metronomeTiming: Lane3TimingSeries(
                expectedSeconds: [0, 0.5, 1.0, 1.5],
                actualSeconds: [0.0002, 0.5003, 1.0004, 1.5005]
            ),
            countInTiming: Lane3TimingSeries(
                expectedSeconds: [-2.0, -1.5, -1.0, -0.5],
                actualSeconds: [-1.9995, -1.4996, -0.9997, -0.4998]
            ),
            practice: Lane3PracticeDSPObservation(
                requestedTempoRatio: 0.90,
                measuredTempoRatio: 0.9004,
                requestedPitchSemitones: 2.0,
                measuredPitchSemitones: 2.02,
                renderLatencyMilliseconds: 32,
                transientPeakLossDB: 1.2,
                noiseFloorIncreaseDB: 2.5,
                artifactListeningReviewed: reviewed,
                artifactListeningPassed: humanPassed
            )
        )
    }

    static func testHarnessOnlyCannotClaimParity() throws {
        let report = try Lane3DeviceMeasurementHarness.evaluate(
            runID: "harness-only",
            capturedAtISO8601: "2026-08-22T17:20:00+09:00",
            captureSurface: .harnessOnly,
            fixture: fixture(),
            actualAudioCaptured: false,
            referenceDifferentialCompleted: false,
            playback: playback(),
            dsp: dsp()
        )
        precondition(report.automatedGatePassed)
        precondition(!report.parityEvidenceEligible)
        precondition(report.blockerCodes.contains("PHYSICAL_IPHONE_CAPTURE_REQUIRED"))
        precondition(report.blockerCodes.contains("ACTUAL_AUDIO_CAPTURE_REQUIRED"))
        precondition(report.blockerCodes.contains("REFERENCE_DIFFERENTIAL_REQUIRED_FOR_PARITY"))
        precondition(!(try Lane3DeviceMeasurementHarness.encodeJSON(report)).isEmpty)
    }

    static func testPhysicalDeviceEligibleWhenAllGatesExist() throws {
        let report = try Lane3DeviceMeasurementHarness.evaluate(
            runID: "device-valid",
            capturedAtISO8601: "2026-08-22T17:20:00+09:00",
            captureSurface: .physicalIPhone,
            fixture: fixture(),
            actualAudioCaptured: true,
            referenceDifferentialCompleted: true,
            playback: playback(),
            dsp: dsp()
        )
        precondition(report.automatedGatePassed)
        precondition(report.humanArtifactReviewComplete)
        precondition(report.humanArtifactGatePassed)
        precondition(report.parityEvidenceEligible)
        precondition(report.blockerCodes.isEmpty)
    }

    static func testSyntheticFixtureFailsClosed() throws {
        let report = try Lane3DeviceMeasurementHarness.evaluate(
            runID: "synthetic",
            capturedAtISO8601: "2026-08-22T17:20:00+09:00",
            captureSurface: .physicalIPhone,
            fixture: fixture(rights: .syntheticOnly, real: false),
            actualAudioCaptured: true,
            referenceDifferentialCompleted: true,
            playback: playback(),
            dsp: dsp()
        )
        precondition(!report.parityEvidenceEligible)
        precondition(report.blockerCodes.contains("FIXTURE_RIGHTS_NOT_CLEARED"))
        precondition(report.blockerCodes.contains("REAL_AUDIO_REQUIRED"))
    }

    static func testTimingFailures() throws {
        do {
            _ = try Lane3DeviceMeasurementHarness.evaluate(
                runID: "bad-count",
                capturedAtISO8601: "2026-08-22T17:20:00+09:00",
                captureSurface: .harnessOnly,
                fixture: fixture(),
                actualAudioCaptured: false,
                referenceDifferentialCompleted: false,
                playback: Lane3PlaybackMeasurementInput(
                    stemOnsetSeconds: ["a": 0, "b": 0],
                    seekCommandSeconds: 1,
                    firstPostSeekOutputSeconds: 1.01,
                    loopTiming: Lane3TimingSeries(expectedSeconds: [1, 2], actualSeconds: [1]),
                    gainTransitions: playback().gainTransitions
                ),
                dsp: dsp()
            )
            preconditionFailure("count mismatch must throw")
        } catch Lane3MeasurementError.countMismatch("loop") {
        }

        do {
            _ = try Lane3DeviceMeasurementHarness.evaluate(
                runID: "bad-order",
                capturedAtISO8601: "2026-08-22T17:20:00+09:00",
                captureSurface: .harnessOnly,
                fixture: fixture(),
                actualAudioCaptured: false,
                referenceDifferentialCompleted: false,
                playback: playback(),
                dsp: Lane3DSPMeasurementInput(
                    metronomeTiming: Lane3TimingSeries(expectedSeconds: [0, 1], actualSeconds: [0.8, 0.2]),
                    countInTiming: dsp().countInTiming,
                    practice: dsp().practice
                )
            )
            preconditionFailure("non-monotonic series must throw")
        } catch Lane3MeasurementError.nonMonotonicSeries("metronome") {
        }
    }

    static func testAutomatedFailureIsVisible() throws {
        let badPlayback = Lane3PlaybackMeasurementInput(
            stemOnsetSeconds: ["vocals": 10.0, "drums": 10.010],
            seekCommandSeconds: 20,
            firstPostSeekOutputSeconds: 20.250,
            loopTiming: playback().loopTiming,
            gainTransitions: playback().gainTransitions
        )
        let report = try Lane3DeviceMeasurementHarness.evaluate(
            runID: "auto-fail",
            capturedAtISO8601: "2026-08-22T17:20:00+09:00",
            captureSurface: .physicalIPhone,
            fixture: fixture(),
            actualAudioCaptured: true,
            referenceDifferentialCompleted: true,
            playback: badPlayback,
            dsp: dsp()
        )
        precondition(!report.automatedGatePassed)
        precondition(!report.parityEvidenceEligible)
        precondition(report.blockerCodes.contains("AUTOMATED_MEASUREMENT_GATE_FAILED"))
    }
}
