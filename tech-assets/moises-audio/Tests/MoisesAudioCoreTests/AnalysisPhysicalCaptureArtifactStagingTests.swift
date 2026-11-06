import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalCaptureArtifactStagingTests: XCTestCase {
    private func artifact(_ role: AnalysisPhysicalCaptureArtifactRole, runID: String = "run-39") -> AnalysisPhysicalCaptureArtifact {
        let leaf: String
        switch role {
        case .w23PerformanceEvidence: leaf = "w23/performance-evidence.json"
        case .w23PerformanceValidation: leaf = "w23/performance-validation.json"
        case .w25WorkloadReceipt: leaf = "w25/workload-receipt.json"
        case .w25WorkloadValidation: leaf = "w25/workload-validation.json"
        case .w35AlgorithmEvidence: leaf = "w35/algorithm-evidence.json"
        case .w36CurrentRuntimeEvidence: leaf = "w36/current-runtime-evidence.json"
        case .w37CapturePlan: leaf = "w37/capture-plan.json"
        case .w37ExecutionIntegrityEvidence: leaf = "w37/execution-integrity-evidence.json"
        case .w37ExecutionIntegrityReport: leaf = "w37/execution-integrity-report.json"
        }
        return .init(
            role: role,
            relativePath: "runs/\(runID)/\(leaf)",
            bytes: Data("\(role.rawValue)|\(runID)".utf8)
        )
    }

    private func bundle(runID: String = "run-39", executionID: String = "exec-39") throws -> AnalysisPhysicalCaptureArtifactBundle {
        let artifacts = AnalysisPhysicalCaptureArtifactRole.allCases.map { artifact($0, runID: runID) }
        let legacyMap: [(AnalysisPhysicalCaptureArtifactRole, AnalysisPhysicalEvidenceArtifactRole)] = [
            (.w23PerformanceEvidence, .w23RawTelemetry),
            (.w23PerformanceValidation, .w23ValidationReport),
            (.w25WorkloadReceipt, .w25WorkloadReceipt),
            (.w25WorkloadValidation, .w25WorkloadValidationReport)
        ]
        let legacy = legacyMap.map { sourceRole, archiveRole -> AnalysisPhysicalEvidenceArchiveEntry in
            let value = artifacts.first(where: { $0.role == sourceRole })!
            return AnalysisPhysicalEvidenceArchiveBuilder.entry(
                role: archiveRole,
                relativePath: value.relativePath,
                runID: runID,
                bytes: value.bytes
            )
        }
        let chainMap: [(AnalysisPhysicalCaptureArtifactRole, AnalysisPhysicalEvidenceChainArtifactRole)] = [
            (.w35AlgorithmEvidence, .w35RuntimeAlgorithmEvidence),
            (.w36CurrentRuntimeEvidence, .w36CurrentRuntimeEvidence),
            (.w37CapturePlan, .w37CapturePlan),
            (.w37ExecutionIntegrityEvidence, .w37ExecutionIntegrityEvidence),
            (.w37ExecutionIntegrityReport, .w37ExecutionIntegrityReport)
        ]
        let chain = chainMap.map { sourceRole, archiveRole -> AnalysisPhysicalEvidenceChainEntry in
            let value = artifacts.first(where: { $0.role == sourceRole })!
            return AnalysisPhysicalEvidenceArchiveChainBuilder.entry(
                role: archiveRole,
                relativePath: value.relativePath,
                runID: runID,
                bytes: value.bytes
            )
        }
        let root = try rootSHA(runID: runID, executionID: executionID, artifacts: artifacts)
        return .init(
            runID: runID,
            workloadExecutionID: executionID,
            bundleRootSHA256: root,
            artifacts: artifacts,
            legacyW27Entries: legacy,
            w38Entries: chain
        )
    }

    private struct RootRecord: Codable {
        let role: AnalysisPhysicalCaptureArtifactRole
        let relativePath: String
        let sha256: String
        let byteLength: UInt64
    }

    private struct RootPayload: Codable {
        let schemaVersion: Int
        let runID: String
        let workloadExecutionID: String
        let artifacts: [RootRecord]
    }

    private func rootSHA(
        runID: String,
        executionID: String,
        artifacts: [AnalysisPhysicalCaptureArtifact]
    ) throws -> String {
        let records = artifacts.map {
            RootRecord(role: $0.role, relativePath: $0.relativePath, sha256: $0.sha256, byteLength: $0.byteLength)
        }.sorted { lhs, rhs in
            let l = "\(lhs.role.rawValue)|\(lhs.relativePath)|\(lhs.sha256)|\(lhs.byteLength)"
            let r = "\(rhs.role.rawValue)|\(rhs.relativePath)|\(rhs.sha256)|\(rhs.byteLength)"
            return l < r
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(RootPayload(schemaVersion: 1, runID: runID, workloadExecutionID: executionID, artifacts: records))
        return AnalysisDeviceWorkloadSHA256.hexDigest(data)
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("moises-w39-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func testValidPreparedBundleHasExactNineFourFiveInventory() throws {
        let value = try bundle()
        let report = AnalysisPhysicalCaptureArtifactBundleValidator.validate(value)
        XCTAssertTrue(report.valid, "\(report.issues)")
        XCTAssertEqual(value.artifacts.count, 9)
        XCTAssertEqual(value.legacyW27Entries.count, 4)
        XCTAssertEqual(value.w38Entries.count, 5)
        XCTAssertEqual(report.computedBundleRootSHA256, value.bundleRootSHA256)
    }

    func testValidatedPublicationWritesExactArtifactsAndControlManifest() throws {
        let value = try bundle()
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let receipt = try AnalysisPhysicalCaptureArtifactPublicationGate.publishValidated(
            bundle: value,
            archiveRootURL: root
        )
        XCTAssertEqual(receipt.status, .published)
        XCTAssertEqual(receipt.artifactCount, 9)
        let final = root.appendingPathComponent("runs/run-39", isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: final.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: final.appendingPathComponent(AnalysisPhysicalCaptureArtifactStager.publicationManifestFileName).path))
        for item in value.artifacts {
            let prefix = "runs/run-39/"
            let suffix = String(item.relativePath.dropFirst(prefix.count))
            let data = try Data(contentsOf: final.appendingPathComponent(suffix))
            XCTAssertEqual(data, item.bytes)
            XCTAssertEqual(AnalysisDeviceWorkloadSHA256.hexDigest(data), item.sha256)
        }
    }

    func testExistingFinalTargetFailsClosedWithoutOverwrite() throws {
        let value = try bundle()
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try AnalysisPhysicalCaptureArtifactPublicationGate.publishValidated(bundle: value, archiveRootURL: root)

        XCTAssertThrowsError(
            try AnalysisPhysicalCaptureArtifactPublicationGate.publishValidated(bundle: value, archiveRootURL: root)
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalCaptureArtifactStagingError, .existingTargetCollision)
        }
    }

    func testInterruptedStageWithMatchingMarkerIsRemovedAndRestaged() throws {
        let value = try bundle()
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        try AnalysisPhysicalCaptureArtifactStager.createInterruptedStageCheckpoint(
            bundle: value,
            archiveRootURL: root
        )
        let stage = AnalysisPhysicalCaptureArtifactStager.stagingDirectoryURL(bundle: value, archiveRootURL: root)
        let partial = stage.appendingPathComponent("w35/partial.tmp")
        try FileManager.default.createDirectory(at: partial.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("partial".utf8).write(to: partial)

        let receipt = try AnalysisPhysicalCaptureArtifactPublicationGate.publishValidated(
            bundle: value,
            archiveRootURL: root
        )
        XCTAssertEqual(receipt.status, .recoveredInterruptedStageAndPublished)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stage.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("runs/run-39").path))
    }

    func testCorruptInterruptedMarkerIsAmbiguousAndNotDeleted() throws {
        let value = try bundle()
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        try AnalysisPhysicalCaptureArtifactStager.createInterruptedStageCheckpoint(bundle: value, archiveRootURL: root)
        let stage = AnalysisPhysicalCaptureArtifactStager.stagingDirectoryURL(bundle: value, archiveRootURL: root)
        try Data("not-json".utf8).write(
            to: stage.appendingPathComponent(AnalysisPhysicalCaptureArtifactStager.stagingManifestFileName),
            options: .atomic
        )

        XCTAssertThrowsError(
            try AnalysisPhysicalCaptureArtifactPublicationGate.publishValidated(bundle: value, archiveRootURL: root)
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalCaptureArtifactStagingError, .ambiguousRecoveryState)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: stage.path))
    }

    func testForgedRootArtifactDigestLegacyAndChainProjectionFailClosed() throws {
        let base = try bundle()
        let forgedRoot = AnalysisPhysicalCaptureArtifactBundle(
            runID: base.runID,
            workloadExecutionID: base.workloadExecutionID,
            bundleRootSHA256: String(repeating: "f", count: 64),
            artifacts: base.artifacts,
            legacyW27Entries: base.legacyW27Entries,
            w38Entries: base.w38Entries
        )
        XCTAssertTrue(AnalysisPhysicalCaptureArtifactBundleValidator.validate(forgedRoot).issues.contains { $0.code == .bundleRootMismatch })

        var alteredArtifacts = base.artifacts
        let first = alteredArtifacts[0]
        alteredArtifacts[0] = AnalysisPhysicalCaptureArtifact(
            role: first.role,
            relativePath: first.relativePath,
            bytes: Data("changed".utf8)
        )
        let staleProjection = AnalysisPhysicalCaptureArtifactBundle(
            runID: base.runID,
            workloadExecutionID: base.workloadExecutionID,
            bundleRootSHA256: base.bundleRootSHA256,
            artifacts: alteredArtifacts,
            legacyW27Entries: base.legacyW27Entries,
            w38Entries: base.w38Entries
        )
        let staleReport = AnalysisPhysicalCaptureArtifactBundleValidator.validate(staleProjection)
        XCTAssertTrue(staleReport.issues.contains { $0.code == .legacyEntryMismatch })
        XCTAssertTrue(staleReport.issues.contains { $0.code == .bundleRootMismatch })

        let missingLegacy = AnalysisPhysicalCaptureArtifactBundle(
            runID: base.runID,
            workloadExecutionID: base.workloadExecutionID,
            bundleRootSHA256: base.bundleRootSHA256,
            artifacts: base.artifacts,
            legacyW27Entries: Array(base.legacyW27Entries.dropLast()),
            w38Entries: base.w38Entries
        )
        XCTAssertTrue(AnalysisPhysicalCaptureArtifactBundleValidator.validate(missingLegacy).issues.contains { $0.code == .legacyEntryMismatch })

        let missingChain = AnalysisPhysicalCaptureArtifactBundle(
            runID: base.runID,
            workloadExecutionID: base.workloadExecutionID,
            bundleRootSHA256: base.bundleRootSHA256,
            artifacts: base.artifacts,
            legacyW27Entries: base.legacyW27Entries,
            w38Entries: Array(base.w38Entries.dropLast())
        )
        XCTAssertTrue(AnalysisPhysicalCaptureArtifactBundleValidator.validate(missingChain).issues.contains { $0.code == .chainEntryMismatch })
    }

    func testPathTraversalAndRunDirectoryRebindingAreRejectedBeforeIO() throws {
        let base = try bundle()
        var artifacts = base.artifacts
        let first = artifacts[0]
        artifacts[0] = AnalysisPhysicalCaptureArtifact(
            role: first.role,
            relativePath: "runs/run-39/../escape.json",
            bytes: first.bytes
        )
        let bad = AnalysisPhysicalCaptureArtifactBundle(
            runID: base.runID,
            workloadExecutionID: base.workloadExecutionID,
            bundleRootSHA256: base.bundleRootSHA256,
            artifacts: artifacts,
            legacyW27Entries: base.legacyW27Entries,
            w38Entries: base.w38Entries
        )
        let report = AnalysisPhysicalCaptureArtifactBundleValidator.validate(bad)
        XCTAssertTrue(report.issues.contains { $0.code == .invalidArtifactPath })
    }

    func testRepeatedValidationIsDeterministic() throws {
        let value = try bundle()
        let expected = AnalysisPhysicalCaptureArtifactBundleValidator.validate(value)
        XCTAssertTrue(expected.valid)
        for _ in 0..<2_000 {
            XCTAssertEqual(AnalysisPhysicalCaptureArtifactBundleValidator.validate(value), expected)
        }
    }
}
