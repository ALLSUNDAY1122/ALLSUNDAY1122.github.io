import Foundation
import XCTest
@testable import MoisesAudioCore

final class ChordVocabularyHardeningTests: XCTestCase {
    func testConservativeVocabularyPreservesClearMajorAndMinor() {
        let cMajor = classify([(48, 0.45), (52, 0.32), (55, 0.30)])
        let aMinor = classify([(45, 0.45), (48, 0.32), (52, 0.30)])
        XCTAssertEqual(cMajor.label, "C")
        XCTAssertEqual(aMinor.label, "A:min")
        XCTAssertGreaterThan(cMajor.confidence ?? 0, 0.20)
        XCTAssertGreaterThan(aMinor.confidence ?? 0, 0.20)
    }

    func testConservativeVocabularyFailsClosedOnStrongSeventhEvidence() {
        let dominant = classify([(48, 0.40), (52, 0.28), (55, 0.27), (58, 0.26)])
        let majorSeven = classify([(48, 0.40), (52, 0.28), (55, 0.27), (59, 0.26)])
        let minorSeven = classify([(45, 0.40), (48, 0.28), (52, 0.27), (55, 0.26)])
        XCTAssertEqual(dominant.label, "X")
        XCTAssertEqual(majorSeven.label, "X")
        XCTAssertEqual(minorSeven.label, "X")
    }

    func testExtendedDiagnosticVocabularyDistinguishesSeventhFamilies() {
        XCTAssertEqual(classify([(48, 0.40), (52, 0.28), (55, 0.27), (58, 0.26)], vocabulary: .extendedDiagnostic).label, "C:7")
        XCTAssertEqual(classify([(48, 0.40), (52, 0.28), (55, 0.27), (59, 0.26)], vocabulary: .extendedDiagnostic).label, "C:maj7")
        XCTAssertEqual(classify([(45, 0.40), (48, 0.28), (52, 0.27), (55, 0.26)], vocabulary: .extendedDiagnostic).label, "A:min7")
    }

    func testExtendedDiagnosticVocabularyHandlesSusDiminishedAndAugmented() {
        XCTAssertEqual(classify([(48, 0.50), (53, 0.28), (55, 0.26)], vocabulary: .extendedDiagnostic).label, "C:sus4")
        XCTAssertEqual(classify([(47, 0.50), (50, 0.30), (53, 0.28)], vocabulary: .extendedDiagnostic).label, "B:dim")
        XCTAssertEqual(classify([(48, 0.50), (52, 0.30), (56, 0.28)], vocabulary: .extendedDiagnostic).label, "C:aug")
    }

    func testBassAwareInversionKeepsHarmonicRoot() {
        let inverted = [(40, 0.55), (48, 0.22), (55, 0.22), (60, 0.22)]
        XCTAssertEqual(classify(inverted).label, "C")
        XCTAssertEqual(classify(inverted, vocabulary: .extendedDiagnostic).label, "C/E")
    }

    func testChordLabelNormalizerCanonicalizesAliasesAndRejectsInvalidLabels() {
        XCTAssertEqual(ChordLabelNormalizer.canonicalize("Bb:maj7/D"), "A#:maj7/D")
        XCTAssertEqual(ChordLabelNormalizer.canonicalize("A:m7/C"), "A:min7/C")
        XCTAssertEqual(ChordLabelNormalizer.canonicalize("Db:sus"), "C#:sus4")
        XCTAssertEqual(ChordLabelNormalizer.canonicalize("N"), "N")
        XCTAssertEqual(ChordLabelNormalizer.canonicalize("X"), "X")
        XCTAssertNil(ChordLabelNormalizer.canonicalize("H:maj7"))
        XCTAssertNil(ChordLabelNormalizer.canonicalize("C:unknown"))
    }

    func testProductTimelineRegressionRemainsGapFreeAndMajorMinorCompatible() {
        var samples: [Float] = []
        appendTones(&samples, tones: [(48, 0.40), (52, 0.30), (55, 0.28)], seconds: 2)
        appendTones(&samples, tones: [(45, 0.40), (48, 0.30), (52, 0.28)], seconds: 2)
        samples += Array(repeating: 0, count: 8_000)
        appendTones(&samples, tones: [(43, 0.40), (47, 0.30), (50, 0.28)], seconds: 2)

        let events = ChordTimelineAnalyzer.analyze(signal: AnalysisSignal(sampleRate: 8_000, monoSamples: samples))
        XCTAssertEqual(events.map(\.normalizedLabel), ["C", "A:min", "N", "G"])
        XCTAssertEqual(events.first?.startSeconds ?? .nan, 0, accuracy: 1e-9)
        XCTAssertEqual(events.last?.endSeconds ?? .nan, 7, accuracy: 1e-9)
        for pair in zip(events, events.dropFirst()) {
            XCTAssertEqual(pair.0.endSeconds, pair.1.startSeconds, accuracy: 1e-9)
        }
    }

    func testDenseChromaticMaterialAndProductComplexChordRemainUnknown() {
        let dense = (48...56).map { ($0, 0.16) }
        XCTAssertEqual(classify(dense).label, "X")

        let signal = makeSignal([(48, 0.40), (52, 0.28), (55, 0.27), (58, 0.26)], seconds: 2)
        let events = ChordTimelineAnalyzer.analyze(signal: signal)
        XCTAssertEqual(events.map(\.normalizedLabel), ["X"])
    }
}

private func classify(
    _ tones: [(Int, Double)],
    vocabulary: ChordVocabularyMode = .conservativeMajorMinor
) -> (label: String, confidence: Double?) {
    let signal = makeSignal(tones, seconds: 2)
    return ChordFrameClassifier.classify(
        samples: signal.monoSamples.map(Double.init),
        sampleRate: signal.sampleRate,
        configuration: .productBaseline,
        vocabulary: vocabulary
    )
}

private func makeSignal(_ tones: [(Int, Double)], seconds: Double) -> AnalysisSignal {
    var samples: [Float] = []
    appendTones(&samples, tones: tones, seconds: seconds)
    return AnalysisSignal(sampleRate: 8_000, monoSamples: samples)
}

private func appendTones(
    _ samples: inout [Float],
    tones: [(Int, Double)],
    seconds: Double,
    sampleRate: Double = 8_000
) {
    let count = Int(seconds * sampleRate)
    samples.reserveCapacity(samples.count + count)
    for index in 0..<count {
        let time = Double(index) / sampleRate
        let value = tones.reduce(0.0) { partial, tone in
            let frequency = 440.0 * pow(2.0, Double(tone.0 - 69) / 12.0)
            return partial + sin(2 * Double.pi * frequency * time) * tone.1
        }
        samples.append(Float(value))
    }
}
