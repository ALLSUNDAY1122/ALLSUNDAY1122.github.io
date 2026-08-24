import Foundation

public enum AnalysisRuntimeAlgorithmCaptureState: String, Codable, Sendable {
    case finalized = "FINALIZED_RUNTIME_IDENTITY"
    case cancelledBeforeFinalization = "CANCELLED_BEFORE_RUNTIME_IDENTITY_FINALIZATION"
}

public enum AnalysisRuntimeTempoEnergyMode: String, Codable, Sendable {
    case referenceRescan = "REFERENCE_RESCAN"
    case rollingReuse = "ROLLING_REUSE"
}

public struct AnalysisRuntimeAlgorithmIdentity: Codable, Equatable, Sendable {
    public static let currentAlgorithmSchemaID = "L4-W35-SINGLE_PASS-W34-GUARDED-V1"

    public let algorithmSchemaID: String
    public let exactSinglePreparedTraversal: Bool
    public let preparedSampleCount: Int
    public let tempoEnergyMode: AnalysisRuntimeTempoEnergyMode
    public let extremeDurationCompressionApplied: Bool
    public let tempoFrameStride: Int
    public let chordFrameStride: Int
    public let sectionEnergyFrameStrideEquivalent: Int
    public let tempoResolutionSafe: Bool
    public let chordWindowRetentionSafe: Bool
    public let sectionResolutionSafe: Bool
    public let chordBackendGuardState: String
    public let chordBackendVerificationFrameLimit: Int
    public let chordBackendVerificationComparisons: Int
    public let chordBackendVerificationMatches: Int
    public let chordBackendFallbackTriggered: Bool
    public let chordBackendFallbackComparisonIndex: Int?
    public let chordBackendReferencePublicationCount: Int
    public let chordBackendVectorizedPublicationCount: Int

    public init(diagnostics: AnalysisSinglePassPreparedFeatureDiagnostics, sourceDurationSeconds: Double) {
        algorithmSchemaID = Self.currentAlgorithmSchemaID
        exactSinglePreparedTraversal = diagnostics.exactSinglePreparedTraversal
        preparedSampleCount = diagnostics.preparedSampleCount
        tempoEnergyMode = sourceDurationSeconds >= AnalysisLongAudioCPUDutyPolicy.rollingTempoMinimumDurationSeconds
            ? .rollingReuse
            : .referenceRescan
        extremeDurationCompressionApplied = diagnostics.extremeDurationCompressionApplied
        tempoFrameStride = diagnostics.tempoFrameStride
        chordFrameStride = diagnostics.chordFrameStride
        sectionEnergyFrameStrideEquivalent = diagnostics.sectionEnergyFrameStrideEquivalent
        tempoResolutionSafe = diagnostics.tempoResolutionSafe
        chordWindowRetentionSafe = diagnostics.chordWindowRetentionSafe
        sectionResolutionSafe = diagnostics.sectionResolutionSafe
        chordBackendGuardState = diagnostics.chordBackendGuardState
        chordBackendVerificationFrameLimit = diagnostics.chordBackendVerificationFrameLimit
        chordBackendVerificationComparisons = diagnostics.chordBackendVerificationComparisons
        chordBackendVerificationMatches = diagnostics.chordBackendVerificationMatches
        chordBackendFallbackTriggered = diagnostics.chordBackendFallbackTriggered
        chordBackendFallbackComparisonIndex = diagnostics.chordBackendFallbackComparisonIndex
        chordBackendReferencePublicationCount = diagnostics.chordBackendReferencePublicationCount
        chordBackendVectorizedPublicationCount = diagnostics.chordBackendVectorizedPublicationCount
    }
}

public struct AnalysisDeviceAlgorithmExecutionEvidence: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let runID: String
    public let performanceEvidenceRunID: String
    public let runKind: AnalysisDevicePerformanceRunKind
    public let workloadExecutionID: String
    public let manifestID: String
    public let manifestSHA256: String
    public let source: AnalysisDeviceWorkloadSourceBinding
    public let identity: AnalysisDeviceWorkloadIdentity
    public let snapshotSHA256: String?
    public let captureState: AnalysisRuntimeAlgorithmCaptureState
    public let runtimeIdentity: AnalysisRuntimeAlgorithmIdentity?
    public let runtimeIdentitySHA256: String?

    public init(
        schemaVersion: Int = 1,
        runID: String,
        performanceEvidenceRunID: String,
        runKind: AnalysisDevicePerformanceRunKind,
        workloadExecutionID: String,
        manifestID: String,
        manifestSHA256: String,
        source: AnalysisDeviceWorkloadSourceBinding,
        identity: AnalysisDeviceWorkloadIdentity,
        snapshotSHA256: String?,
        captureState: AnalysisRuntimeAlgorithmCaptureState,
        runtimeIdentity: AnalysisRuntimeAlgorithmIdentity?,
        runtimeIdentitySHA256: String?
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.performanceEvidenceRunID = performanceEvidenceRunID
        self.runKind = runKind
        self.workloadExecutionID = workloadExecutionID
        self.manifestID = manifestID
        self.manifestSHA256 = manifestSHA256.lowercased()
        self.source = source
        self.identity = identity
        self.snapshotSHA256 = snapshotSHA256?.lowercased()
        self.captureState = captureState
        self.runtimeIdentity = runtimeIdentity
        self.runtimeIdentitySHA256 = runtimeIdentitySHA256?.lowercased()
    }
}

public struct AnalysisDeviceAlgorithmEvidenceBatch: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let batchID: String
    public let performanceProfileID: String
    public let runs: [AnalysisDeviceAlgorithmExecutionEvidence]

    public init(schemaVersion: Int = 1, batchID: String, performanceProfileID: String, runs: [AnalysisDeviceAlgorithmExecutionEvidence]) {
        self.schemaVersion = schemaVersion
        self.batchID = batchID
        self.performanceProfileID = performanceProfileID
        self.runs = runs
    }
}

public enum AnalysisDeviceAlgorithmExecutionEvidenceCodec {
    public static func canonicalJSON(_ identity: AnalysisRuntimeAlgorithmIdentity) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(identity)
    }

    public static func identitySHA256(_ identity: AnalysisRuntimeAlgorithmIdentity) throws -> String {
        AnalysisDeviceWorkloadSHA256.hexDigest(try canonicalJSON(identity))
    }

    public static func canonicalJSON(_ evidence: AnalysisDeviceAlgorithmExecutionEvidence) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(evidence)
    }
}

public enum AnalysisDeviceAlgorithmExecutionEvidenceBuilder {
    public static func finalized(
        receipt: AnalysisDeviceWorkloadReceipt,
        performanceRun: AnalysisDevicePerformanceEvidence,
        diagnostics: AnalysisSinglePassPreparedFeatureDiagnostics
    ) throws -> AnalysisDeviceAlgorithmExecutionEvidence {
        let runtime = AnalysisRuntimeAlgorithmIdentity(
            diagnostics: diagnostics,
            sourceDurationSeconds: receipt.source.sourceDurationSeconds
        )
        return .init(
            runID: receipt.runID,
            performanceEvidenceRunID: performanceRun.provenance.runID,
            runKind: receipt.runKind,
            workloadExecutionID: receipt.executionID,
            manifestID: receipt.manifestID,
            manifestSHA256: receipt.manifestSHA256,
            source: receipt.source,
            identity: receipt.identity,
            snapshotSHA256: receipt.snapshotSHA256,
            captureState: .finalized,
            runtimeIdentity: runtime,
            runtimeIdentitySHA256: try AnalysisDeviceAlgorithmExecutionEvidenceCodec.identitySHA256(runtime)
        )
    }

    public static func cancelledBeforeFinalization(
        receipt: AnalysisDeviceWorkloadReceipt,
        performanceRun: AnalysisDevicePerformanceEvidence
    ) -> AnalysisDeviceAlgorithmExecutionEvidence {
        .init(
            runID: receipt.runID,
            performanceEvidenceRunID: performanceRun.provenance.runID,
            runKind: receipt.runKind,
            workloadExecutionID: receipt.executionID,
            manifestID: receipt.manifestID,
            manifestSHA256: receipt.manifestSHA256,
            source: receipt.source,
            identity: receipt.identity,
            snapshotSHA256: receipt.snapshotSHA256,
            captureState: .cancelledBeforeFinalization,
            runtimeIdentity: nil,
            runtimeIdentitySHA256: nil
        )
    }
}
