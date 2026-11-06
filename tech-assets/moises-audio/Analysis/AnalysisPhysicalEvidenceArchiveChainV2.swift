import Foundation

/// W38 extends the W27 tamper-evident archive without invalidating the legacy
/// W27 schema. The extension root anchors the exact W27 root and then requires
/// the post-W27 W35-W37 capture-chain artifacts for every predeclared W24 run.
public enum AnalysisPhysicalEvidenceChainArtifactRole: String, Codable, CaseIterable, Sendable {
    case w35RuntimeAlgorithmEvidence = "W35_RUNTIME_ALGORITHM_EVIDENCE"
    case w36CurrentRuntimeEvidence = "W36_CURRENT_RUNTIME_EVIDENCE"
    case w37CapturePlan = "W37_CAPTURE_PLAN"
    case w37ExecutionIntegrityEvidence = "W37_EXECUTION_INTEGRITY_EVIDENCE"
    case w37ExecutionIntegrityReport = "W37_EXECUTION_INTEGRITY_REPORT"

    public static let requiredPerRunRoles: Set<Self> = Set(Self.allCases)
}

/// Archive-facing W36 provenance. This is intentionally smaller than the live
/// execution object but captures the facts that distinguish the current W36
/// chunked product path from the historical W25 materialized runner.
public struct AnalysisCurrentDeviceWorkloadArchiveEvidence: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let runID: String
    public let performanceEvidenceRunID: String
    public let runKind: AnalysisDevicePerformanceRunKind
    public let workloadExecutionID: String
    public let sourceMemoryContract: AnalysisChunkedSourceMemoryContract
    public let boundedSourceContractAccepted: Bool
    public let observedSourceChunkCount: Int
    public let observedSourceSampleCount: Int64
    public let outcome: AnalysisDeviceWorkloadExecutionOutcome
    public let snapshotSHA256: String?
    public let algorithmRunID: String?
    public let algorithmWorkloadExecutionID: String?

    public init(
        schemaVersion: Int = 1,
        runID: String,
        performanceEvidenceRunID: String,
        runKind: AnalysisDevicePerformanceRunKind,
        workloadExecutionID: String,
        sourceMemoryContract: AnalysisChunkedSourceMemoryContract,
        boundedSourceContractAccepted: Bool,
        observedSourceChunkCount: Int,
        observedSourceSampleCount: Int64,
        outcome: AnalysisDeviceWorkloadExecutionOutcome,
        snapshotSHA256: String?,
        algorithmRunID: String?,
        algorithmWorkloadExecutionID: String?
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.performanceEvidenceRunID = performanceEvidenceRunID
        self.runKind = runKind
        self.workloadExecutionID = workloadExecutionID
        self.sourceMemoryContract = sourceMemoryContract
        self.boundedSourceContractAccepted = boundedSourceContractAccepted
        self.observedSourceChunkCount = observedSourceChunkCount
        self.observedSourceSampleCount = observedSourceSampleCount
        self.outcome = outcome
        self.snapshotSHA256 = snapshotSHA256?.lowercased()
        self.algorithmRunID = algorithmRunID
        self.algorithmWorkloadExecutionID = algorithmWorkloadExecutionID
    }
}

public enum AnalysisCurrentDeviceWorkloadArchiveEvidenceBuilderError: Error, Equatable, Sendable {
    case missingAlgorithmCompanion
    case missingSourceInputContract
}

public enum AnalysisCurrentDeviceWorkloadArchiveEvidenceBuilder {
    public static func build(
        execution: AnalysisCurrentDeviceWorkloadExecution
    ) throws -> AnalysisCurrentDeviceWorkloadArchiveEvidence {
        guard let algorithm = execution.algorithmEvidence else {
            throw AnalysisCurrentDeviceWorkloadArchiveEvidenceBuilderError.missingAlgorithmCompanion
        }
        guard let sourceContract = algorithm.sourceInputContract else {
            throw AnalysisCurrentDeviceWorkloadArchiveEvidenceBuilderError.missingSourceInputContract
        }
        return .init(
            runID: execution.receipt.runID,
            performanceEvidenceRunID: execution.receipt.performanceEvidenceRunID,
            runKind: execution.receipt.runKind,
            workloadExecutionID: execution.receipt.executionID,
            sourceMemoryContract: sourceContract,
            boundedSourceContractAccepted: execution.boundedSourceContractAccepted,
            observedSourceChunkCount: execution.observedSourceChunkCount,
            observedSourceSampleCount: execution.observedSourceSampleCount,
            outcome: execution.outcome,
            snapshotSHA256: execution.receipt.snapshotSHA256,
            algorithmRunID: algorithm.runID,
            algorithmWorkloadExecutionID: algorithm.workloadExecutionID
        )
    }
}

public struct AnalysisPhysicalEvidenceChainEntry: Codable, Equatable, Sendable {
    public let role: AnalysisPhysicalEvidenceChainArtifactRole
    public let relativePath: String
    public let sha256: String
    public let byteLength: UInt64
    public let runID: String

    public init(
        role: AnalysisPhysicalEvidenceChainArtifactRole,
        relativePath: String,
        sha256: String,
        byteLength: UInt64,
        runID: String
    ) {
        self.role = role
        self.relativePath = relativePath
        self.sha256 = sha256.lowercased()
        self.byteLength = byteLength
        self.runID = runID
    }
}

public struct AnalysisPhysicalEvidenceArchiveChainPolicy: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let policyID: String
    public let authority: String
    public let approvalReference: String
    public let expectedArchiveID: String
    public let legacyW27PolicyID: String
    public let legacyW27ArchiveID: String
    public let legacyW27RootSHA256: String
    public let binding: AnalysisPhysicalEvidenceArchiveBinding
    public let requiredRunIDs: [String]

    public init(
        schemaVersion: Int = 2,
        policyID: String,
        authority: String,
        approvalReference: String,
        expectedArchiveID: String,
        legacyW27PolicyID: String,
        legacyW27ArchiveID: String,
        legacyW27RootSHA256: String,
        binding: AnalysisPhysicalEvidenceArchiveBinding,
        requiredRunIDs: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.policyID = policyID
        self.authority = authority
        self.approvalReference = approvalReference
        self.expectedArchiveID = expectedArchiveID
        self.legacyW27PolicyID = legacyW27PolicyID
        self.legacyW27ArchiveID = legacyW27ArchiveID
        self.legacyW27RootSHA256 = legacyW27RootSHA256.lowercased()
        self.binding = binding
        self.requiredRunIDs = requiredRunIDs
    }
}

public struct AnalysisPhysicalEvidenceArchiveChainManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let archiveID: String
    public let policyID: String
    public let legacyW27ArchiveID: String
    public let legacyW27RootSHA256: String
    public let binding: AnalysisPhysicalEvidenceArchiveBinding
    public let entries: [AnalysisPhysicalEvidenceChainEntry]
    public let declaredRootSHA256: String

    public init(
        schemaVersion: Int = 2,
        archiveID: String,
        policyID: String,
        legacyW27ArchiveID: String,
        legacyW27RootSHA256: String,
        binding: AnalysisPhysicalEvidenceArchiveBinding,
        entries: [AnalysisPhysicalEvidenceChainEntry],
        declaredRootSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.archiveID = archiveID
        self.policyID = policyID
        self.legacyW27ArchiveID = legacyW27ArchiveID
        self.legacyW27RootSHA256 = legacyW27RootSHA256.lowercased()
        self.binding = binding
        self.entries = entries
        self.declaredRootSHA256 = declaredRootSHA256.lowercased()
    }
}

public enum AnalysisPhysicalEvidenceArchiveChainIssueCode: String, Codable, Hashable, Sendable {
    case invalidPolicy = "INVALID_W38_ARCHIVE_POLICY"
    case legacyArchiveNotReady = "LEGACY_W27_ARCHIVE_NOT_READY"
    case invalidManifest = "INVALID_W38_ARCHIVE_MANIFEST"
    case bindingMismatch = "W38_ARCHIVE_BINDING_MISMATCH"
    case invalidRunInventory = "W38_INVALID_RUN_INVENTORY"
    case unsafePath = "W38_UNSAFE_ARCHIVE_PATH"
    case invalidEntry = "W38_INVALID_ARCHIVE_ENTRY"
    case duplicatePath = "W38_DUPLICATE_ARCHIVE_PATH"
    case missingRunArtifact = "W38_MISSING_RUN_ARTIFACT"
    case duplicateRunArtifact = "W38_DUPLICATE_RUN_ARTIFACT"
    case unexpectedRunArtifact = "W38_UNEXPECTED_RUN_ARTIFACT"
    case missingArtifactBytes = "W38_MISSING_ARTIFACT_BYTES"
    case unexpectedArtifactBytes = "W38_UNEXPECTED_ARTIFACT_BYTES"
    case artifactLengthMismatch = "W38_ARTIFACT_LENGTH_MISMATCH"
    case artifactHashMismatch = "W38_ARTIFACT_HASH_MISMATCH"
    case artifactContentMismatch = "W38_ARTIFACT_CONTENT_MISMATCH"
    case captureChainMismatch = "W38_CAPTURE_CHAIN_MISMATCH"
    case reusedExecution = "W38_REUSED_W36_EXECUTION"
    case archiveRootMismatch = "W38_ARCHIVE_ROOT_MISMATCH"
}

public struct AnalysisPhysicalEvidenceArchiveChainIssue: Codable, Equatable, Sendable {
    public let code: AnalysisPhysicalEvidenceArchiveChainIssueCode
    public let role: AnalysisPhysicalEvidenceChainArtifactRole?
    public let relativePath: String?
    public let runID: String?
    public let detail: String

    public init(
        code: AnalysisPhysicalEvidenceArchiveChainIssueCode,
        role: AnalysisPhysicalEvidenceChainArtifactRole? = nil,
        relativePath: String? = nil,
        runID: String? = nil,
        detail: String
    ) {
        self.code = code
        self.role = role
        self.relativePath = relativePath
        self.runID = runID
        self.detail = detail
    }
}

public enum AnalysisPhysicalEvidenceArchiveChainStatus: String, Codable, Sendable {
    case invalidPolicy = "INVALID_W38_ARCHIVE_POLICY"
    case legacyArchiveNotReady = "LEGACY_W27_ARCHIVE_NOT_READY"
    case incompleteOrTampered = "W38_ARCHIVE_INCOMPLETE_OR_TAMPERED"
    case rootConsistentPendingHQ = "W38_CAPTURE_CHAIN_ROOT_CONSISTENT_PENDING_HQ"
}

public struct AnalysisPhysicalEvidenceArchiveChainReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let archiveID: String
    public let status: AnalysisPhysicalEvidenceArchiveChainStatus
    public let computedRootSHA256: String?
    public let entryCount: Int
    public let runCount: Int
    public let issues: [AnalysisPhysicalEvidenceArchiveChainIssue]
    public let limitations: [String]

    public init(
        schemaVersion: Int = 2,
        archiveID: String,
        status: AnalysisPhysicalEvidenceArchiveChainStatus,
        computedRootSHA256: String?,
        entryCount: Int,
        runCount: Int,
        issues: [AnalysisPhysicalEvidenceArchiveChainIssue],
        limitations: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.archiveID = archiveID
        self.status = status
        self.computedRootSHA256 = computedRootSHA256
        self.entryCount = entryCount
        self.runCount = runCount
        self.issues = issues
        self.limitations = limitations
    }
}

public enum AnalysisPhysicalEvidenceArchiveChainBuilder {
    public static func entry(
        role: AnalysisPhysicalEvidenceChainArtifactRole,
        relativePath: String,
        runID: String,
        bytes: Data
    ) -> AnalysisPhysicalEvidenceChainEntry {
        .init(
            role: role,
            relativePath: relativePath,
            sha256: AnalysisDeviceWorkloadSHA256.hexDigest(bytes),
            byteLength: UInt64(bytes.count),
            runID: runID
        )
    }

    public static func manifest(
        archiveID: String,
        policyID: String,
        legacyW27ArchiveID: String,
        legacyW27RootSHA256: String,
        binding: AnalysisPhysicalEvidenceArchiveBinding,
        entries: [AnalysisPhysicalEvidenceChainEntry]
    ) throws -> AnalysisPhysicalEvidenceArchiveChainManifest {
        let provisional = AnalysisPhysicalEvidenceArchiveChainManifest(
            archiveID: archiveID,
            policyID: policyID,
            legacyW27ArchiveID: legacyW27ArchiveID,
            legacyW27RootSHA256: legacyW27RootSHA256,
            binding: binding,
            entries: entries,
            declaredRootSHA256: String(repeating: "0", count: 64)
        )
        let root = try AnalysisPhysicalEvidenceArchiveChainRoot.compute(provisional)
        return .init(
            archiveID: archiveID,
            policyID: policyID,
            legacyW27ArchiveID: legacyW27ArchiveID,
            legacyW27RootSHA256: legacyW27RootSHA256,
            binding: binding,
            entries: entries,
            declaredRootSHA256: root
        )
    }
}

public enum AnalysisPhysicalEvidenceArchiveChainRoot {
    private struct RootPayload: Codable {
        let schemaVersion: Int
        let archiveID: String
        let policyID: String
        let legacyW27ArchiveID: String
        let legacyW27RootSHA256: String
        let binding: AnalysisPhysicalEvidenceArchiveBinding
        let entries: [AnalysisPhysicalEvidenceChainEntry]
    }

    public static func compute(_ manifest: AnalysisPhysicalEvidenceArchiveChainManifest) throws -> String {
        let entries = manifest.entries.sorted {
            let lhs = "\($0.role.rawValue)|\($0.runID)|\($0.relativePath)|\($0.sha256)|\($0.byteLength)"
            let rhs = "\($1.role.rawValue)|\($1.runID)|\($1.relativePath)|\($1.sha256)|\($1.byteLength)"
            return lhs < rhs
        }
        let payload = RootPayload(
            schemaVersion: manifest.schemaVersion,
            archiveID: manifest.archiveID,
            policyID: manifest.policyID,
            legacyW27ArchiveID: manifest.legacyW27ArchiveID,
            legacyW27RootSHA256: manifest.legacyW27RootSHA256,
            binding: manifest.binding,
            entries: entries
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return AnalysisDeviceWorkloadSHA256.hexDigest(try encoder.encode(payload))
    }
}

public enum AnalysisPhysicalEvidenceArchiveChainValidator {
    public static let requiredAuthority = "HQ_LATE_INTEGRATION"
    public static let limitations = [
        "W38 is tamper-evident chaining, not a signature, Secure Enclave proof, Apple attestation, trusted timestamp, or hardware-origin guarantee.",
        "The W38 root is meaningful only after HQ independently anchors both the legacy W27 root and this extension root.",
        "BOUNDED_PULL_CONTRACT remains declarative; physical W23 RSS/physical-footprint telemetry remains authoritative for decoder hidden-buffer behavior.",
        "A root-consistent W38 archive remains NON_PARITY until HQ executes the physical-iPhone and W24 repeated acceptance gates."
    ]

    public static func validate(
        manifest: AnalysisPhysicalEvidenceArchiveChainManifest,
        policy: AnalysisPhysicalEvidenceArchiveChainPolicy,
        legacyManifest: AnalysisPhysicalEvidenceArchiveManifest,
        legacyPolicy: AnalysisPhysicalEvidenceArchivePolicy,
        legacyReport: AnalysisPhysicalEvidenceArchiveReport,
        artifactBytesByPath: [String: Data],
        performanceProfile: AnalysisDevicePerformanceAcceptanceProfile,
        workloadPolicy: AnalysisDeviceWorkloadPolicy
    ) -> AnalysisPhysicalEvidenceArchiveChainReport {
        var issues: [AnalysisPhysicalEvidenceArchiveChainIssue] = []
        validatePolicy(policy, performanceProfile: performanceProfile, workloadPolicy: workloadPolicy, issues: &issues)
        if issues.contains(where: { $0.code == .invalidPolicy }) {
            return report(manifest, policy, status: .invalidPolicy, computedRoot: nil, issues: issues)
        }

        let legacyRoot = legacyReport.computedRootSHA256?.lowercased()
        if legacyReport.status != .rootConsistentPendingHQ
            || legacyManifest.archiveID != policy.legacyW27ArchiveID
            || legacyPolicy.policyID != policy.legacyW27PolicyID
            || legacyManifest.policyID != legacyPolicy.policyID
            || legacyManifest.binding != policy.binding
            || legacyPolicy.binding != policy.binding
            || legacyManifest.declaredRootSHA256.lowercased() != policy.legacyW27RootSHA256
            || legacyRoot != policy.legacyW27RootSHA256 {
            issues.append(.init(code: .legacyArchiveNotReady, detail: "W38 requires the exact root-consistent W27 archive/policy/root/binding before post-W27 artifacts can be chained"))
            return report(manifest, policy, status: .legacyArchiveNotReady, computedRoot: nil, issues: issues)
        }

        if manifest.schemaVersion != 2
            || manifest.archiveID != policy.expectedArchiveID
            || manifest.policyID != policy.policyID
            || manifest.legacyW27ArchiveID != policy.legacyW27ArchiveID
            || manifest.legacyW27RootSHA256.lowercased() != policy.legacyW27RootSHA256
            || !isSHA256(manifest.declaredRootSHA256) {
            issues.append(.init(code: .invalidManifest, detail: "W38 manifest must use schema 2 and bind the approved archive/policy/legacy-root identifiers"))
        }
        if manifest.binding != policy.binding {
            issues.append(.init(code: .bindingMismatch, detail: "W38 manifest binding must exactly equal the approved W27/W38 binding"))
        }

        validateEntries(manifest.entries, requiredRunIDs: policy.requiredRunIDs, issues: &issues)
        validateArtifactBytes(manifest.entries, artifactBytesByPath: artifactBytesByPath, issues: &issues)
        validateCaptureChain(
            entries: manifest.entries,
            bytesByPath: artifactBytesByPath,
            policy: policy,
            performanceProfile: performanceProfile,
            workloadPolicy: workloadPolicy,
            issues: &issues
        )

        let computedRoot = try? AnalysisPhysicalEvidenceArchiveChainRoot.compute(manifest)
        if computedRoot == nil || computedRoot != manifest.declaredRootSHA256.lowercased() {
            issues.append(.init(code: .archiveRootMismatch, detail: "declared W38 root does not match the deterministic canonical extension root"))
        }

        issues.sort(by: issueOrder)
        return report(
            manifest,
            policy,
            status: issues.isEmpty ? .rootConsistentPendingHQ : .incompleteOrTampered,
            computedRoot: computedRoot,
            issues: issues
        )
    }

    private static func validatePolicy(
        _ policy: AnalysisPhysicalEvidenceArchiveChainPolicy,
        performanceProfile: AnalysisDevicePerformanceAcceptanceProfile,
        workloadPolicy: AnalysisDeviceWorkloadPolicy,
        issues: inout [AnalysisPhysicalEvidenceArchiveChainIssue]
    ) {
        let requiredText = [
            policy.policyID, policy.approvalReference, policy.expectedArchiveID,
            policy.legacyW27PolicyID, policy.legacyW27ArchiveID,
            policy.binding.manifestID, policy.binding.coveragePolicyID,
            policy.binding.selectionPolicyID, policy.binding.performanceProfileID,
            policy.binding.batchID, policy.binding.workloadApprovalReference,
            policy.binding.buildIdentity, policy.binding.deviceModel, policy.binding.osVersion
        ]
        if policy.schemaVersion != 2
            || policy.authority != requiredAuthority
            || requiredText.contains(where: { trimmed($0).isEmpty })
            || !isSHA256(policy.legacyW27RootSHA256)
            || !isSHA256(policy.binding.manifestSHA256) {
            issues.append(.init(code: .invalidPolicy, detail: "W38 policy requires schema 2, HQ authority, complete bindings, and valid W27/manifest SHA-256 values"))
        }

        let requiredRuns = Set(policy.requiredRunIDs)
        let plannedRuns = performanceProfile.plannedRuns.map(\.runID)
        if policy.requiredRunIDs.isEmpty
            || requiredRuns.count != policy.requiredRunIDs.count
            || policy.requiredRunIDs.contains(where: { trimmed($0).isEmpty })
            || requiredRuns != Set(plannedRuns)
            || plannedRuns.count != Set(plannedRuns).count {
            issues.append(.init(code: .invalidRunInventory, detail: "W38 required runs must exactly equal the unique W24 predeclared run inventory"))
        }

        let binding = policy.binding
        if binding.performanceProfileID != performanceProfile.profileID
            || binding.batchID != performanceProfile.expectedBatchID
            || binding.manifestID != performanceProfile.expectedManifestID
            || binding.manifestSHA256 != performanceProfile.expectedManifestSHA256.lowercased()
            || binding.manifestID != workloadPolicy.manifestID
            || binding.manifestSHA256 != workloadPolicy.manifestSHA256.lowercased()
            || binding.workloadApprovalReference != workloadPolicy.approvalReference
            || binding.buildIdentity != workloadPolicy.identity.buildIdentity
            || binding.deviceModel != performanceProfile.expectedDeviceModel
            || binding.osVersion != performanceProfile.expectedOSVersion {
            issues.append(.init(code: .bindingMismatch, detail: "W38 binding must agree with W24 performance and W25 workload policy identities"))
        }
    }

    private static func validateEntries(
        _ entries: [AnalysisPhysicalEvidenceChainEntry],
        requiredRunIDs: [String],
        issues: inout [AnalysisPhysicalEvidenceArchiveChainIssue]
    ) {
        let requiredRuns = Set(requiredRunIDs)
        var paths = Set<String>()
        var counts: [String: [AnalysisPhysicalEvidenceChainArtifactRole: Int]] = [:]

        for entry in entries {
            if !safeRelativePath(entry.relativePath) {
                issues.append(.init(code: .unsafePath, role: entry.role, relativePath: entry.relativePath, runID: entry.runID, detail: "W38 paths must be normalized relative paths without traversal"))
            }
            if !paths.insert(entry.relativePath).inserted {
                issues.append(.init(code: .duplicatePath, role: entry.role, relativePath: entry.relativePath, runID: entry.runID, detail: "W38 artifact path appears more than once"))
            }
            if trimmed(entry.runID).isEmpty || !isSHA256(entry.sha256) || entry.byteLength == 0 {
                issues.append(.init(code: .invalidEntry, role: entry.role, relativePath: entry.relativePath, runID: entry.runID, detail: "W38 entries require a nonempty run ID, nonzero bytes and valid SHA-256"))
            }
            if !requiredRuns.contains(entry.runID) {
                issues.append(.init(code: .unexpectedRunArtifact, role: entry.role, relativePath: entry.relativePath, runID: entry.runID, detail: "W38 artifact run ID is not in the W24 inventory"))
            }
            var runCounts = counts[entry.runID] ?? [:]
            runCounts[entry.role, default: 0] += 1
            counts[entry.runID] = runCounts
        }

        for runID in requiredRunIDs.sorted() {
            let runCounts = counts[runID] ?? [:]
            for role in AnalysisPhysicalEvidenceChainArtifactRole.requiredPerRunRoles.sorted(by: { $0.rawValue < $1.rawValue }) {
                let count = runCounts[role] ?? 0
                if count == 0 {
                    issues.append(.init(code: .missingRunArtifact, role: role, runID: runID, detail: "required W35-W37 per-run chain artifact is missing"))
                } else if count > 1 {
                    issues.append(.init(code: .duplicateRunArtifact, role: role, runID: runID, detail: "W35-W37 per-run chain role appears more than once"))
                }
            }
        }
    }

    private static func validateArtifactBytes(
        _ entries: [AnalysisPhysicalEvidenceChainEntry],
        artifactBytesByPath: [String: Data],
        issues: inout [AnalysisPhysicalEvidenceArchiveChainIssue]
    ) {
        let declared = Set(entries.map(\.relativePath))
        let observed = Set(artifactBytesByPath.keys)
        for path in declared.subtracting(observed).sorted() {
            issues.append(.init(code: .missingArtifactBytes, relativePath: path, detail: "declared W38 artifact bytes are missing"))
        }
        for path in observed.subtracting(declared).sorted() {
            issues.append(.init(code: .unexpectedArtifactBytes, relativePath: path, detail: "verification input contains an unmanifested W38 artifact"))
        }
        for entry in entries {
            guard let bytes = artifactBytesByPath[entry.relativePath] else { continue }
            if UInt64(bytes.count) != entry.byteLength {
                issues.append(.init(code: .artifactLengthMismatch, role: entry.role, relativePath: entry.relativePath, runID: entry.runID, detail: "W38 artifact byte length differs from the manifest"))
            }
            if AnalysisDeviceWorkloadSHA256.hexDigest(bytes) != entry.sha256.lowercased() {
                issues.append(.init(code: .artifactHashMismatch, role: entry.role, relativePath: entry.relativePath, runID: entry.runID, detail: "W38 artifact SHA-256 differs from the manifest"))
            }
        }
    }

    private static func validateCaptureChain(
        entries: [AnalysisPhysicalEvidenceChainEntry],
        bytesByPath: [String: Data],
        policy: AnalysisPhysicalEvidenceArchiveChainPolicy,
        performanceProfile: AnalysisDevicePerformanceAcceptanceProfile,
        workloadPolicy: AnalysisDeviceWorkloadPolicy,
        issues: inout [AnalysisPhysicalEvidenceArchiveChainIssue]
    ) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let plannedByID = Dictionary(uniqueKeysWithValues: performanceProfile.plannedRuns.map { ($0.runID, $0) })

        var algorithms: [String: AnalysisDeviceAlgorithmExecutionEvidence] = [:]
        var runtimes: [String: AnalysisCurrentDeviceWorkloadArchiveEvidence] = [:]
        var plans: [String: AnalysisDeviceCapturePlan] = [:]
        var integrityEvidence: [String: AnalysisDeviceCaptureExecutionIntegrityEvidence] = [:]
        var integrityReports: [String: AnalysisDeviceCaptureExecutionIntegrityReport] = [:]

        for entry in entries {
            guard let bytes = bytesByPath[entry.relativePath] else { continue }
            do {
                switch entry.role {
                case .w35RuntimeAlgorithmEvidence:
                    algorithms[entry.runID] = try decoder.decode(AnalysisDeviceAlgorithmExecutionEvidence.self, from: bytes)
                case .w36CurrentRuntimeEvidence:
                    runtimes[entry.runID] = try decoder.decode(AnalysisCurrentDeviceWorkloadArchiveEvidence.self, from: bytes)
                case .w37CapturePlan:
                    plans[entry.runID] = try decoder.decode(AnalysisDeviceCapturePlan.self, from: bytes)
                case .w37ExecutionIntegrityEvidence:
                    integrityEvidence[entry.runID] = try decoder.decode(AnalysisDeviceCaptureExecutionIntegrityEvidence.self, from: bytes)
                case .w37ExecutionIntegrityReport:
                    integrityReports[entry.runID] = try decoder.decode(AnalysisDeviceCaptureExecutionIntegrityReport.self, from: bytes)
                }
            } catch {
                issues.append(.init(code: .artifactContentMismatch, role: entry.role, relativePath: entry.relativePath, runID: entry.runID, detail: "W38 artifact cannot be decoded for its declared role: \(error)"))
            }
        }

        var executionOwner: [String: String] = [:]
        for runID in policy.requiredRunIDs.sorted() {
            guard let planned = plannedByID[runID],
                  let algorithm = algorithms[runID],
                  let runtime = runtimes[runID],
                  let plan = plans[runID],
                  let integrity = integrityEvidence[runID],
                  let archivedIntegrityReport = integrityReports[runID] else { continue }

            let planReport = AnalysisDeviceCapturePlanValidator.validate(
                plan,
                workloadPolicy: workloadPolicy,
                performanceProfile: performanceProfile
            )
            let computedIntegrityReport = AnalysisDeviceCaptureExecutionIntegrityValidator.validate(integrity)

            var chainValid = true
            chainValid = chainValid && planReport.valid
            chainValid = chainValid && computedIntegrityReport.valid
            chainValid = chainValid && archivedIntegrityReport == computedIntegrityReport
            chainValid = chainValid && algorithm.schemaVersion == 1
            chainValid = chainValid && runtime.schemaVersion == 1
            chainValid = chainValid && algorithm.runID == runID
            chainValid = chainValid && algorithm.performanceEvidenceRunID == runID
            chainValid = chainValid && runtime.runID == runID
            chainValid = chainValid && runtime.performanceEvidenceRunID == runID
            chainValid = chainValid && plan.runID == runID
            chainValid = chainValid && integrity.runID == runID
            chainValid = chainValid && planned.runKind == algorithm.runKind
            chainValid = chainValid && planned.runKind == runtime.runKind
            chainValid = chainValid && planned.runKind == plan.runKind
            chainValid = chainValid && planned.runKind == integrity.runKind
            chainValid = chainValid && algorithm.workloadExecutionID == runtime.workloadExecutionID
            chainValid = chainValid && algorithm.workloadExecutionID == integrity.workloadExecutionID
            chainValid = chainValid && runtime.algorithmWorkloadExecutionID == runtime.workloadExecutionID
            chainValid = chainValid && runtime.algorithmRunID == runID
            chainValid = chainValid && algorithm.sourceInputContract == .boundedPull
            chainValid = chainValid && runtime.sourceMemoryContract == .boundedPull
            chainValid = chainValid && runtime.boundedSourceContractAccepted
            chainValid = chainValid && integrity.sourceMemoryContract == .boundedPull
            chainValid = chainValid && runtime.observedSourceChunkCount > 0
            chainValid = chainValid && runtime.observedSourceSampleCount > 0
            chainValid = chainValid && integrity.observedSourceSampleCount == runtime.observedSourceSampleCount
            chainValid = chainValid && integrity.workloadOutcome == runtime.outcome
            chainValid = chainValid && algorithm.snapshotSHA256 == runtime.snapshotSHA256
            chainValid = chainValid && algorithm.source == plan.source
            chainValid = chainValid && algorithm.identity == plan.identity
            chainValid = chainValid && algorithm.manifestID == plan.manifestID
            chainValid = chainValid && algorithm.manifestSHA256 == plan.manifestSHA256.lowercased()
            chainValid = chainValid && plan.manifestID == policy.binding.manifestID
            chainValid = chainValid && plan.manifestSHA256.lowercased() == policy.binding.manifestSHA256
            chainValid = chainValid && integrity.performanceRunID == runID
            chainValid = chainValid && integrity.workloadRunID == runID
            chainValid = chainValid && integrity.algorithmRunID == runID
            chainValid = chainValid && integrity.algorithmWorkloadExecutionID == runtime.workloadExecutionID
            chainValid = chainValid && integrity.requestedSampleIntervalSeconds == plan.telemetrySampleIntervalSeconds

            switch planned.runKind {
            case .completeAnalysis:
                chainValid = chainValid && runtime.outcome == .completed
                chainValid = chainValid && runtime.snapshotSHA256 != nil
                chainValid = chainValid && algorithm.captureState == .finalized
                chainValid = chainValid && algorithm.runtimeIdentity?.algorithmSchemaID == AnalysisRuntimeAlgorithmIdentity.currentAlgorithmSchemaID
                chainValid = chainValid && integrity.cancellationRequestedOffsetSeconds == nil
                chainValid = chainValid && integrity.cancellationObservedOffsetSeconds == nil
            case .cancellationProbe:
                chainValid = chainValid && runtime.outcome == .cancelled
                chainValid = chainValid && runtime.snapshotSHA256 == nil
                chainValid = chainValid && algorithm.captureState == .cancelledBeforeFinalization
                chainValid = chainValid && integrity.cancellationRequestedOffsetSeconds != nil
                chainValid = chainValid && integrity.cancellationObservedOffsetSeconds != nil
            }

            if !chainValid {
                issues.append(.init(code: .captureChainMismatch, runID: runID, detail: "W35 algorithm, W36 current runtime and W37 plan/integrity artifacts do not form one exact bounded-pull execution chain"))
            }

            if let owner = executionOwner[runtime.workloadExecutionID], owner != runID {
                issues.append(.init(code: .reusedExecution, runID: runID, detail: "W36 execution ID \(runtime.workloadExecutionID) is already owned by run \(owner)"))
            } else {
                executionOwner[runtime.workloadExecutionID] = runID
            }
        }

        let batchIssues = AnalysisDeviceCaptureExecutionIntegrityValidator.validateBatch(Array(integrityEvidence.values))
        for issue in batchIssues {
            issues.append(.init(code: issue.code == .reusedExecution ? .reusedExecution : .captureChainMismatch, detail: "W37 batch integrity: \(issue.code.rawValue): \(issue.detail)"))
        }
    }

    private static func report(
        _ manifest: AnalysisPhysicalEvidenceArchiveChainManifest,
        _ policy: AnalysisPhysicalEvidenceArchiveChainPolicy,
        status: AnalysisPhysicalEvidenceArchiveChainStatus,
        computedRoot: String?,
        issues: [AnalysisPhysicalEvidenceArchiveChainIssue]
    ) -> AnalysisPhysicalEvidenceArchiveChainReport {
        .init(
            archiveID: manifest.archiveID,
            status: status,
            computedRootSHA256: computedRoot,
            entryCount: manifest.entries.count,
            runCount: Set(policy.requiredRunIDs).count,
            issues: issues.sorted(by: issueOrder),
            limitations: limitations
        )
    }

    private static func safeRelativePath(_ value: String) -> Bool {
        let t = trimmed(value)
        guard !t.isEmpty, t == value, !value.hasPrefix("/"), !value.hasPrefix("\\") else { return false }
        let normalized = value.replacingOccurrences(of: "\\", with: "/")
        guard normalized == value, !normalized.contains("//") else { return false }
        return normalized.split(separator: "/", omittingEmptySubsequences: false).allSatisfy {
            $0 != "." && $0 != ".." && !$0.isEmpty
        }
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 48...57, 65...70, 97...102: return true
            default: return false
            }
        }
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func issueOrder(
        _ lhs: AnalysisPhysicalEvidenceArchiveChainIssue,
        _ rhs: AnalysisPhysicalEvidenceArchiveChainIssue
    ) -> Bool {
        let l = "\(lhs.code.rawValue)|\(lhs.role?.rawValue ?? "")|\(lhs.runID ?? "")|\(lhs.relativePath ?? "")|\(lhs.detail)"
        let r = "\(rhs.code.rawValue)|\(rhs.role?.rawValue ?? "")|\(rhs.runID ?? "")|\(rhs.relativePath ?? "")|\(rhs.detail)"
        return l < r
    }
}

public enum AnalysisPhysicalEvidenceArchiveChainCodec {
    public static func encodePolicy(_ value: AnalysisPhysicalEvidenceArchiveChainPolicy) throws -> Data { try encoder().encode(value) }
    public static func decodePolicy(_ data: Data) throws -> AnalysisPhysicalEvidenceArchiveChainPolicy { try decoder().decode(AnalysisPhysicalEvidenceArchiveChainPolicy.self, from: data) }
    public static func encodeManifest(_ value: AnalysisPhysicalEvidenceArchiveChainManifest) throws -> Data { try encoder().encode(value) }
    public static func decodeManifest(_ data: Data) throws -> AnalysisPhysicalEvidenceArchiveChainManifest { try decoder().decode(AnalysisPhysicalEvidenceArchiveChainManifest.self, from: data) }
    public static func encodeReport(_ value: AnalysisPhysicalEvidenceArchiveChainReport) throws -> Data { try encoder().encode(value) }
    public static func decodeReport(_ data: Data) throws -> AnalysisPhysicalEvidenceArchiveChainReport { try decoder().decode(AnalysisPhysicalEvidenceArchiveChainReport.self, from: data) }
    public static func encodeCurrentRuntimeEvidence(_ value: AnalysisCurrentDeviceWorkloadArchiveEvidence) throws -> Data { try encoder().encode(value) }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
