import Foundation
import XCTest
@testable import MoisesAudioCore

final class TempoKeyAnalysisTests: XCTestCase {
    func testProjectOwnedAnalyzerDetects120BPMAndCMajor() async throws {
        let fixture = makeFixture(bpm: 120, chord: [261.6256, 329.6276, 391.9954], tonic: 0, mode: "major", duration: 12)
        let analyzer = ProjectOwnedMusicAnalyzer(loader: MemorySignalLoader(signal: fixture.signal))
        let asset = LocalAudioAsset(id: AssetID(), relativePath: "unit.wav", mediaKind: .audio, durationSeconds: fixture.signal.durationSeconds)

        let snapshot = try await analyzer.analyze(projectID: ProjectID(), asset: asset)
        let tempo = try XCTUnwrap(snapshot.tempo)
        let key = try XCTUnwrap(snapshot.key)

        XCTAssertLessThan(abs(tempo.bpm - 120) / 120, 0.04)
        XCTAssertGreaterThan(tempo.confidence ?? 0, 0)
        XCTAssertGreaterThanOrEqual(tempo.beatTimesSeconds.count, 20)
        XCTAssertEqual(key.tonicPitchClass, 0)
        XCTAssertEqual(key.mode, "major")
        XCTAssertGreaterThan(key.confidence ?? 0, 0)
    }

    func testProjectOwnedAnalyzerDetects90BPMAndAMinor() async throws {
        let fixture = makeFixture(bpm: 90, chord: [220.0, 261.6256, 329.6276], tonic: 9, mode: "minor", duration: 12)
        let analyzer = ProjectOwnedMusicAnalyzer(loader: MemorySignalLoader(signal: fixture.signal))
        let asset = LocalAudioAsset(id: AssetID(), relativePath: "unit.wav", mediaKind: .audio, durationSeconds: fixture.signal.durationSeconds)

        let snapshot = try await analyzer.analyze(projectID: ProjectID(), asset: asset)
        let tempo = try XCTUnwrap(snapshot.tempo)
        let key = try XCTUnwrap(snapshot.key)

        XCTAssertLessThan(abs(tempo.bpm - 90) / 90, 0.04)
        XCTAssertEqual(key.tonicPitchClass, 9)
        XCTAssertEqual(key.mode, "minor")
    }

    func testTempoDoesNotCollapse180BPMToHalfTempo() throws {
        let fixture = makeFixture(bpm: 180, chord: [261.6256, 329.6276, 391.9954], tonic: 0, mode: "major", duration: 10)
        let tempo = try XCTUnwrap(TempoBeatAnalyzer.analyze(signal: fixture.signal))
        XCTAssertLessThan(abs(tempo.bpm - 180) / 180, 0.04)
    }

    func testUnknownHandlingRejectsSilenceShortAudioSustainedFalseTempoAndAmbiguousKey() async throws {
        let silent = AnalysisSignal(sampleRate: 8_000, monoSamples: Array(repeating: 0, count: 40_000))
        XCTAssertNil(TempoBeatAnalyzer.analyze(signal: silent))
        XCTAssertNil(MusicalKeyAnalyzer.analyze(signal: silent))

        let short = AnalysisSignal(sampleRate: 8_000, monoSamples: Array(repeating: 0.1, count: 1_000))
        let analyzer = ProjectOwnedMusicAnalyzer(loader: MemorySignalLoader(signal: short))
        let asset = LocalAudioAsset(id: AssetID(), relativePath: "short.wav", mediaKind: .audio, durationSeconds: short.durationSeconds)
        let shortSnapshot = try await analyzer.analyze(projectID: ProjectID(), asset: asset)
        XCTAssertNil(shortSnapshot.tempo)
        XCTAssertNil(shortSnapshot.key)

        let steadyCMajor = makeSignal(chord: [261.6256, 329.6276, 391.9954], duration: 8, bpm: nil)
        XCTAssertNil(TempoBeatAnalyzer.analyze(signal: steadyCMajor), "Sustained tonal energy must not be converted into a fake pulse train")
        XCTAssertEqual(MusicalKeyAnalyzer.analyze(signal: steadyCMajor)?.tonicPitchClass, 0)

        let chromaticFrequencies = (60..<72).map { midi in 440.0 * pow(2.0, Double(midi - 69) / 12.0) }
        let chromatic = makeSignal(chord: chromaticFrequencies, duration: 8, bpm: nil)
        XCTAssertNil(MusicalKeyAnalyzer.analyze(signal: chromatic), "Flat chroma should remain unknown rather than forcing a key")

        let nonFinite = AnalysisSignal(sampleRate: 8_000, monoSamples: Array(repeating: Float.nan, count: 40_000))
        XCTAssertNil(TempoBeatAnalyzer.analyze(signal: nonFinite))
        XCTAssertNil(MusicalKeyAnalyzer.analyze(signal: nonFinite))
    }

    func testSyntheticBenchmarkRowsAreExplicitlyNonParityAndSerializeWithSnapshot() throws {
        let fixture = makeFixture(bpm: 120, chord: [261.6256, 329.6276, 391.9954], tonic: 0, mode: "major", duration: 8)
        let start = Date()
        let tempo = try XCTUnwrap(TempoBeatAnalyzer.analyze(signal: fixture.signal))
        let key = try XCTUnwrap(MusicalKeyAnalyzer.analyze(signal: fixture.signal))
        let wallSeconds = Date().timeIntervalSince(start)
        let snapshot = AnalysisSnapshot(tempo: tempo, key: key, chords: [], sections: [])

        let rows = AnalysisBenchmarkRunner.evaluate(fixture: fixture, snapshot: snapshot, wallSeconds: wallSeconds)
        XCTAssertEqual(rows.count, 3)
        XCTAssertTrue(rows.allSatisfy { !$0.parityEligible && $0.syntheticOnly })
        XCTAssertEqual(rows.first(where: { $0.domain == "tempo" })?.metrics["exact_within_4pct"], 1)
        XCTAssertGreaterThan(rows.first(where: { $0.domain == "beat" })?.metrics["beat_f_70ms"] ?? 0, 0.85)
        XCTAssertEqual(rows.first(where: { $0.domain == "key" })?.metrics["exact_key_accuracy"], 1)
        XCTAssertNil(rows.first?.peakRSSMB)
        XCTAssertNil(rows.first?.thermal)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let rowData = try encoder.encode(rows)
        let decodedRows = try JSONDecoder().decode([AnalysisBenchmarkRow].self, from: rowData)
        XCTAssertEqual(decodedRows, rows)

        let snapshotData = try encoder.encode(snapshot)
        let decodedSnapshot = try JSONDecoder().decode(AnalysisSnapshot.self, from: snapshotData)
        XCTAssertEqual(decodedSnapshot, snapshot)
    }

    func testBenchmarkMetricHelpersExposeOctaveAndKeyRelationships() {
        XCTAssertEqual(AnalysisBenchmarkRunner.beatFMeasure(reference: [0, 0.5, 1], estimated: [0.01, 0.49, 1.03]), 1, accuracy: 1e-12)
        XCTAssertEqual(AnalysisBenchmarkRunner.weightedKeyScore(reference: MusicalKey(tonicPitchClass: 0, mode: "major", confidence: nil), estimated: MusicalKey(tonicPitchClass: 7, mode: "major", confidence: nil)), 0.5)
        XCTAssertEqual(AnalysisBenchmarkRunner.weightedKeyScore(reference: MusicalKey(tonicPitchClass: 0, mode: "major", confidence: nil), estimated: MusicalKey(tonicPitchClass: 9, mode: "minor", confidence: nil)), 0.3)
        XCTAssertEqual(AnalysisBenchmarkRunner.weightedKeyScore(reference: MusicalKey(tonicPitchClass: 0, mode: "major", confidence: nil), estimated: MusicalKey(tonicPitchClass: 0, mode: "minor", confidence: nil)), 0.2)
    }
}

private struct MemorySignalLoader: AnalysisSignalLoading {
    let signal: AnalysisSignal
    func loadSignal(projectID: ProjectID, asset: LocalAudioAsset) async throws -> AnalysisSignal { signal }
}

private func makeSignal(chord: [Double], duration: Double, bpm: Double?) -> AnalysisSignal {
    let sampleRate = 8_000.0
    let count = Int(sampleRate * duration)
    var samples = Array(repeating: Float(0), count: count)
    for index in 0..<count {
        let time = Double(index) / sampleRate
        var value = chord.reduce(0.0) { partial, frequency in
            partial + sin(2 * Double.pi * frequency * time) * (0.30 / Double(max(chord.count, 1)))
        }
        if let bpm {
            let beatPeriod = 60.0 / bpm
            let phase = time.truncatingRemainder(dividingBy: beatPeriod)
            if phase < 0.018 {
                value += (1 - phase / 0.018) * 0.85
            }
        }
        samples[index] = Float(max(-1, min(1, value)))
    }
    return AnalysisSignal(sampleRate: sampleRate, monoSamples: samples)
}

private func makeFixture(bpm: Double, chord: [Double], tonic: Int, mode: String, duration: Double) -> AnalysisBenchmarkFixture {
    let signal = makeSignal(chord: chord, duration: duration, bpm: bpm)
    let beats = stride(from: 0.0, through: duration - 0.001, by: 60.0 / bpm).map { $0 }
    return AnalysisBenchmarkFixture(
        fixtureID: "synthetic-\(Int(bpm))-\(tonic)-\(mode)",
        rightsClass: .projectOwned,
        genre: "unit-synthetic",
        syntheticOnly: true,
        signal: signal,
        reference: TempoBeatKeyReference(
            bpm: bpm,
            beatTimesSeconds: beats,
            key: MusicalKey(tonicPitchClass: tonic, mode: mode, confidence: 1)
        )
    )
}
