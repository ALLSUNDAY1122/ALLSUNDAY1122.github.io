import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalEvidenceW39BatchLoaderTests: XCTestCase {
    private func makeBundle(runID: String = "run-a", executionID: String = "exec-a") throws -> AnalysisPhysicalCaptureArtifactBundle {
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
            bundleRootSHA256: try bundleRoot(runID: runID, executionID: executionID, artifacts: artifacts),
            artifacts: artifacts,
            legacyW27Entries: legacy,
            w38Entries: chain
        )
    }

    private func bundleRoot(
        runID: String,
        executionID: String,
        artifacts: [AnalysisPhysicalCaptureArtifact]
    ) throws -> String {
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

    private func writePublished(
        _ bundle: AnalysisPhysicalCaptureArtifactBundle,
        root: URL,
        overrideRecords: [AnalysisPhysicalCaptureArtifactStagingRecord]? = nil,
        overrideRoot: String? = nil
    ) throws {
        let runDirectory = root.appendingPathComponent("runs/\(bundle.runID)", isDirectory: true)
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        let prefix = "runs/\(bundle.runID)/"
        for artifact in bundle.artifacts {
            let suffix = String(artifact.relativePath.dropFirst(prefix.count))
            let url = runDirectory.appendingPathComponent(suffix)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try artifact.bytes.write(to: url)
        }
        let records = overrideRecords ?? bundle.artifacts.map {
            AnalysisPhysicalCaptureArtifactStagingRecord(
                role: $0.role,
                relativePath: $0.relativePath,
                sha256: $0.sha256,
                byteLength: $0.byteLength
            )
        }
        let control = AnalysisPhysicalCaptureArtifactStagingManifest(
            state: .readyToPublish,
            runID: bundle.runID,
            workloadExecutionID: bundle.workloadExecutionID,
            bundleRootSHA256: overrideRoot ?? bundle.bundleRootSHA256,
            artifacts: records
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(control).write(
            to: runDirectory.appendingPathComponent(AnalysisPhysicalCaptureArtifactStager.publicationManifestFileName)
        )
    }

    private func tempRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("w40-loader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testLoaderReadsOnlyDeclaredW39ArtifactsAndIgnoresExtraFiles() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = try makeBundle()
        try writePublished(bundle, root: root)
        let junk = root.appendingPathComponent("runs/run-a/NOT_EVIDENCE.txt")
        try Data("junk".utf8).write(to: junk)

        let loaded = try AnalysisPhysicalEvidenceW39BatchLoader.load(runID: "run-a", archiveRootURL: root)
        XCTAssertEqual(loaded, bundle)
        XCTAssertEqual(loaded.artifacts.count, 9)
        XCTAssertEqual(loaded.legacyW27Entries.count, 4)
        XCTAssertEqual(loaded.w38Entries.count, 5)
    }

    func testLoaderRejectsTamperedDeclaredArtifact() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = try makeBundle()
        try writePublished(bundle, root: root)
        let target = root.appendingPathComponent("runs/run-a/w36_current_runtime_evidence.json")
        try Data("tampered".utf8).write(to: target)

        XCTAssertThrowsError(try AnalysisPhysicalEvidenceW39BatchLoader.load(runID: "run-a", archiveRootURL: root))
    }

    func testLoaderRejectsStaleBundleRoot() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = try makeBundle()
        try writePublished(bundle, root: root, overrideRoot: String(repeating: "f", count: 64))
        XCTAssertThrowsError(try AnalysisPhysicalEvidenceW39BatchLoader.load(runID: "run-a", archiveRootURL: root))
    }

    func testLoaderRejectsTraversalInControlManifest() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = try makeBundle()
        var records = bundle.artifacts.map {
            AnalysisPhysicalCaptureArtifactStagingRecord(
                role: $0.role, relativePath: $0.relativePath, sha256: $0.sha256, byteLength: $0.byteLength
            )
        }
        let first = records[0]
        records[0] = .init(role: first.role, relativePath: "runs/run-a/../escape.json", sha256: first.sha256, byteLength: first.byteLength)
        try writePublished(bundle, root: root, overrideRecords: records)
        XCTAssertThrowsError(try AnalysisPhysicalEvidenceW39BatchLoader.load(runID: "run-a", archiveRootURL: root))
    }

    func testLoaderRejectsUnsafeAndMissingRunIDs() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try AnalysisPhysicalEvidenceW39BatchLoader.load(runID: "../run", archiveRootURL: root))
        XCTAssertThrowsError(try AnalysisPhysicalEvidenceW39BatchLoader.load(runID: "missing", archiveRootURL: root))
    }

    func testLoaderRepeatedReadIsDeterministic() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = try makeBundle()
        try writePublished(bundle, root: root)
        for _ in 0..<500 {
            XCTAssertEqual(
                try AnalysisPhysicalEvidenceW39BatchLoader.load(runID: bundle.runID, archiveRootURL: root),
                bundle
            )
        }
    }
}
