import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisBoundedMemoryPipelineTests: XCTestCase {
    func testLazyReaderExactlyMatchesWholeTrackPreparationForResampledSignal() throws {
        var samples = w28Sine(frequency: 337, seconds: 3, sampleRate: 44_100)
        samples[11] = .nan
        samples[12] = .infinity
        samples[13] = 42
        let source = AnalysisSignal(sampleRate: 44_100, monoSamples: samples)
        let legacy = AnalysisWorkingSetPolicy.prepare(signal: source).signal
        let reader = AnalysisPreparedSampleReader(signal: source, blockSampleCount: 1_024)
        XCTAssertEqual(reader.sampleRate, legacy.sampleRate)
        XCTAssertEqual(reader.sampleCount, legacy.monoSamples.count)
        XCTAssertEqual(reader.durationSeconds, legacy.durationSeconds, accuracy: 1e-12)
        for index in legacy.monoSamples.indices {
            XCTAssertEqual(try reader.sample(at: index), legacy.monoSamples[index], "prepared sample mismatch at \(index)")
        }
    }

    func testLazyReaderMatchesSanitizationWithoutResampling() throws {
        var samples = w28Sine(frequency: 220, seconds: 2, sampleRate: 8_000)
        samples[20] = -.infinity
        samples[21] = -100
        let source = AnalysisSignal(sampleRate: 8_000, monoSamples: samples)
        let legacy = AnalysisWorkingSetPolicy.prepare(signal: source).signal
        let reader = AnalysisPreparedSampleReader(signal: source, blockSampleCount: 1_024)
        XCTAssertEqual(reader.sampleRate, 8_000)
        XCTAssertEqual(reader.sampleCount, samples.count)
        for index in legacy.monoSamples.indices {
            XCTAssertEqual(try reader.sample(at: index), legacy.monoSamples[index])
        }
    }

    func testStreamingTempoMatchesLegacyPreparedAnalyzer() throws {
        let source = AnalysisSignal(sampleRate: 44_100, monoSamples: w28ClickTrack(bpm: 120, seconds: 20, sampleRate: 44_100))
        let configuration = MusicAnalysisConfiguration(minimumTempoConfidence: 0.05)
        let prepared = AnalysisWorkingSetPolicy.prepare(signal: source).signal
        let legacy = try XCTUnwrap(BoundedTempoBeatAnalyzer.analyze(signal: prepared, configuration: configuration))
        let streaming = try XCTUnwrap(StreamingBoundedTempoBeatAnalyzer.analyzeCancellable(reader: AnalysisPreparedSampleReader(signal: source), configuration: configuration))
        XCTAssertEqual(streaming.bpm, legacy.bpm, accuracy: 1e-12)
        XCTAssertEqual(streaming.confidence ?? -1, legacy.confidence ?? -1, accuracy: 1e-12)
        XCTAssertEqual(streaming.beatTimesSeconds, legacy.beatTimesSeconds)
    }

    func testStreamingKeyMatchesLegacyPreparedAnalyzer() throws {
        let source = AnalysisSignal(sampleRate: 44_100, monoSamples: w28Triad(rootMIDI: 60, minor: false, seconds: 8, sampleRate: 44_100))
        let configuration = MusicAnalysisConfiguration(minimumKeyConfidence: 0.001)
        let prepared = AnalysisWorkingSetPolicy.prepare(signal: source).signal
        let legacy = try XCTUnwrap(BoundedMusicalKeyAnalyzer.analyze(signal: prepared, configuration: configuration))
        let streaming = try XCTUnwrap(StreamingBoundedMusicalKeyAnalyzer.analyzeCancellable(reader: AnalysisPreparedSampleReader(signal: source), configuration: configuration))
        XCTAssertEqual(streaming.tonicPitchClass, legacy.tonicPitchClass)
        XCTAssertEqual(streaming.mode, legacy.mode)
        XCTAssertEqual(streaming.confidence ?? -1, legacy.confidence ?? -1, accuracy: 1e-12)
    }

    func testStreamingChordTimelineMatchesLegacyPreparedAnalyzer() throws {
        let source = AnalysisSignal(sampleRate: 44_100, monoSamples: w28Triad(rootMIDI: 60, minor: false, seconds: 5, sampleRate: 44_100))
        let configuration = MusicAnalysisConfiguration(minimumChordConfidence: 0.05, minimumChordTemplateScore: 0.50)
        let prepared = AnalysisWorkingSetPolicy.prepare(signal: source).signal
        let legacy = BoundedChordTimelineAnalyzer.analyze(signal: prepared, configuration: configuration)
        let streaming = try StreamingBoundedChordTimelineAnalyzer.analyzeCancellable(reader: AnalysisPreparedSampleReader(signal: source), configuration: configuration)
        XCTAssertEqual(streaming, legacy)
    }

    func testSectionEnergyFeaturePreservesDeterministicBoundaryFixture() throws {
        let sampleRate = 8_000.0
        let seconds = 48
        var samples = Array(repeating: Float(0.05), count: Int(sampleRate) * seconds)
        for index in (Int(sampleRate) * 16)..<(Int(sampleRate) * 32) { samples[index] = 0.25 }
        let source = AnalysisSignal(sampleRate: sampleRate, monoSamples: samples)
        let reader = AnalysisPreparedSampleReader(signal: source)
        let feature = try AnalysisSectionEnergyFeatureExtractor.makeSignal(from: reader)
        XCTAssertEqual(feature.durationSeconds, source.durationSeconds, accuracy: 1e-9)
        XCTAssertEqual(feature.sampleRate, 100, accuracy: 1e-9)

        let chords = stride(from: 0.0, to: 48.0, by: 4.0).map {
            ChordEvent(startSeconds: $0, endSeconds: min(48, $0 + 4), normalizedLabel: "C", confidence: 0.9)
        }
        let legacyDetected = try CancellableSongSectionPipeline.analyze(signal: source, chords: chords)
        let legacy = try SongSectionBoundaryHardener.harden(sections: legacyDetected, signal: source, chords: chords)
        let boundedDetected = try CancellableSongSectionPipeline.analyze(signal: feature, chords: chords)
        let bounded = try SongSectionBoundaryHardener.harden(sections: boundedDetected, signal: feature, chords: chords)
        XCTAssertEqual(bounded.map(\.structuralLabel), legacy.map(\.structuralLabel))
        XCTAssertEqual(bounded.map(\.functionalLabel), legacy.map(\.functionalLabel))
        XCTAssertEqual(bounded.count, legacy.count)
        for (lhs, rhs) in zip(bounded, legacy) {
            XCTAssertEqual(lhs.startSeconds, rhs.startSeconds, accuracy: 0.011)
            XCTAssertEqual(lhs.endSeconds, rhs.endSeconds, accuracy: 0.011)
        }
    }

    func testOneHourBudgetRemovesWholeTrackPreparedPCMAllocation() {
        let reader = AnalysisPreparedSampleReader.estimate(sourceSampleRate: 44_100, durationSeconds: 3_600)
        XCTAssertEqual(reader.sourcePCMBytes, 635_040_000)
        XCTAssertEqual(reader.logicalPreparedPCMBytes, 115_200_000)
        XCTAssertEqual(reader.maximumCachedPreparedPCMBytes, 131_072)
        XCTAssertEqual(reader.sectionEnergyFeaturePCMBytesEstimate, 1_440_000)

        let budget = AnalysisBoundedMemoryBudget.estimate(sourceSampleRate: 44_100, durationSeconds: 3_600)
        XCTAssertEqual(budget.avoidedWholeTrackPreparedPCMBytes, 115_200_000)
        XCTAssertLessThan(budget.estimatedMajorAdditionalWorkingSetBytes, 11_000_000)
        XCTAssertGreaterThan(budget.preparedToMajorAdditionalReductionRatio, 11)
        XCTAssertEqual(budget.sourcePCMBytes, 635_040_000, "source loader memory is deliberately not hidden by W28")
    }

    func testTwentyFourHourBudgetStaysFeatureBoundedRatherThanPreparedPCMBound() {
        let budget = AnalysisBoundedMemoryBudget.estimate(sourceSampleRate: 44_100, durationSeconds: 86_400)
        XCTAssertEqual(budget.avoidedWholeTrackPreparedPCMBytes, 2_764_800_000)
        XCTAssertLessThan(budget.estimatedMajorAdditionalWorkingSetBytes, 200_000_000)
        XCTAssertGreaterThan(budget.preparedToMajorAdditionalReductionRatio, 14)
    }

    func testSectionFeatureExtractionHonorsPreCancellation() async {
        let source = AnalysisSignal(sampleRate: 44_100, monoSamples: w28Sine(frequency: 220, seconds: 10, sampleRate: 44_100))
        let task = Task { () throws -> AnalysisSignal in
            try await Task.sleep(for: .milliseconds(1))
            return try AnalysisSectionEnergyFeatureExtractor.makeSignal(from: AnalysisPreparedSampleReader(signal: source))
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("cancelled bounded-memory feature extraction must not publish a signal")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("expected CancellationError, got \(error)")
        }
    }
}

private func w28Sine(frequency: Double, seconds: Double, sampleRate: Double, amplitude: Double = 0.2) -> [Float] {
    let count = Int((seconds * sampleRate).rounded())
    return (0..<count).map { Float(amplitude * sin(2 * Double.pi * frequency * Double($0) / sampleRate)) }
}

private func w28ClickTrack(bpm: Double, seconds: Double, sampleRate: Double) -> [Float] {
    let count = Int((seconds * sampleRate).rounded())
    var output = Array(repeating: Float(0), count: count)
    let spacing = max(1, Int((60 / bpm * sampleRate).rounded()))
    let clickLength = max(1, Int((0.012 * sampleRate).rounded()))
    var start = 0
    while start < count {
        for offset in 0..<min(clickLength, count - start) {
            output[start + offset] += Float(0.8 * (1 - Double(offset) / Double(clickLength)))
        }
        start += spacing
    }
    return output
}

private func w28Triad(rootMIDI: Int, minor: Bool, seconds: Double, sampleRate: Double) -> [Float] {
    let intervals = minor ? [0, 3, 7] : [0, 4, 7]
    let count = Int((seconds * sampleRate).rounded())
    var output = Array(repeating: Float(0), count: count)
    for interval in intervals {
        let frequency = 440 * pow(2, Double(rootMIDI + interval - 69) / 12)
        for index in output.indices {
            output[index] += Float((0.18 / 3) * sin(2 * Double.pi * frequency * Double(index) / sampleRate))
        }
    }
    return output
}
