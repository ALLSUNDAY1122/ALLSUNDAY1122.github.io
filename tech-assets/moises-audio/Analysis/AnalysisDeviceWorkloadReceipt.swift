import Foundation

public enum AnalysisDeviceWorkloadStage: String, Codable, CaseIterable, Sendable {
    case signalPreparation = "SIGNAL_PREPARATION"
    case tempo = "TEMPO"
    case beat = "BEAT"
    case key = "KEY"
    case chord = "CHORD"
    case section = "SECTION"
    case finalSnapshotPublication = "FINAL_SNAPSHOT_PUBLICATION"

    public static let requiredCompleteOrder: [Self] = [
        .signalPreparation, .tempo, .beat, .key, .chord, .section, .finalSnapshotPublication
    ]
}

public enum AnalysisDeviceWorkloadStageStatus: String, Codable, Sendable {
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"
    case failed = "FAILED"
}

public struct AnalysisDeviceWorkloadStageEvent: Codable, Equatable, Sendable {
    public let stage: AnalysisDeviceWorkloadStage
    public let startedOffsetSeconds: Double
    public let endedOffsetSeconds: Double
    public let status: AnalysisDeviceWorkloadStageStatus

    public init(stage: AnalysisDeviceWorkloadStage, startedOffsetSeconds: Double, endedOffsetSeconds: Double, status: AnalysisDeviceWorkloadStageStatus) {
        self.stage = stage
        self.startedOffsetSeconds = startedOffsetSeconds
        self.endedOffsetSeconds = endedOffsetSeconds
        self.status = status
    }
}

public struct AnalysisDeviceWorkloadSourceBinding: Codable, Equatable, Sendable {
    public let fixtureID: String
    public let sourceSHA256: String
    public let sourceDurationSeconds: Double
    public let sourceSampleRate: Double
    public let sourceChannelCount: Int

    public init(fixtureID: String, sourceSHA256: String, sourceDurationSeconds: Double, sourceSampleRate: Double, sourceChannelCount: Int) {
        self.fixtureID = fixtureID
        self.sourceSHA256 = sourceSHA256.lowercased()
        self.sourceDurationSeconds = sourceDurationSeconds
        self.sourceSampleRate = sourceSampleRate
        self.sourceChannelCount = sourceChannelCount
    }
}

public struct AnalysisDeviceWorkloadIdentity: Codable, Equatable, Sendable {
    public let analyzerID: String
    public let analyzerVersion: String
    public let analysisConfigurationID: String
    public let buildIdentity: String

    public init(analyzerID: String, analyzerVersion: String, analysisConfigurationID: String, buildIdentity: String) {
        self.analyzerID = analyzerID
        self.analyzerVersion = analyzerVersion
        self.analysisConfigurationID = analysisConfigurationID
        self.buildIdentity = buildIdentity
    }
}

public struct AnalysisDeviceWorkloadOutputSummary: Codable, Equatable, Sendable {
    public let tempoPresent: Bool
    public let beatCount: Int
    public let keyPresent: Bool
    public let chordCount: Int
    public let sectionCount: Int

    public init(snapshot: AnalysisSnapshot) {
        self.tempoPresent = snapshot.tempo != nil
        self.beatCount = snapshot.tempo?.beatTimesSeconds.count ?? 0
        self.keyPresent = snapshot.key != nil
        self.chordCount = snapshot.chords.count
        self.sectionCount = snapshot.sections.count
    }
}

public struct AnalysisDeviceWorkloadReceipt: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let runID: String
    public let performanceEvidenceRunID: String
    public let runKind: AnalysisDevicePerformanceRunKind
    public let manifestID: String
    public let manifestSHA256: String
    public let source: AnalysisDeviceWorkloadSourceBinding
    public let identity: AnalysisDeviceWorkloadIdentity
    public let executionID: String
    public let workloadStartedAt: Date
    public let stages: [AnalysisDeviceWorkloadStageEvent]
    public let snapshotCanonicalJSON: Data?
    public let snapshotSHA256: String?
    public let outputSummary: AnalysisDeviceWorkloadOutputSummary?
    public let executionBindingSHA256: String

    public init(
        schemaVersion: Int = 1,
        runID: String,
        performanceEvidenceRunID: String,
        runKind: AnalysisDevicePerformanceRunKind,
        manifestID: String,
        manifestSHA256: String,
        source: AnalysisDeviceWorkloadSourceBinding,
        identity: AnalysisDeviceWorkloadIdentity,
        executionID: String,
        workloadStartedAt: Date,
        stages: [AnalysisDeviceWorkloadStageEvent],
        snapshotCanonicalJSON: Data?,
        snapshotSHA256: String?,
        outputSummary: AnalysisDeviceWorkloadOutputSummary?,
        executionBindingSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.performanceEvidenceRunID = performanceEvidenceRunID
        self.runKind = runKind
        self.manifestID = manifestID
        self.manifestSHA256 = manifestSHA256.lowercased()
        self.source = source
        self.identity = identity
        self.executionID = executionID
        self.workloadStartedAt = workloadStartedAt
        self.stages = stages
        self.snapshotCanonicalJSON = snapshotCanonicalJSON
        self.snapshotSHA256 = snapshotSHA256?.lowercased()
        self.outputSummary = outputSummary
        self.executionBindingSHA256 = executionBindingSHA256.lowercased()
    }
}

public struct AnalysisDeviceWorkloadPolicy: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let authority: String
    public let approvalReference: String
    public let manifestID: String
    public let manifestSHA256: String
    public let identity: AnalysisDeviceWorkloadIdentity
    public let fixtures: [String: AnalysisDeviceWorkloadSourceBinding]

    public init(
        schemaVersion: Int = 1,
        authority: String,
        approvalReference: String,
        manifestID: String,
        manifestSHA256: String,
        identity: AnalysisDeviceWorkloadIdentity,
        fixtures: [String: AnalysisDeviceWorkloadSourceBinding]
    ) {
        self.schemaVersion = schemaVersion
        self.authority = authority
        self.approvalReference = approvalReference
        self.manifestID = manifestID
        self.manifestSHA256 = manifestSHA256.lowercased()
        self.identity = identity
        self.fixtures = fixtures
    }
}

public enum AnalysisDeviceWorkloadIssueCode: String, Codable, Hashable, Sendable {
    case invalidPolicy = "INVALID_POLICY"
    case invalidReceipt = "INVALID_RECEIPT"
    case performanceBindingMismatch = "PERFORMANCE_BINDING_MISMATCH"
    case manifestBindingMismatch = "MANIFEST_BINDING_MISMATCH"
    case sourceBindingMismatch = "SOURCE_BINDING_MISMATCH"
    case analyzerBindingMismatch = "ANALYZER_BINDING_MISMATCH"
    case invalidStageTimeline = "INVALID_STAGE_TIMELINE"
    case missingRequiredStage = "MISSING_REQUIRED_STAGE"
    case duplicateStage = "DUPLICATE_STAGE"
    case stageOrderViolation = "STAGE_ORDER_VIOLATION"
    case semanticMismatch = "RUN_KIND_SEMANTIC_MISMATCH"
    case noRealWorkBeforeCancellation = "NO_REAL_WORK_BEFORE_CANCELLATION"
    case invalidSnapshotArtifact = "INVALID_SNAPSHOT_ARTIFACT"
    case snapshotHashMismatch = "SNAPSHOT_HASH_MISMATCH"
    case outputSummaryMismatch = "OUTPUT_SUMMARY_MISMATCH"
    case executionBindingMismatch = "EXECUTION_BINDING_MISMATCH"
    case reusedExecution = "REUSED_EXECUTION_RECEIPT"
}

public struct AnalysisDeviceWorkloadIssue: Codable, Equatable, Sendable {
    public let code: AnalysisDeviceWorkloadIssueCode
    public let runID: String?
    public let stage: AnalysisDeviceWorkloadStage?
    public let detail: String

    public init(code: AnalysisDeviceWorkloadIssueCode, runID: String? = nil, stage: AnalysisDeviceWorkloadStage? = nil, detail: String) {
        self.code = code
        self.runID = runID
        self.stage = stage
        self.detail = detail
    }
}

public enum AnalysisDeviceWorkloadValidationStatus: String, Codable, Sendable {
    case invalid = "INVALID_WORKLOAD_RECEIPT"
    case fullWorkloadCompletePendingHQ = "FULL_WORKLOAD_COMPLETE_PENDING_HQ"
    case realWorkCancellationPendingHQ = "REAL_WORK_CANCELLATION_PENDING_HQ"
}

public struct AnalysisDeviceWorkloadValidationReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let runID: String
    public let status: AnalysisDeviceWorkloadValidationStatus
    public let issues: [AnalysisDeviceWorkloadIssue]

    public init(schemaVersion: Int = 1, runID: String, status: AnalysisDeviceWorkloadValidationStatus, issues: [AnalysisDeviceWorkloadIssue]) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.status = status
        self.issues = issues
    }
}

public enum AnalysisDeviceWorkloadReceiptCodec {
    public static func canonicalJSON(_ receipt: AnalysisDeviceWorkloadReceipt) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(receipt)
    }

    public static func canonicalJSON(_ policy: AnalysisDeviceWorkloadPolicy) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(policy)
    }
}

public enum AnalysisDeviceWorkloadSHA256 {
    public static func hexDigest(_ data: Data) -> String {
        var hasher = AnalysisDeviceWorkloadPortableSHA256()
        hasher.update(data)
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
