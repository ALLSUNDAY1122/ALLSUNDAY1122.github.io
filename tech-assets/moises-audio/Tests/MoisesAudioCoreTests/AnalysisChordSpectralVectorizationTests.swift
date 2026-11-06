import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisChordSpectralVectorizationTests: XCTestCase {
    func testInterleavedSpectralEvidenceMatchesReferenceBitForBit() {
        let sampleRate = 8_000.0
        let sampleCount = 5_600
        var workspace = AnalysisReusableChordSpectralWorkspace(
            sampleRate: sampleRate,
            windowSampleCount: sampleCount
        )

        for fixture in 0..<24 {
            let samples = makeFixture(index: fixture, sampleCount: sampleCount, sampleRate: sampleRate)
            let reference = AnalysisChordSpectralEvidenceComputer.compute(
                samples: samples,
                workspace: &workspace,
                backend: .referencePerBin
            )
            let vectorized = AnalysisChordSpectralEvidenceComputer.compute(
                samples: samples,
                workspace: &workspace,
                backend: .interleavedMultiBin
            )

            XCTAssertEqual(reference.bassPitchClass, vectorized.bassPitchClass)
            XCTAssertEqual(reference.bassDominance.bitPattern, vectorized.bassDominance.bitPattern)
            XCTAssertEqual(reference.chroma.count, 12)
            XCTAssertEqual(vectorized.chroma.count, 12)
            for pitchClass in 0..<12 {
                XCTAssertEqual(
                    reference.chroma[pitchClass].bitPattern,
                    vectorized.chroma[pitchClass].bitPattern,
                    "fixture=\(fixture) pitchClass=\(pitchClass)"
                )
            }
        }
    }

    func testProductionVectorizedClassifierMatchesLegacyLabelAndConfidenceExactly() {
        let sampleRate = 8_000.0
        let sampleCount = 5_600
        let configuration = MusicAnalysisConfiguration(
            minimumChordConfidence: 0.02,
            minimumChordTemplateScore: 0.40
        )
        var workspace = AnalysisReusableChordSpectralWorkspace(
            sampleRate: sampleRate,
            windowSampleCount: sampleCount
        )

        for fixture in 0..<48 {
            let samples = makeFixture(index: fixture, sampleCount: sampleCount, sampleRate: sampleRate)
            let legacy = ChordFrameClassifier.classify(
                samples: samples,
                sampleRate: sampleRate,
                configuration: configuration,
                vocabulary: .conservativeMajorMinor
            )
            let vectorized = AnalysisReusableChordFrameClassifier.classify(
                samples: samples,
                workspace: &workspace,
                sampleRate: sampleRate,
                configuration: configuration,
                vocabulary: .conservativeMajorMinor
            )
            XCTAssertEqual(vectorized.label, legacy.label, "fixture=\(fixture)")
            XCTAssertEqual(
                vectorized.confidence?.bitPattern,
                legacy.confidence?.bitPattern,
                "fixture=\(fixture)"
            )
        }
        XCTAssertEqual(workspace.classificationCount, 48)
    }

    func testOneHourBudgetCutsWindowTraversalsWithoutChangingRecurrenceCountOrCadence() {
        let budget = AnalysisChordSpectralVectorizationBudgetEstimator.estimate(
            sourceSampleRate: 44_100,
            durationSeconds: 3_600
        )
        XCTAssertEqual(budget.analysisSampleRate, 8_000)
        XCTAssertEqual(budget.chordWindowSamples, 5_600)
        XCTAssertEqual(budget.chordHopSamples, 2_000)
        XCTAssertEqual(budget.chordFrameCount, 14_400)
        XCTAssertEqual(budget.activeSpectralBinCount, 48)
        XCTAssertEqual(budget.referenceWindowElementVisits, 3_870_720_000)
        XCTAssertEqual(budget.interleavedWindowElementVisits, 80_640_000)
        XCTAssertEqual(budget.recurrenceUpdates, 3_870_720_000)
        XCTAssertEqual(budget.windowTraversalReductionRatio, 48)
    }

    func testWorkspaceMismatchStillFallsBackToLegacy() {
        let samples = makeFixture(index: 7, sampleCount: 2_048, sampleRate: 8_000)
        let configuration = MusicAnalysisConfiguration()
        var workspace = AnalysisReusableChordSpectralWorkspace(
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
            workspace: &workspace,
            sampleRate: 8_000,
            configuration: configuration
        )
        XCTAssertEqual(fallback.label, legacy.label)
        XCTAssertEqual(fallback.confidence?.bitPattern, legacy.confidence?.bitPattern)
        XCTAssertEqual(workspace.classificationCount, 0)
    }

    private func makeFixture(index: Int, sampleCount: Int, sampleRate: Double) -> [Double] {
        let roots = [110.0, 130.81278265, 146.83238396, 164.81377846, 196.0, 220.0]
        let root = roots[index % roots.count]
        let minor = index % 3 == 1
        let third = root * pow(2, (minor ? 3.0 : 4.0) / 12.0)
        let fifth = root * pow(2, 7.0 / 12.0)
        return (0..<sampleCount).map { sampleIndex in
            let time = Double(sampleIndex) / sampleRate
            let deterministicNoise = Double((sampleIndex * 31 + index * 17) % 97) / 97_000.0
            return 0.72 * sin(2 * Double.pi * root * time)
                + 0.54 * sin(2 * Double.pi * third * time)
                + 0.48 * sin(2 * Double.pi * fifth * time)
                + deterministicNoise
        }
    }
}
