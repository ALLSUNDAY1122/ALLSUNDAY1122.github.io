import Foundation
import XCTest
@testable import MoisesAudioCore

final class RealAudioBenchmarkSuiteTests: XCTestCase {
    func testValidRightsClearedRealAudioCaseIsParityEligible() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let item = makeBenchmarkCase(sourceKind: .realAudio)
        let manifest = AnalysisRealAudioBenchmarkManifest(manifestID: "golden-mir-v1", createdAt: now, cases: [item])

        XCTAssertTrue(AnalysisRealAudioManifestValidator.validate(manifest, at: now).isEmpty)
        XCTAssertTrue(AnalysisRealAudioManifestValidator.isParityEligible(item, at: now))
    }

    func testSyntheticCaseNeverBecomesParityEligible() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let item = makeBenchmarkCase(sourceKind: .syntheticTest)
        let manifest = AnalysisRealAudioBenchmarkManifest(manifestID: "synthetic", createdAt: now, cases: [item])

        XCTAssertTrue(AnalysisRealAudioManifestValidator.validate(manifest, at: now).isEmpty)
        XCTAssertFalse(AnalysisRealAudioManifestValidator.isParityEligible(item, at: now))
    }

    func testManifestFailsClosedForRightsPathHashAndReferenceDefects() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let valid = makeBenchmarkCase()
        let invalid = AnalysisRealAudioBenchmarkCase(
            fixtureID: "bad",
            projectID: valid.projectID,
            assetID: valid.assetID,
            relativePath: "../escape.wav",
            genre: "rock",
            sourceKind: .realAudio,
            expectedDurationSeconds: 4,
            rights: AnalysisRightsEvidence(
                grantID: "",
                rightsClass: .projectOwned,
                permittedUses: [],
                expiresAt: now.addingTimeInterval(-1),
                sourceSHA256: "not-a-sha"
            ),
            reference: AnalysisReferenceAnnotation()
        )
        let manifest = AnalysisRealAudioBenchmarkManifest(manifestID: "invalid", createdAt: now, cases: [invalid])
        let codes = Set(AnalysisRealAudioManifestValidator.validate(manifest, at: now).map(\.code))

        XCTAssertTrue(codes.contains(.unsafeRelativePath))
        XCTAssertTrue(codes.contains(.emptyRightsGrantID))
        XCTAssertTrue(codes.contains(.benchmarkUseNotPermitted))
        XCTAssertTrue(codes.contains(.expiredRightsGrant))
        XCTAssertTrue(codes.contains(.invalidSourceSHA256))
        XCTAssertTrue(codes.contains(.noReferenceDomain))
    }

    func testManifestRejectsDuplicateIDsAndBrokenTimelineAnnotations() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let base = makeBenchmarkCase()
        let broken = AnalysisRealAudioBenchmarkCase(
            fixtureID: base.fixtureID,
            projectID: base.projectID,
            assetID: base.assetID,
            relativePath: base.relativePath,
            genre: base.genre,
            sourceKind: .realAudio,
            expectedDurationSeconds: 4,
            rights: base.rights,
            reference: AnalysisReferenceAnnotation(
                bpm: 120,
                beatTimesSeconds: [0, 0.5, 4.5],
                key: MusicalKey(tonicPitchClass: 0, mode: "major", confidence: 1),
                chords: [
                    ChordEvent(startSeconds: 0, endSeconds: 2.5, normalizedLabel: "C", confidence: 1),
                    ChordEvent(startSeconds: 2.0, endSeconds: 4.0, normalizedLabel: "G", confidence: 1)
                ],
                sections: [
                    SongSection(startSeconds: 0, endSeconds: 1.5, structuralLabel: "A", functionalLabel: "intro", confidence: 1),
                    SongSection(startSeconds: 2.0, endSeconds: 3.5, structuralLabel: "B", functionalLabel: "verse", confidence: 1)
                ]
            )
        )
        let manifest = AnalysisRealAudioBenchmarkManifest(manifestID: "broken", createdAt: now, cases: [base, broken])
        let codes = Set(AnalysisRealAudioManifestValidator.validate(manifest, at: now).map(\.code))

        XCTAssertTrue(codes.contains(.duplicateFixtureID))
        XCTAssertTrue(codes.contains(.beatOutsideDuration))
        XCTAssertTrue(codes.contains(.chordOverlap))
        XCTAssertTrue(codes.contains(.sectionOverlapOrGap))
        XCTAssertTrue(codes.contains(.sectionDoesNotCoverTrack))
    }

    func testBatchRunnerProducesAllAnalysisDomainsButSyntheticEvidenceRemainsNonParity() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let item = makeBenchmarkCase(sourceKind: .syntheticTest)
        let manifest = AnalysisRealAudioBenchmarkManifest(manifestID: "synthetic-batch", createdAt: now, cases: [item])
        let signal = makeBenchmarkSignal(duration: 4)
        let loader = MemoryBenchmarkSignalLoader(signal: signal, sourceSHA256: benchmarkSHA())

        let report = try await AnalysisRealAudioBenchmarkRunner.run(
            manifest: manifest,
            loader: loader,
            engineVersion: "test",
            runDate: now
        )

        XCTAssertEqual(report.rows.map(\.domain).sorted(), ["beat", "chord", "key", "structure", "tempo"])
        XCTAssertEqual(report.summaries.map(\.domain).sorted(), ["beat", "chord", "key", "structure", "tempo"])
        XCTAssertFalse(report.parityEligible)
        XCTAssertTrue(report.rows.allSatisfy { !$0.parityEligible })

        let data = try JSONEncoder().encode(report)
        XCTAssertEqual(try JSONDecoder().decode(AnalysisRealAudioBenchmarkReport.self, from: data), report)
    }

    func testBatchRunnerRejectsChecksumAndDurationMismatch() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let real = makeBenchmarkCase(sourceKind: .realAudio)
        let manifest = AnalysisRealAudioBenchmarkManifest(manifestID: "real", createdAt: now, cases: [real])
        let correctDuration = makeBenchmarkSignal(duration: 4)

        do {
            _ = try await AnalysisRealAudioBenchmarkRunner.run(
                manifest: manifest,
                loader: MemoryBenchmarkSignalLoader(signal: correctDuration, sourceSHA256: String(repeating: "b", count: 64)),
                runDate: now
            )
            XCTFail("checksum mismatch must fail closed")
        } catch AnalysisRealAudioBenchmarkError.sourceChecksumMismatch(let fixtureID, _, _) {
            XCTAssertEqual(fixtureID, real.fixtureID)
        }

        do {
            _ = try await AnalysisRealAudioBenchmarkRunner.run(
                manifest: manifest,
                loader: MemoryBenchmarkSignalLoader(signal: makeBenchmarkSignal(duration: 3.5), sourceSHA256: benchmarkSHA()),
                runDate: now
            )
            XCTFail("duration mismatch must fail closed")
        } catch AnalysisRealAudioBenchmarkError.durationMismatch(let fixtureID, _, _) {
            XCTAssertEqual(fixtureID, real.fixtureID)
        }
    }
}

private struct MemoryBenchmarkSignalLoader: AnalysisBenchmarkSignalLoading {
    let signal: AnalysisSignal
    let sourceSHA256: String

    func loadBenchmarkSignal(projectID: ProjectID, asset: LocalAudioAsset) async throws -> AnalysisBenchmarkLoadedSignal {
        AnalysisBenchmarkLoadedSignal(signal: signal, sourceSHA256: sourceSHA256)
    }
}

private func makeBenchmarkCase(sourceKind: AnalysisBenchmarkSourceKind = .realAudio) -> AnalysisRealAudioBenchmarkCase {
    AnalysisRealAudioBenchmarkCase(
        fixtureID: "rock-001",
        projectID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        assetID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        relativePath: "fixtures/golden/rock-001.wav",
        genre: "rock",
        sourceKind: sourceKind,
        expectedDurationSeconds: 4,
        rights: AnalysisRightsEvidence(
            grantID: "project-owned-rock-001",
            rightsClass: .projectOwned,
            permittedUses: [.analysisBenchmark, .internalQualityReview],
            sourceSHA256: benchmarkSHA()
        ),
        reference: AnalysisReferenceAnnotation(
            bpm: 120,
            beatTimesSeconds: stride(from: 0.0, to: 4.0, by: 0.5).map { $0 },
            key: MusicalKey(tonicPitchClass: 0, mode: "major", confidence: 1),
            chords: [ChordEvent(startSeconds: 0, endSeconds: 4, normalizedLabel: "C", confidence: 1)],
            sections: [SongSection(startSeconds: 0, endSeconds: 4, structuralLabel: "A", functionalLabel: "verse", confidence: 1)]
        )
    )
}

private func makeBenchmarkSignal(duration: Double) -> AnalysisSignal {
    let sampleRate = 8_000.0
    let count = Int(sampleRate * duration)
    var samples = Array(repeating: Float(0), count: count)
    for index in samples.indices {
        let time = Double(index) / sampleRate
        let tone = 0.12 * sin(2 * Double.pi * 261.6256 * time)
            + 0.10 * sin(2 * Double.pi * 329.6276 * time)
            + 0.08 * sin(2 * Double.pi * 391.9954 * time)
        let phase = time.truncatingRemainder(dividingBy: 0.5)
        let click = phase < 0.015 ? (1 - phase / 0.015) * 0.7 : 0
        samples[index] = Float(max(-1, min(1, tone + click)))
    }
    return AnalysisSignal(sampleRate: sampleRate, monoSamples: samples)
}

private func benchmarkSHA() -> String {
    String(repeating: "a", count: 64)
}
