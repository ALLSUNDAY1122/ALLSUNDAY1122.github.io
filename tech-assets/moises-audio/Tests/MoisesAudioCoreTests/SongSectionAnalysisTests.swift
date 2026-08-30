import Foundation
import XCTest
@testable import MoisesAudioCore

final class SongSectionAnalysisTests: XCTestCase {
    func testSectionAnalyzerFindsBoundariesAndRepeatedStructuralFamily() throws {
        let fixture = makeSectionFixture(addBeatClicks: false)
        let sections = SongSectionAnalyzer.analyze(signal: fixture.signal, chords: fixture.referenceChords)

        XCTAssertEqual(sections.count, 5)
        XCTAssertEqual(sections.map(\.startSeconds), [0, 4, 12, 20, 28])
        XCTAssertEqual(sections.map(\.endSeconds), [4, 12, 20, 28, 32])
        XCTAssertEqual(sections[1].structuralLabel, sections[3].structuralLabel)
        XCTAssertNotEqual(sections[1].structuralLabel, sections[2].structuralLabel)
        XCTAssertEqual(sections.first?.functionalLabel, "intro")
        XCTAssertEqual(sections.last?.functionalLabel, "outro")
        XCTAssertNil(sections[1].functionalLabel)
        XCTAssertNil(sections[2].functionalLabel)
        XCTAssertNil(sections[3].functionalLabel)
        XCTAssertTrue(sections.compactMap(\.confidence).allSatisfy { (0...1).contains($0) })
    }

    func testSilenceReturnsExplicitUnknownSection() {
        let signal = AnalysisSignal(sampleRate: 8_000, monoSamples: Array(repeating: 0, count: 64_000))
        let sections = SongSectionAnalyzer.analyze(signal: signal, chords: [])

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].structuralLabel, "X")
        XCTAssertNil(sections[0].functionalLabel)
        XCTAssertNil(sections[0].confidence)
        XCTAssertEqual(sections[0].startSeconds, 0, accuracy: 1e-9)
        XCTAssertEqual(sections[0].endSeconds, 8, accuracy: 1e-9)
    }

    func testLowChordCoverageReturnsUnknownInsteadOfInventedStructure() {
        let signal = AnalysisSignal(
            sampleRate: 8_000,
            monoSamples: sineTone(midi: 60, duration: 8, sampleRate: 8_000, amplitude: 0.12)
        )
        let chords = [
            ChordEvent(startSeconds: 0, endSeconds: 8, normalizedLabel: "X", confidence: nil)
        ]
        let sections = SongSectionAnalyzer.analyze(signal: signal, chords: chords)

        XCTAssertEqual(sections.map(\.structuralLabel), ["X"])
        XCTAssertNil(sections[0].functionalLabel)
    }

    func testSectionTimelineIsGapFreeOrderedAndCodable() throws {
        let fixture = makeSectionFixture(addBeatClicks: false)
        let sections = SongSectionAnalyzer.analyze(signal: fixture.signal, chords: fixture.referenceChords)
        XCTAssertEqual(sections.first?.startSeconds, 0)
        XCTAssertEqual(sections.last?.endSeconds, fixture.signal.durationSeconds)
        for index in 1..<sections.count {
            XCTAssertEqual(sections[index - 1].endSeconds, sections[index].startSeconds, accuracy: 1e-9)
            XCTAssertLessThan(sections[index - 1].startSeconds, sections[index].startSeconds)
        }

        let snapshot = AnalysisSnapshot(tempo: nil, key: nil, chords: fixture.referenceChords, sections: sections)
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(AnalysisSnapshot.self, from: data)
        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.sections.map(\.startSeconds), sections.map(\.startSeconds))
        XCTAssertEqual(decoded.sections.map(\.structuralLabel), sections.map(\.structuralLabel))
    }

    func testPerfectSectionReferenceProducesPerfectAN001Metrics() throws {
        let reference = referenceSections()
        let metrics = SectionBenchmarkEvaluator.metrics(reference: reference, estimated: reference, duration: 32)

        XCTAssertEqual(try XCTUnwrap(metrics["boundary_f_0_5s"]), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(metrics["boundary_f_3_0s"]), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(metrics["pairwise_f"]), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(metrics["adjusted_rand_index"]), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(metrics["normalized_ref_given_est_entropy"]), 0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(metrics["normalized_est_given_ref_entropy"]), 0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(metrics["structural_coverage"]), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(metrics["functional_macro_f1"]), 1, accuracy: 1e-9)
    }

    func testBoundaryShiftIsVisibleAtStrictToleranceButAcceptedAtThreeSeconds() throws {
        let reference = referenceSections()
        let estimated = [
            section(0, 5, "A", "intro"),
            section(5, 13, "B", nil),
            section(13, 21, "C", nil),
            section(21, 29, "B", nil),
            section(29, 32, "A", "outro")
        ]
        let metrics = SectionBenchmarkEvaluator.metrics(reference: reference, estimated: estimated, duration: 32)

        XCTAssertEqual(try XCTUnwrap(metrics["boundary_f_0_5s"]), 0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(metrics["boundary_f_3_0s"]), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(metrics["median_reference_to_estimate_boundary_error_seconds"]), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(metrics["median_estimate_to_reference_boundary_error_seconds"]), 1, accuracy: 1e-9)
    }

    func testUnknownEstimateReducesStructuralCoverage() throws {
        let reference = referenceSections()
        let estimated = [section(0, 32, "X", nil, confidence: nil)]
        let metrics = SectionBenchmarkEvaluator.metrics(reference: reference, estimated: estimated, duration: 32)

        XCTAssertEqual(try XCTUnwrap(metrics["structural_coverage"]), 0, accuracy: 1e-9)
        XCTAssertLessThan(try XCTUnwrap(metrics["pairwise_f"]), 1)
        XCTAssertLessThan(try XCTUnwrap(metrics["adjusted_rand_index"]), 1)
    }

    func testCombinedProjectAnalyzerPopulatesTempoKeyChordsAndSections() async throws {
        let fixture = makeSectionFixture(addBeatClicks: true)
        let loader = SectionSignalLoader(signal: fixture.signal)
        let configuration = MusicAnalysisConfiguration(
            minimumTempoConfidence: 0.05,
            minimumKeyConfidence: 0.005,
            minimumChordConfidence: 0.08,
            minimumChordTemplateScore: 0.52,
            sectionNoveltyThreshold: 0.36
        )
        let analyzer: any MusicAnalyzing = ProjectOwnedMusicAnalyzer(loader: loader, configuration: configuration)
        let asset = LocalAudioAsset(
            id: AssetID(),
            relativePath: "imports/combined-analysis.wav",
            mediaKind: .audio,
            durationSeconds: fixture.signal.durationSeconds
        )

        let snapshot = try await analyzer.analyze(projectID: ProjectID(), asset: asset)

        XCTAssertNotNil(snapshot.tempo)
        XCTAssertNotNil(snapshot.key)
        XCTAssertFalse(snapshot.chords.isEmpty)
        XCTAssertFalse(snapshot.sections.isEmpty)
        XCTAssertEqual(snapshot.sections.first?.startSeconds, 0)
        XCTAssertEqual(snapshot.sections.last?.endSeconds, fixture.signal.durationSeconds)
        XCTAssertTrue(snapshot.chords.allSatisfy { $0.endSeconds > $0.startSeconds })
        XCTAssertTrue(snapshot.sections.allSatisfy { $0.endSeconds > $0.startSeconds })
    }
}

private struct SectionSignalLoader: AnalysisSignalLoading {
    let signal: AnalysisSignal
    func loadSignal(projectID: ProjectID, asset: LocalAudioAsset) async throws -> AnalysisSignal { signal }
}

private func makeSectionFixture(addBeatClicks: Bool) -> (signal: AnalysisSignal, referenceChords: [ChordEvent]) {
    let sampleRate = 8_000.0
    var samples: [Float] = []
    var chords: [ChordEvent] = []
    var time = 0.0

    func appendChord(root: Int, minor: Bool, duration: Double, amplitude: Double) {
        let startSample = samples.count
        let segment = triad(root: root, minor: minor, duration: duration, sampleRate: sampleRate, amplitude: amplitude)
        samples.append(contentsOf: segment)
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        chords.append(
            ChordEvent(
                startSeconds: time,
                endSeconds: time + duration,
                normalizedLabel: names[root] + (minor ? ":min" : ""),
                confidence: 0.9
            )
        )
        if addBeatClicks {
            addClicks(to: &samples, startSample: startSample, count: segment.count, sampleRate: sampleRate)
        }
        time += duration
    }

    appendChord(root: 0, minor: false, duration: 4, amplitude: 0.08)
    appendChord(root: 0, minor: false, duration: 2, amplitude: 0.18)
    appendChord(root: 9, minor: true, duration: 2, amplitude: 0.18)
    appendChord(root: 5, minor: false, duration: 2, amplitude: 0.18)
    appendChord(root: 7, minor: false, duration: 2, amplitude: 0.18)
    appendChord(root: 2, minor: false, duration: 2, amplitude: 0.30)
    appendChord(root: 11, minor: true, duration: 2, amplitude: 0.30)
    appendChord(root: 7, minor: false, duration: 2, amplitude: 0.30)
    appendChord(root: 9, minor: false, duration: 2, amplitude: 0.30)
    appendChord(root: 0, minor: false, duration: 2, amplitude: 0.18)
    appendChord(root: 9, minor: true, duration: 2, amplitude: 0.18)
    appendChord(root: 5, minor: false, duration: 2, amplitude: 0.18)
    appendChord(root: 7, minor: false, duration: 2, amplitude: 0.18)
    appendChord(root: 0, minor: false, duration: 4, amplitude: 0.06)

    return (AnalysisSignal(sampleRate: sampleRate, monoSamples: samples), chords)
}

private func referenceSections() -> [SongSection] {
    [
        section(0, 4, "A", "intro"),
        section(4, 12, "B", nil),
        section(12, 20, "C", nil),
        section(20, 28, "B", nil),
        section(28, 32, "A", "outro")
    ]
}

private func section(
    _ start: Double,
    _ end: Double,
    _ structural: String,
    _ functional: String?,
    confidence: Double? = 0.8
) -> SongSection {
    SongSection(
        startSeconds: start,
        endSeconds: end,
        structuralLabel: structural,
        functionalLabel: functional,
        confidence: confidence
    )
}

private func triad(
    root: Int,
    minor: Bool,
    duration: Double,
    sampleRate: Double,
    amplitude: Double
) -> [Float] {
    let intervals = minor ? [0, 3, 7] : [0, 4, 7]
    let count = Int((duration * sampleRate).rounded())
    var output = Array(repeating: Float(0), count: count)
    for interval in intervals {
        var midi = 60 + root + interval
        if midi > 71 { midi -= 12 }
        let frequency = 440 * pow(2, Double(midi - 69) / 12)
        for index in 0..<count {
            let time = Double(index) / sampleRate
            output[index] += Float((amplitude / 3) * sin(2 * Double.pi * frequency * time))
        }
    }
    return output
}

private func sineTone(midi: Int, duration: Double, sampleRate: Double, amplitude: Double) -> [Float] {
    let count = Int((duration * sampleRate).rounded())
    let frequency = 440 * pow(2, Double(midi - 69) / 12)
    return (0..<count).map { index in
        Float(amplitude * sin(2 * Double.pi * frequency * Double(index) / sampleRate))
    }
}

private func addClicks(to samples: inout [Float], startSample: Int, count: Int, sampleRate: Double) {
    let clickSpacing = Int((0.5 * sampleRate).rounded())
    let clickLength = max(1, Int((0.012 * sampleRate).rounded()))
    var local = 0
    while local < count {
        for offset in 0..<min(clickLength, count - local) {
            let envelope = 1 - Double(offset) / Double(clickLength)
            samples[startSample + local + offset] += Float(0.45 * envelope)
        }
        local += clickSpacing
    }
}
