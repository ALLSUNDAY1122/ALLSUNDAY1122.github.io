import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisSinglePassPreparedPipelineTests: XCTestCase {
    func testSinglePassPipelineMatchesW28CompatibilityOutputs() throws {
        let source = w29MusicalFixture(seconds: 24, sampleRate: 44_100)
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
        let compatibilitySectionSignal = try AnalysisSectionEnergyFeatureExtractor.makeSignal(
            from: compatibilityReader
        )

        let singlePassReader = AnalysisPreparedSampleReader(signal: source)
        let singlePass = try AnalysisSinglePassPreparedPipeline.analyze(
            reader: singlePassReader,
            configuration: configuration
        )

        XCTAssertEqual(singlePass.tempo, compatibilityTempo)
        XCTAssertEqual(singlePass.key, compatibilityKey)
        XCTAssertEqual(singlePass.chords, compatibilityChords)
        XCTAssertEqual(singlePass.sectionEnergySignal, compatibilitySectionSignal)
        XCTAssertTrue(singlePass.featureDiagnostics.exactSinglePreparedTraversal)
        XCTAssertEqual(singlePass.featureDiagnostics.preparedSampleRequests, singlePassReader.sampleCount)
        XCTAssertEqual(singlePass.featureDiagnostics.preparedSampleComputations, singlePassReader.sampleCount)
        XCTAssertGreaterThan(compatibilityReader.preparedSampleComputationCount, singlePassReader.preparedSampleComputationCount)
    }

    func testFeatureExtractorPreservesPathologicalPreparedSemantics() throws {
        var samples = w29MusicalFixture(seconds: 6, sampleRate: 44_100).monoSamples
        samples[101] = .nan
        samples[202] = .infinity
        samples[303] = -100
        let source = AnalysisSignal(sampleRate: 44_100, monoSamples: samples)

        let materialized = AnalysisWorkingSetPolicy.prepare(signal: source).signal
        let reader = AnalysisPreparedSampleReader(signal: source)
        let features = try AnalysisSinglePassPreparedFeatureExtractor.extract(reader: reader)

        XCTAssertEqual(reader.sampleRate, materialized.sampleRate)
        XCTAssertEqual(reader.sampleCount, materialized.monoSamples.count)
        XCTAssertTrue(features.diagnostics.exactSinglePreparedTraversal)
        for index in stride(from: 0, to: materialized.monoSamples.count, by: 997) {
            XCTAssertEqual(try reader.sample(at: index), materialized.monoSamples[index])
        }
    }

    func testSectionEnergyFeatureMatchesCompatibilityExtractor() throws {
        let source = w29EnergyStepFixture(seconds: 12, sampleRate: 44_100)
        let compatibilityReader = AnalysisPreparedSampleReader(signal: source)
        let compatibility = try AnalysisSectionEnergyFeatureExtractor.makeSignal(from: compatibilityReader)
        let reader = AnalysisPreparedSampleReader(signal: source)
        let features = try AnalysisSinglePassPreparedFeatureExtractor.extract(reader: reader)

        XCTAssertEqual(features.sectionEnergySignal, compatibility)
        XCTAssertEqual(features.sectionEnergySignal.durationSeconds, reader.durationSeconds, accuracy: 1e-9)
    }

    func testOneHourBudgetKeepsPreparedPCMEliminated() {
        let budget = AnalysisSinglePassPreparedBudget.estimate(
            sourceSampleRate: 44_100,
            durationSeconds: 3_600
        )
        XCTAssertEqual(budget.sourcePCMBytes, 635_040_000)
        XCTAssertEqual(budget.avoidedWholeTrackPreparedPCMBytes, 115_200_000)
        XCTAssertEqual(budget.logicalPreparedSamplesPerSinglePass, 28_800_000)
        XCTAssertEqual(budget.estimatedMajorAdditionalWorkingSetBytes, 10_766_976)
        XCTAssertGreaterThan(budget.preparedToMajorAdditionalReductionRatio, 10)
        XCTAssertLessThan(budget.estimatedMajorAdditionalWorkingSetBytes, 11_000_000)
    }

    func testTwentyFourHourBudgetDoesNotReintroducePreparedPCM() {
        let budget = AnalysisSinglePassPreparedBudget.estimate(
            sourceSampleRate: 44_100,
            durationSeconds: 86_400
        )
        XCTAssertEqual(budget.avoidedWholeTrackPreparedPCMBytes, 2_764_800_000)
        XCTAssertEqual(budget.estimatedMajorAdditionalWorkingSetBytes, 197_563_776)
        XCTAssertGreaterThan(budget.preparedToMajorAdditionalReductionRatio, 13)
    }

    func testPreCancelledSinglePassFailsBeforePublication() async {
        let source = w29MusicalFixture(seconds: 8, sampleRate: 44_100)
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

private func w29MusicalFixture(seconds: Double, sampleRate: Double) -> AnalysisSignal {
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

private func w29EnergyStepFixture(seconds: Double, sampleRate: Double) -> AnalysisSignal {
    let count = Int((seconds * sampleRate).rounded())
    var samples = Array(repeating: Float(0), count: count)
    for index in samples.indices {
        let time = Double(index) / sampleRate
        let amplitude = time < seconds / 2 ? 0.04 : 0.20
        samples[index] = Float(amplitude * sin(2 * Double.pi * 220 * time))
    }
    return AnalysisSignal(sampleRate: sampleRate, monoSamples: samples)
}
