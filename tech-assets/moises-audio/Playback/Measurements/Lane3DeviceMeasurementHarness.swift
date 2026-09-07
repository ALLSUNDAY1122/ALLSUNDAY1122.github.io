import Foundation

public enum Lane3MeasurementError: Error, Equatable, Sendable {
    case emptySeries(String)
    case countMismatch(String)
    case nonFinite(String)
    case nonMonotonicSeries(String)
    case invalidValue(String)
}

public enum Lane3CaptureSurface: String, Codable, Sendable {
    case harnessOnly
    case simulator
    case macOS
    case physicalIPhone
}

public enum Lane3FixtureRights: String, Codable, Sendable {
    case rightsCleared
    case unknown
    case syntheticOnly
}

public enum Lane3MetricComparator: String, Codable, Sendable {
    case lessThanOrEqual
}

public struct Lane3FixtureManifest: Codable, Equatable, Sendable {
    public let fixtureID: String
    public let provenance: String
    public let rights: Lane3FixtureRights
    public let genre: String
    public let durationSeconds: Double
    public let sampleRate: Double
    public let stemRoles: [String]
    public let containsRealAudio: Bool

    public init(
        fixtureID: String,
        provenance: String,
        rights: Lane3FixtureRights,
        genre: String,
        durationSeconds: Double,
        sampleRate: Double,
        stemRoles: [String],
        containsRealAudio: Bool
    ) {
        self.fixtureID = fixtureID
        self.provenance = provenance
        self.rights = rights
        self.genre = genre
        self.durationSeconds = durationSeconds
        self.sampleRate = sampleRate
        self.stemRoles = stemRoles
        self.containsRealAudio = containsRealAudio
    }
}

public struct Lane3MeasurementThresholds: Codable, Equatable, Sendable {
    public let onsetSkewMilliseconds: Double
    public let seekGapMilliseconds: Double
    public let loopMaxDriftMilliseconds: Double
    public let loopEndToEndDriftMilliseconds: Double
    public let gainStepOverLocalRMSDB: Double
    public let gainSettlingMilliseconds: Double
    public let clickMaxOnsetErrorMilliseconds: Double
    public let clickEndToEndDriftMilliseconds: Double
    public let countInMaxOnsetErrorMilliseconds: Double
    public let tempoRatioErrorPercent: Double
    public let pitchErrorCents: Double
    public let renderLatencyMilliseconds: Double
    public let transientPeakLossDB: Double
    public let noiseFloorIncreaseDB: Double

    public static let provisionalEngineering = Lane3MeasurementThresholds(
        onsetSkewMilliseconds: 2.0,
        seekGapMilliseconds: 100.0,
        loopMaxDriftMilliseconds: 2.0,
        loopEndToEndDriftMilliseconds: 2.0,
        gainStepOverLocalRMSDB: 12.0,
        gainSettlingMilliseconds: 20.0,
        clickMaxOnsetErrorMilliseconds: 2.0,
        clickEndToEndDriftMilliseconds: 1.0,
        countInMaxOnsetErrorMilliseconds: 2.0,
        tempoRatioErrorPercent: 0.10,
        pitchErrorCents: 5.0,
        renderLatencyMilliseconds: 100.0,
        transientPeakLossDB: 3.0,
        noiseFloorIncreaseDB: 6.0
    )
}

public struct Lane3TimingSeries: Codable, Equatable, Sendable {
    public let expectedSeconds: [Double]
    public let actualSeconds: [Double]

    public init(expectedSeconds: [Double], actualSeconds: [Double]) {
        self.expectedSeconds = expectedSeconds
        self.actualSeconds = actualSeconds
    }
}

public struct Lane3GainTransitionObservation: Codable, Equatable, Sendable {
    public let transitionID: String
    public let maximumAbsoluteSampleStep: Double
    public let localRMS: Double
    public let settlingMilliseconds: Double
    public let audibleArtifactReviewed: Bool
    public let audibleArtifactPassed: Bool?

    public init(
        transitionID: String,
        maximumAbsoluteSampleStep: Double,
        localRMS: Double,
        settlingMilliseconds: Double,
        audibleArtifactReviewed: Bool,
        audibleArtifactPassed: Bool?
    ) {
        self.transitionID = transitionID
        self.maximumAbsoluteSampleStep = maximumAbsoluteSampleStep
        self.localRMS = localRMS
        self.settlingMilliseconds = settlingMilliseconds
        self.audibleArtifactReviewed = audibleArtifactReviewed
        self.audibleArtifactPassed = audibleArtifactPassed
    }
}

public struct Lane3PracticeDSPObservation: Codable, Equatable, Sendable {
    public let requestedTempoRatio: Double
    public let measuredTempoRatio: Double
    public let requestedPitchSemitones: Double
    public let measuredPitchSemitones: Double
    public let renderLatencyMilliseconds: Double
    public let transientPeakLossDB: Double
    public let noiseFloorIncreaseDB: Double
    public let artifactListeningReviewed: Bool
    public let artifactListeningPassed: Bool?

    public init(
        requestedTempoRatio: Double,
        measuredTempoRatio: Double,
        requestedPitchSemitones: Double,
        measuredPitchSemitones: Double,
        renderLatencyMilliseconds: Double,
        transientPeakLossDB: Double,
        noiseFloorIncreaseDB: Double,
        artifactListeningReviewed: Bool,
        artifactListeningPassed: Bool?
    ) {
        self.requestedTempoRatio = requestedTempoRatio
        self.measuredTempoRatio = measuredTempoRatio
        self.requestedPitchSemitones = requestedPitchSemitones
        self.measuredPitchSemitones = measuredPitchSemitones
        self.renderLatencyMilliseconds = renderLatencyMilliseconds
        self.transientPeakLossDB = transientPeakLossDB
        self.noiseFloorIncreaseDB = noiseFloorIncreaseDB
        self.artifactListeningReviewed = artifactListeningReviewed
        self.artifactListeningPassed = artifactListeningPassed
    }
}

public struct Lane3PlaybackMeasurementInput: Codable, Equatable, Sendable {
    public let stemOnsetSeconds: [String: Double]
    public let seekCommandSeconds: Double
    public let firstPostSeekOutputSeconds: Double
    public let loopTiming: Lane3TimingSeries
    public let gainTransitions: [Lane3GainTransitionObservation]

    public init(
        stemOnsetSeconds: [String: Double],
        seekCommandSeconds: Double,
        firstPostSeekOutputSeconds: Double,
        loopTiming: Lane3TimingSeries,
        gainTransitions: [Lane3GainTransitionObservation]
    ) {
        self.stemOnsetSeconds = stemOnsetSeconds
        self.seekCommandSeconds = seekCommandSeconds
        self.firstPostSeekOutputSeconds = firstPostSeekOutputSeconds
        self.loopTiming = loopTiming
        self.gainTransitions = gainTransitions
    }
}

public struct Lane3DSPMeasurementInput: Codable, Equatable, Sendable {
    public let metronomeTiming: Lane3TimingSeries
    public let countInTiming: Lane3TimingSeries
    public let practice: Lane3PracticeDSPObservation

    public init(
        metronomeTiming: Lane3TimingSeries,
        countInTiming: Lane3TimingSeries,
        practice: Lane3PracticeDSPObservation
    ) {
        self.metronomeTiming = metronomeTiming
        self.countInTiming = countInTiming
        self.practice = practice
    }
}

public struct Lane3MetricResult: Codable, Equatable, Sendable {
    public let metricID: String
    public let value: Double
    public let unit: String
    public let threshold: Double
    public let comparator: Lane3MetricComparator
    public let passed: Bool
    public let evidenceNote: String
}

public struct Lane3MeasurementReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let runID: String
    public let capturedAtISO8601: String
    public let thresholdProfile: String
    public let captureSurface: Lane3CaptureSurface
    public let fixture: Lane3FixtureManifest
    public let actualAudioCaptured: Bool
    public let referenceDifferentialCompleted: Bool
    public let metrics: [Lane3MetricResult]
    public let automatedGatePassed: Bool
    public let humanArtifactReviewComplete: Bool
    public let humanArtifactGatePassed: Bool
    public let parityEvidenceEligible: Bool
    public let blockerCodes: [String]
}

public enum Lane3DeviceMeasurementHarness {
    public static func evaluate(
        runID: String,
        capturedAtISO8601: String,
        captureSurface: Lane3CaptureSurface,
        fixture: Lane3FixtureManifest,
        actualAudioCaptured: Bool,
        referenceDifferentialCompleted: Bool,
        playback: Lane3PlaybackMeasurementInput,
        dsp: Lane3DSPMeasurementInput,
        thresholds: Lane3MeasurementThresholds = .provisionalEngineering
    ) throws -> Lane3MeasurementReport {
        try validateFixture(fixture)
        try validateTimingSeries(playback.loopTiming, name: "loop")
        try validateTimingSeries(dsp.metronomeTiming, name: "metronome")
        try validateTimingSeries(dsp.countInTiming, name: "countIn")

        let onsetValues = Array(playback.stemOnsetSeconds.values)
        guard onsetValues.count >= 2 else { throw Lane3MeasurementError.emptySeries("stemOnsetSeconds") }
        try requireFinite(onsetValues, name: "stemOnsetSeconds")
        let onsetSkewMs = ((onsetValues.max() ?? 0) - (onsetValues.min() ?? 0)) * 1000

        guard playback.seekCommandSeconds.isFinite,
              playback.firstPostSeekOutputSeconds.isFinite,
              playback.firstPostSeekOutputSeconds >= playback.seekCommandSeconds else {
            throw Lane3MeasurementError.invalidValue("seekTiming")
        }
        let seekGapMs = (playback.firstPostSeekOutputSeconds - playback.seekCommandSeconds) * 1000

        let loopErrorsMs = zip(playback.loopTiming.expectedSeconds, playback.loopTiming.actualSeconds)
            .map { abs($1 - $0) * 1000 }
        let loopMaxDriftMs = loopErrorsMs.max() ?? 0
        let loopSignedErrorsMs = zip(playback.loopTiming.expectedSeconds, playback.loopTiming.actualSeconds)
            .map { ($1 - $0) * 1000 }
        let loopEndToEndMs = abs((loopSignedErrorsMs.last ?? 0) - (loopSignedErrorsMs.first ?? 0))

        let clickErrorsMs = zip(dsp.metronomeTiming.expectedSeconds, dsp.metronomeTiming.actualSeconds)
            .map { abs($1 - $0) * 1000 }
        let clickSignedErrorsMs = zip(dsp.metronomeTiming.expectedSeconds, dsp.metronomeTiming.actualSeconds)
            .map { ($1 - $0) * 1000 }
        let clickMaxErrorMs = clickErrorsMs.max() ?? 0
        let clickEndToEndMs = abs((clickSignedErrorsMs.last ?? 0) - (clickSignedErrorsMs.first ?? 0))

        let countInMaxErrorMs = zip(dsp.countInTiming.expectedSeconds, dsp.countInTiming.actualSeconds)
            .map { abs($1 - $0) * 1000 }
            .max() ?? 0

        let gainResults = try evaluateGainTransitions(playback.gainTransitions, thresholds: thresholds)
        let practiceResults = try evaluatePracticeDSP(dsp.practice, thresholds: thresholds)

        var metrics: [Lane3MetricResult] = [
            metric("playback.onset_skew", onsetSkewMs, "ms", thresholds.onsetSkewMilliseconds, "Measured across simultaneously scheduled stem markers."),
            metric("playback.seek_gap", seekGapMs, "ms", thresholds.seekGapMilliseconds, "Command-to-first-post-seek-audio interval."),
            metric("playback.loop_max_drift", loopMaxDriftMs, "ms", thresholds.loopMaxDriftMilliseconds, "Maximum absolute loop boundary timing error."),
            metric("playback.loop_end_to_end_drift", loopEndToEndMs, "ms", thresholds.loopEndToEndDriftMilliseconds, "Change in signed boundary error from first to last measured loop."),
            metric("dsp.metronome_max_onset_error", clickMaxErrorMs, "ms", thresholds.clickMaxOnsetErrorMilliseconds, "Maximum click onset error against sample-derived expected beat times."),
            metric("dsp.metronome_end_to_end_drift", clickEndToEndMs, "ms", thresholds.clickEndToEndDriftMilliseconds, "Change in signed click error from first to last measured click."),
            metric("dsp.count_in_max_onset_error", countInMaxErrorMs, "ms", thresholds.countInMaxOnsetErrorMilliseconds, "Maximum count-in onset error against planned preroll clicks.")
        ]
        metrics.append(contentsOf: gainResults)
        metrics.append(contentsOf: practiceResults)

        let automatedGatePassed = metrics.allSatisfy(\.passed)
        let gainHumanComplete = playback.gainTransitions.allSatisfy { $0.audibleArtifactReviewed && $0.audibleArtifactPassed != nil }
        let gainHumanPassed = playback.gainTransitions.allSatisfy { $0.audibleArtifactPassed == true }
        let dspHumanComplete = dsp.practice.artifactListeningReviewed && dsp.practice.artifactListeningPassed != nil
        let dspHumanPassed = dsp.practice.artifactListeningPassed == true
        let humanComplete = gainHumanComplete && dspHumanComplete
        let humanPassed = gainHumanPassed && dspHumanPassed

        var blockers: [String] = []
        if fixture.rights != .rightsCleared { blockers.append("FIXTURE_RIGHTS_NOT_CLEARED") }
        if !fixture.containsRealAudio { blockers.append("REAL_AUDIO_REQUIRED") }
        if captureSurface != .physicalIPhone { blockers.append("PHYSICAL_IPHONE_CAPTURE_REQUIRED") }
        if !actualAudioCaptured { blockers.append("ACTUAL_AUDIO_CAPTURE_REQUIRED") }
        if !referenceDifferentialCompleted { blockers.append("REFERENCE_DIFFERENTIAL_REQUIRED_FOR_PARITY") }
        if !automatedGatePassed { blockers.append("AUTOMATED_MEASUREMENT_GATE_FAILED") }
        if !humanComplete { blockers.append("HUMAN_ARTIFACT_REVIEW_REQUIRED") }
        else if !humanPassed { blockers.append("HUMAN_ARTIFACT_GATE_FAILED") }

        let parityEligible = blockers.isEmpty
        return Lane3MeasurementReport(
            schemaVersion: 1,
            runID: runID,
            capturedAtISO8601: capturedAtISO8601,
            thresholdProfile: "LANE3_PROVISIONAL_ENGINEERING_NOT_REFERENCE",
            captureSurface: captureSurface,
            fixture: fixture,
            actualAudioCaptured: actualAudioCaptured,
            referenceDifferentialCompleted: referenceDifferentialCompleted,
            metrics: metrics,
            automatedGatePassed: automatedGatePassed,
            humanArtifactReviewComplete: humanComplete,
            humanArtifactGatePassed: humanPassed,
            parityEvidenceEligible: parityEligible,
            blockerCodes: blockers
        )
    }

    public static func encodeJSON(_ report: Lane3MeasurementReport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(report)
    }

    private static func evaluateGainTransitions(
        _ observations: [Lane3GainTransitionObservation],
        thresholds: Lane3MeasurementThresholds
    ) throws -> [Lane3MetricResult] {
        guard !observations.isEmpty else { throw Lane3MeasurementError.emptySeries("gainTransitions") }
        var worstStepDB = -Double.infinity
        var worstSettlingMs = 0.0
        for observation in observations {
            guard observation.maximumAbsoluteSampleStep.isFinite,
                  observation.maximumAbsoluteSampleStep >= 0,
                  observation.localRMS.isFinite,
                  observation.localRMS >= 0,
                  observation.settlingMilliseconds.isFinite,
                  observation.settlingMilliseconds >= 0 else {
                throw Lane3MeasurementError.invalidValue("gainTransition")
            }
            let denominator = max(observation.localRMS, 1e-9)
            let ratio = max(observation.maximumAbsoluteSampleStep / denominator, 1e-12)
            worstStepDB = max(worstStepDB, 20 * log10(ratio))
            worstSettlingMs = max(worstSettlingMs, observation.settlingMilliseconds)
        }
        return [
            metric("playback.gain_step_over_local_rms", worstStepDB, "dB", thresholds.gainStepOverLocalRMSDB, "Controlled-fixture discontinuity indicator; human click/pop review remains mandatory."),
            metric("playback.gain_settling", worstSettlingMs, "ms", thresholds.gainSettlingMilliseconds, "Worst observed settling interval after volume/solo/mute transition.")
        ]
    }

    private static func evaluatePracticeDSP(
        _ observation: Lane3PracticeDSPObservation,
        thresholds: Lane3MeasurementThresholds
    ) throws -> [Lane3MetricResult] {
        let values = [
            observation.requestedTempoRatio,
            observation.measuredTempoRatio,
            observation.requestedPitchSemitones,
            observation.measuredPitchSemitones,
            observation.renderLatencyMilliseconds,
            observation.transientPeakLossDB,
            observation.noiseFloorIncreaseDB
        ]
        try requireFinite(values, name: "practiceDSP")
        guard observation.requestedTempoRatio > 0,
              observation.measuredTempoRatio > 0,
              observation.renderLatencyMilliseconds >= 0,
              observation.transientPeakLossDB >= 0,
              observation.noiseFloorIncreaseDB >= 0 else {
            throw Lane3MeasurementError.invalidValue("practiceDSP")
        }
        let tempoErrorPercent = abs(observation.measuredTempoRatio - observation.requestedTempoRatio) / observation.requestedTempoRatio * 100
        let pitchErrorCents = abs(observation.measuredPitchSemitones - observation.requestedPitchSemitones) * 100
        return [
            metric("dsp.tempo_ratio_error", tempoErrorPercent, "%", thresholds.tempoRatioErrorPercent, "Measured output duration/beat ratio versus requested tempo ratio."),
            metric("dsp.pitch_error", pitchErrorCents, "cents", thresholds.pitchErrorCents, "Measured pitch shift error versus requested semitone shift."),
            metric("dsp.render_latency", observation.renderLatencyMilliseconds, "ms", thresholds.renderLatencyMilliseconds, "Instrumented render/control response latency; not planner CPU time."),
            metric("dsp.transient_peak_loss", observation.transientPeakLossDB, "dB", thresholds.transientPeakLossDB, "Objective guardrail only; listening review remains mandatory."),
            metric("dsp.noise_floor_increase", observation.noiseFloorIncreaseDB, "dB", thresholds.noiseFloorIncreaseDB, "Objective guardrail only; listening review remains mandatory.")
        ]
    }

    private static func metric(
        _ id: String,
        _ value: Double,
        _ unit: String,
        _ threshold: Double,
        _ note: String
    ) -> Lane3MetricResult {
        Lane3MetricResult(
            metricID: id,
            value: value,
            unit: unit,
            threshold: threshold,
            comparator: .lessThanOrEqual,
            passed: value <= threshold,
            evidenceNote: note
        )
    }

    private static func validateFixture(_ fixture: Lane3FixtureManifest) throws {
        guard !fixture.fixtureID.isEmpty,
              !fixture.provenance.isEmpty,
              fixture.durationSeconds.isFinite,
              fixture.durationSeconds > 0,
              fixture.sampleRate.isFinite,
              fixture.sampleRate > 0 else {
            throw Lane3MeasurementError.invalidValue("fixture")
        }
    }

    private static func validateTimingSeries(_ series: Lane3TimingSeries, name: String) throws {
        guard !series.expectedSeconds.isEmpty else { throw Lane3MeasurementError.emptySeries(name) }
        guard series.expectedSeconds.count == series.actualSeconds.count else { throw Lane3MeasurementError.countMismatch(name) }
        try requireFinite(series.expectedSeconds, name: name + ".expected")
        try requireFinite(series.actualSeconds, name: name + ".actual")
        guard isMonotonicNondecreasing(series.expectedSeconds), isMonotonicNondecreasing(series.actualSeconds) else {
            throw Lane3MeasurementError.nonMonotonicSeries(name)
        }
    }

    private static func requireFinite(_ values: [Double], name: String) throws {
        guard values.allSatisfy(\.isFinite) else { throw Lane3MeasurementError.nonFinite(name) }
    }

    private static func isMonotonicNondecreasing(_ values: [Double]) -> Bool {
        zip(values, values.dropFirst()).allSatisfy { $0 <= $1 }
    }
}
