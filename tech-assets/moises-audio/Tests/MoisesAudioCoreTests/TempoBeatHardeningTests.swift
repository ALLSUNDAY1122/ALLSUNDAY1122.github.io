import Foundation
import XCTest
@testable import MoisesAudioCore

final class TempoBeatHardeningTests: XCTestCase {
    func testWeakSubdivisionsDoNotDouble75BPM() throws {
        let fixture = makePulseFixture(duration: 20, bpm: 75, beatAmplitudes: [0.85], subdivisionAmplitude: 0.20)
        let tempo = try XCTUnwrap(TempoBeatAnalyzer.analyze(signal: fixture.signal))
        XCTAssertLessThan(abs(tempo.bpm - 75) / 75, 0.04)
        XCTAssertGreaterThan(AnalysisBenchmarkRunner.beatFMeasure(reference: fixture.beats, estimated: tempo.beatTimesSeconds), 0.90)
    }

    func testAlternatingAccentDoesNotCollapse150To75() throws {
        let fixture = makePulseFixture(duration: 20, bpm: 150, beatAmplitudes: [0.90, 0.55])
        let tempo = try XCTUnwrap(TempoBeatAnalyzer.analyze(signal: fixture.signal))
        XCTAssertLessThan(abs(tempo.bpm - 150) / 150, 0.04)
        XCTAssertGreaterThan(AnalysisBenchmarkRunner.beatFMeasure(reference: fixture.beats, estimated: tempo.beatTimesSeconds), 0.90)
    }

    func testLinearTempoDriftAdaptsBeatGridAndReportsMedianTempo() throws {
        let fixture = makeTempoRampFixture(duration: 30, startBPM: 100, endBPM: 130)
        let tempo = try XCTUnwrap(TempoBeatAnalyzer.analyze(signal: fixture.signal))
        XCTAssertGreaterThan(tempo.bpm, 108)
        XCTAssertLessThan(tempo.bpm, 123)
        XCTAssertGreaterThan(AnalysisBenchmarkRunner.beatFMeasure(reference: fixture.beats, estimated: tempo.beatTimesSeconds), 0.90)

        let intervals = zip(tempo.beatTimesSeconds.dropFirst(), tempo.beatTimesSeconds).map(-)
        let quarter = max(2, intervals.count / 4)
        let early = intervals.prefix(quarter).reduce(0, +) / Double(quarter)
        let late = intervals.suffix(quarter).reduce(0, +) / Double(quarter)
        XCTAssertGreaterThan(early, late, "Adaptive tracking should shorten the beat period as the source accelerates")
    }

    func testWeakPercussionSurvivesTonalBedAndDeterministicNoise() throws {
        let fixture = makePulseFixture(duration: 24, bpm: 96, beatAmplitudes: [0.12], noiseAmplitude: 0.004)
        let tempo = try XCTUnwrap(TempoBeatAnalyzer.analyze(signal: fixture.signal))
        XCTAssertLessThan(abs(tempo.bpm - 96) / 96, 0.04)
        XCTAssertGreaterThan(AnalysisBenchmarkRunner.beatFMeasure(reference: fixture.beats, estimated: tempo.beatTimesSeconds), 0.80)
    }

    func testCommonMeterAmbiguityFailsClosedInsteadOfReturningConfidentWrongTempo() {
        let fixture = makePulseFixture(duration: 20, bpm: 90, beatAmplitudes: [0.70], subdivisionAmplitude: 0.70)
        XCTAssertNil(TempoBeatAnalyzer.analyze(signal: fixture.signal))
    }

    func testSyncopatedGhostNotesPreserveTempoRate() throws {
        let fixture = makePulseFixture(
            duration: 20,
            bpm: 120,
            beatAmplitudes: [0.42],
            subdivisionAmplitude: 0.55,
            subdivisionFraction: 0.65
        )
        let tempo = try XCTUnwrap(TempoBeatAnalyzer.analyze(signal: fixture.signal))
        XCTAssertLessThan(abs(tempo.bpm - 120) / 120, 0.04)
        XCTAssertGreaterThan(tempo.confidence ?? 0, 0.30)
    }

    func testRelaxedWeakPercussionGateStillRejectsSustainedTone() {
        let sampleRate = 8_000.0
        let count = Int(sampleRate * 8)
        let samples = (0..<count).map { index -> Float in
            let time = Double(index) / sampleRate
            return Float(0.2 * sin(2 * Double.pi * 261.6256 * time))
        }
        XCTAssertNil(TempoBeatAnalyzer.analyze(signal: AnalysisSignal(sampleRate: sampleRate, monoSamples: samples)))
    }
}

private struct TempoHardeningFixture {
    let signal: AnalysisSignal
    let beats: [Double]
}

private func makePulseFixture(
    duration: Double,
    bpm: Double,
    beatAmplitudes: [Double],
    subdivisionAmplitude: Double? = nil,
    subdivisionFraction: Double = 0.5,
    noiseAmplitude: Double = 0
) -> TempoHardeningFixture {
    let sampleRate = 8_000.0
    let count = Int(duration * sampleRate)
    var samples = Array(repeating: Float(0), count: count)
    for index in 0..<count {
        let time = Double(index) / sampleRate
        let tonal = 0.04 * sin(2 * Double.pi * 220 * time)
            + 0.04 * sin(2 * Double.pi * 277.18 * time)
            + 0.04 * sin(2 * Double.pi * 329.63 * time)
        let deterministicNoise = noiseAmplitude
            * sin(2 * Double.pi * 997 * time)
            * sin(2 * Double.pi * 431 * time)
        samples[index] = Float(tonal + deterministicNoise)
    }

    let period = 60 / bpm
    var beats: [Double] = []
    var beatIndex = 0
    while Double(beatIndex) * period < duration {
        let time = Double(beatIndex) * period
        beats.append(time)
        addTempoPulse(&samples, sampleRate: sampleRate, time: time, amplitude: beatAmplitudes[beatIndex % beatAmplitudes.count])
        if let subdivisionAmplitude {
            let subdivisionTime = time + period * subdivisionFraction
            if subdivisionTime < duration {
                addTempoPulse(&samples, sampleRate: sampleRate, time: subdivisionTime, amplitude: subdivisionAmplitude)
            }
        }
        beatIndex += 1
    }
    return TempoHardeningFixture(signal: AnalysisSignal(sampleRate: sampleRate, monoSamples: samples), beats: beats)
}

private func makeTempoRampFixture(duration: Double, startBPM: Double, endBPM: Double) -> TempoHardeningFixture {
    let sampleRate = 8_000.0
    let count = Int(duration * sampleRate)
    var samples = Array(repeating: Float(0), count: count)
    for index in 0..<count {
        let time = Double(index) / sampleRate
        samples[index] = Float(
            0.04 * sin(2 * Double.pi * 220 * time)
                + 0.04 * sin(2 * Double.pi * 277.18 * time)
                + 0.002 * sin(2 * Double.pi * 911 * time)
        )
    }

    var beats = [0.0]
    var time = 0.0
    while true {
        let fraction = min(1, time / duration)
        let bpm = startBPM + (endBPM - startBPM) * fraction
        time += 60 / bpm
        if time >= duration { break }
        beats.append(time)
    }
    for beat in beats {
        addTempoPulse(&samples, sampleRate: sampleRate, time: beat, amplitude: 0.70)
    }
    return TempoHardeningFixture(signal: AnalysisSignal(sampleRate: sampleRate, monoSamples: samples), beats: beats)
}

private func addTempoPulse(_ samples: inout [Float], sampleRate: Double, time: Double, amplitude: Double) {
    let start = max(0, Int((time * sampleRate).rounded(.down)))
    guard start < samples.count else { return }
    let length = max(1, Int((0.018 * sampleRate).rounded()))
    let end = min(samples.count, start + length)
    for index in start..<end {
        let phase = Double(index - start) / Double(length)
        samples[index] += Float(amplitude * (1 - phase))
    }
}
