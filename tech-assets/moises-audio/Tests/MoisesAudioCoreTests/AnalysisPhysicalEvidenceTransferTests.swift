import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalEvidenceTransferTests: XCTestCase {
    private let runID = "run-w41"
    private let executionID = "exec-w41"
    private let publicationID = "batch-w41"
    private let transferID = "transfer-w41"

    private var binding: AnalysisPhysicalEvidenceArchiveBinding {
        .init(
            manifestID: "manifest-w41",
            manifestSHA256: String(repeating: "a", count: 64),
            coveragePolicyID: "coverage-w41",
            selectionPolicyID: "selection-w41",
            performanceProfileID: "profile-w41",
            batchID: "perf-batch-w41",
            workloadApprovalReference: "HQ-W25-W41",
            buildIdentity: "build-w41",
            deviceModel: "iPhone17,3",
            osVersion: "26.6"
        )
    }

    private func tempRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("w41-transfer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeRunBundle() throws -> AnalysisPhysicalCaptureArtifactBundle {
        let artifacts = AnalysisPhysicalCaptureArtifactRole.allCases.map { role in
            AnalysisPhysicalCaptureArtifact(
                role: role,
                relativePath: "runs/\(runID)/\(role.rawValue.lowercased()).json",
                bytes: Data("{\"role\":\"\(role.rawValue)\",\"wave\":41}".utf8)
            )
        }
        let legacyMap: [(AnalysisPhysicalCaptureArtifactRole, AnalysisPhysicalEvidenceArtifactRole)] = [
            (.w23PerformanceEvidence, .w23RawTelemetry),
            (.w23PerformanceValidation, .w23ValidationReport),
            (.w25WorkloadReceipt, .w25WorkloadReceipt),
            (.w25WorkloadValidation, .w25WorkloadValidationReport)
        ]
        let chainMap: [(AnalysisPhysicalCaptureArtifactRole, AnalysisPhysicalEvidenceChainArtifactRole)] = [
            (.w35AlgorithmEvidence, .w35RuntimeAlgorithmEvidence),
            (.w36CurrentRuntimeEvidence, .w36CurrentRuntimeEvidence),
            (.w37CapturePlan, .w37CapturePlan),
            (.w37ExecutionIntegrityEvidence, .w37ExecutionIntegrityEvidence),
            (.w37ExecutionIntegrityReport, .w37ExecutionIntegrityReport)
        ]
        let legacy = legacyMap.map { source, target in
            let artifact = artifacts.first { $0.role == source }!
            return AnalysisPhysicalEvidenceArchiveBuilder.entry(
                role: target, relativePath: artifact.relativePath, runID: runID, bytes: artifact.bytes
            )
        }
        let chain = chainMap.map { source, target in
            let artifact = artifacts.first { $0.role == source }!
            return AnalysisPhysicalEvidenceArchiveChainBuilder.entry(
                role: target, relativePath: artifact.relativePath, runID: runID, bytes: artifact.bytes
            )
        }
        return .init(
            runID: runID,
            workloadExecutionID: executionID,
            bundleRootSHA256: try w39Root(artifacts),
            artifacts: artifacts,
            legacyW27Entries: legacy,
            w38Entries: chain
        )
    }

    private func w39Root(_ artifacts: [AnalysisPhysicalCaptureArtifact]) throws -> String {
        struct Record: Codable {
            let role: AnalysisPhysicalCaptureArtifactRole
            let relativePath: String
            let sha256: String
            let byteLength: UInt64
        }
        struct Payload: Codable {
            let schemaVersion: Int
            let runID: String
            let workloadExecutionID: String
            let artifacts: [Record]
        }
        let records = artifacts.map {
            Record(role: $0.role, relativePath: $0.relativePath, sha256: $0.sha256, byteLength: $0.byteLength)
        }.sorted {
            "\($0.role.rawValue)|\($0.relativePath)|\($0.sha256)|\($0.byteLength)"
                < "\($1.role.rawValue)|\($1.relativePath)|\($1.sha256)|\($1.byteLength)"
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return AnalysisDeviceWorkloadSHA256.hexDigest(
            try encoder.encode(Payload(schemaVersion: 1, runID: runID, workloadExecutionID: executionID, artifacts: records))
        )
    }

    private func writeRunBundle(_ bundle: AnalysisPhysicalCaptureArtifactBundle, root: URL) throws {
        let directory = root.appendingPathComponent("runs/\(runID)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let prefix = "runs/\(runID)/"
        for artifact in bundle.artifacts {
            let url = directory.appendingPathComponent(String(artifact.relativePath.dropFirst(prefix.count)))
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try artifact.bytes.write(to: url)
        }
        let control = AnalysisPhysicalCaptureArtifactStagingManifest(
            state: .readyToPublish,
            runID: runID,
            workloadExecutionID: executionID,
            bundleRootSHA256: bundle.bundleRootSHA256,
            artifacts: bundle.artifacts.map {
                .init(role: $0.role, relativePath: $0.relativePath, sha256: $0.sha256, byteLength: $0.byteLength)
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(control).write(to: directory.appendingPathComponent(AnalysisPhysicalCaptureArtifactStager.publicationManifestFileName))
    }

    private func makeAssembly(_ bundle: AnalysisPhysicalCaptureArtifactBundle) throws -> AnalysisPhysicalEvidenceBatchAssembly {
        let singletons = AnalysisPhysicalEvidenceArtifactRole.requiredSingletonRoles.map { role in
            AnalysisPhysicalEvidenceBatchStoredSingleton(
                role: role,
                relativePath: "batches/\(publicationID)/singletons/\(role.rawValue.lowercased()).json",
                bytes: Data("{\"singleton\":\"\(role.rawValue)\",\"wave\":41}".utf8)
            )
        }.sorted { $0.relativePath < $1.relativePath }
        let w27Policy = AnalysisPhysicalEvidenceArchivePolicy(
            policyID: "w27-policy-w41",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W27-W41",
            expectedArchiveID: "w27-archive-w41",
            binding: binding,
            requiredRunIDs: [runID]
        )
        var w27Entries = singletons.map {
            AnalysisPhysicalEvidenceArchiveBuilder.entry(role: $0.role, relativePath: $0.relativePath, bytes: $0.bytes)
        }
        w27Entries.append(contentsOf: bundle.legacyW27Entries)
        let w27Manifest = try AnalysisPhysicalEvidenceArchiveBuilder.manifest(
            archiveID: w27Policy.expectedArchiveID,
            policyID: w27Policy.policyID,
            binding: binding,
            entries: w27Entries
        )
        let w27Report = AnalysisPhysicalEvidenceArchiveReport(
            archiveID: w27Manifest.archiveID,
            status: .rootConsistentPendingHQ,
            computedRootSHA256: w27Manifest.declaredRootSHA256,
            entryCount: w27Manifest.entries.count,
            runCount: 1,
            issues: [],
            limitations: AnalysisPhysicalEvidenceArchiveValidator.limitations
        )
        let w38Policy = AnalysisPhysicalEvidenceArchiveChainPolicy(
            policyID: "w38-policy-w41",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W38-W41",
            expectedArchiveID: "w38-archive-w41",
            legacyW27PolicyID: w27Policy.policyID,
            legacyW27ArchiveID: w27Manifest.archiveID,
            legacyW27RootSHA256: w27Manifest.declaredRootSHA256,
            binding: binding,
            requiredRunIDs: [runID]
        )
        let w38Manifest = try AnalysisPhysicalEvidenceArchiveChainBuilder.manifest(
            archiveID: w38Policy.expectedArchiveID,
            policyID: w38Policy.policyID,
            legacyW27ArchiveID: w38Policy.legacyW27ArchiveID,
            legacyW27RootSHA256: w38Policy.legacyW27RootSHA256,
            binding: binding,
            entries: bundle.w38Entries
        )
        let w38Report = AnalysisPhysicalEvidenceArchiveChainReport(
            archiveID: w38Manifest.archiveID,
            status: .rootConsistentPendingHQ,
            computedRootSHA256: w38Manifest.declaredRootSHA256,
            entryCount: w38Manifest.entries.count,
            runCount: 1,
            issues: [],
            limitations: AnalysisPhysicalEvidenceArchiveChainValidator.limitations
        )
        let summaries = [AnalysisPhysicalEvidenceBatchRunSummary(
            runID: runID,
            workloadExecutionID: executionID,
            w39BundleRootSHA256: bundle.bundleRootSHA256
        )]
        let root = try AnalysisPhysicalEvidenceBatchAssembler.computeBatchRoot(
            publicationID: publicationID,
            runs: summaries,
            singletons: singletons,
            w27Root: w27Manifest.declaredRootSHA256,
            w38Root: w38Manifest.declaredRootSHA256
        )
        return .init(
            publicationID: publicationID,
            batchRootSHA256: root,
            runSummaries: summaries,
            singletons: singletons,
            w27Policy: w27Policy,
            w27Manifest: w27Manifest,
            w27Report: w27Report,
            w38Policy: w38Policy,
            w38Manifest: w38Manifest,
            w38Report: w38Report
        )
    }

    private func publishW40(at root: URL) throws -> AnalysisPhysicalEvidenceBatchAssembly {
        let bundle = try makeRunBundle()
        try writeRunBundle(bundle, root: root)
        let assembly = try makeAssembly(bundle)
        _ = try AnalysisPhysicalEvidenceBatchStager.publish(assembly: assembly, archiveRootURL: root)
        return assembly
    }

    func testReopenRecomputesW39W27W38AndW40WithoutCachedRoots() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let assembly = try publishW40(at: root)
        let reopened = try AnalysisPhysicalEvidencePublishedBatchReopener.reopen(publicationID: publicationID, archiveRootURL: root)
        XCTAssertEqual(reopened.w40RootSHA256, assembly.batchRootSHA256)
        XCTAssertEqual(reopened.w27RootSHA256, assembly.w27Manifest.declaredRootSHA256)
        XCTAssertEqual(reopened.w38RootSHA256, assembly.w38Manifest.declaredRootSHA256)
        XCTAssertEqual(reopened.items.count, 28)
    }

    func testTransferPublishCopiesExactPackageAndDestinationVerifierPasses() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try publishW40(at: root)
        let receipt = try AnalysisPhysicalEvidenceTransferExporter.publish(
            transferID: transferID,
            publicationID: publicationID,
            archiveRootURL: root
        )
        XCTAssertEqual(receipt.status, .published)
        XCTAssertEqual(receipt.itemCount, 28)
        let final = root.appendingPathComponent("transfers/\(transferID)", isDirectory: true)
        let verified = try AnalysisPhysicalEvidenceTransferVerifier.verify(transferDirectoryURL: final)
        XCTAssertEqual(verified.declaredTransferRootSHA256, receipt.transferRootSHA256)

        let copied = root.appendingPathComponent("copied-destination", isDirectory: true)
        try FileManager.default.copyItem(at: final, to: copied)
        XCTAssertNoThrow(try AnalysisPhysicalEvidenceTransferVerifier.verify(transferDirectoryURL: copied))
    }

    func testTruncatedPayloadFailsClosed() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try publishW40(at: root)
        _ = try AnalysisPhysicalEvidenceTransferExporter.publish(transferID: transferID, publicationID: publicationID, archiveRootURL: root)
        let final = root.appendingPathComponent("transfers/\(transferID)", isDirectory: true)
        let manifest = try AnalysisPhysicalEvidenceTransferVerifier.verify(transferDirectoryURL: final)
        let target = final.appendingPathComponent(manifest.items.first!.payloadRelativePath)
        try Data("x".utf8).write(to: target)
        XCTAssertThrowsError(try AnalysisPhysicalEvidenceTransferVerifier.verify(transferDirectoryURL: final))
    }

    func testUnexpectedPayloadFileFailsClosed() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try publishW40(at: root)
        _ = try AnalysisPhysicalEvidenceTransferExporter.publish(transferID: transferID, publicationID: publicationID, archiveRootURL: root)
        let final = root.appendingPathComponent("transfers/\(transferID)", isDirectory: true)
        try Data("extra".utf8).write(to: final.appendingPathComponent("payload/extra.json"))
        XCTAssertThrowsError(try AnalysisPhysicalEvidenceTransferVerifier.verify(transferDirectoryURL: final)) { error in
            guard case .unexpectedPayload = error as? AnalysisPhysicalEvidenceTransferError else {
                XCTFail("expected unexpected payload"); return
            }
        }
    }

    func testW39MutationAfterW40PublicationFailsReopen() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try publishW40(at: root)
        let target = root.appendingPathComponent("runs/\(runID)/w35_algorithm_evidence.json")
        try Data("tampered".utf8).write(to: target)
        XCTAssertThrowsError(try AnalysisPhysicalEvidencePublishedBatchReopener.reopen(publicationID: publicationID, archiveRootURL: root))
    }

    func testCachedReportMutationFailsReopenEvenWhenArchiveManifestIsUntouched() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try publishW40(at: root)
        let reportURL = root.appendingPathComponent("batches/\(publicationID)/w27-report.json")
        var report = try AnalysisPhysicalEvidenceArchiveCodec.decodeReport(Data(contentsOf: reportURL))
        report = .init(
            archiveID: report.archiveID,
            status: report.status,
            computedRootSHA256: report.computedRootSHA256,
            entryCount: report.entryCount,
            runCount: report.runCount,
            issues: report.issues,
            limitations: report.limitations + ["modified-after-publication"]
        )
        try AnalysisPhysicalEvidenceArchiveCodec.encodeReport(report).write(to: reportURL)
        XCTAssertThrowsError(try AnalysisPhysicalEvidencePublishedBatchReopener.reopen(publicationID: publicationID, archiveRootURL: root)) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidencePublishedBatchReopenError, .staleW27Report)
        }
    }

    func testMatchingInterruptedStageIsRecoveredAndPublished() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try publishW40(at: root)
        try AnalysisPhysicalEvidenceTransferExporter.createInterruptedStageCheckpoint(
            transferID: transferID,
            publicationID: publicationID,
            archiveRootURL: root
        )
        let receipt = try AnalysisPhysicalEvidenceTransferExporter.publish(
            transferID: transferID,
            publicationID: publicationID,
            archiveRootURL: root
        )
        XCTAssertEqual(receipt.status, .recoveredInterruptedStageAndPublished)
    }

    func testCorruptInterruptedStageIsPreservedAsAmbiguous() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try publishW40(at: root)
        try AnalysisPhysicalEvidenceTransferExporter.createInterruptedStageCheckpoint(
            transferID: transferID,
            publicationID: publicationID,
            archiveRootURL: root
        )
        let stage = try AnalysisPhysicalEvidenceTransferExporter.stagingDirectoryURL(
            transferID: transferID,
            publicationID: publicationID,
            archiveRootURL: root
        )
        try Data("corrupt".utf8).write(to: stage.appendingPathComponent(AnalysisPhysicalEvidenceTransferExporter.stagingMarkerFileName))
        XCTAssertThrowsError(try AnalysisPhysicalEvidenceTransferExporter.publish(transferID: transferID, publicationID: publicationID, archiveRootURL: root)) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceTransferError, .ambiguousRecoveryState)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: stage.path))
    }
}
