import Foundation
import XCTest
@testable import MoisesAudioCore

final class MusicalKeyHardeningTests: XCTestCase {
    func testClearMajorMinorAndTransposedMajorRemainDecided() throws {
        let cMajor = try XCTUnwrap(MusicalKeyAnalyzer.analyze(signal: makeKeySignal(segments: [([60, 64, 67], 12)])))
        XCTAssertEqual(cMajor.tonicPitchClass, 0)
        XCTAssertEqual(cMajor.mode, "major")
        XCTAssertGreaterThan(cMajor.confidence ?? 0, 0.50)

        let aMinor = try XCTUnwrap(MusicalKeyAnalyzer.analyze(signal: makeKeySignal(segments: [([57, 60, 64], 12)])))
        XCTAssertEqual(aMinor.tonicPitchClass, 9)
        XCTAssertEqual(aMinor.mode, "minor")
        XCTAssertGreaterThan(aMinor.confidence ?? 0, 0.50)

        let dMajor = try XCTUnwrap(MusicalKeyAnalyzer.analyze(signal: makeKeySignal(segments: [([62, 66, 69], 12)])))
        XCTAssertEqual(dMajor.tonicPitchClass, 2)
        XCTAssertEqual(dMajor.mode, "major")
    }

    func testRelativeMajorMinorScaleWithoutTonicEvidenceFailsClosed() {
        let cMajorPitchClasses = [0, 2, 4, 5, 7, 9, 11]
        let signal = makeKeySignal(segments: [(midis(forPitchClasses: cMajorPitchClasses, near: 60), 12)])
        XCTAssertNil(
            MusicalKeyAnalyzer.analyze(signal: signal),
            "C major and A minor share the same pitch collection; without tonic evidence the analyzer must not force either label"
        )
    }

    func testRootedDorianAndMixolydianSignaturesFailClosedUntilReferenceVocabularyIsVerified() {
        let dDorian = makeWeightedKeySignal(
            tones: [(62, 2.0), (65, 1.4), (69, 1.0), (71, 1.6), (72, 0.8), (64, 0.6)],
            duration: 12
        )
        XCTAssertNil(MusicalKeyAnalyzer.analyze(signal: dDorian))

        let gMixolydian = makeWeightedKeySignal(
            tones: [(55, 2.0), (59, 1.4), (62, 1.0), (65, 1.7), (57, 0.7), (60, 0.6)],
            duration: 12
        )
        XCTAssertNil(MusicalKeyAnalyzer.analyze(signal: gMixolydian))
    }

    func testStrongMidTrackModulationFailsClosedInsteadOfReturningOnlyTheLastKey() {
        let cMajor = midis(forPitchClasses: [0, 2, 4, 5, 7, 9, 11], near: 60)
        let eMajor = midis(forPitchClasses: [4, 6, 8, 9, 11, 1, 3], near: 64)
        let signal = makeKeySignal(segments: [(cMajor, 8), (eMajor, 8)])
        XCTAssertNil(MusicalKeyAnalyzer.analyze(signal: signal))
    }

    func testShortForeignKeyIntroDoesNotOverrideDominantBodyKey() throws {
        let signal = makeKeySignal(segments: [
            ([55, 59, 62], 2),
            ([60, 64, 67], 10)
        ])
        let key = try XCTUnwrap(MusicalKeyAnalyzer.analyze(signal: signal))
        XCTAssertEqual(key.tonicPitchClass, 0)
        XCTAssertEqual(key.mode, "major")
        XCTAssertGreaterThan(key.confidence ?? 0, 0.50)
    }

    func testThresholdConfigurationCanForceLowConfidenceDecisionToUnknown() {
        var configuration = MusicAnalysisConfiguration.productBaseline
        configuration.minimumKeyConfidence = 0.90
        let signal = makeKeySignal(segments: [
            ([55, 59, 62], 2),
            ([60, 64, 67], 10)
        ])
        XCTAssertNil(MusicalKeyAnalyzer.analyze(signal: signal, configuration: configuration))
    }
}

private func makeKeySignal(
    segments: [([Int], Double)],
    sampleRate: Double = 8_000
) -> AnalysisSignal {
    var samples: [Float] = []
    var absoluteStart = 0.0
    for (midis, duration) in segments {
        let count = Int(sampleRate * duration)
        for index in 0..<count {
            let time = absoluteStart + Double(index) / sampleRate
            let value = midis.reduce(0.0) { partial, midi in
                partial + sin(2 * Double.pi * keyFrequency(midi) * time) * (0.60 / Double(max(midis.count, 1)))
            }
            samples.append(Float(value))
        }
        absoluteStart += duration
    }
    return AnalysisSignal(sampleRate: sampleRate, monoSamples: samples)
}

private func makeWeightedKeySignal(
    tones: [(midi: Int, weight: Double)],
    duration: Double,
    sampleRate: Double = 8_000
) -> AnalysisSignal {
    let count = Int(sampleRate * duration)
    let normalization = max(tones.reduce(0.0) { $0 + $1.weight }, 1e-9)
    var samples = Array(repeating: Float(0), count: count)
    for index in 0..<count {
        let time = Double(index) / sampleRate
        let value = tones.reduce(0.0) { partial, tone in
            partial + sin(2 * Double.pi * keyFrequency(tone.midi) * time) * (0.75 * tone.weight / normalization)
        }
        samples[index] = Float(value)
    }
    return AnalysisSignal(sampleRate: sampleRate, monoSamples: samples)
}

private func midis(forPitchClasses pitchClasses: [Int], near baseMidi: Int) -> [Int] {
    pitchClasses.map { pitchClass in
        baseMidi + ((pitchClass - baseMidi % 12 + 12) % 12)
    }
}

private func keyFrequency(_ midi: Int) -> Double {
    440.0 * pow(2.0, Double(midi - 69) / 12.0)
}
