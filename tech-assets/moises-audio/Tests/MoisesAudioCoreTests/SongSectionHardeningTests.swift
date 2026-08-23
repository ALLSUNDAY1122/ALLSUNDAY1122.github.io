import Foundation
import XCTest
@testable import MoisesAudioCore

final class SongSectionHardeningTests: XCTestCase {
    func testVariedStructureAssignsFunctionalLabelsAndReusesFamilies() throws {
        let fixture = makeHardeningFixture([
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

        let result = SongSectionHardener.harden(
            sections: fixture.baseSections,
            signal: fixture.signal,
            chords: fixture.chords
        )
        let labels = result.map(\.functionalLabel)

        XCTAssertEqual(labels[0], "intro")
        XCTAssertEqual(labels[1], "verse")
        XCTAssertEqual(labels[2], "pre-chorus")
        XCTAssertEqual(labels[3], "chorus")
        XCTAssertEqual(labels[4], "verse")
        XCTAssertEqual(labels[5], "pre-chorus")
        XCTAssertEqual(labels[6], "chorus")
        XCTAssertEqual(labels[7], "bridge")
        XCTAssertEqual(labels[8], "chorus")
        XCTAssertEqual(labels[9], "outro")

        XCTAssertEqual(result[1].structuralLabel, result[4].structuralLabel)
        XCTAssertEqual(result[2].structuralLabel, result[5].structuralLabel)
        XCTAssertEqual(result[3].structuralLabel, result[6].structuralLabel)
        XCTAssertEqual(result[6].structuralLabel, result[8].structuralLabel)
        XCTAssertNotEqual(result[1].structuralLabel, result[3].structuralLabel)
    }

    func testABAStructureReusesCanonicalFamily() {
        let fixture = makeHardeningFixture([
            .init(duration: 6, amplitude: 0.18, chords: ["C", "G"]),
            .init(duration: 6, amplitude: 0.23, chords: ["D:min", "A:min"]),
            .init(duration: 6, amplitude: 0.18, chords: ["C", "G"])
        ])

        let result = SongSectionHardener.harden(
            sections: fixture.baseSections,
            signal: fixture.signal,
            chords: fixture.chords
        )

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].structuralLabel, result[2].structuralLabel)
        XCTAssertNotEqual(result[0].structuralLabel, result[1].structuralLabel)
    }

    func testFalseBoundarySuppressionMergesNearDuplicateNeighbors() {
        let fixture = makeHardeningFixture([
            .init(duration: 4, amplitude: 0.18, chords: ["C", "G"]),
            .init(duration: 4, amplitude: 0.18, chords: ["C", "G"]),
            .init(duration: 6, amplitude: 0.30, chords: ["D", "A"])
        ])

        let result = SongSectionHardener.harden(
            sections: fixture.baseSections,
            signal: fixture.signal,
            chords: fixture.chords
        )

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].startSeconds, 0, accuracy: 1e-9)
        XCTAssertEqual(result[0].endSeconds, 8, accuracy: 1e-9)
        XCTAssertEqual(result[1].startSeconds, 8, accuracy: 1e-9)
    }

    func testLocalUndecidedSectionFailsClosedToX() {
        let fixture = makeHardeningFixture([
            .init(duration: 6, amplitude: 0.18, chords: ["C", "G"]),
            .init(duration: 6, amplitude: 0.18, chords: ["X"]),
            .init(duration: 6, amplitude: 0.18, chords: ["D", "A"])
        ])

        let result = SongSectionHardener.harden(
            sections: fixture.baseSections,
            signal: fixture.signal,
            chords: fixture.chords
        )

        XCTAssertEqual(result[1].structuralLabel, "X")
        XCTAssertNil(result[1].functionalLabel)
        XCTAssertNil(result[1].confidence)
    }

    func testAmbiguousRepeatedFamiliesDoNotInventVerseChorus() {
        let fixture = makeHardeningFixture([
            .init(duration: 6, amplitude: 0.20, chords: ["C", "G"]),
            .init(duration: 6, amplitude: 0.205, chords: ["D", "A"]),
            .init(duration: 6, amplitude: 0.20, chords: ["C", "G"]),
            .init(duration: 6, amplitude: 0.205, chords: ["D", "A"])
        ])

        let result = SongSectionHardener.harden(
            sections: fixture.baseSections,
            signal: fixture.signal,
            chords: fixture.chords
        )

        XCTAssertTrue(result.allSatisfy { $0.functionalLabel == nil })
    }

    func testDiagnosticsExposeUnknownAndFunctionalCoverage() throws {
        let sections = [
            SongSection(startSeconds: 0, endSeconds: 4, structuralLabel: "X", functionalLabel: nil, confidence: nil),
            SongSection(startSeconds: 4, endSeconds: 8, structuralLabel: "A", functionalLabel: "chorus", confidence: 0.8)
        ]
        let metrics = SongSectionHardener.diagnostics(sections: sections, duration: 8)

        XCTAssertEqual(try XCTUnwrap(metrics["section_count"]), 2, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(metrics["unknown_duration_ratio"]), 0.5, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(metrics["functional_decision_ratio"]), 0.5, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(metrics["mean_section_confidence"]), 0.8, accuracy: 1e-9)
    }
}

private struct HardeningSegmentSpec {
    var duration: Double
    var amplitude: Double
    var chords: [String]
}

private func makeHardeningFixture(
    _ specs: [HardeningSegmentSpec],
    sampleRate: Double = 400
) -> (signal: AnalysisSignal, chords: [ChordEvent], baseSections: [SongSection]) {
    var samples: [Float] = []
    var chords: [ChordEvent] = []
    var sections: [SongSection] = []
    var time = 0.0

    for (index, spec) in specs.enumerated() {
        let count = Int((spec.duration * sampleRate).rounded())
        for sample in 0..<count {
            let localTime = Double(sample) / sampleRate
            samples.append(Float(spec.amplitude * sin(2 * Double.pi * 3 * localTime)))
        }

        let chordDuration = spec.duration / Double(spec.chords.count)
        for (chordIndex, label) in spec.chords.enumerated() {
            chords.append(
                ChordEvent(
                    startSeconds: time + Double(chordIndex) * chordDuration,
                    endSeconds: time + Double(chordIndex + 1) * chordDuration,
                    normalizedLabel: label,
                    confidence: label == "X" ? nil : 0.9
                )
            )
        }

        sections.append(
            SongSection(
                startSeconds: time,
                endSeconds: time + spec.duration,
                structuralLabel: "seed-\(index)",
                functionalLabel: nil,
                confidence: 0.88
            )
        )
        time += spec.duration
    }

    return (AnalysisSignal(sampleRate: sampleRate, monoSamples: samples), chords, sections)
}
