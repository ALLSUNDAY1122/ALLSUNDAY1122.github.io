import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisLongAudioHardeningTests: XCTestCase {
    func testPreparationDownsamplesHighRateAndSanitizesPathologicalSamples() {
        var samples = w11Sine(frequency: 440, seconds: 2, sampleRate: 44_100)
        samples[100] = .nan
        samples[101] = .infinity
        samples[102] = 100
        let source = AnalysisSignal(sampleRate: 44_100, monoSamples: samples)
        let result = AnalysisWorkingSetPolicy.prepare(signal: source)
        XCTAssertEqual(result.signal.sampleRate, 8_000)
        XCTAssertEqual(result.signal.durationSeconds, source.durationSeconds, accuracy: 0.001)
        XCTAssertTrue(result.signal.monoSamples.allSatisfy { $0.isFinite && abs($0) <= 16 })
        XCTAssertTrue(result.diagnostics.usedResampling)
        XCTAssertLessThan(result.signal.monoSamples.count, source.monoSamples.count / 5)
    }

    func testCleanEightKilohertzSignalIsNotResampled() {
        let source = AnalysisSignal(sampleRate: 8_000, monoSamples: w11Sine(frequency: 220, seconds: 2, sampleRate: 8_000))
        let result = AnalysisWorkingSetPolicy.prepare(signal: source)
        XCTAssertEqual(result.signal, source)
        XCTAssertFalse(result.diagnostics.usedResampling)
    }

    func testPreparationIsDeterministic() {
        let source = AnalysisSignal(sampleRate: 44_100, monoSamples: w11Sine(frequency: 330, seconds: 3, sampleRate: 44_100))
        XCTAssertEqual(AnalysisWorkingSetPolicy.prepare(signal: source).signal, AnalysisWorkingSetPolicy.prepare(signal: source).signal)
    }

    func testOneHourBudgetAvoidsLegacyWholeTrackDoubleAmplification() {
        let budget = AnalysisLongAudioPerformanceBenchmark.estimate(sourceSampleRate: 44_100, durationSeconds: 3_600)
        XCTAssertEqual(budget.analysisSampleRate, 8_000)
        XCTAssertEqual(budget.sourcePCMBytes, 635_040_000)
        XCTAssertEqual(budget.preparedPCMBytes, 115_200_000)
        XCTAssertEqual(budget.legacyWholeTrackDoubleBytes, 1_270_080_000)
        XCTAssertLessThan(budget.estimatedPeakAdditionalBytes, 120_000_000)
        XCTAssertGreaterThan(budget.estimatedPeakReductionRatio, 10)
    }

    func testBoundedTempoFindsSynthetic120BPM() throws {
        let signal = AnalysisSignal(sampleRate: 8_000, monoSamples: w11ClickTrack(bpm: 120, seconds: 20, sampleRate: 8_000))
        let configuration = MusicAnalysisConfiguration(minimumTempoConfidence: 0.05)
        let tempo = try XCTUnwrap(BoundedTempoBeatAnalyzer.analyze(signal: signal, configuration: configuration))
        XCTAssertEqual(tempo.bpm, 120, accuracy: 4)
        XCTAssertGreaterThanOrEqual(tempo.beatTimesSeconds.count, 20)
        XCTAssertTrue(zip(tempo.beatTimesSeconds, tempo.beatTimesSeconds.dropFirst()).allSatisfy { $0 < $1 })
    }

    func testBoundedTempoFailsClosedOnSustainedTone() {
        let signal = AnalysisSignal(sampleRate: 8_000, monoSamples: w11Sine(frequency: 440, seconds: 12, sampleRate: 8_000))
        XCTAssertNil(BoundedTempoBeatAnalyzer.analyze(signal: signal))
    }

    func testBoundedKeyFindsSyntheticCMajorWithoutWholeTrackDoubleBuffer() throws {
        let signal = AnalysisSignal(sampleRate: 8_000, monoSamples: w11Triad(rootMIDI: 60, minor: false, seconds: 8, sampleRate: 8_000))
        let configuration = MusicAnalysisConfiguration(minimumKeyConfidence: 0.001)
        let key = try XCTUnwrap(BoundedMusicalKeyAnalyzer.analyze(signal: signal, configuration: configuration))
        XCTAssertEqual(key.tonicPitchClass, 0)
        XCTAssertEqual(key.mode, "major")
    }

    func testBoundedChordTimelineIsGapFreeAndEndsAtDuration() throws {
        let signal = AnalysisSignal(sampleRate: 8_000, monoSamples: w11Triad(rootMIDI: 60, minor: false, seconds: 4, sampleRate: 8_000))
        let configuration = MusicAnalysisConfiguration(minimumChordConfidence: 0.05, minimumChordTemplateScore: 0.50)
        let chords = BoundedChordTimelineAnalyzer.analyze(signal: signal, configuration: configuration)
        XCTAssertFalse(chords.isEmpty)
        XCTAssertEqual(chords.first?.startSeconds, 0)
        XCTAssertEqual(try XCTUnwrap(chords.last).endSeconds, 4, accuracy: 1e-6)
        for index in 1..<chords.count {
            XCTAssertEqual(chords[index - 1].endSeconds, chords[index].startSeconds, accuracy: 1e-6)
        }
    }

    func testPreparationBenchmarkCanNeverSelfDeclareParity() {
        let signal = AnalysisSignal(sampleRate: 44_100, monoSamples: w11Sine(frequency: 220, seconds: 1, sampleRate: 44_100))
        let row = AnalysisLongAudioPerformanceBenchmark.benchmarkPreparation(signal: signal, syntheticOnly: true).row
        XCTAssertTrue(row.syntheticOnly)
        XCTAssertFalse(row.parityEligible)
        XCTAssertGreaterThanOrEqual(row.wallSeconds, 0)
    }
}

private func w11Sine(frequency: Double, seconds: Double, sampleRate: Double, amplitude: Double = 0.2) -> [Float] {
    let count = Int((seconds * sampleRate).rounded())
    return (0..<count).map { Float(amplitude * sin(2 * Double.pi * frequency * Double($0) / sampleRate)) }
}

private func w11ClickTrack(bpm: Double, seconds: Double, sampleRate: Double) -> [Float] {
    let count = Int((seconds * sampleRate).rounded())
    var output = Array(repeating: Float(0), count: count)
    let spacing = max(1, Int((60 / bpm * sampleRate).rounded()))
    let clickLength = max(1, Int((0.012 * sampleRate).rounded()))
    var start = 0
    while start < count {
        for offset in 0..<min(clickLength, count - start) { output[start + offset] += Float(0.8 * (1 - Double(offset) / Double(clickLength))) }
        start += spacing
    }
    return output
}

private func w11Triad(rootMIDI: Int, minor: Bool, seconds: Double, sampleRate: Double) -> [Float] {
    let intervals = minor ? [0, 3, 7] : [0, 4, 7]
    let count = Int((seconds * sampleRate).rounded())
    var output = Array(repeating: Float(0), count: count)
    for interval in intervals {
        let frequency = 440 * pow(2, Double(rootMIDI + interval - 69) / 12)
        for index in output.indices { output[index] += Float((0.18 / 3) * sin(2 * Double.pi * frequency * Double(index) / sampleRate)) }
    }
    return output
}
