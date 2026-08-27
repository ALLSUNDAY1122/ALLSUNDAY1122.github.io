import Foundation

public enum AnalysisPhysicalEvidenceW39BatchLoaderError: Error, Equatable, Sendable {
    case unsafeRunID
    case missingPublishedRun(String)
    case invalidControlManifest(String)
    case invalidArtifact(String)
    case invalidBundle(String)
}

public enum AnalysisPhysicalEvidenceW39BatchLoader {
    public static func load(
        runID: String,
        archiveRootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalCaptureArtifactBundle {
        guard safeComponent(runID) else { throw AnalysisPhysicalEvidenceW39BatchLoaderError.unsafeRunID }
        let runDirectory = archiveRootURL
            .appendingPathComponent("runs", isDirectory: true)
            .appendingPathComponent(runID, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: runDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw AnalysisPhysicalEvidenceW39BatchLoaderError.missingPublishedRun(runID)
        }

        let manifestURL = runDirectory.appendingPathComponent(AnalysisPhysicalCaptureArtifactStager.publicationManifestFileName)
        let manifest: AnalysisPhysicalCaptureArtifactStagingManifest
        do {
            manifest = try JSONDecoder().decode(
                AnalysisPhysicalCaptureArtifactStagingManifest.self,
                from: try readRegularFile(manifestURL, within: archiveRootURL)
            )
        } catch {
            throw AnalysisPhysicalEvidenceW39BatchLoaderError.invalidControlManifest(runID)
        }

        let roles = manifest.artifacts.map { $0.role.rawValue }
        guard manifest.schemaVersion == 1,
              manifest.state == .readyToPublish,
              manifest.runID == runID,
              safeComponent(manifest.workloadExecutionID),
              isSHA256(manifest.bundleRootSHA256),
              manifest.artifacts.count == AnalysisPhysicalCaptureArtifactMaterializer.artifactCount,
              Set(roles) == Set(AnalysisPhysicalCaptureArtifactRole.allCases.map { $0.rawValue }),
              Set(manifest.artifacts.map(\.relativePath)).count == manifest.artifacts.count else {
            throw AnalysisPhysicalEvidenceW39BatchLoaderError.invalidControlManifest(runID)
        }

        let prefix = "runs/\(runID)/"
        var artifacts: [AnalysisPhysicalCaptureArtifact] = []
        for record in manifest.artifacts.sorted(by: { $0.relativePath < $1.relativePath }) {
            guard safeRelativePath(record.relativePath), record.relativePath.hasPrefix(prefix) else {
                throw AnalysisPhysicalEvidenceW39BatchLoaderError.invalidArtifact(runID)
            }
            let suffix = String(record.relativePath.dropFirst(prefix.count))
            guard safeRelativePath(suffix) else {
                throw AnalysisPhysicalEvidenceW39BatchLoaderError.invalidArtifact(runID)
            }
            let url = runDirectory.appendingPathComponent(suffix, isDirectory: false)
            guard let bytes = try? readRegularFile(url, within: archiveRootURL),
                  !bytes.isEmpty,
                  UInt64(bytes.count) == record.byteLength,
                  AnalysisDeviceWorkloadSHA256.hexDigest(bytes) == record.sha256.lowercased() else {
                throw AnalysisPhysicalEvidenceW39BatchLoaderError.invalidArtifact(runID)
            }
            artifacts.append(.init(role: record.role, relativePath: record.relativePath, bytes: bytes))
        }

        let bundle = AnalysisPhysicalCaptureArtifactBundle(
            runID: runID,
            workloadExecutionID: manifest.workloadExecutionID,
            bundleRootSHA256: manifest.bundleRootSHA256,
            artifacts: artifacts,
            legacyW27Entries: try w27Entries(artifacts, runID: runID),
            w38Entries: try w38Entries(artifacts, runID: runID)
        )
        let report = AnalysisPhysicalCaptureArtifactBundleValidator.validate(bundle)
        guard report.valid,
              report.computedBundleRootSHA256 == manifest.bundleRootSHA256.lowercased() else {
            throw AnalysisPhysicalEvidenceW39BatchLoaderError.invalidBundle(runID)
        }
        return bundle
    }

    private static func w27Entries(
        _ artifacts: [AnalysisPhysicalCaptureArtifact],
        runID: String
    ) throws -> [AnalysisPhysicalEvidenceArchiveEntry] {
        let mapping: [(AnalysisPhysicalCaptureArtifactRole, AnalysisPhysicalEvidenceArtifactRole)] = [
            (.w23PerformanceEvidence, .w23RawTelemetry),
            (.w23PerformanceValidation, .w23ValidationReport),
            (.w25WorkloadReceipt, .w25WorkloadReceipt),
            (.w25WorkloadValidation, .w25WorkloadValidationReport)
        ]
        return try mapping.map { sourceRole, archiveRole in
            guard let artifact = artifacts.first(where: { $0.role == sourceRole }) else {
                throw AnalysisPhysicalEvidenceW39BatchLoaderError.invalidBundle(runID)
            }
            return AnalysisPhysicalEvidenceArchiveBuilder.entry(
                role: archiveRole,
                relativePath: artifact.relativePath,
                runID: runID,
                bytes: artifact.bytes
            )
        }
    }

    private static func w38Entries(
        _ artifacts: [AnalysisPhysicalCaptureArtifact],
        runID: String
    ) throws -> [AnalysisPhysicalEvidenceChainEntry] {
        let mapping: [(AnalysisPhysicalCaptureArtifactRole, AnalysisPhysicalEvidenceChainArtifactRole)] = [
            (.w35AlgorithmEvidence, .w35RuntimeAlgorithmEvidence),
            (.w36CurrentRuntimeEvidence, .w36CurrentRuntimeEvidence),
            (.w37CapturePlan, .w37CapturePlan),
            (.w37ExecutionIntegrityEvidence, .w37ExecutionIntegrityEvidence),
            (.w37ExecutionIntegrityReport, .w37ExecutionIntegrityReport)
        ]
        return try mapping.map { sourceRole, archiveRole in
            guard let artifact = artifacts.first(where: { $0.role == sourceRole }) else {
                throw AnalysisPhysicalEvidenceW39BatchLoaderError.invalidBundle(runID)
            }
            return AnalysisPhysicalEvidenceArchiveChainBuilder.entry(
                role: archiveRole,
                relativePath: artifact.relativePath,
                runID: runID,
                bytes: artifact.bytes
            )
        }
    }

    private static func readRegularFile(_ url: URL, within root: URL) throws -> Data {
        let standardizedRoot = root.standardizedFileURL
        let standardizedURL = url.standardizedFileURL
        let lexicalPrefix = standardizedRoot.path.hasSuffix("/") ? standardizedRoot.path : standardizedRoot.path + "/"
        guard standardizedURL.path.hasPrefix(lexicalPrefix) else {
            throw AnalysisPhysicalEvidenceW39BatchLoaderError.invalidArtifact("path-outside-root")
        }
        let values = try standardizedURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw AnalysisPhysicalEvidenceW39BatchLoaderError.invalidArtifact("non-regular-file")
        }
        let resolvedRoot = standardizedRoot.resolvingSymlinksInPath().path
        let resolvedURL = standardizedURL.resolvingSymlinksInPath().path
        let resolvedPrefix = resolvedRoot.hasSuffix("/") ? resolvedRoot : resolvedRoot + "/"
        guard resolvedURL.hasPrefix(resolvedPrefix) else {
            throw AnalysisPhysicalEvidenceW39BatchLoaderError.invalidArtifact("resolved-path-outside-root")
        }
        return try Data(contentsOf: standardizedURL)
    }

    static func safeComponent(_ value: String) -> Bool {
        guard !value.isEmpty,
              value == value.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.contains("/"), !value.contains("\\"),
              value != ".", value != ".." else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 45, 46, 48...57, 65...90, 95, 97...122: return true
            default: return false
            }
        }
    }

    static func safeRelativePath(_ value: String) -> Bool {
        guard !value.isEmpty,
              value == value.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.hasPrefix("/"), !value.hasPrefix("\\"),
              !value.contains("\\"), !value.contains("//") else { return false }
        return value.split(separator: "/", omittingEmptySubsequences: false).allSatisfy {
            !$0.isEmpty && $0 != "." && $0 != ".."
        }
    }

    static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 48...57, 65...70, 97...102: return true
            default: return false
            }
        }
    }
}
