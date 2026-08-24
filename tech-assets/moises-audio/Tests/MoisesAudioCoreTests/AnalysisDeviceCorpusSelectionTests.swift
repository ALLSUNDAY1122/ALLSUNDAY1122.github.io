import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisDeviceCorpusSelectionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_787_534_800)
    private let manifestSHA = String(repeating: "a", count: 64)

    private func sourceSHA(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }

    private func rights(_ sha: String) -> AnalysisRightsEvidence {
        .init(
            grantID: "grant-\(sha.prefix(4))",
            rightsClass: .licensedTest,
            permittedUses: [.analysisBenchmark, .differentialReference],
            sourceSHA256: sha
        )
    }

    private func fixture(
        id: String,
        sourceSHA: String,
        genre: String,
        bpm: Double,
        mode: String,
        chordLabels: [String],
        sections: [(String, String?)]
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
            sourceKind: .realAudio,
            expectedDurationSeconds: 120,
            rights: rights(sourceSHA),
            reference: .init(
                bpm: bpm,
                beatTimesSeconds: stride(from: 0.0, to: 120.0, by: 0.5).map { $0 },
                key: MusicalKey(tonicPitchClass: 0, mode: mode, confidence: nil),
                chords: chords,
                sections: sectionEvents
            )
        )
    }

    private var rockSlow: AnalysisRealAudioBenchmarkCase {
        fixture(
            id: "rock-slow", sourceSHA: sourceSHA("b"), genre: "rock", bpm: 80, mode: "major",
            chordLabels: ["C:maj/E", "N", "F:maj"],
            sections: [("A", "verse"), ("B", "chorus"), ("A", "verse")]
        )
    }

    private var jazzFast: AnalysisRealAudioBenchmarkCase {
        fixture(
            id: "jazz-fast", sourceSHA: sourceSHA("c"), genre: "jazz", bpm: 160, mode: "minor",
            chordLabels: ["C:maj7", "D:min7", "G:7"],
            sections: [("A", "verse"), ("B", "chorus"), ("C", "bridge")]
        )
    }

    private var easyMid: AnalysisRealAudioBenchmarkCase {
        fixture(
            id: "easy-mid", sourceSHA: sourceSHA("d"), genre: "pop", bpm: 120, mode: "major",
            chordLabels: ["C:maj", "F:maj", "G:maj"],
            sections: [("A", "verse"), ("B", "chorus")]
        )
    }

    private func manifest(_ cases: [AnalysisRealAudioBenchmarkCase]? = nil) -> AnalysisRealAudioBenchmarkManifest {
        .init(manifestID: "golden-v1", createdAt: now, cases: cases ?? [rockSlow, jazzFast, easyMid])
    }

    private func domainMinimums() -> [AnalysisCorpusCoverageDomainMinimum] {
        ["tempo", "beat", "key", "chord", "structure"].map {
            .init(domain: $0, minimumFixtureCount: 2, minimumTotalDurationSeconds: 200)
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

    private func coveragePolicy() -> AnalysisCorpusCoveragePolicy {
        .init(
            policyID: "coverage-v1", authority: "HQ_LATE_INTEGRATION", approvalReference: "HQ-COVERAGE-001",
            expectedManifestID: "golden-v1", expectedManifestSHA256: manifestSHA,
            minimumUniqueFixtureCount: 2, minimumTotalDurationSeconds: 200,
            domainMinimums: domainMinimums(), strata: strata()
        )
    }

    private var workloadIdentity: AnalysisDeviceWorkloadIdentity {
        .init(
            analyzerID: "ProjectOwnedMusicAnalyzer", analyzerVersion: "lane4-w26",
            analysisConfigurationID: "product-baseline-v1", buildIdentity: "build-101"
        )
    }

    private func performanceProfile(_ ids: [String], durations: [String: Double]? = nil) -> AnalysisDevicePerformanceAcceptanceProfile {
        let runs = ids.flatMap { id in
            [
                AnalysisDevicePerformancePlannedRun(runID: "\(id)-c1", fixtureID: id, runKind: .completeAnalysis),
                .init(runID: "\(id)-c2", fixtureID: id, runKind: .completeAnalysis),
                .init(runID: "\(id)-x1", fixtureID: id, runKind: .cancellationProbe),
                .init(runID: "\(id)-x2", fixtureID: id, runKind: .cancellationProbe)
            ]
        }
        return .init(
            profileID: "p1", authority: "HQ_LATE_INTEGRATION", approvalReference: "HQ-P021-001",
            expectedBatchID: "b1", expectedDeviceModel: "iPhone17,3", expectedOSVersion: "20.0",
            expectedAppBundleIdentifier: "com.example.moises", expectedAppVersion: "1.0", expectedBuildVersion: "101",
            expectedManifestID: "golden-v1", expectedManifestSHA256: manifestSHA,
            requiredFixtureIDs: ids,
            expectedFixtureDurationsSeconds: durations ?? Dictionary(uniqueKeysWithValues: ids.map { ($0, 120.0) }),
            minimumCompleteRunsPerFixture: 2, minimumCancellationRunsPerFixture: 2, plannedRuns: runs,
            maximumCompleteWallSeconds: 30, maximumPeakResidentBytes: 500_000_000,
            maximumPeakPhysicalFootprintBytes: 600_000_000,
            maximumStartingThermalState: .fair, maximumWorstThermalState: .serious,
            maximumBatteryDrainFraction: 0.1, maximumMemoryPressureEventCount: 0,
            maximumCancellationLatencySeconds: 0.5, requireUnpluggedBatteryForCompleteRuns: true
        )
    }

    private func workloadPolicy(_ ids: [String], sourceOverride: [String: String] = [:], durationOverride: [String: Double] = [:]) -> AnalysisDeviceWorkloadPolicy {
        let byID = Dictionary(uniqueKeysWithValues: manifest().cases.map { ($0.fixtureID, $0) })
        let fixtures = Dictionary(uniqueKeysWithValues: ids.compactMap { id -> (String, AnalysisDeviceWorkloadSourceBinding)? in
            guard let item = byID[id] else { return nil }
            return (
                id,
                .init(
                    fixtureID: id,
                    sourceSHA256: sourceOverride[id] ?? item.rights.sourceSHA256,
                    sourceDurationSeconds: durationOverride[id] ?? item.expectedDurationSeconds,
                    sourceSampleRate: 44_100,
                    sourceChannelCount: 2
                )
            )
        })
        return .init(
            authority: "HQ_LATE_INTEGRATION", approvalReference: "HQ-W25-APPROVED",
            manifestID: "golden-v1", manifestSHA256: manifestSHA,
            identity: workloadIdentity, fixtures: fixtures
        )
    }

    private func fullSelectionPolicy() -> AnalysisDeviceCorpusSelectionPolicy {
        .init(
            policyID: "selection-full", authority: "HQ_LATE_INTEGRATION", approvalReference: "HQ-W26-001",
            expectedCoveragePolicyID: "coverage-v1", expectedManifestID: "golden-v1", expectedManifestSHA256: manifestSHA,
            mode: .fullW22EligibleCorpus, exactSelectedFixtureIDs: [],
            minimumSelectedFixtureCount: 0, minimumSelectedTotalDurationSeconds: 0,
            domainRequirements: [], stratumRequirements: []
        )
    }

    private func subsetSelectionPolicy(
        ids: [String],
        omitStratum: String? = nil,
        weaken: Bool = false
    ) -> AnalysisDeviceCorpusSelectionPolicy {
        let domains = domainMinimums().map {
            AnalysisDeviceCorpusDomainRequirement(
                domain: $0.domain,
                minimumSelectedFixtureCount: weaken ? 1 : $0.minimumFixtureCount,
                minimumSelectedDurationSeconds: weaken ? 100 : $0.minimumTotalDurationSeconds
            )
        }
        let stratumRequirements = strata().filter { $0.stratumID != omitStratum }.map {
            AnalysisDeviceCorpusStratumRequirement(
                stratumID: $0.stratumID,
                minimumSelectedFixtureCount: $0.minimumFixtureCount,
                minimumSelectedDurationSeconds: $0.minimumTotalDurationSeconds
            )
        }
        return .init(
            policyID: "selection-subset", authority: "HQ_LATE_INTEGRATION", approvalReference: "HQ-W26-002",
            expectedCoveragePolicyID: "coverage-v1", expectedManifestID: "golden-v1", expectedManifestSHA256: manifestSHA,
            mode: .hqApprovedExactSubset, exactSelectedFixtureIDs: ids,
            minimumSelectedFixtureCount: weaken ? 1 : 2,
            minimumSelectedTotalDurationSeconds: weaken ? 100 : 200,
            domainRequirements: domains,
            stratumRequirements: stratumRequirements
        )
    }

    private func evaluate(
        selection: AnalysisDeviceCorpusSelectionPolicy,
        performance: AnalysisDevicePerformanceAcceptanceProfile,
        workload: AnalysisDeviceWorkloadPolicy,
        manifest value: AnalysisRealAudioBenchmarkManifest? = nil,
        manifestSHA256: String? = nil
    ) -> AnalysisDeviceCorpusSelectionReport {
        AnalysisDeviceCorpusSelectionEvaluator.evaluate(
            manifest: value ?? manifest(), manifestSHA256: manifestSHA256 ?? manifestSHA,
            coveragePolicy: coveragePolicy(), selectionPolicy: selection,
            performanceProfile: performance, workloadPolicy: workload, evaluatedAt: now
        )
    }

    func testFullModeBindsEveryW22EligibleFixture() {
        let ids = ["easy-mid", "jazz-fast", "rock-slow"]
        let result = evaluate(selection: fullSelectionPolicy(), performance: performanceProfile(ids), workload: workloadPolicy(ids))
        XCTAssertEqual(result.status, .selectionReadyPendingHQ)
        XCTAssertEqual(result.selectedFixtureIDs, ids)
        XCTAssertEqual(result.selectedFixtureCount, 3)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.fixtureDiagnostics.first { $0.fixtureID == "rock-slow" }?.sourceSHA256, sourceSHA("b"))
    }

    func testExactSubsetCanDropEasyExtraOnlyWhenItStillMeetsW22Floors() {
        let ids = ["jazz-fast", "rock-slow"]
        let result = evaluate(selection: subsetSelectionPolicy(ids: ids), performance: performanceProfile(ids), workload: workloadPolicy(ids))
        XCTAssertEqual(result.status, .selectionReadyPendingHQ)
        XCTAssertTrue(result.domainDiagnostics.allSatisfy(\.satisfied))
        XCTAssertTrue(result.stratumDiagnostics.allSatisfy(\.satisfied))
    }

    func testEasySubsetFailsDerivedW22Strata() {
        let ids = ["easy-mid", "rock-slow"]
        let result = evaluate(selection: subsetSelectionPolicy(ids: ids), performance: performanceProfile(ids), workload: workloadPolicy(ids))
        XCTAssertEqual(result.status, .selectionIncomplete)
        XCTAssertTrue(result.issues.contains { $0.code == .stratumSelectionDeficit })
    }

    func testExactSubsetCannotWeakenW22GlobalOrDomainFloors() {
        let ids = ["jazz-fast", "rock-slow"]
        let result = evaluate(selection: subsetSelectionPolicy(ids: ids, weaken: true), performance: performanceProfile(ids), workload: workloadPolicy(ids))
        XCTAssertEqual(result.status, .invalidPolicy)
        XCTAssertTrue(result.issues.contains { $0.code == .invalidPolicy })
    }

    func testEveryW22StratumMustBeExplicitlyPreservedBySubsetPolicy() {
        let ids = ["jazz-fast", "rock-slow"]
        let result = evaluate(selection: subsetSelectionPolicy(ids: ids, omitStratum: "key-minor"), performance: performanceProfile(ids), workload: workloadPolicy(ids))
        XCTAssertEqual(result.status, .invalidPolicy)
        XCTAssertTrue(result.issues.contains { $0.code == .missingStratumRequirement && $0.stratumID == "key-minor" })
    }

    func testDuplicateAndUnknownSelectedFixturesFailClosed() {
        var result = evaluate(
            selection: subsetSelectionPolicy(ids: ["rock-slow", "rock-slow", "jazz-fast"]),
            performance: performanceProfile(["jazz-fast", "rock-slow"]),
            workload: workloadPolicy(["jazz-fast", "rock-slow"])
        )
        XCTAssertEqual(result.status, .invalidPolicy)
        XCTAssertTrue(result.issues.contains { $0.code == .duplicateSelectedFixture })

        let ids = ["missing", "rock-slow"]
        let missingBinding = AnalysisDeviceWorkloadSourceBinding(
            fixtureID: "missing", sourceSHA256: sourceSHA("e"), sourceDurationSeconds: 120,
            sourceSampleRate: 44_100, sourceChannelCount: 2
        )
        var workload = workloadPolicy(["rock-slow"])
        workload = .init(
            authority: "HQ_LATE_INTEGRATION", approvalReference: "HQ-W25-APPROVED",
            manifestID: "golden-v1", manifestSHA256: manifestSHA, identity: workloadIdentity,
            fixtures: ["rock-slow": workload.fixtures["rock-slow"]!, "missing": missingBinding]
        )
        result = evaluate(
            selection: subsetSelectionPolicy(ids: ids),
            performance: performanceProfile(ids), workload: workload
        )
        XCTAssertTrue(result.issues.contains { $0.code == .selectedFixtureNotEligible && $0.fixtureID == "missing" })
    }

    func testW24AndW25InventoriesMustExactlyMatchSelection() {
        let ids = ["jazz-fast", "rock-slow"]
        var result = evaluate(
            selection: subsetSelectionPolicy(ids: ids),
            performance: performanceProfile(ids + ["easy-mid"]), workload: workloadPolicy(ids)
        )
        XCTAssertTrue(result.issues.contains { $0.code == .performanceProfileBindingMismatch })

        result = evaluate(
            selection: subsetSelectionPolicy(ids: ids),
            performance: performanceProfile(ids), workload: workloadPolicy(["rock-slow"])
        )
        XCTAssertTrue(result.issues.contains { $0.code == .workloadPolicyBindingMismatch })
    }

    func testSourceSHAAndDurationStayBoundToCanonicalManifest() {
        let ids = ["jazz-fast", "rock-slow"]
        var result = evaluate(
            selection: subsetSelectionPolicy(ids: ids), performance: performanceProfile(ids),
            workload: workloadPolicy(ids, sourceOverride: ["rock-slow": sourceSHA("f")])
        )
        XCTAssertTrue(result.issues.contains { $0.code == .sourceBindingMismatch && $0.fixtureID == "rock-slow" })

        result = evaluate(
            selection: subsetSelectionPolicy(ids: ids),
            performance: performanceProfile(ids, durations: ["jazz-fast": 120, "rock-slow": 119]),
            workload: workloadPolicy(ids)
        )
        XCTAssertTrue(result.issues.contains { $0.code == .durationBindingMismatch && $0.fixtureID == "rock-slow" })
    }

    func testManifestSwapAndInsufficientW22CorpusStopPhysicalSelection() {
        let allIDs = ["easy-mid", "jazz-fast", "rock-slow"]
        var result = evaluate(
            selection: fullSelectionPolicy(), performance: performanceProfile(allIDs), workload: workloadPolicy(allIDs),
            manifestSHA256: String(repeating: "f", count: 64)
        )
        XCTAssertTrue(result.issues.contains { $0.code == .manifestBindingMismatch })

        result = evaluate(
            selection: fullSelectionPolicy(), performance: performanceProfile(["rock-slow"]), workload: workloadPolicy(["rock-slow"]),
            manifest: manifest([rockSlow])
        )
        XCTAssertEqual(result.status, .w22CorpusNotReady)
        XCTAssertTrue(result.issues.contains { $0.code == .w22CorpusNotReady })
    }

    func testFullModeRejectsRedundantSubsetFields() {
        let invalid = AnalysisDeviceCorpusSelectionPolicy(
            policyID: "ambiguous", authority: "HQ_LATE_INTEGRATION", approvalReference: "HQ",
            expectedCoveragePolicyID: "coverage-v1", expectedManifestID: "golden-v1", expectedManifestSHA256: manifestSHA,
            mode: .fullW22EligibleCorpus, exactSelectedFixtureIDs: ["rock-slow"],
            minimumSelectedFixtureCount: 1, minimumSelectedTotalDurationSeconds: 120,
            domainRequirements: [], stratumRequirements: []
        )
        let ids = ["easy-mid", "jazz-fast", "rock-slow"]
        let result = evaluate(selection: invalid, performance: performanceProfile(ids), workload: workloadPolicy(ids))
        XCTAssertEqual(result.status, .invalidPolicy)
    }

    func testInvalidSelectionStopsWorkloadAndPerformanceGate() {
        let ids = ["easy-mid", "rock-slow"]
        let result = AnalysisDeviceCorpusBoundPerformanceGate.evaluate(
            manifest: manifest(), manifestSHA256: manifestSHA, coveragePolicy: coveragePolicy(),
            selectionPolicy: subsetSelectionPolicy(ids: ids),
            batch: .init(batchID: "b1", profileID: "p1", runs: []), receipts: [],
            workloadPolicy: workloadPolicy(ids), performanceProfile: performanceProfile(ids), evaluatedAt: now
        )
        XCTAssertEqual(result.corpusSelection.status, .selectionIncomplete)
        XCTAssertNil(result.workloadAndPerformance)
    }

    func testSelectionCodecIsDeterministic() throws {
        let value = subsetSelectionPolicy(ids: ["jazz-fast", "rock-slow"])
        let a = try AnalysisDeviceCorpusSelectionCodec.encodePolicy(value)
        let b = try AnalysisDeviceCorpusSelectionCodec.encodePolicy(value)
        XCTAssertEqual(a, b)
        XCTAssertEqual(try AnalysisDeviceCorpusSelectionCodec.decodePolicy(a), value)
    }
}
