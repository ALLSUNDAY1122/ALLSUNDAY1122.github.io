import Foundation
import XCTest
@testable import MoisesAudioCore

final class ChordTimelineAnalysisTests: XCTestCase {
    func testChordTimelineDetectsMajorMinorNoChordAndReturnsPlaybackClockOrder() throws {
        let signal = makeProgression([
            ("C", 2.0),
            ("A:min", 2.0),
            ("N", 1.0),
            ("G", 2.0)
        ])
        let chords = ChordTimelineAnalyzer.analyze(signal: signal)

        XCTAssertEqual(label(at: 1.0, in: chords), "C")
        XCTAssertEqual(label(at: 3.0, in: chords), "A:min")
        XCTAssertEqual(label(at: 4.5, in: chords), "N")
        XCTAssertEqual(label(at: 6.0, in: chords), "G")
        XCTAssertEqual(try XCTUnwrap(chords.first).startSeconds, 0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(chords.last).endSeconds, signal.durationSeconds, accuracy: 1e-9)
        XCTAssertTrue(chords.allSatisfy { $0.endSeconds > $0.startSeconds })
        for index in 1..<chords.count {
            XCTAssertEqual(chords[index - 1].endSeconds, chords[index].startSeconds, accuracy: 1e-9)
            XCTAssertLessThanOrEqual(chords[index - 1].startSeconds, chords[index].startSeconds)
        }
    }

    func testSilenceEmitsExplicitNoChordAcrossWholeTimeline() throws {
        let signal = AnalysisSignal(sampleRate: 8_000, monoSamples: Array(repeating: 0, count: 16_000))
        let chords = ChordTimelineAnalyzer.analyze(signal: signal)

        XCTAssertEqual(chords.count, 1)
        XCTAssertEqual(chords[0].normalizedLabel, "N")
        XCTAssertEqual(chords[0].startSeconds, 0, accuracy: 1e-9)
        XCTAssertEqual(chords[0].endSeconds, 2, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(chords[0].confidence), 1, accuracy: 1e-9)
    }

    func testChromaticAmbiguityEmitsUnknownInsteadOfForcedChord() {
        let signal = makeChromaticSignal(duration: 2.0)
        let chords = ChordTimelineAnalyzer.analyze(signal: signal)

        XCTAssertFalse(chords.isEmpty)
        XCTAssertTrue(chords.allSatisfy { $0.normalizedLabel == "X" })
    }

    func testBriefAmbiguousGlitchDoesNotCreateUnstableStandaloneSegment() {
        let signal = makeProgression([
            ("C", 1.5),
            ("X", 0.05),
            ("C", 1.5)
        ])
        let chords = ChordTimelineAnalyzer.analyze(signal: signal)

        XCTAssertEqual(label(at: 1.0, in: chords), "C")
        XCTAssertEqual(label(at: 1.525, in: chords), "C")
        XCTAssertEqual(label(at: 2.0, in: chords), "C")
        XCTAssertFalse(chords.contains { $0.normalizedLabel == "X" && ($0.endSeconds - $0.startSeconds) < 0.35 })
    }

    func testExactChordTimelineBenchmarkScoresPerfectAndPreservesNoChordMetrics() throws {
        let reference = [
            chord(0, 1, "C"),
            chord(1, 1.5, "N"),
            chord(1.5, 3, "A:min")
        ]
        let metrics = AnalysisBenchmarkRunner.chordMetrics(reference: reference, estimated: reference, duration: 3)

        XCTAssertEqual(try XCTUnwrap(metrics["root_weighted_accuracy"]), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(metrics["majmin_weighted_accuracy"]), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(metrics["no_chord_precision"]), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(metrics["no_chord_recall"]), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(metrics["coverage"]), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(metrics["boundary_median_abs_error_seconds"]), 0, accuracy: 1e-9)
    }

    func testUnknownIntervalsReduceCoverageRatherThanInflatingBenchmark() throws {
        let reference = [chord(0, 2, "C")]
        let estimate = [chord(0, 1, "C"), chord(1, 2, "X")]
        let metrics = AnalysisBenchmarkRunner.chordMetrics(reference: reference, estimated: estimate, duration: 2)

        XCTAssertEqual(try XCTUnwrap(metrics["root_weighted_accuracy"]), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(metrics["coverage"]), 0.5, accuracy: 1e-9)
    }

    func testAnalysisSnapshotCodableRoundTripPreservesChordOrderAndTimestamps() throws {
        let snapshot = AnalysisSnapshot(
            tempo: nil,
            key: nil,
            chords: [
                chord(0, 0.75, "C"),
                chord(0.75, 1.5, "G"),
                chord(1.5, 2.25, "A:min")
            ],
            sections: []
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(AnalysisSnapshot.self, from: data)
        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.chords.map(\.normalizedLabel), ["C", "G", "A:min"])
        XCTAssertEqual(decoded.chords.map(\.startSeconds), [0, 0.75, 1.5])
    }

    func testProjectOwnedAnalyzerPopulatesChordTimelineThroughFrozenMusicAnalyzingContract() async throws {
        let signal = makeProgression([("C", 2), ("G", 2)])
        let loader = SignalLoaderStub(signal: signal)
        let analyzer: any MusicAnalyzing = ProjectOwnedMusicAnalyzer(loader: loader)
        let projectID = ProjectID()
        let asset = LocalAudioAsset(id: AssetID(), relativePath: "imports/chords.wav", mediaKind: .audio, durationSeconds: signal.durationSeconds)

        let snapshot = try await analyzer.analyze(projectID: projectID, asset: asset)

        XCTAssertFalse(snapshot.chords.isEmpty)
        XCTAssertEqual(label(at: 1.0, in: snapshot.chords), "C")
        XCTAssertEqual(label(at: 3.0, in: snapshot.chords), "G")
        XCTAssertFalse(snapshot.sections.isEmpty)
    }
}

private struct SignalLoaderStub: AnalysisSignalLoading {
    let signal: AnalysisSignal
    func loadSignal(projectID: ProjectID, asset: LocalAudioAsset) async throws -> AnalysisSignal { signal }
}

private func chord(_ start: Double, _ end: Double, _ label: String, confidence: Double? = 0.8) -> ChordEvent {
    ChordEvent(startSeconds: start, endSeconds: end, normalizedLabel: label, confidence: confidence)
}

private func label(at time: Double, in events: [ChordEvent]) -> String? {
    events.first { time >= $0.startSeconds && time < $0.endSeconds }?.normalizedLabel
}

private func makeProgression(_ segments: [(String, Double)], sampleRate: Double = 8_000) -> AnalysisSignal {
    var samples: [Float] = []
    for (label, duration) in segments {
        if label == "N" {
            samples.append(contentsOf: Array(repeating: 0, count: Int((duration * sampleRate).rounded())))
        } else if label == "X" {
            samples.append(contentsOf: chromaticSamples(duration: duration, sampleRate: sampleRate))
        } else {
            samples.append(contentsOf: chordSamples(label: label, duration: duration, sampleRate: sampleRate))
        }
    }
    return AnalysisSignal(sampleRate: sampleRate, monoSamples: samples)
}

private func makeChromaticSignal(duration: Double, sampleRate: Double = 8_000) -> AnalysisSignal {
    AnalysisSignal(sampleRate: sampleRate, monoSamples: chromaticSamples(duration: duration, sampleRate: sampleRate))
}

private func chordSamples(label: String, duration: Double, sampleRate: Double) -> [Float] {
    let pitchClasses = ["C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11]
    let parts = label.split(separator: ":", maxSplits: 1).map(String.init)
    let root = pitchClasses[parts[0]] ?? 0
    let isMinor = parts.count > 1 && parts[1] == "min"
    let intervals = isMinor ? [0, 3, 7] : [0, 4, 7]
    let count = Int((duration * sampleRate).rounded())
    var result = Array(repeating: Float(0), count: count)

    for interval in intervals {
        var midi = 60 + root + interval
        if midi > 71 { midi -= 12 }
        let frequency = 440.0 * pow(2.0, Double(midi - 69) / 12.0)
        let lower = frequency / 2
        for index in 0..<count {
            let time = Double(index) / sampleRate
            let envelope = edgeEnvelope(index: index, count: count, sampleRate: sampleRate)
            let value = 0.20 * sin(2 * Double.pi * frequency * time) + 0.06 * sin(2 * Double.pi * lower * time)
            result[index] += Float(value * envelope)
        }
    }
    return result
}

private func chromaticSamples(duration: Double, sampleRate: Double) -> [Float] {
    let count = Int((duration * sampleRate).rounded())
    var result = Array(repeating: Float(0), count: count)
    for pitchClass in 0..<12 {
        let midi = 60 + pitchClass
        let frequency = 440.0 * pow(2.0, Double(midi - 69) / 12.0)
        for index in 0..<count {
            let time = Double(index) / sampleRate
            result[index] += Float(0.025 * sin(2 * Double.pi * frequency * time))
        }
    }
    return result
}

private func edgeEnvelope(index: Int, count: Int, sampleRate: Double) -> Double {
    let fadeSamples = max(1, Int(sampleRate * 0.01))
    if index < fadeSamples { return Double(index) / Double(fadeSamples) }
    if index >= count - fadeSamples { return Double(count - index - 1) / Double(fadeSamples) }
    return 1
}
