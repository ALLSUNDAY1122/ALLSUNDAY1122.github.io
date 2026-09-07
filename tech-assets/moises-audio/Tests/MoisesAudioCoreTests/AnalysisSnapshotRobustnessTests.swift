import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisSnapshotRobustnessTests: XCTestCase {
    func testSanitizerReplacesNonfiniteAndClampsPathologicalSamples() {
        let signal = AnalysisSignal(
            sampleRate: 8_000,
            monoSamples: [0, .nan, .infinity, -.infinity, 100, -100, 0.5]
        )

        let sanitized = AnalysisSnapshotRobustness.sanitize(signal: signal)

        XCTAssertTrue(sanitized.monoSamples.allSatisfy(\.isFinite))
        XCTAssertEqual(sanitized.monoSamples[1], 0)
        XCTAssertEqual(sanitized.monoSamples[2], 0)
        XCTAssertEqual(sanitized.monoSamples[3], 0)
        XCTAssertEqual(sanitized.monoSamples[4], 16)
        XCTAssertEqual(sanitized.monoSamples[5], -16)
        XCTAssertEqual(sanitized.monoSamples[6], 0.5)
    }

    func testTempoBeatMismatchFailsClosed() {
        let snapshot = AnalysisSnapshot(
            tempo: TempoAnalysis(
                bpm: 120,
                confidence: 0.9,
                beatTimesSeconds: [0, 1, 2, 3]
            ),
            key: nil,
            chords: [],
            sections: []
        )

        let hardened = AnalysisSnapshotRobustness.harden(snapshot: snapshot, duration: 4)

        XCTAssertNil(hardened.tempo)
    }

    func testConsistentTempoAndMajorMinorKeyArePreserved() throws {
        let snapshot = AnalysisSnapshot(
            tempo: TempoAnalysis(
                bpm: 120,
                confidence: 0.8,
                beatTimesSeconds: [0, 0.5, 1, 1.5, 2]
            ),
            key: MusicalKey(tonicPitchClass: 0, mode: "major", confidence: 0.7),
            chords: [ChordEvent(startSeconds: 0, endSeconds: 2, normalizedLabel: "C", confidence: 0.8)],
            sections: [SongSection(startSeconds: 0, endSeconds: 2, structuralLabel: "A", functionalLabel: "chorus", confidence: 0.8)]
        )

        let hardened = AnalysisSnapshotRobustness.harden(snapshot: snapshot, duration: 2)

        XCTAssertEqual(hardened.tempo?.bpm, 120)
        XCTAssertEqual(hardened.tempo?.beatTimesSeconds, [0, 0.5, 1, 1.5, 2])
        XCTAssertEqual(hardened.key?.tonicPitchClass, 0)
        XCTAssertEqual(hardened.key?.mode, "major")
    }

    func testUnverifiedModalKeyFailsClosedAtProductSnapshotBoundary() {
        let snapshot = AnalysisSnapshot(
            tempo: nil,
            key: MusicalKey(tonicPitchClass: 2, mode: "dorian", confidence: 0.9),
            chords: [],
            sections: []
        )

        let hardened = AnalysisSnapshotRobustness.harden(snapshot: snapshot, duration: 4)

        XCTAssertNil(hardened.key)
    }

    func testChordTimelineFillsGapsTrimsOverlapAndRejectsUnsupportedProductLabel() {
        let snapshot = AnalysisSnapshot(
            tempo: nil,
            key: nil,
            chords: [
                ChordEvent(startSeconds: 2, endSeconds: 5, normalizedLabel: "C:7", confidence: 1.4),
                ChordEvent(startSeconds: 0, endSeconds: 1, normalizedLabel: "C", confidence: 0.8),
                ChordEvent(startSeconds: 4, endSeconds: 8, normalizedLabel: "A:min", confidence: 0.7)
            ],
            sections: []
        )

        let hardened = AnalysisSnapshotRobustness.harden(snapshot: snapshot, duration: 8)

        XCTAssertEqual(hardened.chords.first?.startSeconds, 0)
        XCTAssertEqual(hardened.chords.last?.endSeconds, 8)
        XCTAssertTrue(hardened.chords.contains { $0.normalizedLabel == "X" })
        XCTAssertTrue(hardened.chords.contains { $0.normalizedLabel == "A:min" })
        XCTAssertTrue(hardened.chords.allSatisfy { event in
            event.confidence == nil || (0...1).contains(event.confidence!)
        })
        for index in 1..<hardened.chords.count {
            XCTAssertEqual(
                hardened.chords[index - 1].endSeconds,
                hardened.chords[index].startSeconds,
                accuracy: 1e-9
            )
        }
    }

    func testLowChordEvidenceSuppressesSectionSemantics() {
        let snapshot = AnalysisSnapshot(
            tempo: nil,
            key: nil,
            chords: [ChordEvent(startSeconds: 0, endSeconds: 10, normalizedLabel: "X", confidence: nil)],
            sections: [SongSection(startSeconds: 0, endSeconds: 10, structuralLabel: "A", functionalLabel: "chorus", confidence: 0.9)]
        )

        let hardened = AnalysisSnapshotRobustness.harden(snapshot: snapshot, duration: 10)

        XCTAssertEqual(hardened.sections.count, 1)
        XCTAssertEqual(hardened.sections[0].structuralLabel, "X")
        XCTAssertNil(hardened.sections[0].functionalLabel)
        XCTAssertNil(hardened.sections[0].confidence)
    }

    func testFunctionalLabelsRequireSupportedVocabularyAndConfidence() {
        let snapshot = AnalysisSnapshot(
            tempo: nil,
            key: nil,
            chords: [ChordEvent(startSeconds: 0, endSeconds: 8, normalizedLabel: "C", confidence: 0.9)],
            sections: [
                SongSection(startSeconds: 0, endSeconds: 3, structuralLabel: "A", functionalLabel: "VERSE", confidence: 0.8),
                SongSection(startSeconds: 3, endSeconds: 5, structuralLabel: "B", functionalLabel: "drop", confidence: 0.9),
                SongSection(startSeconds: 5, endSeconds: 8, structuralLabel: "C", functionalLabel: "chorus", confidence: 0.4)
            ]
        )

        let hardened = AnalysisSnapshotRobustness.harden(snapshot: snapshot, duration: 8)

        XCTAssertEqual(hardened.sections[0].functionalLabel, "verse")
        XCTAssertNil(hardened.sections[1].functionalLabel)
        XCTAssertNil(hardened.sections[2].functionalLabel)
    }

    func testCanonicalEncodingAndDiagnosticsAreDeterministic() throws {
        let snapshot = AnalysisSnapshot(
            tempo: TempoAnalysis(bpm: 120, confidence: 0.8, beatTimesSeconds: [0, 0.5, 1, 1.5, 2]),
            key: MusicalKey(tonicPitchClass: 0, mode: "major", confidence: 0.7),
            chords: [ChordEvent(startSeconds: 0, endSeconds: 2, normalizedLabel: "C", confidence: 0.8)],
            sections: [SongSection(startSeconds: 0, endSeconds: 2, structuralLabel: "A", functionalLabel: "chorus", confidence: 0.8)]
        )
        let hardened = AnalysisSnapshotRobustness.harden(snapshot: snapshot, duration: 2)

        let first = try AnalysisSnapshotRobustness.canonicalJSON(hardened)
        let second = try AnalysisSnapshotRobustness.canonicalJSON(hardened)
        let metrics = AnalysisSnapshotRobustness.diagnostics(snapshot: hardened, duration: 2)

        XCTAssertEqual(first, second)
        XCTAssertEqual(metrics["chord_gap_seconds"], 0)
        XCTAssertEqual(metrics["chord_overlap_seconds"], 0)
        XCTAssertEqual(metrics["section_gap_seconds"], 0)
        XCTAssertEqual(metrics["section_overlap_seconds"], 0)
        XCTAssertEqual(metrics["invalid_confidence_count"], 0)
        XCTAssertEqual(metrics["beat_times_strictly_monotonic"], 1)
    }
}
