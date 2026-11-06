import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisDeviceAlgorithmExecutionEvidenceTests: XCTestCase {
    private let sha = String(repeating: "1", count: 64)
    private let snapshotSHA = String(repeating: "2", count: 64)

    func testExactCompleteAndCancellationInventoryBinds() throws {
        let fixture = makeFixture()
        let algorithm = try makeAlgorithmBatch(fixture: fixture)
        let report = AnalysisDeviceAlgorithmEvidenceValidator.validateBatch(
            algorithmBatch: algorithm,
            performanceBatch: fixture.performanceBatch,
            receipts: fixture.receipts,
            workloadPolicy: fixture.workloadPolicy,
            performanceProfile: fixture.profile
        )
        XCTAssertTrue(report.valid)
        XCTAssertTrue(report.exactRunInventory)
        XCTAssertEqual(report.runReports.filter { $0.status == .completeRuntimeBoundPendingHQ }.count, 2)
        XCTAssertEqual(report.runReports.filter { $0.status == .cancellationBoundPendingHQ }.count, 2)
        XCTAssertTrue(report.issues.isEmpty)
    }

    func testMissingAlgorithmRunSuppressesW24() throws {
        let fixture = makeFixture()
        let full = try makeAlgorithmBatch(fixture: fixture)
        let missing = AnalysisDeviceAlgorithmEvidenceBatch(
            batchID: full.batchID,
            performanceProfileID: full.performanceProfileID,
            runs: Array(full.runs.dropLast())
        )
        let gate = AnalysisDevicePerformanceAcceptanceWithAlgorithmEvaluator.evaluate(
            batch: fixture.performanceBatch,
            receipts: fixture.receipts,
            workloadPolicy: fixture.workloadPolicy,
            algorithmBatch: missing,
            performanceProfile: fixture.profile,
            evaluatedAt: Date(timeIntervalSince1970: 100)
        )
        XCTAssertFalse(gate.algorithmEvidenceValid)
        XCTAssertNil(gate.workloadAndPerformance)
        XCTAssertTrue(gate.algorithmEvidence.issues.contains { $0.code == .missingRun })
    }

    func testMixedCompleteRuntimeIdentityWithinFixtureIsRejected() throws {
        let fixture = makeFixture()
        var runs = try makeAlgorithmBatch(fixture: fixture).runs
        let receipt = fixture.receipts.first { $0.runID == "complete-2" }!
        let performance = fixture.performanceBatch.runs.first { $0.provenance.runID == "complete-2" }!
        runs[runs.firstIndex { $0.runID == "complete-2" }!] = try AnalysisDeviceAlgorithmExecutionEvidenceBuilder.finalized(
            receipt: receipt,
            performanceRun: performance,
            diagnostics: makeDiagnostics(state: .scalarFallback)
        )
        let report = AnalysisDeviceAlgorithmEvidenceValidator.validateBatch(
            algorithmBatch: .init(batchID: "batch", performanceProfileID: "profile", runs: runs),
            performanceBatch: fixture.performanceBatch,
            receipts: fixture.receipts,
            workloadPolicy: fixture.workloadPolicy,
            performanceProfile: fixture.profile
        )
        XCTAssertFalse(report.valid)
        XCTAssertTrue(report.issues.contains { $0.code == .mixedCompleteRuntimeIdentity })
    }

    func testLegacyMaterializedRuntimeCannotMasqueradeAsCurrent() throws {
        let fixture = makeFixture()
        var runs = try makeAlgorithmBatch(fixture: fixture).runs
        let receipt = fixture.receipts.first { $0.runID == "complete-1" }!
        let performance = fixture.performanceBatch.runs.first { $0.provenance.runID == "complete-1" }!
        runs[runs.firstIndex { $0.runID == "complete-1" }!] = try AnalysisDeviceAlgorithmExecutionEvidenceBuilder.finalized(
            receipt: receipt,
            performanceRun: performance,
            diagnostics: makeDiagnostics(state: .vectorizedVerified, exactSinglePass: false)
        )
        let report = AnalysisDeviceAlgorithmEvidenceValidator.validateBatch(
            algorithmBatch: .init(batchID: "batch", performanceProfileID: "profile", runs: runs),
            performanceBatch: fixture.performanceBatch,
            receipts: fixture.receipts,
            workloadPolicy: fixture.workloadPolicy,
            performanceProfile: fixture.profile
        )
        XCTAssertFalse(report.valid)
        XCTAssertTrue(report.issues.contains { $0.code == .nonCurrentRuntimePath })
    }

    func testExecutionIDSubstitutionIsRejected() throws {
        let fixture = makeFixture()
        var runs = try makeAlgorithmBatch(fixture: fixture).runs
        let index = runs.firstIndex { $0.runID == "complete-1" }!
        let original = runs[index]
        runs[index] = .init(
            runID: original.runID,
            performanceEvidenceRunID: original.performanceEvidenceRunID,
            runKind: original.runKind,
            workloadExecutionID: "substituted-execution",
            manifestID: original.manifestID,
            manifestSHA256: original.manifestSHA256,
            source: original.source,
            identity: original.identity,
            snapshotSHA256: original.snapshotSHA256,
            captureState: original.captureState,
            runtimeIdentity: original.runtimeIdentity,
            runtimeIdentitySHA256: original.runtimeIdentitySHA256
        )
        let report = AnalysisDeviceAlgorithmEvidenceValidator.validateBatch(
            algorithmBatch: .init(batchID: "batch", performanceProfileID: "profile", runs: runs),
            performanceBatch: fixture.performanceBatch,
            receipts: fixture.receipts,
            workloadPolicy: fixture.workloadPolicy,
            performanceProfile: fixture.profile
        )
        XCTAssertFalse(report.valid)
        XCTAssertTrue(report.issues.contains { $0.code == .bindingMismatch })
    }

    private struct Fixture {
        let source: AnalysisDeviceWorkloadSourceBinding
        let identity: AnalysisDeviceWorkloadIdentity
        let profile: AnalysisDevicePerformanceAcceptanceProfile
        let workloadPolicy: AnalysisDeviceWorkloadPolicy
        let performanceBatch: AnalysisDevicePerformanceEvidenceBatch
        let receipts: [AnalysisDeviceWorkloadReceipt]
    }

    private func makeFixture() -> Fixture {
        let source = AnalysisDeviceWorkloadSourceBinding(
            fixtureID: "fixture-1",
            sourceSHA256: sha,
            sourceDurationSeconds: 120,
            sourceSampleRate: 44_100,
            sourceChannelCount: 1
        )
        let identity = AnalysisDeviceWorkloadIdentity(
            analyzerID: "ProjectOwnedMusicAnalyzer",
            analyzerVersion: "w35",
            analysisConfigurationID: "product-baseline",
            buildIdentity: "build-1"
        )
        let planned = [
            AnalysisDevicePerformancePlannedRun(runID: "complete-1", fixtureID: "fixture-1", runKind: .completeAnalysis),
            AnalysisDevicePerformancePlannedRun(runID: "complete-2", fixtureID: "fixture-1", runKind: .completeAnalysis),
            AnalysisDevicePerformancePlannedRun(runID: "cancel-1", fixtureID: "fixture-1", runKind: .cancellationProbe),
            AnalysisDevicePerformancePlannedRun(runID: "cancel-2", fixtureID: "fixture-1", runKind: .cancellationProbe)
        ]
        let profile = AnalysisDevicePerformanceAcceptanceProfile(
            profileID: "profile",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "approval",
            expectedBatchID: "batch",
            expectedDeviceModel: "iPhone17,1",
            expectedOSVersion: "20.0",
            expectedAppBundleIdentifier: "example.moises",
            expectedAppVersion: "1.0",
            expectedBuildVersion: "1",
            expectedManifestID: "manifest",
            expectedManifestSHA256: sha,
            requiredFixtureIDs: ["fixture-1"],
            expectedFixtureDurationsSeconds: ["fixture-1": 120],
            minimumCompleteRunsPerFixture: 2,
            minimumCancellationRunsPerFixture: 2,
            plannedRuns: planned,
            maximumCompleteWallSeconds: 600,
            maximumPeakResidentBytes: 1_000_000_000,
            maximumPeakPhysicalFootprintBytes: 1_000_000_000,
            maximumStartingThermalState: .fair,
            maximumWorstThermalState: .serious,
            maximumBatteryDrainFraction: 0.5,
            maximumMemoryPressureEventCount: 10,
            maximumCancellationLatencySeconds: 2,
            requireUnpluggedBatteryForCompleteRuns: false
        )
        let policy = AnalysisDeviceWorkloadPolicy(
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "approval",
            manifestID: "manifest",
            manifestSHA256: sha,
            identity: identity,
            fixtures: ["fixture-1": source]
        )
        let performance = planned.map { makePerformance(runID: $0.runID, kind: $0.runKind) }
        let receipts = planned.map { makeReceipt(runID: $0.runID, kind: $0.runKind, source: source, identity: identity) }
        return .init(
            source: source,
            identity: identity,
            profile: profile,
            workloadPolicy: policy,
            performanceBatch: .init(batchID: "batch", profileID: "profile", runs: performance),
            receipts: receipts
        )
    }

    private func makePerformance(runID: String, kind: AnalysisDevicePerformanceRunKind) -> AnalysisDevicePerformanceEvidence {
        let provenance = AnalysisDevicePerformanceProvenance(
            runID: runID,
            runKind: kind,
            startedAt: Date(timeIntervalSince1970: 1),
            runtimeClass: .physicalIOSDevice,
            deviceModel: "iPhone17,1",
            osVersion: "20.0",
            appBundleIdentifier: "example.moises",
            appVersion: "1.0",
            buildVersion: "1",
            manifestID: "manifest",
            manifestSHA256: sha,
            fixtureID: "fixture-1",
            fixtureDurationSeconds: 120
        )
        return AnalysisDevicePerformanceEvidence(
            provenance: provenance,
            finishedAt: Date(timeIntervalSince1970: 2),
            wallSeconds: 1,
            requestedSampleIntervalSeconds: 1,
            maximumSampleCount: 16,
            memoryTelemetry: .availableChannel,
            thermalTelemetry: .availableChannel,
            batteryTelemetry: .availableChannel,
            memoryPressureObservation: .availableChannel,
            memorySamples: [], thermalSamples: [], batterySamples: [], memoryPressureEvents: [],
            cancellation: .init(requestedOffsetSeconds: nil, observedTerminationOffsetSeconds: nil),
            completedNormally: kind == .completeAnalysis
        )
    }

    private func makeReceipt(
        runID: String,
        kind: AnalysisDevicePerformanceRunKind,
        source: AnalysisDeviceWorkloadSourceBinding,
        identity: AnalysisDeviceWorkloadIdentity
    ) -> AnalysisDeviceWorkloadReceipt {
        AnalysisDeviceWorkloadReceipt(
            runID: runID,
            performanceEvidenceRunID: runID,
            runKind: kind,
            manifestID: "manifest",
            manifestSHA256: sha,
            source: source,
            identity: identity,
            executionID: "exec-\(runID)",
            workloadStartedAt: Date(timeIntervalSince1970: 1),
            stages: [],
            snapshotCanonicalJSON: nil,
            snapshotSHA256: kind == .completeAnalysis ? snapshotSHA : nil,
            outputSummary: nil,
            executionBindingSHA256: sha
        )
    }

    private func makeAlgorithmBatch(fixture: Fixture) throws -> AnalysisDeviceAlgorithmEvidenceBatch {
        let runs = try fixture.receipts.map { receipt -> AnalysisDeviceAlgorithmExecutionEvidence in
            let performance = fixture.performanceBatch.runs.first { $0.provenance.runID == receipt.runID }!
            if receipt.runKind == .completeAnalysis {
                return try AnalysisDeviceAlgorithmExecutionEvidenceBuilder.finalized(
                    receipt: receipt,
                    performanceRun: performance,
                    diagnostics: makeDiagnostics(state: .vectorizedVerified)
                )
            }
            return AnalysisDeviceAlgorithmExecutionEvidenceBuilder.cancelledBeforeFinalization(
                receipt: receipt,
                performanceRun: performance
            )
        }
        return .init(batchID: "batch", performanceProfileID: "profile", runs: runs)
    }

    private func makeDiagnostics(
        state: AnalysisChordBackendGuardState,
        exactSinglePass: Bool = true
    ) -> AnalysisSinglePassPreparedFeatureDiagnostics {
        switch state {
        case .vectorizedVerified:
            return .init(
                preparedSampleCount: 960_000, preparedSampleRequests: 960_000,
                preparedSampleComputations: 960_000, preparedBlockLoads: 1,
                tempoOnsetCount: 11_996, keyWindowCount: 24, keyWindowSampleCount: 49_152,
                chordFrameDecisionCount: 480, sectionEnergyFrameCount: 12_000,
                maximumTempoRingSamples: 368, maximumChordRingSamples: 5_600,
                estimatedRetainedFeatureBytes: 1_000_000,
                exactSinglePreparedTraversal: exactSinglePass,
                chordBackendGuardState: state.rawValue,
                chordBackendVerificationFrameLimit: 8,
                chordBackendVerificationComparisons: 8,
                chordBackendVerificationMatches: 8,
                chordBackendFallbackTriggered: false,
                chordBackendReferencePublicationCount: 8,
                chordBackendVectorizedPublicationCount: 100
            )
        case .scalarFallback:
            return .init(
                preparedSampleCount: 960_000, preparedSampleRequests: 960_000,
                preparedSampleComputations: 960_000, preparedBlockLoads: 1,
                tempoOnsetCount: 11_996, keyWindowCount: 24, keyWindowSampleCount: 49_152,
                chordFrameDecisionCount: 480, sectionEnergyFrameCount: 12_000,
                maximumTempoRingSamples: 368, maximumChordRingSamples: 5_600,
                estimatedRetainedFeatureBytes: 1_000_000,
                exactSinglePreparedTraversal: exactSinglePass,
                chordBackendGuardState: state.rawValue,
                chordBackendVerificationFrameLimit: 8,
                chordBackendVerificationComparisons: 2,
                chordBackendVerificationMatches: 1,
                chordBackendFallbackTriggered: true,
                chordBackendFallbackComparisonIndex: 2,
                chordBackendReferencePublicationCount: 100,
                chordBackendVectorizedPublicationCount: 0
            )
        case .verifying:
            return .init(
                preparedSampleCount: 960_000, preparedSampleRequests: 960_000,
                preparedSampleComputations: 960_000, preparedBlockLoads: 1,
                tempoOnsetCount: 11_996, keyWindowCount: 24, keyWindowSampleCount: 49_152,
                chordFrameDecisionCount: 4, sectionEnergyFrameCount: 12_000,
                maximumTempoRingSamples: 368, maximumChordRingSamples: 5_600,
                estimatedRetainedFeatureBytes: 1_000_000,
                exactSinglePreparedTraversal: exactSinglePass,
                chordBackendGuardState: state.rawValue,
                chordBackendVerificationFrameLimit: 8,
                chordBackendVerificationComparisons: 4,
                chordBackendVerificationMatches: 4,
                chordBackendFallbackTriggered: false,
                chordBackendReferencePublicationCount: 4,
                chordBackendVectorizedPublicationCount: 0
            )
        }
    }
}
