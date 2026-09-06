import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalEvidenceBatchStagingTests: XCTestCase {
    private let runID = "run-a"
    private let executionID = "exec-a"
    private let publicationID = "batch-publication-a"

    private var binding: AnalysisPhysicalEvidenceArchiveBinding {
        .init(
            manifestID: "manifest-a",
            manifestSHA256: String(repeating: "a", count: 64),
            coveragePolicyID: "coverage-a",
            selectionPolicyID: "selection-a",
            performanceProfileID: "profile-a",
            batchID: "performance-batch-a",
            workloadApprovalReference: "HQ-W25-A",
            buildIdentity: "build-a",
            deviceModel: "iPhone17,3",
            osVersion: "26.6"
        )
    }

    private func makeRunBundle() throws -> AnalysisPhysicalCaptureArtifactBundle {
        let artifacts = AnalysisPhysicalCaptureArtifactRole.allCases.map { role in
            AnalysisPhysicalCaptureArtifact(
                role: role,
                relativePath: "runs/\(runID)/\(role.rawValue.lowercased()).json",
                bytes: Data("{\"role\":\"\(role.rawValue)\"}".utf8)
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
        let dir = root.appendingPathComponent("runs/\(runID)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let prefix = "runs/\(runID)/"
        for artifact in bundle.artifacts {
            let url = dir.appendingPathComponent(String(artifact.relativePath.dropFirst(prefix.count)))
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
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(control).write(to: dir.appendingPathComponent(AnalysisPhysicalCaptureArtifactStager.publicationManifestFileName))
    }

    private func makeAssembly(runBundle: AnalysisPhysicalCaptureArtifactBundle) throws -> AnalysisPhysicalEvidenceBatchAssembly {
        let singletons = AnalysisPhysicalEvidenceArtifactRole.requiredSingletonRoles.map { role in
            AnalysisPhysicalEvidenceBatchStoredSingleton(
                role: role,
                relativePath: "batches/\(publicationID)/singletons/\(role.rawValue.lowercased()).json",
                bytes: Data("{\"singleton\":\"\(role.rawValue)\"}".utf8)
            )
        }.sorted { $0.relativePath < $1.relativePath }

        let w27Policy = AnalysisPhysicalEvidenceArchivePolicy(
            policyID: "w27-policy-a",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W27-A",
            expectedArchiveID: "w27-archive-a",
            binding: binding,
            requiredRunIDs: [runID]
        )
        var w27Entries = singletons.map {
            AnalysisPhysicalEvidenceArchiveBuilder.entry(role: $0.role, relativePath: $0.relativePath, bytes: $0.bytes)
        }
        w27Entries.append(contentsOf: runBundle.legacyW27Entries)
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
            limitations: []
        )

        let w38Policy = AnalysisPhysicalEvidenceArchiveChainPolicy(
            policyID: "w38-policy-a",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W38-A",
            expectedArchiveID: "w38-archive-a",
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
            entries: runBundle.w38Entries
        )
        let w38Report = AnalysisPhysicalEvidenceArchiveChainReport(
            archiveID: w38Manifest.archiveID,
            status: .rootConsistentPendingHQ,
            computedRootSHA256: w38Manifest.declaredRootSHA256,
            entryCount: w38Manifest.entries.count,
            runCount: 1,
            issues: [],
            limitations: []
        )
        let summaries = [AnalysisPhysicalEvidenceBatchRunSummary(
            runID: runID,
            workloadExecutionID: executionID,
            w39BundleRootSHA256: runBundle.bundleRootSHA256
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

    private func tempRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("w40-batch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testPreparedAssemblyRequiresCompleteW27AndW38Inventories() throws {
        let bundle = try makeRunBundle()
        let assembly = try makeAssembly(runBundle: bundle)
        XCTAssertTrue(AnalysisPhysicalEvidenceBatchAssemblyValidator.validate(assembly))

        let shortenedEntries = Array(assembly.w38Manifest.entries.dropLast())
        let shortenedManifest = try AnalysisPhysicalEvidenceArchiveChainBuilder.manifest(
            archiveID: assembly.w38Manifest.archiveID,
            policyID: assembly.w38Manifest.policyID,
            legacyW27ArchiveID: assembly.w38Manifest.legacyW27ArchiveID,
            legacyW27RootSHA256: assembly.w38Manifest.legacyW27RootSHA256,
            binding: assembly.w38Manifest.binding,
            entries: shortenedEntries
        )
        let shortenedReport = AnalysisPhysicalEvidenceArchiveChainReport(
            archiveID: shortenedManifest.archiveID,
            status: .rootConsistentPendingHQ,
            computedRootSHA256: shortenedManifest.declaredRootSHA256,
            entryCount: shortenedManifest.entries.count,
            runCount: 1,
            issues: [],
            limitations: []
        )
        let forgedRoot = try AnalysisPhysicalEvidenceBatchAssembler.computeBatchRoot(
            publicationID: publicationID,
            runs: assembly.runSummaries,
            singletons: assembly.singletons,
            w27Root: assembly.w27Manifest.declaredRootSHA256,
            w38Root: shortenedManifest.declaredRootSHA256
        )
        let incomplete = AnalysisPhysicalEvidenceBatchAssembly(
            publicationID: publicationID,
            batchRootSHA256: forgedRoot,
            runSummaries: assembly.runSummaries,
            singletons: assembly.singletons,
            w27Policy: assembly.w27Policy,
            w27Manifest: assembly.w27Manifest,
            w27Report: assembly.w27Report,
            w38Policy: assembly.w38Policy,
            w38Manifest: shortenedManifest,
            w38Report: shortenedReport
        )
        XCTAssertFalse(AnalysisPhysicalEvidenceBatchAssemblyValidator.validate(incomplete))
    }

    func testPublishWritesBatchAtomicallyAndRejectsSecondPublish() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = try makeRunBundle()
        try writeRunBundle(bundle, root: root)
        let assembly = try makeAssembly(runBundle: bundle)

        let receipt = try AnalysisPhysicalEvidenceBatchStager.publish(assembly: assembly, archiveRootURL: root)
        XCTAssertEqual(receipt.status, .published)
        XCTAssertEqual(receipt.runCount, 1)
        let final = root.appendingPathComponent("batches/\(publicationID)", isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: final.appendingPathComponent(AnalysisPhysicalEvidenceBatchStager.publicationManifestFileName).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: final.appendingPathComponent("w27-manifest.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: final.appendingPathComponent("w38-manifest.json").path))

        XCTAssertThrowsError(try AnalysisPhysicalEvidenceBatchStager.publish(assembly: assembly, archiveRootURL: root)) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceBatchStagingError, .existingTargetCollision)
        }
    }

    func testMatchingInterruptedStageIsRecoveredAndRepublished() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = try makeRunBundle()
        try writeRunBundle(bundle, root: root)
        let assembly = try makeAssembly(runBundle: bundle)
        try AnalysisPhysicalEvidenceBatchStager.createInterruptedStageCheckpoint(assembly: assembly, archiveRootURL: root)

        let receipt = try AnalysisPhysicalEvidenceBatchStager.publish(assembly: assembly, archiveRootURL: root)
        XCTAssertEqual(receipt.status, .recoveredInterruptedStageAndPublished)
        XCTAssertFalse(FileManager.default.fileExists(atPath: AnalysisPhysicalEvidenceBatchStager.stagingDirectoryURL(assembly: assembly, archiveRootURL: root).path))
    }

    func testCorruptInterruptedMarkerIsPreservedAsAmbiguous() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = try makeRunBundle()
        try writeRunBundle(bundle, root: root)
        let assembly = try makeAssembly(runBundle: bundle)
        try AnalysisPhysicalEvidenceBatchStager.createInterruptedStageCheckpoint(assembly: assembly, archiveRootURL: root)
        let stage = AnalysisPhysicalEvidenceBatchStager.stagingDirectoryURL(assembly: assembly, archiveRootURL: root)
        try Data("corrupt".utf8).write(to: stage.appendingPathComponent(AnalysisPhysicalEvidenceBatchStager.stagingManifestFileName))

        XCTAssertThrowsError(try AnalysisPhysicalEvidenceBatchStager.publish(assembly: assembly, archiveRootURL: root)) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceBatchStagingError, .ambiguousRecoveryState)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: stage.path))
    }

    func testW39MutationBetweenAssemblyAndPublicationFailsClosed() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = try makeRunBundle()
        try writeRunBundle(bundle, root: root)
        let assembly = try makeAssembly(runBundle: bundle)
        let target = root.appendingPathComponent("runs/\(runID)/w35_algorithm_evidence.json")
        try Data("changed-after-assembly".utf8).write(to: target)

        XCTAssertThrowsError(try AnalysisPhysicalEvidenceBatchStager.publish(assembly: assembly, archiveRootURL: root)) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceBatchStagingError, .invalidAssembly)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("batches/\(publicationID)").path))
    }
}
