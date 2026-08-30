import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalEvidenceArchiveChainV2StrictTests: XCTestCase {
    private let manifestSHA = String(repeating: "a", count: 64)
    private let sourceSHA = String(repeating: "b", count: 64)

    private var source: AnalysisDeviceWorkloadSourceBinding {
        .init(fixtureID: "fixture-a", sourceSHA256: sourceSHA, sourceDurationSeconds: 60, sourceSampleRate: 44_100, sourceChannelCount: 2)
    }

    private var identity: AnalysisDeviceWorkloadIdentity {
        .init(analyzerID: "ProjectOwnedMusicAnalyzer", analyzerVersion: "w38", analysisConfigurationID: "product-baseline-v1", buildIdentity: "w38-build")
    }

    private var binding: AnalysisPhysicalEvidenceArchiveBinding {
        .init(
            manifestID: "golden-v1", manifestSHA256: manifestSHA,
            coveragePolicyID: "coverage-v1", selectionPolicyID: "selection-v1",
            performanceProfileID: "performance-v1", batchID: "batch-v1",
            workloadApprovalReference: "HQ-W25", buildIdentity: identity.buildIdentity,
            deviceModel: "iPhone17,3", osVersion: "20.0"
        )
    }

    private var workloadPolicy: AnalysisDeviceWorkloadPolicy {
        .init(
            authority: "HQ_LATE_INTEGRATION", approvalReference: binding.workloadApprovalReference,
            manifestID: binding.manifestID, manifestSHA256: binding.manifestSHA256,
            identity: identity, fixtures: [source.fixtureID: source]
        )
    }

    private func profile(_ plannedRuns: [AnalysisDevicePerformancePlannedRun]) -> AnalysisDevicePerformanceAcceptanceProfile {
        .init(
            profileID: binding.performanceProfileID, authority: "HQ_LATE_INTEGRATION", approvalReference: "HQ-W24",
            expectedBatchID: binding.batchID, expectedDeviceModel: binding.deviceModel, expectedOSVersion: binding.osVersion,
            expectedAppBundleIdentifier: "com.example.moises", expectedAppVersion: "1", expectedBuildVersion: "1",
            expectedManifestID: binding.manifestID, expectedManifestSHA256: binding.manifestSHA256,
            requiredFixtureIDs: [source.fixtureID], expectedFixtureDurationsSeconds: [source.fixtureID: 60],
            minimumCompleteRunsPerFixture: 0, minimumCancellationRunsPerFixture: 1, plannedRuns: plannedRuns,
            maximumCompleteWallSeconds: 60, maximumPeakResidentBytes: 1_000_000_000,
            maximumPeakPhysicalFootprintBytes: 1_000_000_000, maximumStartingThermalState: .fair,
            maximumWorstThermalState: .serious, maximumBatteryDrainFraction: 0.10,
            maximumMemoryPressureEventCount: 0, maximumCancellationLatencySeconds: 1,
            requireUnpluggedBatteryForCompleteRuns: false
        )
    }

    private func legacy(runIDs: [String]) throws -> (AnalysisPhysicalEvidenceArchivePolicy, AnalysisPhysicalEvidenceArchiveManifest) {
        let policy = AnalysisPhysicalEvidenceArchivePolicy(
            policyID: "w27-policy", authority: "HQ_LATE_INTEGRATION", approvalReference: "HQ-W27",
            expectedArchiveID: "w27-archive", binding: binding, requiredRunIDs: runIDs
        )
        let manifest = try AnalysisPhysicalEvidenceArchiveBuilder.manifest(
            archiveID: policy.expectedArchiveID, policyID: policy.policyID, binding: binding, entries: []
        )
        return (policy, manifest)
    }

    private func chainPolicy(runIDs: [String], legacyPolicy: AnalysisPhysicalEvidenceArchivePolicy, legacyManifest: AnalysisPhysicalEvidenceArchiveManifest) -> AnalysisPhysicalEvidenceArchiveChainPolicy {
        .init(
            policyID: "w38-policy", authority: "HQ_LATE_INTEGRATION", approvalReference: "HQ-W38",
            expectedArchiveID: "w38-archive", legacyW27PolicyID: legacyPolicy.policyID,
            legacyW27ArchiveID: legacyManifest.archiveID, legacyW27RootSHA256: legacyManifest.declaredRootSHA256,
            binding: binding, requiredRunIDs: runIDs
        )
    }

    private func chainManifest(policy: AnalysisPhysicalEvidenceArchiveChainPolicy) throws -> AnalysisPhysicalEvidenceArchiveChainManifest {
        try AnalysisPhysicalEvidenceArchiveChainBuilder.manifest(
            archiveID: policy.expectedArchiveID, policyID: policy.policyID,
            legacyW27ArchiveID: policy.legacyW27ArchiveID, legacyW27RootSHA256: policy.legacyW27RootSHA256,
            binding: policy.binding, entries: []
        )
    }

    func testDuplicateW24PlannedRunIDsFailBeforeDictionaryConstruction() throws {
        let runID = "run-a"
        let (legacyPolicy, legacyManifest) = try legacy(runIDs: [runID])
        let policy = chainPolicy(runIDs: [runID], legacyPolicy: legacyPolicy, legacyManifest: legacyManifest)
        let manifest = try chainManifest(policy: policy)
        let duplicateProfile = profile([
            .init(runID: runID, fixtureID: source.fixtureID, runKind: .cancellationProbe),
            .init(runID: runID, fixtureID: source.fixtureID, runKind: .cancellationProbe)
        ])
        let legacyReport = AnalysisPhysicalEvidenceArchiveReport(
            archiveID: legacyManifest.archiveID, status: .rootConsistentPendingHQ,
            computedRootSHA256: legacyManifest.declaredRootSHA256, entryCount: 0, runCount: 1,
            issues: [], limitations: []
        )

        let report = AnalysisPhysicalEvidenceArchiveChainValidator.validateStrict(
            manifest: manifest, policy: policy, legacyManifest: legacyManifest, legacyPolicy: legacyPolicy,
            legacyReport: legacyReport, artifactBytesByPath: [:], performanceProfile: duplicateProfile,
            workloadPolicy: workloadPolicy
        )
        XCTAssertEqual(report.status, .invalidPolicy)
        XCTAssertEqual(report.issues.first?.code, .invalidRunInventory)
    }

    func testForgedLegacyReportRootCannotBypassLocalW27RootRecomputation() throws {
        let runID = "run-a"
        let (legacyPolicy, legacyManifest) = try legacy(runIDs: [runID])
        let policy = chainPolicy(runIDs: [runID], legacyPolicy: legacyPolicy, legacyManifest: legacyManifest)
        let manifest = try chainManifest(policy: policy)
        let validProfile = profile([.init(runID: runID, fixtureID: source.fixtureID, runKind: .cancellationProbe)])
        let forgedReport = AnalysisPhysicalEvidenceArchiveReport(
            archiveID: legacyManifest.archiveID, status: .rootConsistentPendingHQ,
            computedRootSHA256: String(repeating: "c", count: 64), entryCount: 0, runCount: 1,
            issues: [], limitations: []
        )

        let report = AnalysisPhysicalEvidenceArchiveChainValidator.validateStrict(
            manifest: manifest, policy: policy, legacyManifest: legacyManifest, legacyPolicy: legacyPolicy,
            legacyReport: forgedReport, artifactBytesByPath: [:], performanceProfile: validProfile,
            workloadPolicy: workloadPolicy
        )
        XCTAssertEqual(report.status, .legacyArchiveNotReady)
        XCTAssertEqual(report.issues.first?.code, .legacyArchiveNotReady)
    }
}
