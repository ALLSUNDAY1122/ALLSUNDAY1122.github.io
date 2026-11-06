import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisBenchmarkCorpusCoverageTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_787_531_400)
    private let manifestSHA = String(repeating: "a", count: 64)
    private let sourceSHA = String(repeating: "c", count: 64)

    private func rights(differential: Bool = true) -> AnalysisRightsEvidence {
        var uses: Set<AnalysisBenchmarkPermittedUse> = [.analysisBenchmark]
        if differential { uses.insert(.differentialReference) }
        return .init(
            grantID: "grant",
            rightsClass: .licensedTest,
            permittedUses: uses,
            sourceSHA256: sourceSHA
        )
    }

    private func fixture(
        id: String,
        genre: String,
        bpm: Double,
        mode: String,
        chordLabels: [String],
        sections: [(String, String?)],
        sourceKind: AnalysisBenchmarkSourceKind = .realAudio,
        differential: Bool = true
    ) -> AnalysisRealAudioBenchmarkCase {
        let chordSpan = 120.0 / Double(chordLabels.count)
        let chords = chordLabels.enumerated().map { index, label in
            ChordEvent(
                startSeconds: Double(index) * chordSpan,
                endSeconds: Double(index + 1) * chordSpan,
                normalizedLabel: label,
                confidence: nil
            )
        }
        let sectionSpan = 120.0 / Double(sections.count)
        let sectionEvents = sections.enumerated().map { index, value in
            SongSection(
                startSeconds: Double(index) * sectionSpan,
                endSeconds: Double(index + 1) * sectionSpan,
                structuralLabel: value.0,
                functionalLabel: value.1,
                confidence: nil
            )
        }
        return .init(
            fixtureID: id,
            projectID: UUID(),
            assetID: UUID(),
            relativePath: "fixtures/\(id).wav",
            genre: genre,
            sourceKind: sourceKind,
            expectedDurationSeconds: 120,
            rights: rights(differential: differential),
            reference: .init(
                bpm: bpm,
                beatTimesSeconds: stride(from: 0.0, to: 120.0, by: 0.5).map { $0 },
                key: MusicalKey(tonicPitchClass: 0, mode: mode, confidence: nil),
                chords: chords,
                sections: sectionEvents
            )
        )
    }

    private func manifest(_ cases: [AnalysisRealAudioBenchmarkCase]) -> AnalysisRealAudioBenchmarkManifest {
        .init(manifestID: "golden-v1", createdAt: now, cases: cases)
    }

    private func domainMinimums(count: Int = 2, duration: Double = 200) -> [AnalysisCorpusCoverageDomainMinimum] {
        ["tempo", "beat", "key", "chord", "structure"].map {
            .init(domain: $0, minimumFixtureCount: count, minimumTotalDurationSeconds: duration)
        }
    }

    private func strata() -> [AnalysisCorpusCoverageStratum] {
        [
            .init(stratumID: "genre-rock", domain: "tempo", minimumFixtureCount: 1, minimumTotalDurationSeconds: 100, predicate: .init(genreExact: "rock")),
            .init(stratumID: "tempo-slow", domain: "tempo", minimumFixtureCount: 1, minimumTotalDurationSeconds: 100, predicate: .init(maximumBPMExclusive: 100)),
            .init(stratumID: "tempo-fast", domain: "beat", minimumFixtureCount: 1, minimumTotalDurationSeconds: 100, predicate: .init(minimumBPMInclusive: 140)),
            .init(stratumID: "key-minor", domain: "key", minimumFixtureCount: 1, minimumTotalDurationSeconds: 100, predicate: .init(keyModeExact: "minor")),
            .init(stratumID: "chord-extended", domain: "chord", minimumFixtureCount: 1, minimumTotalDurationSeconds: 100, predicate: .init(chordQualitiesAnyOf: ["major7", "minor7"])),
            .init(stratumID: "chord-inversion", domain: "chord", minimumFixtureCount: 1, minimumTotalDurationSeconds: 100, predicate: .init(requiresChordInversion: true)),
            .init(stratumID: "chord-no-chord", domain: "chord", minimumFixtureCount: 1, minimumTotalDurationSeconds: 100, predicate: .init(requiresNoChord: true)),
            .init(stratumID: "structure-varied", domain: "structure", minimumFixtureCount: 2, minimumTotalDurationSeconds: 200, predicate: .init(minimumDistinctStructuralLabels: 2, requiredFunctionalLabels: ["verse", "chorus"])),
            .init(stratumID: "structure-repeat", domain: "structure", minimumFixtureCount: 1, minimumTotalDurationSeconds: 100, predicate: .init(requiresRepeatedStructuralLabel: true))
        ]
    }

    private func policy(
        domainMinimums: [AnalysisCorpusCoverageDomainMinimum]? = nil,
        strata: [AnalysisCorpusCoverageStratum]? = nil
    ) -> AnalysisCorpusCoveragePolicy {
        .init(
            policyID: "coverage-v1",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-COVERAGE-001",
            expectedManifestID: "golden-v1",
            expectedManifestSHA256: manifestSHA,
            minimumUniqueFixtureCount: 2,
            minimumTotalDurationSeconds: 200,
            domainMinimums: domainMinimums ?? self.domainMinimums(),
            strata: strata ?? self.strata()
        )
    }

    private func balancedCases() -> [AnalysisRealAudioBenchmarkCase] {
        [
            fixture(
                id: "rock-slow",
                genre: "rock",
                bpm: 80,
                mode: "major",
                chordLabels: ["C:maj/E", "N", "F:maj"],
                sections: [("A", "verse"), ("B", "chorus"), ("A", "verse")]
            ),
            fixture(
                id: "jazz-fast",
                genre: "jazz",
                bpm: 160,
                mode: "minor",
                chordLabels: ["C:maj7", "D:min7", "G:7"],
                sections: [("A", "verse"), ("B", "chorus"), ("C", "bridge")]
            )
        ]
    }

    func testBalancedCorpusSatisfiesExternallySuppliedCoveragePolicy() {
        let report = AnalysisCorpusCoverageValidator.validate(
            manifest: manifest(balancedCases()),
            manifestSHA256: manifestSHA,
            policy: policy(),
            evaluatedAt: now
        )
        XCTAssertTrue(report.comparisonCorpusReady)
        XCTAssertEqual(report.status, .sufficientPendingHQ)
        XCTAssertEqual(report.eligibleFixtureCount, 2)
        XCTAssertTrue(report.domainDiagnostics.allSatisfy(\.satisfied))
        XCTAssertTrue(report.stratumDiagnostics.allSatisfy(\.satisfied))
        XCTAssertTrue(report.issues.isEmpty)
    }

    func testTrivialOneTrackCorpusFailsGlobalDomainAndStratumMinimums() {
        let report = AnalysisCorpusCoverageValidator.validate(
            manifest: manifest([balancedCases()[0]]),
            manifestSHA256: manifestSHA,
            policy: policy(),
            evaluatedAt: now
        )
        XCTAssertFalse(report.comparisonCorpusReady)
        XCTAssertTrue(report.issues.contains { $0.code == .globalFixtureDeficit })
        XCTAssertTrue(report.issues.contains { $0.code == .domainFixtureDeficit })
        XCTAssertTrue(report.issues.contains { $0.code == .stratumFixtureDeficit })
    }

    func testExactManifestHashBindingPreventsCorpusSwap() {
        let report = AnalysisCorpusCoverageValidator.validate(
            manifest: manifest(balancedCases()),
            manifestSHA256: String(repeating: "b", count: 64),
            policy: policy(),
            evaluatedAt: now
        )
        XCTAssertTrue(report.issues.contains { $0.code == .manifestBindingMismatch })
    }

    func testEveryAnalysisDomainMustHaveAnHQMinimum() {
        let partial = [AnalysisCorpusCoverageDomainMinimum(domain: "tempo", minimumFixtureCount: 1, minimumTotalDurationSeconds: 1)]
        let report = AnalysisCorpusCoverageValidator.validate(
            manifest: manifest(balancedCases()),
            manifestSHA256: manifestSHA,
            policy: policy(domainMinimums: partial),
            evaluatedAt: now
        )
        XCTAssertEqual(report.issues.filter { $0.code == .requiredDomainMissing }.count, 4)
    }

    func testDuplicateDomainAndStratumDefinitionsFailWithoutDictionaryTrap() {
        let duplicateDomains = domainMinimums() + [domainMinimums()[0]]
        let duplicateStrata = strata() + [strata()[0]]
        let report = AnalysisCorpusCoverageValidator.validate(
            manifest: manifest(balancedCases()),
            manifestSHA256: manifestSHA,
            policy: policy(domainMinimums: duplicateDomains, strata: duplicateStrata),
            evaluatedAt: now
        )
        XCTAssertTrue(report.issues.contains { $0.code == .duplicateDomainMinimum })
        XCTAssertTrue(report.issues.contains { $0.code == .duplicateStratumID })
    }

    func testSyntheticAndNonDifferentialFixturesCannotPadCoverage() {
        let synthetic = fixture(
            id: "synthetic-padding", genre: "rock", bpm: 80, mode: "major",
            chordLabels: ["C:maj/E", "N"], sections: [("A", "verse"), ("B", "chorus")],
            sourceKind: .syntheticTest
        )
        let noDifferentialRight = fixture(
            id: "rights-padding", genre: "jazz", bpm: 160, mode: "minor",
            chordLabels: ["C:maj7", "D:min7"], sections: [("A", "verse"), ("B", "chorus")],
            differential: false
        )
        let report = AnalysisCorpusCoverageValidator.validate(
            manifest: manifest(balancedCases() + [synthetic, noDifferentialRight]),
            manifestSHA256: manifestSHA,
            policy: policy(),
            evaluatedAt: now
        )
        XCTAssertFalse(report.comparisonCorpusReady)
        XCTAssertEqual(report.issues.filter { $0.code == .ineligibleFixture }.count, 2)
        XCTAssertEqual(report.eligibleFixtureCount, 2)
    }

    func testTempoBandKeyModeChordAndStructurePredicatesAreDerivedFromGoldenAnnotations() {
        let report = AnalysisCorpusCoverageValidator.validate(
            manifest: manifest(balancedCases()),
            manifestSHA256: manifestSHA,
            policy: policy(),
            evaluatedAt: now
        )
        let diagnostics = Dictionary(uniqueKeysWithValues: report.stratumDiagnostics.map { ($0.stratumID, $0) })
        XCTAssertEqual(diagnostics["tempo-slow"]?.matchedFixtureIDs, ["rock-slow"])
        XCTAssertEqual(diagnostics["tempo-fast"]?.matchedFixtureIDs, ["jazz-fast"])
        XCTAssertEqual(diagnostics["key-minor"]?.matchedFixtureIDs, ["jazz-fast"])
        XCTAssertEqual(diagnostics["chord-inversion"]?.matchedFixtureIDs, ["rock-slow"])
        XCTAssertEqual(diagnostics["chord-no-chord"]?.matchedFixtureIDs, ["rock-slow"])
        XCTAssertEqual(diagnostics["structure-repeat"]?.matchedFixtureIDs, ["rock-slow"])
    }

    func testEmptyOrUnsupportedSemanticPredicateFailsClosed() {
        let empty = AnalysisCorpusCoverageStratum(
            stratumID: "empty", domain: "tempo", minimumFixtureCount: 1, minimumTotalDurationSeconds: 1, predicate: .init()
        )
        let unknownChord = AnalysisCorpusCoverageStratum(
            stratumID: "unknown-chord", domain: "chord", minimumFixtureCount: 1, minimumTotalDurationSeconds: 1,
            predicate: .init(chordQualitiesAnyOf: ["magic13"])
        )
        let report = AnalysisCorpusCoverageValidator.validate(
            manifest: manifest(balancedCases()),
            manifestSHA256: manifestSHA,
            policy: policy(strata: [empty, unknownChord]),
            evaluatedAt: now
        )
        XCTAssertGreaterThanOrEqual(report.issues.filter { $0.code == .invalidPolicy }.count, 2)
    }

    func testCoveragePolicyAndReportCodecRoundTripDeterministically() throws {
        let value = policy()
        let encodedA = try AnalysisCorpusCoverageCodec.encodePolicy(value)
        let encodedB = try AnalysisCorpusCoverageCodec.encodePolicy(value)
        XCTAssertEqual(encodedA, encodedB)
        XCTAssertEqual(try AnalysisCorpusCoverageCodec.decodePolicy(encodedA), value)

        let report = AnalysisCorpusCoverageValidator.validate(
            manifest: manifest(balancedCases()), manifestSHA256: manifestSHA, policy: value, evaluatedAt: now
        )
        let reportData = try AnalysisCorpusCoverageCodec.encodeReport(report)
        XCTAssertEqual(try AnalysisCorpusCoverageCodec.decodeReport(reportData), report)
    }
}
