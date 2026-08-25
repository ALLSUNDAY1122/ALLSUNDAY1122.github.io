import Foundation

public enum AnalysisPhysicalCaptureArtifactRole: String, Codable, CaseIterable, Sendable {
    case w23PerformanceEvidence = "W23_PERFORMANCE_EVIDENCE"
    case w23PerformanceValidation = "W23_PERFORMANCE_VALIDATION"
    case w25WorkloadReceipt = "W25_WORKLOAD_RECEIPT"
    case w25WorkloadValidation = "W25_WORKLOAD_VALIDATION"
    case w35AlgorithmEvidence = "W35_ALGORITHM_EVIDENCE"
    case w36CurrentRuntimeEvidence = "W36_CURRENT_RUNTIME_EVIDENCE"
    case w37CapturePlan = "W37_CAPTURE_PLAN"
    case w37ExecutionIntegrityEvidence = "W37_EXECUTION_INTEGRITY_EVIDENCE"
    case w37ExecutionIntegrityReport = "W37_EXECUTION_INTEGRITY_REPORT"
}

public struct AnalysisPhysicalCaptureArtifact: Equatable, Sendable {
    public let role: AnalysisPhysicalCaptureArtifactRole
    public let relativePath: String
    public let bytes: Data
    public let sha256: String
    public let byteLength: UInt64

    public init(role: AnalysisPhysicalCaptureArtifactRole, relativePath: String, bytes: Data) {
        self.role = role
        self.relativePath = relativePath
        self.bytes = bytes
        self.sha256 = AnalysisDeviceWorkloadSHA256.hexDigest(bytes)
        self.byteLength = UInt64(bytes.count)
    }
}

public struct AnalysisPhysicalCaptureArtifactBundle: Equatable, Sendable {
    public let schemaVersion: Int
    public let runID: String
    public let workloadExecutionID: String
    public let bundleRootSHA256: String
    public let artifacts: [AnalysisPhysicalCaptureArtifact]
    public let legacyW27Entries: [AnalysisPhysicalEvidenceArchiveEntry]
    public let w38Entries: [AnalysisPhysicalEvidenceChainEntry]

    public init(
        schemaVersion: Int = 1,
        runID: String,
        workloadExecutionID: String,
        bundleRootSHA256: String,
        artifacts: [AnalysisPhysicalCaptureArtifact],
        legacyW27Entries: [AnalysisPhysicalEvidenceArchiveEntry],
        w38Entries: [AnalysisPhysicalEvidenceChainEntry]
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.workloadExecutionID = workloadExecutionID
        self.bundleRootSHA256 = bundleRootSHA256.lowercased()
        self.artifacts = artifacts
        self.legacyW27Entries = legacyW27Entries
        self.w38Entries = w38Entries
    }
}

public struct AnalysisPhysicalCaptureMaterializationInput: Sendable {
    public let plan: AnalysisDeviceCapturePlan
    public let performanceEvidence: AnalysisDevicePerformanceEvidence
    public let performanceValidation: AnalysisDevicePerformanceValidationReport
    public let workloadReceipt: AnalysisDeviceWorkloadReceipt
    public let workloadValidation: AnalysisDeviceWorkloadValidationReport
    public let algorithmEvidence: AnalysisDeviceAlgorithmExecutionEvidence
    public let currentRuntimeEvidence: AnalysisCurrentDeviceWorkloadArchiveEvidence
    public let executionIntegrityEvidence: AnalysisDeviceCaptureExecutionIntegrityEvidence
    public let executionIntegrityValidation: AnalysisDeviceCaptureExecutionIntegrityReport
    public let performanceProfile: AnalysisDevicePerformanceAcceptanceProfile
    public let workloadPolicy: AnalysisDeviceWorkloadPolicy

    public init(
        plan: AnalysisDeviceCapturePlan,
        performanceEvidence: AnalysisDevicePerformanceEvidence,
        performanceValidation: AnalysisDevicePerformanceValidationReport,
        workloadReceipt: AnalysisDeviceWorkloadReceipt,
        workloadValidation: AnalysisDeviceWorkloadValidationReport,
        algorithmEvidence: AnalysisDeviceAlgorithmExecutionEvidence,
        currentRuntimeEvidence: AnalysisCurrentDeviceWorkloadArchiveEvidence,
        executionIntegrityEvidence: AnalysisDeviceCaptureExecutionIntegrityEvidence,
        executionIntegrityValidation: AnalysisDeviceCaptureExecutionIntegrityReport,
        performanceProfile: AnalysisDevicePerformanceAcceptanceProfile,
        workloadPolicy: AnalysisDeviceWorkloadPolicy
    ) {
        self.plan = plan
        self.performanceEvidence = performanceEvidence
        self.performanceValidation = performanceValidation
        self.workloadReceipt = workloadReceipt
        self.workloadValidation = workloadValidation
        self.algorithmEvidence = algorithmEvidence
        self.currentRuntimeEvidence = currentRuntimeEvidence
        self.executionIntegrityEvidence = executionIntegrityEvidence
        self.executionIntegrityValidation = executionIntegrityValidation
        self.performanceProfile = performanceProfile
        self.workloadPolicy = workloadPolicy
    }
}

public enum AnalysisPhysicalCaptureArtifactMaterializationError: Error, Equatable, Sendable {
    case unsafeRunID
    case invalidPlan
    case invalidPerformanceEvidence
    case invalidWorkloadReceipt
    case invalidExecutionIntegrity
    case nonBoundedCurrentRuntime
    case captureChainBindingMismatch
    case invalidRunSemantics
    case encodingFailure
}

public enum AnalysisPhysicalCaptureArtifactMaterializer {
    public static let artifactCount = 9

    public static func materialize(
        _ input: AnalysisPhysicalCaptureMaterializationInput
    ) throws -> AnalysisPhysicalCaptureArtifactBundle {
        guard safeRunID(input.plan.runID) else {
            throw AnalysisPhysicalCaptureArtifactMaterializationError.unsafeRunID
        }

        let planReport = AnalysisDeviceCapturePlanValidator.validate(
            input.plan,
            workloadPolicy: input.workloadPolicy,
            performanceProfile: input.performanceProfile
        )
        guard planReport.valid else {
            throw AnalysisPhysicalCaptureArtifactMaterializationError.invalidPlan
        }

        let recomputedPerformance = AnalysisDevicePerformanceEvidenceValidator.validate(
            input.performanceEvidence,
            expectedManifestID: input.plan.manifestID,
            expectedManifestSHA256: input.plan.manifestSHA256,
            evaluatedAt: input.performanceValidation.generatedAt
        )
        guard recomputedPerformance == input.performanceValidation,
              input.performanceValidation.status == .structurallyCompletePendingHQ else {
            throw AnalysisPhysicalCaptureArtifactMaterializationError.invalidPerformanceEvidence
        }

        let recomputedWorkload = AnalysisDeviceWorkloadReceiptValidator.validate(
            input.workloadReceipt,
            performanceEvidence: input.performanceEvidence,
            policy: input.workloadPolicy
        )
        let expectedWorkloadStatus: AnalysisDeviceWorkloadValidationStatus = input.plan.runKind == .completeAnalysis
            ? .fullWorkloadCompletePendingHQ
            : .realWorkCancellationPendingHQ
        guard recomputedWorkload == input.workloadValidation,
              input.workloadValidation.status == expectedWorkloadStatus else {
            throw AnalysisPhysicalCaptureArtifactMaterializationError.invalidWorkloadReceipt
        }

        let recomputedIntegrity = AnalysisDeviceCaptureExecutionIntegrityValidator.validate(input.executionIntegrityEvidence)
        guard recomputedIntegrity == input.executionIntegrityValidation,
              input.executionIntegrityValidation.valid else {
            throw AnalysisPhysicalCaptureArtifactMaterializationError.invalidExecutionIntegrity
        }

        guard input.currentRuntimeEvidence.sourceMemoryContract == .boundedPull,
              input.currentRuntimeEvidence.boundedSourceContractAccepted,
              input.algorithmEvidence.sourceInputContract == .boundedPull,
              input.executionIntegrityEvidence.sourceMemoryContract == .boundedPull else {
            throw AnalysisPhysicalCaptureArtifactMaterializationError.nonBoundedCurrentRuntime
        }

        let runID = input.plan.runID
        let executionID = input.workloadReceipt.executionID
        let bindingOK = input.performanceEvidence.provenance.runID == runID
            && input.performanceEvidence.provenance.runKind == input.plan.runKind
            && input.performanceEvidence.provenance.fixtureID == input.plan.source.fixtureID
            && input.performanceEvidence.provenance.manifestID == input.plan.manifestID
            && input.performanceEvidence.provenance.manifestSHA256.lowercased() == input.plan.manifestSHA256.lowercased()
            && input.workloadReceipt.runID == runID
            && input.workloadReceipt.performanceEvidenceRunID == runID
            && input.workloadReceipt.runKind == input.plan.runKind
            && input.workloadReceipt.source == input.plan.source
            && input.workloadReceipt.identity == input.plan.identity
            && input.algorithmEvidence.runID == runID
            && input.algorithmEvidence.performanceEvidenceRunID == runID
            && input.algorithmEvidence.workloadExecutionID == executionID
            && input.algorithmEvidence.source == input.plan.source
            && input.algorithmEvidence.identity == input.plan.identity
            && input.currentRuntimeEvidence.runID == runID
            && input.currentRuntimeEvidence.performanceEvidenceRunID == runID
            && input.currentRuntimeEvidence.runKind == input.plan.runKind
            && input.currentRuntimeEvidence.workloadExecutionID == executionID
            && input.currentRuntimeEvidence.algorithmRunID == runID
            && input.currentRuntimeEvidence.algorithmWorkloadExecutionID == executionID
            && input.executionIntegrityEvidence.runID == runID
            && input.executionIntegrityEvidence.performanceRunID == runID
            && input.executionIntegrityEvidence.workloadRunID == runID
            && input.executionIntegrityEvidence.workloadExecutionID == executionID
            && input.executionIntegrityEvidence.algorithmRunID == runID
            && input.executionIntegrityEvidence.algorithmWorkloadExecutionID == executionID
            && input.executionIntegrityValidation.runID == runID
        guard bindingOK else {
            throw AnalysisPhysicalCaptureArtifactMaterializationError.captureChainBindingMismatch
        }

        guard validSemantics(input) else {
            throw AnalysisPhysicalCaptureArtifactMaterializationError.invalidRunSemantics
        }

        do {
            let prefix = "runs/\(runID)"
            let artifacts: [AnalysisPhysicalCaptureArtifact] = [
                .init(
                    role: .w23PerformanceEvidence,
                    relativePath: "\(prefix)/w23/performance-evidence.json",
                    bytes: try AnalysisDevicePerformanceEvidenceCodec.encodeEvidence(input.performanceEvidence)
                ),
                .init(
                    role: .w23PerformanceValidation,
                    relativePath: "\(prefix)/w23/performance-validation.json",
                    bytes: try AnalysisDevicePerformanceEvidenceCodec.encodeReport(input.performanceValidation)
                ),
                .init(
                    role: .w25WorkloadReceipt,
                    relativePath: "\(prefix)/w25/workload-receipt.json",
                    bytes: try stableJSON(input.workloadReceipt)
                ),
                .init(
                    role: .w25WorkloadValidation,
                    relativePath: "\(prefix)/w25/workload-validation.json",
                    bytes: try stableJSON(input.workloadValidation)
                ),
                .init(
                    role: .w35AlgorithmEvidence,
                    relativePath: "\(prefix)/w35/algorithm-evidence.json",
                    bytes: try stableJSON(input.algorithmEvidence)
                ),
                .init(
                    role: .w36CurrentRuntimeEvidence,
                    relativePath: "\(prefix)/w36/current-runtime-evidence.json",
                    bytes: try AnalysisPhysicalEvidenceArchiveChainCodec.encodeCurrentRuntimeEvidence(input.currentRuntimeEvidence)
                ),
                .init(
                    role: .w37CapturePlan,
                    relativePath: "\(prefix)/w37/capture-plan.json",
                    bytes: try stableJSON(input.plan)
                ),
                .init(
                    role: .w37ExecutionIntegrityEvidence,
                    relativePath: "\(prefix)/w37/execution-integrity-evidence.json",
                    bytes: try AnalysisDeviceCaptureExecutionIntegrityCodec.encodeEvidence(input.executionIntegrityEvidence)
                ),
                .init(
                    role: .w37ExecutionIntegrityReport,
                    relativePath: "\(prefix)/w37/execution-integrity-report.json",
                    bytes: try AnalysisDeviceCaptureExecutionIntegrityCodec.encodeReport(input.executionIntegrityValidation)
                )
            ]

            guard artifacts.count == artifactCount,
                  Set(artifacts.map { $0.role.rawValue }).count == artifactCount,
                  Set(artifacts.map(\.relativePath)).count == artifactCount else {
                throw AnalysisPhysicalCaptureArtifactMaterializationError.encodingFailure
            }

            let legacy = try legacyEntries(artifacts, runID: runID)
            let chain = try chainEntries(artifacts, runID: runID)
            let root = try bundleRoot(
                runID: runID,
                workloadExecutionID: executionID,
                artifacts: artifacts
            )
            return .init(
                runID: runID,
                workloadExecutionID: executionID,
                bundleRootSHA256: root,
                artifacts: artifacts.sorted(by: { $0.relativePath < $1.relativePath }),
                legacyW27Entries: legacy.sorted(by: { $0.relativePath < $1.relativePath }),
                w38Entries: chain.sorted(by: { $0.relativePath < $1.relativePath })
            )
        } catch let error as AnalysisPhysicalCaptureArtifactMaterializationError {
            throw error
        } catch {
            throw AnalysisPhysicalCaptureArtifactMaterializationError.encodingFailure
        }
    }

    private static func validSemantics(_ input: AnalysisPhysicalCaptureMaterializationInput) -> Bool {
        switch input.plan.runKind {
        case .completeAnalysis:
            return input.currentRuntimeEvidence.outcome == .completed
                && input.currentRuntimeEvidence.snapshotSHA256 != nil
                && input.algorithmEvidence.captureState == .finalized
                && input.algorithmEvidence.runtimeIdentity != nil
                && input.algorithmEvidence.runtimeIdentitySHA256 != nil
                && input.executionIntegrityEvidence.workloadOutcome == .completed
                && input.executionIntegrityEvidence.cancellationCoordination == .notApplicable
        case .cancellationProbe:
            return input.currentRuntimeEvidence.outcome == .cancelled
                && input.currentRuntimeEvidence.observedSourceSampleCount > 0
                && input.currentRuntimeEvidence.snapshotSHA256 == nil
                && input.algorithmEvidence.captureState == .cancelledBeforeFinalization
                && input.algorithmEvidence.runtimeIdentity == nil
                && input.algorithmEvidence.runtimeIdentitySHA256 == nil
                && input.executionIntegrityEvidence.workloadOutcome == .cancelled
                && input.executionIntegrityEvidence.cancellationCoordination == .requestedAfterObservedSourceWork
                && input.executionIntegrityEvidence.cancellationRequestedOffsetSeconds != nil
                && input.executionIntegrityEvidence.cancellationObservedOffsetSeconds != nil
        }
    }

    private static func legacyEntries(
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
                throw AnalysisPhysicalCaptureArtifactMaterializationError.encodingFailure
            }
            return AnalysisPhysicalEvidenceArchiveBuilder.entry(
                role: archiveRole,
                relativePath: artifact.relativePath,
                runID: runID,
                bytes: artifact.bytes
            )
        }
    }

    private static func chainEntries(
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
                throw AnalysisPhysicalCaptureArtifactMaterializationError.encodingFailure
            }
            return AnalysisPhysicalEvidenceArchiveChainBuilder.entry(
                role: archiveRole,
                relativePath: artifact.relativePath,
                runID: runID,
                bytes: artifact.bytes
            )
        }
    }

    private struct BundleRootRecord: Codable {
        let role: AnalysisPhysicalCaptureArtifactRole
        let relativePath: String
        let sha256: String
        let byteLength: UInt64
    }

    private struct BundleRootPayload: Codable {
        let schemaVersion: Int
        let runID: String
        let workloadExecutionID: String
        let artifacts: [BundleRootRecord]
    }

    private static func bundleRoot(
        runID: String,
        workloadExecutionID: String,
        artifacts: [AnalysisPhysicalCaptureArtifact]
    ) throws -> String {
        let records = artifacts.map {
            BundleRootRecord(role: $0.role, relativePath: $0.relativePath, sha256: $0.sha256, byteLength: $0.byteLength)
        }.sorted { lhs, rhs in
            let l = "\(lhs.role.rawValue)|\(lhs.relativePath)|\(lhs.sha256)|\(lhs.byteLength)"
            let r = "\(rhs.role.rawValue)|\(rhs.relativePath)|\(rhs.sha256)|\(rhs.byteLength)"
            return l < r
        }
        let payload = BundleRootPayload(
            schemaVersion: 1,
            runID: runID,
            workloadExecutionID: workloadExecutionID,
            artifacts: records
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return AnalysisDeviceWorkloadSHA256.hexDigest(try encoder.encode(payload))
    }

    private static func stableJSON<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }

    private static func safeRunID(_ value: String) -> Bool {
        guard !value.isEmpty,
              value.count <= 128,
              value == value.trimmingCharacters(in: .whitespacesAndNewlines),
              value != ".",
              value != ".." else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 45, 46, 48...57, 65...90, 95, 97...122:
                return true
            default:
                return false
            }
        }
    }
}
