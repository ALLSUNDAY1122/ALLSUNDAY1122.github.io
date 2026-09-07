import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisSnapshotPublicationHardeningTests: XCTestCase {
    func testCancellableGuardMatchesLegacyGuardForNormalSnapshot() throws {
        let snapshot = AnalysisSnapshot(
            tempo: TempoAnalysis(
                bpm: 120,
                confidence: 0.8,
                beatTimesSeconds: [2, 0, 1, 0.5, 1.5]
            ),
            key: MusicalKey(tonicPitchClass: 0, mode: "major", confidence: 0.7),
            chords: [
                ChordEvent(startSeconds: 2, endSeconds: 5, normalizedLabel: "C:7", confidence: 1.4),
                ChordEvent(startSeconds: 0, endSeconds: 1, normalizedLabel: "C", confidence: 0.8),
                ChordEvent(startSeconds: 4, endSeconds: 8, normalizedLabel: "A:min", confidence: 0.7)
            ],
            sections: [
                SongSection(startSeconds: 0, endSeconds: 3, structuralLabel: "A", functionalLabel: "VERSE", confidence: 0.8),
                SongSection(startSeconds: 3, endSeconds: 5, structuralLabel: "B", functionalLabel: "drop", confidence: 0.9),
                SongSection(startSeconds: 5, endSeconds: 8, structuralLabel: "C", functionalLabel: "chorus", confidence: 0.4)
            ]
        )

        let legacy = AnalysisSnapshotRobustness.harden(snapshot: snapshot, duration: 8)
        let cancellable = try AnalysisSnapshotRobustness.hardenCancellable(snapshot: snapshot, duration: 8)

        XCTAssertEqual(cancellable, legacy)
        XCTAssertEqual(
            try AnalysisSnapshotRobustness.canonicalJSON(cancellable),
            try AnalysisSnapshotRobustness.canonicalJSON(legacy)
        )
    }

    func testOneHourCardinalityLimitsPreserveNormalAnalyzerScale() {
        let snapshot = AnalysisSnapshot(tempo: nil, key: nil, chords: [], sections: [])
        let diagnostics = AnalysisSnapshotCardinalityPolicy.diagnostics(
            snapshot: snapshot,
            duration: 3_600
        )

        XCTAssertEqual(diagnostics.beatInputLimit, 25_264)
        XCTAssertEqual(diagnostics.chordInputLimit, 28_864)
        XCTAssertEqual(diagnostics.sectionInputLimit, 3_664)
    }

    func testBeatOverflowFailsClosedOnlyTempo() throws {
        let snapshot = AnalysisSnapshot(
            tempo: TempoAnalysis(
                bpm: 120,
                confidence: 0.9,
                beatTimesSeconds: Array(repeating: 0, count: 3_000)
            ),
            key: MusicalKey(tonicPitchClass: 0, mode: "major", confidence: 0.8),
            chords: [ChordEvent(startSeconds: 0, endSeconds: 10, normalizedLabel: "C", confidence: 0.9)],
            sections: [SongSection(startSeconds: 0, endSeconds: 10, structuralLabel: "A", functionalLabel: "chorus", confidence: 0.9)]
        )

        let hardened = try AnalysisSnapshotRobustness.hardenCancellable(snapshot: snapshot, duration: 10)

        XCTAssertNil(hardened.tempo)
        XCTAssertNotNil(hardened.key)
        XCTAssertEqual(hardened.chords.first?.normalizedLabel, "C")
        XCTAssertEqual(hardened.sections.first?.functionalLabel, "chorus")
    }

    func testChordOverflowFailsClosedAndSuppressesSectionSemantics() throws {
        let chords = (0..<5_000).map { index in
            ChordEvent(
                startSeconds: Double(index) / 500,
                endSeconds: Double(index + 1) / 500,
                normalizedLabel: "C",
                confidence: 0.9
            )
        }
        let snapshot = AnalysisSnapshot(
            tempo: nil,
            key: nil,
            chords: chords,
            sections: [SongSection(startSeconds: 0, endSeconds: 10, structuralLabel: "A", functionalLabel: "chorus", confidence: 0.9)]
        )

        let hardened = try AnalysisSnapshotRobustness.hardenCancellable(snapshot: snapshot, duration: 10)

        XCTAssertEqual(hardened.chords.count, 1)
        XCTAssertEqual(hardened.chords[0].normalizedLabel, "X")
        XCTAssertEqual(hardened.chords[0].startSeconds, 0)
        XCTAssertEqual(hardened.chords[0].endSeconds, 10)
        XCTAssertEqual(hardened.sections.count, 1)
        XCTAssertEqual(hardened.sections[0].structuralLabel, "X")
        XCTAssertNil(hardened.sections[0].functionalLabel)
    }

    func testSectionOverflowFailsClosedWithoutChangingChordTimeline() throws {
        let sections = (0..<600).map { index in
            SongSection(
                startSeconds: Double(index) / 60,
                endSeconds: Double(index + 1) / 60,
                structuralLabel: "A",
                functionalLabel: "chorus",
                confidence: 0.9
            )
        }
        let snapshot = AnalysisSnapshot(
            tempo: nil,
            key: nil,
            chords: [ChordEvent(startSeconds: 0, endSeconds: 10, normalizedLabel: "C", confidence: 0.9)],
            sections: sections
        )

        let hardened = try AnalysisSnapshotRobustness.hardenCancellable(snapshot: snapshot, duration: 10)

        XCTAssertEqual(hardened.chords.count, 1)
        XCTAssertEqual(hardened.chords[0].normalizedLabel, "C")
        XCTAssertEqual(hardened.sections.count, 1)
        XCTAssertEqual(hardened.sections[0].structuralLabel, "X")
    }

    func testPrecancelledPublicationThrowsCancellationError() async {
        let snapshot = AnalysisSnapshot(
            tempo: nil,
            key: nil,
            chords: [ChordEvent(startSeconds: 0, endSeconds: 10, normalizedLabel: "C", confidence: 0.9)],
            sections: []
        )
        let task = Task.detached { () throws -> AnalysisSnapshot in
            try Task.checkCancellation()
            return try AnalysisSnapshotRobustness.hardenCancellable(snapshot: snapshot, duration: 10)
        }
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

    func testMidflightLargeChordNormalizationIsCancellable() async throws {
        let count = 300_000
        let duration = 86_400.0
        let chords = (0..<count).map { index -> ChordEvent in
            let time = Double(count - index) * 0.25
            return ChordEvent(
                startSeconds: time,
                endSeconds: min(duration, time + 0.25),
                normalizedLabel: index.isMultiple(of: 2) ? "C" : "G",
                confidence: 0.9
            )
        }
        let snapshot = AnalysisSnapshot(tempo: nil, key: nil, chords: chords, sections: [])
        let clock = ContinuousClock()
        let task = Task.detached {
            try AnalysisSnapshotRobustness.hardenCancellable(snapshot: snapshot, duration: duration)
        }

        try await Task.sleep(nanoseconds: 1_000_000)
        let cancellationRequested = clock.now
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            let latency = cancellationRequested.duration(to: clock.now)
            XCTAssertLessThan(latency, .milliseconds(250))
        }
    }
}
