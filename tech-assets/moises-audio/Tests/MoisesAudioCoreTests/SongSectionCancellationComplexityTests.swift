import Foundation
import XCTest
@testable import MoisesAudioCore

final class SongSectionCancellationComplexityTests: XCTestCase {
    func testW09VariedStructureRegressionIsPreserved() throws {
        let fixture = makeW13Fixture([
            .init(duration: 4, amplitude: 0.06, chords: ["C"]),
            .init(duration: 8, amplitude: 0.16, chords: ["C", "A:min", "F", "G"]),
            .init(duration: 4, amplitude: 0.22, chords: ["D:min", "G"]),
            .init(duration: 8, amplitude: 0.34, chords: ["D", "B:min", "G", "A"]),
            .init(duration: 8, amplitude: 0.16, chords: ["C", "A:min", "F", "G"]),
            .init(duration: 4, amplitude: 0.22, chords: ["D:min", "G"]),
            .init(duration: 8, amplitude: 0.34, chords: ["D", "B:min", "G", "A"]),
            .init(duration: 6, amplitude: 0.20, chords: ["D#", "A#", "C:min"]),
            .init(duration: 8, amplitude: 0.34, chords: ["D", "B:min", "G", "A"]),
            .init(duration: 4, amplitude: 0.05, chords: ["C"])
        ])
        let result = try CancellableSongSectionPipeline.hardenCancellable(
            sections: fixture.baseSections, signal: fixture.signal, chords: fixture.chords
        )
        XCTAssertEqual(result.map(\.functionalLabel), [
            "intro", "verse", "pre-chorus", "chorus", "verse",
            "pre-chorus", "chorus", "bridge", "chorus", "outro"
        ])
        XCTAssertEqual(result[1].structuralLabel, result[4].structuralLabel)
        XCTAssertEqual(result[3].structuralLabel, result[8].structuralLabel)
    }

    func testUndecidedEvidenceStillFailsClosed() throws {
        let fixture = makeW13Fixture([
            .init(duration: 6, amplitude: 0.18, chords: ["C", "G"]),
            .init(duration: 6, amplitude: 0.18, chords: ["X"]),
            .init(duration: 6, amplitude: 0.18, chords: ["D", "A"])
        ])
        let result = try CancellableSongSectionPipeline.hardenCancellable(
            sections: fixture.baseSections, signal: fixture.signal, chords: fixture.chords
        )
        XCTAssertEqual(result[1].structuralLabel, "X")
        XCTAssertNil(result[1].functionalLabel)
        XCTAssertNil(result[1].confidence)
    }

    func testOneHourComplexityBudgetAvoidsNaiveQuadraticChordScanning() {
        let metrics = SongSectionComplexityBudget.estimate(
            durationSeconds: 3_600,
            chordCount: 14_400,
            configuredHop: 1
        )
        XCTAssertEqual(metrics.estimatedBoundaryCandidates, 3_600)
        XCTAssertLessThanOrEqual(metrics.estimatedBoundaryCandidates, metrics.maximumBoundaryCandidates)
        XCTAssertGreaterThan(
            metrics.legacyNaiveChordVisitsUpperBound,
            metrics.indexedChordVisitsNominalUpperBound * 100
        )
    }

    func testExtremeDurationRaisesHopRatherThanGrowingCandidateArrayUnbounded() {
        let metrics = SongSectionComplexityBudget.estimate(
            durationSeconds: 24 * 60 * 60,
            chordCount: 345_600,
            configuredHop: 1
        )
        XCTAssertLessThanOrEqual(metrics.estimatedBoundaryCandidates, 16_384)
        XCTAssertGreaterThan(metrics.effectiveSectionHopSeconds, 1)
        XCTAssertEqual(metrics.maximumPrototypeClusters, 64)
        XCTAssertEqual(metrics.descriptorSampleCap, 8_000)
    }

    func testPreCancelledSectionAnalysisThrowsCancellationError() async {
        let signal = AnalysisSignal(sampleRate: 400, monoSamples: Array(repeating: 0.2, count: 400 * 60))
        let chords = (0..<60).map {
            ChordEvent(startSeconds: Double($0), endSeconds: Double($0 + 1), normalizedLabel: "C", confidence: 0.9)
        }
        let task = Task.detached { try CancellableSongSectionPipeline.analyze(signal: signal, chords: chords) }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private struct W13SegmentSpec {
    var duration: Double
    var amplitude: Double
    var chords: [String]
}

private func makeW13Fixture(
    _ specs: [W13SegmentSpec],
    sampleRate: Double = 400
) -> (signal: AnalysisSignal, chords: [ChordEvent], baseSections: [SongSection]) {
    var samples: [Float] = []
    var chords: [ChordEvent] = []
    var sections: [SongSection] = []
    var time = 0.0
    for (index, spec) in specs.enumerated() {
        let sampleCount = Int((spec.duration * sampleRate).rounded())
        for sample in 0..<sampleCount {
            let localTime = Double(sample) / sampleRate
            samples.append(Float(spec.amplitude * sin(2 * Double.pi * 3 * localTime)))
        }
        let chordDuration = spec.duration / Double(spec.chords.count)
        for (chordIndex, label) in spec.chords.enumerated() {
            chords.append(.init(
                startSeconds: time + Double(chordIndex) * chordDuration,
                endSeconds: time + Double(chordIndex + 1) * chordDuration,
                normalizedLabel: label,
                confidence: label == "X" ? nil : 0.9
            ))
        }
        sections.append(.init(
            startSeconds: time,
            endSeconds: time + spec.duration,
            structuralLabel: "seed-\(index)",
            functionalLabel: nil,
            confidence: 0.88
        ))
        time += spec.duration
    }
    return (AnalysisSignal(sampleRate: sampleRate, monoSamples: samples), chords, sections)
}
