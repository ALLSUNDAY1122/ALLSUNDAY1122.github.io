import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisCPUDutyCycleTests: XCTestCase {
    func testRollingTempoEnergyMatchesReferenceRescanWithinFloatingNoise() {
        let frameSize = 368
        let hopSize = 80
        let sampleCount = 240_000
        var reference = AnalysisTempoFrameEnergyTracker(
            frameSize: frameSize,
            hopSize: hopSize,
            mode: .referenceRescan
        )
        var rolling = AnalysisTempoFrameEnergyTracker(
            frameSize: frameSize,
            hopSize: hopSize,
            mode: .rollingReuse
        )
        var frameCount = 0
        var maximumAbsoluteDelta = 0.0

        for index in 0..<sampleCount {
            let time = Double(index) / 8_000
            let transient = index % 4_000 < 20 ? 0.65 : 0
            let value = Float(
                0.15 * sin(2 * Double.pi * 220 * time)
                    + 0.06 * cos(2 * Double.pi * 329.6276 * time)
                    + transient
            )
            let square = Double(value) * Double(value)
            let expected = reference.consume(value, precomputedSquare: square, at: index)
            let actual = rolling.consume(value, precomputedSquare: square, at: index)
            XCTAssertEqual(expected == nil, actual == nil)
            if let expected, let actual {
                frameCount += 1
                maximumAbsoluteDelta = max(maximumAbsoluteDelta, abs(expected - actual))
            }
        }

        XCTAssertGreaterThan(frameCount, 2_000)
        XCTAssertLessThan(maximumAbsoluteDelta, 1e-11)
        XCTAssertLessThan(
            rolling.rollingSquareUpdates + rolling.referenceSquareTerms,
            reference.referenceSquareTerms
        )
    }

    func testOrdinaryDurationBudgetKeepsHistoricalTempoRescanMode() {
        let budget = AnalysisLongAudioCPUDutyBudgetEstimator.estimate(
            sourceSampleRate: 44_100,
            durationSeconds: 600
        )
        XCTAssertFalse(budget.tempoUsesRollingReuse)
        XCTAssertEqual(
            budget.baselineTempoWindowSquareTerms,
            budget.rollingTempoSquareUpdatesUpperBound
        )
        XCTAssertEqual(budget.rollingTempoPeriodicRebaseSquareTermsUpperBound, 0)
        XCTAssertEqual(budget.tempoSquareTermReductionRatio, 1)
    }

    func testOneHourBudgetReducesTempoRescanTermsWithoutReducingChordCadence() {
        let budget = AnalysisLongAudioCPUDutyBudgetEstimator.estimate(
            sourceSampleRate: 44_100,
            durationSeconds: 3_600
        )
        XCTAssertTrue(budget.tempoUsesRollingReuse)
        XCTAssertEqual(budget.analysisSampleRate, 8_000)
        XCTAssertEqual(budget.tempoFrameSize, 368)
        XCTAssertEqual(budget.tempoNaturalFrameCount, 359_996)
        XCTAssertEqual(budget.baselineTempoWindowSquareTerms, 132_478_528)
        XCTAssertEqual(budget.rollingTempoSquareUpdatesUpperBound, 57_599_632)
        XCTAssertEqual(budget.rollingTempoPeriodicRebaseSquareTermsUpperBound, 64_768)
        XCTAssertGreaterThan(budget.tempoSquareTermReductionRatio, 2.29)

        XCTAssertEqual(budget.chordWindowSamples, 5_600)
        XCTAssertEqual(budget.chordFrameCount, 14_400)
        XCTAssertEqual(budget.chordSpectralBinCount, 48)
        XCTAssertEqual(budget.baselineChordSetupTranscendentalEvaluations, 82_022_400)
        XCTAssertEqual(budget.reusedChordSetupTranscendentalEvaluations, 5_696)
        XCTAssertEqual(budget.chordSetupTranscendentalReductionRatio, 14_400)
        XCTAssertEqual(budget.goertzelSampleIterationsUnchanged, 3_870_720_000)
    }

    func testReusableChordWorkspaceExactlyMatchesLegacyClassifier() {
        let configuration = MusicAnalysisConfiguration(
            minimumChordConfidence: 0.02,
            minimumChordTemplateScore: 0.40
        )
        let sampleRate = 8_000.0
        let windowCount = 5_600
        var workspace = AnalysisReusableChordSpectralWorkspace(
            sampleRate: sampleRate,
            windowSampleCount: windowCount
        )

        let frequencySets: [[Double]] = [
            [261.6256, 329.6276, 391.9954],
            [220.0000, 261.6256, 329.6276],
            [293.6648, 369.9944, 440.0000],
            [164.8138, 196.0000, 246.9417],
            [130.8128, 164.8138, 195.9977],
            [196.0000, 246.9417, 293.6648]
        ]

        for (fixtureIndex, frequencies) in frequencySets.enumerated() {
            let samples = (0..<windowCount).map { index -> Double in
                let time = Double(index + fixtureIndex * 317) / sampleRate
                return frequencies.enumerated().reduce(0.0) { partial, item in
                    partial + (0.11 - Double(item.offset) * 0.018)
                        * sin(2 * Double.pi * item.element * time)
                }
            }
            let legacy = ChordFrameClassifier.classify(
                samples: samples,
                sampleRate: sampleRate,
                configuration: configuration,
                vocabulary: .conservativeMajorMinor
            )
            let reused = AnalysisReusableChordFrameClassifier.classify(
                samples: samples,
                workspace: &workspace,
                sampleRate: sampleRate,
                configuration: configuration,
                vocabulary: .conservativeMajorMinor
            )
            XCTAssertEqual(reused.label, legacy.label)
            XCTAssertEqual(reused.confidence, legacy.confidence)
        }
        XCTAssertEqual(workspace.classificationCount, frequencySets.count)
    }

    func testReusableChordWorkspaceMismatchFallsBackToLegacy() {
        let configuration = MusicAnalysisConfiguration()
        let samples = (0..<2_048).map { index in
            0.1 * sin(2 * Double.pi * 220 * Double(index) / 8_000)
        }
        var wrongWorkspace = AnalysisReusableChordSpectralWorkspace(
            sampleRate: 8_000,
            windowSampleCount: 5_600
        )
        let legacy = ChordFrameClassifier.classify(
            samples: samples,
            sampleRate: 8_000,
            configuration: configuration
        )
        let fallback = AnalysisReusableChordFrameClassifier.classify(
            samples: samples,
            workspace: &wrongWorkspace,
            sampleRate: 8_000,
            configuration: configuration
        )
        XCTAssertEqual(fallback.label, legacy.label)
        XCTAssertEqual(fallback.confidence, legacy.confidence)
        XCTAssertEqual(wrongWorkspace.classificationCount, 0)
    }
}
