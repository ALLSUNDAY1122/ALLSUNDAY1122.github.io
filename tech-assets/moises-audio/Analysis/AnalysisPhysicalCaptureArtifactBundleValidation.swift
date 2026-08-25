import Foundation

public enum AnalysisPhysicalCaptureArtifactBundleValidationIssueCode: String, Codable, Hashable, Sendable {
    case invalidBundle = "W39_INVALID_BUNDLE"
    case invalidArtifactInventory = "W39_INVALID_ARTIFACT_INVENTORY"
    case invalidArtifactPath = "W39_INVALID_ARTIFACT_PATH"
    case artifactDigestMismatch = "W39_ARTIFACT_DIGEST_MISMATCH"
    case legacyEntryMismatch = "W39_LEGACY_ENTRY_MISMATCH"
    case chainEntryMismatch = "W39_CHAIN_ENTRY_MISMATCH"
    case bundleRootMismatch = "W39_BUNDLE_ROOT_MISMATCH"
}

public struct AnalysisPhysicalCaptureArtifactBundleValidationIssue: Codable, Equatable, Sendable {
    public let code: AnalysisPhysicalCaptureArtifactBundleValidationIssueCode
    public let detail: String

    public init(code: AnalysisPhysicalCaptureArtifactBundleValidationIssueCode, detail: String) {
        self.code = code
        self.detail = detail
    }
}

public struct AnalysisPhysicalCaptureArtifactBundleValidationReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let runID: String
    public let valid: Bool
    public let computedBundleRootSHA256: String?
    public let issues: [AnalysisPhysicalCaptureArtifactBundleValidationIssue]

    public init(
        schemaVersion: Int = 1,
        runID: String,
        valid: Bool,
        computedBundleRootSHA256: String?,
        issues: [AnalysisPhysicalCaptureArtifactBundleValidationIssue]
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.valid = valid
        self.computedBundleRootSHA256 = computedBundleRootSHA256
        self.issues = issues
    }
}

public enum AnalysisPhysicalCaptureArtifactBundleValidator {
    public static func validate(
        _ bundle: AnalysisPhysicalCaptureArtifactBundle
    ) -> AnalysisPhysicalCaptureArtifactBundleValidationReport {
        var issues: [AnalysisPhysicalCaptureArtifactBundleValidationIssue] = []
        if bundle.schemaVersion != 1
            || bundle.runID.isEmpty
            || bundle.workloadExecutionID.isEmpty
            || !isSHA256(bundle.bundleRootSHA256) {
            issues.append(.init(code: .invalidBundle, detail: "bundle requires schema 1, nonempty run/execution IDs and a SHA-256 root"))
        }

        let roles = bundle.artifacts.map { $0.role.rawValue }
        let paths = bundle.artifacts.map(\.relativePath)
        if bundle.artifacts.count != AnalysisPhysicalCaptureArtifactMaterializer.artifactCount
            || Set(roles).count != AnalysisPhysicalCaptureArtifactMaterializer.artifactCount
            || Set(paths).count != AnalysisPhysicalCaptureArtifactMaterializer.artifactCount
            || Set(roles) != Set(AnalysisPhysicalCaptureArtifactRole.allCases.map(\.rawValue)) {
            issues.append(.init(code: .invalidArtifactInventory, detail: "bundle must contain exactly one of each of the nine W23-W37 materialization roles"))
        }

        let prefix = "runs/\(bundle.runID)/"
        for artifact in bundle.artifacts {
            if !safeRelativePath(artifact.relativePath) || !artifact.relativePath.hasPrefix(prefix) {
                issues.append(.init(code: .invalidArtifactPath, detail: "artifact \(artifact.role.rawValue) is outside the exact run directory"))
            }
            if artifact.bytes.isEmpty
                || artifact.byteLength != UInt64(artifact.bytes.count)
                || !isSHA256(artifact.sha256)
                || AnalysisDeviceWorkloadSHA256.hexDigest(artifact.bytes) != artifact.sha256.lowercased() {
                issues.append(.init(code: .artifactDigestMismatch, detail: "artifact \(artifact.role.rawValue) bytes/length/SHA do not agree"))
            }
        }

        validateLegacyEntries(bundle, issues: &issues)
        validateChainEntries(bundle, issues: &issues)

        let computedRoot = try? computeRoot(bundle)
        if computedRoot == nil || computedRoot != bundle.bundleRootSHA256.lowercased() {
            issues.append(.init(code: .bundleRootMismatch, detail: "declared W39 bundle root does not match the deterministic artifact metadata root"))
        }

        issues.sort { ($0.code.rawValue, $0.detail) < ($1.code.rawValue, $1.detail) }
        return .init(
            runID: bundle.runID,
            valid: issues.isEmpty,
            computedBundleRootSHA256: computedRoot,
            issues: issues
        )
    }

    private static func validateLegacyEntries(
        _ bundle: AnalysisPhysicalCaptureArtifactBundle,
        issues: inout [AnalysisPhysicalCaptureArtifactBundleValidationIssue]
    ) {
        let expected: [(AnalysisPhysicalCaptureArtifactRole, AnalysisPhysicalEvidenceArtifactRole)] = [
            (.w23PerformanceEvidence, .w23RawTelemetry),
            (.w23PerformanceValidation, .w23ValidationReport),
            (.w25WorkloadReceipt, .w25WorkloadReceipt),
            (.w25WorkloadValidation, .w25WorkloadValidationReport)
        ]
        if bundle.legacyW27Entries.count != expected.count {
            issues.append(.init(code: .legacyEntryMismatch, detail: "W27 projection must contain exactly four per-run entries"))
            return
        }
        for (artifactRole, archiveRole) in expected {
            guard let artifact = bundle.artifacts.first(where: { $0.role == artifactRole }) else { continue }
            let matches = bundle.legacyW27Entries.filter {
                $0.role == archiveRole
                    && $0.runID == bundle.runID
                    && $0.relativePath == artifact.relativePath
                    && $0.sha256 == artifact.sha256
                    && $0.byteLength == artifact.byteLength
            }
            if matches.count != 1 {
                issues.append(.init(code: .legacyEntryMismatch, detail: "W27 projection for \(artifactRole.rawValue) does not exactly match materialized bytes"))
            }
        }
    }

    private static func validateChainEntries(
        _ bundle: AnalysisPhysicalCaptureArtifactBundle,
        issues: inout [AnalysisPhysicalCaptureArtifactBundleValidationIssue]
    ) {
        let expected: [(AnalysisPhysicalCaptureArtifactRole, AnalysisPhysicalEvidenceChainArtifactRole)] = [
            (.w35AlgorithmEvidence, .w35RuntimeAlgorithmEvidence),
            (.w36CurrentRuntimeEvidence, .w36CurrentRuntimeEvidence),
            (.w37CapturePlan, .w37CapturePlan),
            (.w37ExecutionIntegrityEvidence, .w37ExecutionIntegrityEvidence),
            (.w37ExecutionIntegrityReport, .w37ExecutionIntegrityReport)
        ]
        if bundle.w38Entries.count != expected.count {
            issues.append(.init(code: .chainEntryMismatch, detail: "W38 projection must contain exactly five per-run entries"))
            return
        }
        for (artifactRole, archiveRole) in expected {
            guard let artifact = bundle.artifacts.first(where: { $0.role == artifactRole }) else { continue }
            let matches = bundle.w38Entries.filter {
                $0.role == archiveRole
                    && $0.runID == bundle.runID
                    && $0.relativePath == artifact.relativePath
                    && $0.sha256 == artifact.sha256
                    && $0.byteLength == artifact.byteLength
            }
            if matches.count != 1 {
                issues.append(.init(code: .chainEntryMismatch, detail: "W38 projection for \(artifactRole.rawValue) does not exactly match materialized bytes"))
            }
        }
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

    private static func computeRoot(_ bundle: AnalysisPhysicalCaptureArtifactBundle) throws -> String {
        let records = bundle.artifacts.map {
            RootRecord(role: $0.role, relativePath: $0.relativePath, sha256: $0.sha256, byteLength: $0.byteLength)
        }.sorted { lhs, rhs in
            let l = "\(lhs.role.rawValue)|\(lhs.relativePath)|\(lhs.sha256)|\(lhs.byteLength)"
            let r = "\(rhs.role.rawValue)|\(rhs.relativePath)|\(rhs.sha256)|\(rhs.byteLength)"
            return l < r
        }
        let payload = RootPayload(
            schemaVersion: 1,
            runID: bundle.runID,
            workloadExecutionID: bundle.workloadExecutionID,
            artifacts: records
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return AnalysisDeviceWorkloadSHA256.hexDigest(try encoder.encode(payload))
    }

    private static func safeRelativePath(_ value: String) -> Bool {
        guard !value.isEmpty,
              value == value.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.hasPrefix("/"),
              !value.hasPrefix("\\"),
              !value.contains("\\"),
              !value.contains("//") else { return false }
        return value.split(separator: "/", omittingEmptySubsequences: false).allSatisfy {
            !$0.isEmpty && $0 != "." && $0 != ".."
        }
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 48...57, 65...70, 97...102:
                return true
            default:
                return false
            }
        }
    }
}
