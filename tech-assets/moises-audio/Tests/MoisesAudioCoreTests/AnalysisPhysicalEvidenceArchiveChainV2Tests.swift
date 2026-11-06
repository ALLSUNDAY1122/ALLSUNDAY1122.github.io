import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalEvidenceArchiveChainV2Tests: XCTestCase {
    private let manifestSHA = String(repeating: "a", count: 64)
    private let sourceSHA = String(repeating: "b", count: 64)

    private var source: AnalysisDeviceWorkloadSourceBinding {
        .init(
            fixtureID: "fixture-a",
            sourceSHA256: sourceSHA,
            sourceDurationSeconds: 3600,
            sourceSampleRate: 44_100,
            sourceChannelCount: 2
        )
    }

    private var identity: AnalysisDeviceWorkloadIdentity {
        .init(
            analyzerID: "ProjectOwnedMusicAnalyzer",
            analyzerVersion: "lane4-w38",
            analysisConfigurationID: "product-baseline-v1",
            buildIdentity: "commit-w38:200"
        )
    }

    private var binding: AnalysisPhysicalEvidenceArchiveBinding {
        .init(
            manifestID: "golden-v1",
            manifestSHA256: manifestSHA,
            coveragePolicyID: "coverage-v1",
            selectionPolicyID: "selection-v1",
            performanceProfileID: "performance-v1",
            batchID: "batch-v1",
            workloadApprovalReference: "HQ-W25-001",
            buildIdentity: identity.buildIdentity,
            deviceModel: "iPhone17,3",
            osVersion: "20.0"
        )
    }

    private var workloadPolicy: AnalysisDeviceWorkloadPolicy {
        .init(
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: binding.workloadApprovalReference,
            manifestID: binding.manifestID,
            manifestSHA256: binding.manifestSHA256,
            identity: identity,
            fixtures: [source.fixtureID: source]
        )
    }

    private func profile(runIDs: [String]) -> AnalysisDevicePerformanceAcceptanceProfile {
        .init(
            profileID: binding.performanceProfileID,
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-P021-W38",
            expectedBatchID: binding.batchID,
            expectedDeviceModel: binding.deviceModel,
            expectedOSVersion: binding.osVersion,
            expectedAppBundleIdentifier: "com.example.moises",
            expectedAppVersion: "1.0",
            expectedBuildVersion: "200",
            expectedManifestID: binding.manifestID,
            expectedManifestSHA256: binding.manifestSHA256,
            requiredFixtureIDs: [source.fixtureID],
            expectedFixtureDurationsSeconds: [source.fixtureID: source.sourceDurationSeconds],
            minimumCompleteRunsPerFixture: 0,
            minimumCancellationRunsPerFixture: runIDs.count,
            plannedRuns: runIDs.map { .init(runID: $0, fixtureID: source.fixtureID, runKind: .cancellationProbe) },
            maximumCompleteWallSeconds: 60,
            maximumPeakResidentBytes: 500_000_000,
            maximumPeakPhysicalFootprintBytes: 600_000_000,
            maximumStartingThermalState: .fair,
            maximumWorstThermalState: .serious,
            maximumBatteryDrainFraction: 0.10,
            maximumMemoryPressureEventCount: 0,
            maximumCancellationLatencySeconds: 0.50,
            requireUnpluggedBatteryForCompleteRuns: false
        )
    }

    private func capturePlan(runID: String, authority: String = "HQ_LATE_INTEGRATION") -> AnalysisDeviceCapturePlan {
        .init(
            authority: authority,
            approvalReference: "HQ-W37-\(runID)",
            runID: runID,
            runKind: .cancellationProbe,
            manifestID: binding.manifestID,
            manifestSHA256: binding.manifestSHA256,
            source: source,
            identity: identity,
            telemetrySampleIntervalSeconds: 1,
            maximumTelemetrySampleCount: 100,
            cancellation: .init(
                delayAfterObservedSourceWorkSeconds: 0.10,
                sourceWorkPollIntervalSeconds: 0.01,
                maximumWaitForObservedSourceWorkSeconds: 5
            )
        )
    }

    private func algorithm(runID: String, executionID: String) -> AnalysisDeviceAlgorithmExecutionEvidence {
        .init(
            runID: runID,
            performanceEvidenceRunID: runID,
            runKind: .cancellationProbe,
            workloadExecutionID: executionID,
            manifestID: binding.manifestID,
            manifestSHA256: binding.manifestSHA256,
            source: source,
            identity: identity,
            sourceInputContract: .boundedPull,
            snapshotSHA256: nil,
            captureState: .cancelledBeforeFinalization,
            runtimeIdentity: nil,
            runtimeIdentitySHA256: nil
        )
    }

    private func runtime(runID: String, executionID: String) -> AnalysisCurrentDeviceWorkloadArchiveEvidence {
        .init(
            runID: runID,
            performanceEvidenceRunID: runID,
            runKind: .cancellationProbe,
            workloadExecutionID: executionID,
            sourceMemoryContract: .boundedPull,
            boundedSourceContractAccepted: true,
            observedSourceChunkCount: 2,
            observedSourceSampleCount: 4096,
            outcome: .cancelled,
            snapshotSHA256: nil,
            algorithmRunID: runID,
            algorithmWorkloadExecutionID: executionID
        )
    }

    private func integrity(runID: String, executionID: String) -> AnalysisDeviceCaptureExecutionIntegrityEvidence {
        .init(
            runID: runID,
            runKind: .cancellationProbe,
            performanceRunID: runID,
            workloadRunID: runID,
            workloadExecutionID: executionID,
            algorithmRunID: runID,
            algorithmWorkloadExecutionID: executionID,
            sourceMemoryContract: .boundedPull,
            workloadOutcome: .cancelled,
            observedSourceSampleCount: 4096,
            cancellationCoordination: .requestedAfterObservedSourceWork,
            cancellationRequestedOffsetSeconds: 0.20,
            cancellationObservedOffsetSeconds: 0.30,
            requestedSampleIntervalSeconds: 1,
            captureWallSeconds: 2,
            telemetrySampling: .init(
                samplingAttempts: 1,
                periodicSamplesCaptured: 1,
                sampleCapReached: false,
                samplerTerminated: true
            ),
            cancellationTaskTerminated: true,
            performanceLimitations: []
        )
    }

    private func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }

    private struct ChainArtifacts {
        let entries: [AnalysisPhysicalEvidenceChainEntry]
        let bytes: [String: Data]
    }

    private func artifacts(runID: String, executionID: String, planAuthority: String = "HQ_LATE_INTEGRATION") throws -> ChainArtifacts {
        let algorithmValue = algorithm(runID: runID, executionID: executionID)
        let runtimeValue = runtime(runID: runID, executionID: executionID)
        let planValue = capturePlan(runID: runID, authority: planAuthority)
        let integrityValue = integrity(runID: runID, executionID: executionID)
        let reportValue = AnalysisDeviceCaptureExecutionIntegrityValidator.validate(integrityValue)

        let values: [(AnalysisPhysicalEvidenceChainArtifactRole, String, Data)] = [
            (.w35RuntimeAlgorithmEvidence, "runs/\(runID)/w35-algorithm.json", try encoded(algorithmValue)),
            (.w36CurrentRuntimeEvidence, "runs/\(runID)/w36-current-runtime.json", try AnalysisPhysicalEvidenceArchiveChainCodec.encodeCurrentRuntimeEvidence(runtimeValue)),
            (.w37CapturePlan, "runs/\(runID)/w37-plan.json", try encoded(planValue)),
            (.w37ExecutionIntegrityEvidence, "runs/\(runID)/w37-integrity.json", try AnalysisDeviceCaptureExecutionIntegrityCodec.encodeEvidence(integrityValue)),
            (.w37ExecutionIntegrityReport, "runs/\(runID)/w37-integrity-report.json", try AnalysisDeviceCaptureExecutionIntegrityCodec.encodeReport(reportValue))
        ]
        let entries = values.map {
            AnalysisPhysicalEvidenceArchiveChainBuilder.entry(role: $0.0, relativePath: $0.1, runID: runID, bytes: $0.2)
        }
        return .init(entries: entries, bytes: Dictionary(uniqueKeysWithValues: values.map { ($0.1, $0.2) }))
    }

    private struct LegacyAnchor {
        let policy: AnalysisPhysicalEvidenceArchivePolicy
        let manifest: AnalysisPhysicalEvidenceArchiveManifest
        let report: AnalysisPhysicalEvidenceArchiveReport
    }

    private func legacyAnchor(runIDs: [String]) throws -> LegacyAnchor {
        let legacyPolicy = AnalysisPhysicalEvidenceArchivePolicy(
            policyID: "w27-policy",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W27",
            expectedArchiveID: "w27-archive",
            binding: binding,
            requiredRunIDs: runIDs
        )
        let legacyManifest = try AnalysisPhysicalEvidenceArchiveBuilder.manifest(
            archiveID: legacyPolicy.expectedArchiveID,
            policyID: legacyPolicy.policyID,
            binding: binding,
            entries: []
        )
        let legacyReport = AnalysisPhysicalEvidenceArchiveReport(
            archiveID: legacyManifest.archiveID,
            status: .rootConsistentPendingHQ,
            computedRootSHA256: legacyManifest.declaredRootSHA256,
            entryCount: legacyManifest.entries.count,
            runCount: runIDs.count,
            issues: [],
            limitations: []
        )
        return .init(policy: legacyPolicy, manifest: legacyManifest, report: legacyReport)
    }

    private func chainPolicy(runIDs: [String], legacy: LegacyAnchor) -> AnalysisPhysicalEvidenceArchiveChainPolicy {
        .init(
            policyID: "w38-policy",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W38",
            expectedArchiveID: "w38-archive",
            legacyW27PolicyID: legacy.policy.policyID,
            legacyW27ArchiveID: legacy.manifest.archiveID,
            legacyW27RootSHA256: legacy.manifest.declaredRootSHA256,
            binding: binding,
            requiredRunIDs: runIDs
        )
    }

    private func validate(
        runIDs: [String],
        artifacts: ChainArtifacts,
        legacy: LegacyAnchor,
        policy: AnalysisPhysicalEvidenceArchiveChainPolicy? = nil
    ) throws -> AnalysisPhysicalEvidenceArchiveChainReport {
        let selectedPolicy = policy ?? chainPolicy(runIDs: runIDs, legacy: legacy)
        let manifest = try AnalysisPhysicalEvidenceArchiveChainBuilder.manifest(
            archiveID: selectedPolicy.expectedArchiveID,
            policyID: selectedPolicy.policyID,
            legacyW27ArchiveID: selectedPolicy.legacyW27ArchiveID,
            legacyW27RootSHA256: selectedPolicy.legacyW27RootSHA256,
            binding: selectedPolicy.binding,
            entries: artifacts.entries
        )
        return AnalysisPhysicalEvidenceArchiveChainValidator.validate(
            manifest: manifest,
            policy: selectedPolicy,
            legacyManifest: legacy.manifest,
            legacyPolicy: legacy.policy,
            legacyReport: legacy.report,
            artifactBytesByPath: artifacts.bytes,
            performanceProfile: profile(runIDs: runIDs),
            workloadPolicy: workloadPolicy
        )
    }

    func testRequiredRolesExplicitlyCoverW35W36AndW37() {
        XCTAssertEqual(AnalysisPhysicalEvidenceChainArtifactRole.requiredPerRunRoles.count, 5)
        XCTAssertTrue(AnalysisPhysicalEvidenceChainArtifactRole.requiredPerRunRoles.contains(.w35RuntimeAlgorithmEvidence))
        XCTAssertTrue(AnalysisPhysicalEvidenceChainArtifactRole.requiredPerRunRoles.contains(.w36CurrentRuntimeEvidence))
        XCTAssertTrue(AnalysisPhysicalEvidenceChainArtifactRole.requiredPerRunRoles.contains(.w37CapturePlan))
        XCTAssertTrue(AnalysisPhysicalEvidenceChainArtifactRole.requiredPerRunRoles.contains(.w37ExecutionIntegrityEvidence))
        XCTAssertTrue(AnalysisPhysicalEvidenceChainArtifactRole.requiredPerRunRoles.contains(.w37ExecutionIntegrityReport))
    }

    func testValidTwoRunChainAnchorsLegacyRootAndExactExecutions() throws {
        let runIDs = ["run-a", "run-b"]
        let legacy = try legacyAnchor(runIDs: runIDs)
        let a = try artifacts(runID: "run-a", executionID: "exec-a")
        let b = try artifacts(runID: "run-b", executionID: "exec-b")
        let combined = ChainArtifacts(entries: a.entries + b.entries, bytes: a.bytes.merging(b.bytes) { $1 })
        let report = try validate(runIDs: runIDs, artifacts: combined, legacy: legacy)
        XCTAssertEqual(report.status, .rootConsistentPendingHQ)
        XCTAssertTrue(report.issues.isEmpty)
        XCTAssertEqual(report.entryCount, 10)
        XCTAssertEqual(report.runCount, 2)
    }

    func testMissingRoleFailsClosed() throws {
        let runIDs = ["run-a"]
        let legacy = try legacyAnchor(runIDs: runIDs)
        let all = try artifacts(runID: "run-a", executionID: "exec-a")
        let removed = all.entries.first { $0.role == .w37ExecutionIntegrityReport }!
        var bytes = all.bytes
        bytes.removeValue(forKey: removed.relativePath)
        let reduced = ChainArtifacts(entries: all.entries.filter { $0.relativePath != removed.relativePath }, bytes: bytes)
        let report = try validate(runIDs: runIDs, artifacts: reduced, legacy: legacy)
        XCTAssertEqual(report.status, .incompleteOrTampered)
        XCTAssertTrue(report.issues.contains { $0.code == .missingRunArtifact && $0.role == .w37ExecutionIntegrityReport })
    }

    func testMalformedCapturePlanFailsCaptureChain() throws {
        let runIDs = ["run-a"]
        let legacy = try legacyAnchor(runIDs: runIDs)
        let broken = try artifacts(runID: "run-a", executionID: "exec-a", planAuthority: "WORKER_DEFINED")
        let report = try validate(runIDs: runIDs, artifacts: broken, legacy: legacy)
        XCTAssertEqual(report.status, .incompleteOrTampered)
        XCTAssertTrue(report.issues.contains { $0.code == .captureChainMismatch })
    }

    func testArtifactByteTamperingFailsHashAndLengthContract() throws {
        let runIDs = ["run-a"]
        let legacy = try legacyAnchor(runIDs: runIDs)
        let original = try artifacts(runID: "run-a", executionID: "exec-a")
        let target = original.entries.first { $0.role == .w36CurrentRuntimeEvidence }!
        var bytes = original.bytes
        bytes[target.relativePath] = Data("tampered".utf8)
        let tampered = ChainArtifacts(entries: original.entries, bytes: bytes)
        let report = try validate(runIDs: runIDs, artifacts: tampered, legacy: legacy)
        XCTAssertTrue(report.issues.contains { $0.code == .artifactHashMismatch })
        XCTAssertTrue(report.issues.contains { $0.code == .artifactLengthMismatch })
    }

    func testReusedW36ExecutionAcrossRunsFailsClosed() throws {
        let runIDs = ["run-a", "run-b"]
        let legacy = try legacyAnchor(runIDs: runIDs)
        let a = try artifacts(runID: "run-a", executionID: "same-exec")
        let b = try artifacts(runID: "run-b", executionID: "same-exec")
        let combined = ChainArtifacts(entries: a.entries + b.entries, bytes: a.bytes.merging(b.bytes) { $1 })
        let report = try validate(runIDs: runIDs, artifacts: combined, legacy: legacy)
        XCTAssertEqual(report.status, .incompleteOrTampered)
        XCTAssertTrue(report.issues.contains { $0.code == .reusedExecution })
    }

    func testLegacyRootSwapIsRejectedBeforeChainAcceptance() throws {
        let runIDs = ["run-a"]
        let legacy = try legacyAnchor(runIDs: runIDs)
        let artifacts = try artifacts(runID: "run-a", executionID: "exec-a")
        let wrong = AnalysisPhysicalEvidenceArchiveChainPolicy(
            policyID: "w38-policy",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W38",
            expectedArchiveID: "w38-archive",
            legacyW27PolicyID: legacy.policy.policyID,
            legacyW27ArchiveID: legacy.manifest.archiveID,
            legacyW27RootSHA256: String(repeating: "c", count: 64),
            binding: binding,
            requiredRunIDs: runIDs
        )
        let report = try validate(runIDs: runIDs, artifacts: artifacts, legacy: legacy, policy: wrong)
        XCTAssertEqual(report.status, .legacyArchiveNotReady)
        XCTAssertTrue(report.issues.contains { $0.code == .legacyArchiveNotReady })
    }

    func testLegacyW27CodecRemainsUnchangedAndW38CodecIsDeterministic() throws {
        let runIDs = ["run-a"]
        let legacy = try legacyAnchor(runIDs: runIDs)
        let oldA = try AnalysisPhysicalEvidenceArchiveCodec.encodePolicy(legacy.policy)
        let oldB = try AnalysisPhysicalEvidenceArchiveCodec.encodePolicy(legacy.policy)
        XCTAssertEqual(oldA, oldB)
        XCTAssertEqual(try AnalysisPhysicalEvidenceArchiveCodec.decodePolicy(oldA), legacy.policy)

        let policy = chainPolicy(runIDs: runIDs, legacy: legacy)
        let newA = try AnalysisPhysicalEvidenceArchiveChainCodec.encodePolicy(policy)
        let newB = try AnalysisPhysicalEvidenceArchiveChainCodec.encodePolicy(policy)
        XCTAssertEqual(newA, newB)
        XCTAssertEqual(try AnalysisPhysicalEvidenceArchiveChainCodec.decodePolicy(newA), policy)
    }
}
