import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisExtremeDurationRetentionTests: XCTestCase {
    func testNormalSongUsesExactW29W30Cadence() throws {
        let duration = 600.0
        let plan = AnalysisExtremeDurationRetentionPolicy.plan(
            sampleRate: 8_000,
            sampleCount: Int(8_000 * duration),
            durationSeconds: duration
        )
        XCTAssertFalse(plan.compressionApplied)
        XCTAssertEqual(plan.tempoFrameStride, 1)
        XCTAssertEqual(plan.chordFrameStride, 1)
        XCTAssertEqual(plan.retainedSectionEnergyFrameCount, 60_000)
        XCTAssertTrue(plan.tempoResolutionSafe)
        XCTAssertTrue(plan.chordWindowRetentionSafe)
        XCTAssertTrue(plan.sectionResolutionSafe)

        let source = w31MusicalFixture(seconds: 18, sampleRate: 44_100)
        let configuration = MusicAnalysisConfiguration(
            minimumTempoConfidence: 0.05,
            minimumKeyConfidence: 0.001,
            minimumChordConfidence: 0.05,
            minimumChordTemplateScore: 0.50
        )
        let compatibilityReader = AnalysisPreparedSampleReader(signal: source)
        let compatibilityTempo = try StreamingBoundedTempoBeatAnalyzer.analyzeCancellable(
            reader: compatibilityReader,
            configuration: configuration
        )
        let compatibilityKey = try StreamingBoundedMusicalKeyAnalyzer.analyzeCancellable(
            reader: compatibilityReader,
            configuration: configuration
        )
        let compatibilityChords = try StreamingBoundedChordTimelineAnalyzer.analyzeCancellable(
            reader: compatibilityReader,
            configuration: configuration
        )
        let compatibilitySection = try AnalysisSectionEnergyFeatureExtractor.makeSignal(
            from: compatibilityReader
        )

        let singlePass = try AnalysisSinglePassPreparedPipeline.analyze(
            reader: AnalysisPreparedSampleReader(signal: source),
            configuration: configuration
        )
        XCTAssertEqual(singlePass.tempo, compatibilityTempo)
        XCTAssertEqual(singlePass.key, compatibilityKey)
        XCTAssertEqual(singlePass.chords, compatibilityChords)
        XCTAssertEqual(singlePass.sectionEnergySignal, compatibilitySection)
        XCTAssertFalse(singlePass.featureDiagnostics.extremeDurationCompressionApplied)
    }

    func testTwentyFourHourPlanBoundsTempoAndSectionButPreservesChordCadence() {
        let duration = 86_400.0
        let plan = AnalysisExtremeDurationRetentionPolicy.plan(
            sampleRate: 8_000,
            sampleCount: Int(8_000 * duration),
            durationSeconds: duration
        )
        XCTAssertTrue(plan.compressionApplied)
        XCTAssertEqual(plan.naturalTempoFrameCount, 8_639_996)
        XCTAssertEqual(plan.tempoFrameStride, 9)
        XCTAssertEqual(plan.retainedTempoFrameUpperBound, 960_000)
        XCTAssertTrue(plan.tempoResolutionSafe)
        XCTAssertEqual(plan.naturalChordFrameCount, 345_600)
        XCTAssertEqual(plan.chordFrameStride, 1)
        XCTAssertEqual(plan.retainedChordFrameUpperBound, 345_600)
        XCTAssertTrue(plan.chordWindowRetentionSafe)
        XCTAssertEqual(plan.naturalSectionEnergyFrameCount, 8_640_000)
        XCTAssertEqual(plan.retainedSectionEnergyFrameCount, 262_144)
        XCTAssertTrue(plan.sectionResolutionSafe)
        XCTAssertEqual(plan.suppressedDomains, [])
    }

    func testFortyEightHourTempoFailsClosedWhenNyquistUnsafe() {
        let duration = 172_800.0
        let plan = AnalysisExtremeDurationRetentionPolicy.plan(
            sampleRate: 8_000,
            sampleCount: Int(8_000 * duration),
            durationSeconds: duration
        )
        XCTAssertFalse(plan.tempoResolutionSafe)
        XCTAssertEqual(plan.retainedTempoFrameUpperBound, 0)
        XCTAssertTrue(plan.suppressedDomains.contains("TEMPO_ONSET"))
    }

    func testNinetySixHourChordFailsClosedWhenHopExceedsWindow() {
        let duration = 345_600.0
        let plan = AnalysisExtremeDurationRetentionPolicy.plan(
            sampleRate: 8_000,
            sampleCount: Int(8_000 * duration),
            durationSeconds: duration
        )
        XCTAssertEqual(plan.chordFrameStride, 3)
        XCTAssertFalse(plan.chordWindowRetentionSafe)
        XCTAssertEqual(plan.retainedChordFrameUpperBound, 1)
        XCTAssertTrue(plan.suppressedDomains.contains("CHORD_PREDECISION"))
    }

    func testThirtyDaySectionFailsClosedWhenMinimumSectionCannotBeRepresented() {
        let duration = 30.0 * 86_400.0
        let plan = AnalysisExtremeDurationRetentionPolicy.plan(
            sampleRate: 8_000,
            sampleCount: Int(8_000 * duration),
            durationSeconds: duration
        )
        XCTAssertFalse(plan.sectionResolutionSafe)
        XCTAssertEqual(plan.retainedSectionEnergyFrameCount, 0)
        XCTAssertTrue(plan.suppressedDomains.contains("SECTION_ENERGY"))
    }

    func testTwentyFourHourBudgetShrinksPreviousRetainedFeatureEstimate() {
        let budget = AnalysisExtremeDurationRetentionBudgetEstimator.estimate(
            sourceSampleRate: 44_100,
            durationSeconds: 86_400
        )
        XCTAssertEqual(budget.previousUnboundedEstimateBytes, 197_563_776)
        XCTAssertEqual(budget.estimatedMajorWorker4WorkingSetBytes, 41_172_416)
        XCTAssertEqual(budget.tempoOnsetAndMedianScratchBytes, 15_360_000)
        XCTAssertEqual(budget.chordDecisionRetentionBytes, 22_118_400)
        XCTAssertEqual(budget.sectionEnergyRetentionBytes, 1_048_576)
        XCTAssertGreaterThan(budget.previousToBoundedReductionRatio, 4.79)
        XCTAssertLessThan(budget.estimatedMajorWorker4WorkingSetBytes, 42_000_000)
    }

    func testRetentionPlanCapsHoldAcrossLongDurations() {
        for hours in [1, 6, 12, 24, 36, 48, 72, 96, 168] {
            let duration = Double(hours) * 3_600
            let plan = AnalysisExtremeDurationRetentionPolicy.plan(
                sampleRate: 8_000,
                sampleCount: Int(8_000 * duration),
                durationSeconds: duration
            )
            XCTAssertLessThanOrEqual(
                plan.retainedTempoFrameUpperBound,
                AnalysisExtremeDurationRetentionPolicy.maximumTempoFrames
            )
            XCTAssertLessThanOrEqual(
                plan.retainedChordFrameUpperBound,
                AnalysisExtremeDurationRetentionPolicy.maximumChordFrameDecisions
            )
            XCTAssertLessThanOrEqual(
                plan.retainedSectionEnergyFrameCount,
                AnalysisExtremeDurationRetentionPolicy.maximumSectionEnergyFrames
            )
        }
    }

    func testDiagnosticsCodecRetainsCompressionAndSafetyFlags() throws {
        let value = AnalysisSinglePassPreparedFeatureDiagnostics(
            preparedSampleCount: 10,
            preparedSampleRequests: 10,
            preparedSampleComputations: 10,
            preparedBlockLoads: 0,
            tempoOnsetCount: 0,
            keyWindowCount: 1,
            keyWindowSampleCount: 10,
            chordFrameDecisionCount: 1,
            sectionEnergyFrameCount: 0,
            maximumTempoRingSamples: 368,
            maximumChordRingSamples: 5_600,
            estimatedRetainedFeatureBytes: 256,
            exactSinglePreparedTraversal: true,
            extremeDurationCompressionApplied: true,
            tempoFrameStride: 17,
            chordFrameStride: 3,
            naturalSectionEnergyFrameCount: 1_000_000,
            sectionEnergyFrameStrideEquivalent: 4,
            tempoResolutionSafe: false,
            chordWindowRetentionSafe: false,
            sectionResolutionSafe: true
        )
        let data = try JSONEncoder().encode(value)
        XCTAssertEqual(try JSONDecoder().decode(AnalysisSinglePassPreparedFeatureDiagnostics.self, from: data), value)
    }

    func testPreCancelledPipelineStillFailsBeforePublication() async {
        let source = w31MusicalFixture(seconds: 8, sampleRate: 44_100)
        let task = Task {
            try AnalysisSinglePassPreparedPipeline.analyze(
                reader: AnalysisPreparedSampleReader(signal: source)
            )
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private func w31MusicalFixture(seconds: Double, sampleRate: Double) -> AnalysisSignal {
    let count = Int((seconds * sampleRate).rounded())
    let beatSpacing = max(1, Int((0.5 * sampleRate).rounded()))
    let clickLength = max(1, Int((0.010 * sampleRate).rounded()))
    let frequencies = [261.6256, 329.6276, 391.9954]
    var samples = Array(repeating: Float(0), count: count)
    for index in samples.indices {
        let time = Double(index) / sampleRate
        var value = frequencies.reduce(0.0) { partial, frequency in
            partial + 0.045 * sin(2 * Double.pi * frequency * time)
        }
        let phase = index % beatSpacing
        if phase < clickLength {
            value += 0.75 * (1 - Double(phase) / Double(clickLength))
        }
        samples[index] = Float(value)
    }
    return AnalysisSignal(sampleRate: sampleRate, monoSamples: samples)
}
