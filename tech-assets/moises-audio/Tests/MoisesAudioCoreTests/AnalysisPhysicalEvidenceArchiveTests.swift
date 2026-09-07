import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalEvidenceArchiveTests: XCTestCase {
    private let sha = String(repeating: "a", count: 64)

    private var binding: AnalysisPhysicalEvidenceArchiveBinding {
        .init(
            manifestID: "golden-v1",
            manifestSHA256: sha,
            coveragePolicyID: "coverage-v1",
            selectionPolicyID: "selection-v1",
            performanceProfileID: "performance-v1",
            batchID: "batch-v1",
            workloadApprovalReference: "HQ-W25-001",
            buildIdentity: "commit-abc:100",
            deviceModel: "iPhone17,3",
            osVersion: "20.0"
        )
    }

    func testEntryCapturesExactBytesAndLength() {
        let bytes = Data("archive artifact".utf8)
        let entry = AnalysisPhysicalEvidenceArchiveBuilder.entry(
            role: .w22CoveragePolicy,
            relativePath: "policies/w22.json",
            bytes: bytes
        )
        XCTAssertEqual(entry.byteLength, UInt64(bytes.count))
        XCTAssertEqual(entry.sha256, AnalysisDeviceWorkloadSHA256.hexDigest(bytes))
        XCTAssertNil(entry.runID)
    }

    func testPerRunEntryPreservesRunBinding() {
        let bytes = Data("telemetry".utf8)
        let entry = AnalysisPhysicalEvidenceArchiveBuilder.entry(
            role: .w23RawTelemetry,
            relativePath: "runs/run-01/w23.json",
            runID: "run-01",
            bytes: bytes
        )
        XCTAssertEqual(entry.runID, "run-01")
        XCTAssertTrue(entry.role.isPerRun)
    }

    func testCanonicalRootIsIndependentOfInputEntryOrder() throws {
        let a = AnalysisPhysicalEvidenceArchiveBuilder.entry(
            role: .w22CoveragePolicy, relativePath: "a.json", bytes: Data("a".utf8)
        )
        let b = AnalysisPhysicalEvidenceArchiveBuilder.entry(
            role: .w23RawTelemetry, relativePath: "b.json", runID: "run-01", bytes: Data("b".utf8)
        )
        let first = try AnalysisPhysicalEvidenceArchiveBuilder.manifest(
            archiveID: "archive-1", policyID: "policy-1", binding: binding, entries: [a, b]
        )
        let second = try AnalysisPhysicalEvidenceArchiveBuilder.manifest(
            archiveID: "archive-1", policyID: "policy-1", binding: binding, entries: [b, a]
        )
        XCTAssertEqual(first.declaredRootSHA256, second.declaredRootSHA256)
    }

    func testRootChangesWhenArtifactHashOrRunBindingChanges() throws {
        let original = AnalysisPhysicalEvidenceArchiveBuilder.entry(
            role: .w23RawTelemetry,
            relativePath: "runs/run-01/w23.json",
            runID: "run-01",
            bytes: Data("one".utf8)
        )
        let changedBytes = AnalysisPhysicalEvidenceArchiveBuilder.entry(
            role: .w23RawTelemetry,
            relativePath: "runs/run-01/w23.json",
            runID: "run-01",
            bytes: Data("two".utf8)
        )
        let changedRun = AnalysisPhysicalEvidenceArchiveEntry(
            role: original.role,
            relativePath: original.relativePath,
            sha256: original.sha256,
            byteLength: original.byteLength,
            runID: "run-02"
        )
        let a = try AnalysisPhysicalEvidenceArchiveBuilder.manifest(
            archiveID: "archive-1", policyID: "policy-1", binding: binding, entries: [original]
        )
        let b = try AnalysisPhysicalEvidenceArchiveBuilder.manifest(
            archiveID: "archive-1", policyID: "policy-1", binding: binding, entries: [changedBytes]
        )
        let c = try AnalysisPhysicalEvidenceArchiveBuilder.manifest(
            archiveID: "archive-1", policyID: "policy-1", binding: binding, entries: [changedRun]
        )
        XCTAssertNotEqual(a.declaredRootSHA256, b.declaredRootSHA256)
        XCTAssertNotEqual(a.declaredRootSHA256, c.declaredRootSHA256)
    }

    func testRootChangesWhenDeviceOrBuildBindingChanges() throws {
        let entry = AnalysisPhysicalEvidenceArchiveBuilder.entry(
            role: .goldenManifest, relativePath: "golden.json", bytes: Data("x".utf8)
        )
        let first = try AnalysisPhysicalEvidenceArchiveBuilder.manifest(
            archiveID: "archive-1", policyID: "policy-1", binding: binding, entries: [entry]
        )
        let changed = AnalysisPhysicalEvidenceArchiveBinding(
            manifestID: binding.manifestID,
            manifestSHA256: binding.manifestSHA256,
            coveragePolicyID: binding.coveragePolicyID,
            selectionPolicyID: binding.selectionPolicyID,
            performanceProfileID: binding.performanceProfileID,
            batchID: binding.batchID,
            workloadApprovalReference: binding.workloadApprovalReference,
            buildIdentity: "different-build",
            deviceModel: binding.deviceModel,
            osVersion: binding.osVersion
        )
        let second = try AnalysisPhysicalEvidenceArchiveBuilder.manifest(
            archiveID: "archive-1", policyID: "policy-1", binding: changed, entries: [entry]
        )
        XCTAssertNotEqual(first.declaredRootSHA256, second.declaredRootSHA256)
    }

    func testArchiveCodecRoundTripsDeterministically() throws {
        let policy = AnalysisPhysicalEvidenceArchivePolicy(
            policyID: "policy-1",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W27-001",
            expectedArchiveID: "archive-1",
            binding: binding,
            requiredRunIDs: ["run-01", "run-02"]
        )
        let encodedA = try AnalysisPhysicalEvidenceArchiveCodec.encodePolicy(policy)
        let encodedB = try AnalysisPhysicalEvidenceArchiveCodec.encodePolicy(policy)
        XCTAssertEqual(encodedA, encodedB)
        XCTAssertEqual(try AnalysisPhysicalEvidenceArchiveCodec.decodePolicy(encodedA), policy)
    }

    func testRequiredRoleSetsSeparateSingletonAndPerRunArtifacts() {
        XCTAssertTrue(AnalysisPhysicalEvidenceArtifactRole.requiredSingletonRoles.contains(.goldenManifest))
        XCTAssertTrue(AnalysisPhysicalEvidenceArtifactRole.requiredSingletonRoles.contains(.buildCorroboration))
        XCTAssertTrue(AnalysisPhysicalEvidenceArtifactRole.requiredPerRunRoles.contains(.w23RawTelemetry))
        XCTAssertTrue(AnalysisPhysicalEvidenceArtifactRole.requiredPerRunRoles.contains(.w25WorkloadReceipt))
        XCTAssertFalse(AnalysisPhysicalEvidenceArtifactRole.requiredSingletonRoles.contains(.w23RawTelemetry))
    }
}
