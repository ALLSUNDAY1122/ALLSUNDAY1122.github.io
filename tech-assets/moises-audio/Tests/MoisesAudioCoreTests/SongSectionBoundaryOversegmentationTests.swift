import Foundation
import XCTest
@testable import MoisesAudioCore

final class SongSectionBoundaryOversegmentationTests: XCTestCase {
    func testBoundaryGateRemovesChordSubphraseFragmentsButPreservesShortSectionsAndFamilies() throws {
        let fixture = makeW14Fixture()
        let raw = makeSections(
            boundaries: [0, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 50, 54, 58, 62]
        )

        let result = try SongSectionBoundaryHardener.harden(
            sections: raw,
            signal: fixture.signal,
            chords: fixture.chords
        )

        XCTAssertEqual(
            result.map(\.endSeconds),
            [4, 12, 16, 24, 32, 36, 44, 50, 58, 62]
        )
        XCTAssertEqual(
            result.map(\.functionalLabel),
            ["intro", "verse", "pre-chorus", "chorus", "verse", "pre-chorus", "chorus", "bridge", "chorus", "outro"]
        )
        XCTAssertEqual(result[1].structuralLabel, result[4].structuralLabel)
        XCTAssertEqual(result[2].structuralLabel, result[5].structuralLabel)
        XCTAssertEqual(result[3].structuralLabel, result[6].structuralLabel)
        XCTAssertEqual(result[6].structuralLabel, result[8].structuralLabel)
        XCTAssertNotEqual(result[1].structuralLabel, result[3].structuralLabel)
    }

    func testFullAnalyzeVariedFixtureReducesFragmentation() throws {
        let fixture = makeW14Fixture()
        let detected = try CancellableSongSectionPipeline.analyze(
            signal: fixture.signal,
            chords: fixture.chords
        )
        let hardened = try SongSectionBoundaryHardener.harden(
            sections: detected,
            signal: fixture.signal,
            chords: fixture.chords
        )
        let metrics = SongSectionBoundaryHardener.diagnostics(
            before: detected,
            after: hardened,
            duration: fixture.signal.durationSeconds
        )

        XCTAssertLessThanOrEqual(hardened.count, detected.count)
        XCTAssertLessThanOrEqual(metrics.outputBoundaryDensityPerMinute, metrics.inputBoundaryDensityPerMinute)
        XCTAssertGreaterThanOrEqual(metrics.outputMedianSectionSeconds, metrics.inputMedianSectionSeconds)
        XCTAssertLessThanOrEqual(hardened.count, 11)
        XCTAssertTrue(hardened.allSatisfy {
            $0.endSeconds - $0.startSeconds >= MusicAnalysisConfiguration.productBaseline.minimumSectionSeconds - 1e-6
        })
    }

    func testStableRepeatedProgressionDoesNotSplitAtEveryChordSubphrase() throws {
        let fixture = makeFixture([
            .init(duration: 16, amplitude: 0.20, chords: ["C", "A:min", "F", "G", "C", "A:min", "F", "G"])
        ])
        let raw = makeSections(boundaries: [0, 4, 8, 12, 16])

        let result = try SongSectionBoundaryHardener.harden(
            sections: raw,
            signal: fixture.signal,
            chords: fixture.chords
        )

        XCTAssertLessThanOrEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.endSeconds - $0.startSeconds >= 8 - 1e-6 })
    }

    func testUnknownChordCoverageFailsClosedInsteadOfInventingFamilies() throws {
        let fixture = makeFixture([
            .init(duration: 8, amplitude: 0.18, chords: ["X", "X"]),
            .init(duration: 8, amplitude: 0.18, chords: ["X", "X"])
        ])
        let raw = makeSections(boundaries: [0, 4, 8, 12, 16])

        let result = try SongSectionBoundaryHardener.harden(
            sections: raw,
            signal: fixture.signal,
            chords: fixture.chords
        )

        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { $0.structuralLabel == "X" })
        XCTAssertTrue(result.allSatisfy { $0.functionalLabel == nil })
    }

    func testDiagnosticsExposeFragmentationReductionAndStableJSONKeys() throws {
        let before = makeSections(boundaries: [0, 4, 8, 12, 16])
        let after = makeSections(boundaries: [0, 8, 16])
        let metrics = SongSectionBoundaryHardener.diagnostics(
            before: before,
            after: after,
            duration: 16
        )

        XCTAssertEqual(metrics.inputSectionCount, 4)
        XCTAssertEqual(metrics.outputSectionCount, 2)
        XCTAssertEqual(metrics.removedBoundaryCount, 2)
        XCTAssertEqual(metrics.preferredStructuralSpacingSeconds, 8, accuracy: 1e-9)
        XCTAssertEqual(metrics.inputMedianSectionSeconds, 4, accuracy: 1e-9)
        XCTAssertEqual(metrics.outputMedianSectionSeconds, 8, accuracy: 1e-9)

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(metrics)) as? [String: Any]
        )
        XCTAssertNotNil(object["input_section_count"])
        XCTAssertNotNil(object["output_boundary_density_per_minute"])
    }

    func testPreCancelledBoundaryHardeningThrowsCancellationError() async throws {
        let fixture = makeW14Fixture()
        let raw = makeSections(
            boundaries: [0, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 50, 54, 58, 62]
        )
        let task = Task {
            try SongSectionBoundaryHardener.harden(
                sections: raw,
                signal: fixture.signal,
                chords: fixture.chords
            )
        }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // Expected.
        }
    }

    func testW13ComplexityCapsRemainUnchanged() {
        XCTAssertEqual(SongSectionComplexityBudget.maximumBoundaryCandidates, 16_384)
        XCTAssertEqual(SongSectionComplexityBudget.maximumPrototypeClusters, 64)
        XCTAssertEqual(SongSectionComplexityBudget.descriptorSampleCap, 8_000)
    }
}

private struct W14SegmentSpec {
    let duration: Double
    let amplitude: Double
    let chords: [String]
}

private func makeW14Fixture() -> (signal: AnalysisSignal, chords: [ChordEvent]) {
    makeFixture([
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
}

private func makeFixture(
    _ specs: [W14SegmentSpec],
    sampleRate: Double = 400
) -> (signal: AnalysisSignal, chords: [ChordEvent]) {
    var samples: [Float] = []
    var chords: [ChordEvent] = []
    var time = 0.0

    for spec in specs {
        let sampleCount = Int((spec.duration * sampleRate).rounded())
        for sampleIndex in 0..<sampleCount {
            let localTime = Double(sampleIndex) / sampleRate
            samples.append(
                Float(spec.amplitude * sin(2 * Double.pi * 3 * localTime))
            )
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
        time += spec.duration
    }

    return (
        AnalysisSignal(sampleRate: sampleRate, monoSamples: samples),
        chords
    )
}

private func makeSections(boundaries: [Double]) -> [SongSection] {
    guard boundaries.count >= 2 else { return [] }
    return (0..<(boundaries.count - 1)).map { index in
        SongSection(
            startSeconds: boundaries[index],
            endSeconds: boundaries[index + 1],
            structuralLabel: "fragment-\(index)",
            functionalLabel: nil,
            confidence: 0.80
        )
    }
}
