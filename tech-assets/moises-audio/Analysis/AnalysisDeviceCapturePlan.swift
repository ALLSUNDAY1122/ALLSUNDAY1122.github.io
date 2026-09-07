import Foundation

public struct AnalysisDeviceCancellationCapturePlan: Codable, Equatable, Sendable {
    public let delayAfterObservedSourceWorkSeconds: Double
    public let sourceWorkPollIntervalSeconds: Double
    public let maximumWaitForObservedSourceWorkSeconds: Double

    public init(
        delayAfterObservedSourceWorkSeconds: Double,
        sourceWorkPollIntervalSeconds: Double,
        maximumWaitForObservedSourceWorkSeconds: Double
    ) {
        self.delayAfterObservedSourceWorkSeconds = delayAfterObservedSourceWorkSeconds
        self.sourceWorkPollIntervalSeconds = sourceWorkPollIntervalSeconds
        self.maximumWaitForObservedSourceWorkSeconds = maximumWaitForObservedSourceWorkSeconds
    }
}

public struct AnalysisDeviceCapturePlan: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let authority: String
    public let approvalReference: String
    public let runID: String
    public let runKind: AnalysisDevicePerformanceRunKind
    public let manifestID: String
    public let manifestSHA256: String
    public let source: AnalysisDeviceWorkloadSourceBinding
    public let identity: AnalysisDeviceWorkloadIdentity
    public let telemetrySampleIntervalSeconds: Double
    public let maximumTelemetrySampleCount: Int
    public let cancellation: AnalysisDeviceCancellationCapturePlan?

    public init(
        schemaVersion: Int = 1,
        authority: String,
        approvalReference: String,
        runID: String,
        runKind: AnalysisDevicePerformanceRunKind,
        manifestID: String,
        manifestSHA256: String,
        source: AnalysisDeviceWorkloadSourceBinding,
        identity: AnalysisDeviceWorkloadIdentity,
        telemetrySampleIntervalSeconds: Double,
        maximumTelemetrySampleCount: Int,
        cancellation: AnalysisDeviceCancellationCapturePlan?
    ) {
        self.schemaVersion = schemaVersion
        self.authority = authority
        self.approvalReference = approvalReference
        self.runID = runID
        self.runKind = runKind
        self.manifestID = manifestID
        self.manifestSHA256 = manifestSHA256.lowercased()
        self.source = source
        self.identity = identity
        self.telemetrySampleIntervalSeconds = telemetrySampleIntervalSeconds
        self.maximumTelemetrySampleCount = maximumTelemetrySampleCount
        self.cancellation = cancellation
    }

    public var workloadContext: AnalysisDeviceWorkloadRunContext {
        .init(
            runID: runID,
            runKind: runKind,
            manifestID: manifestID,
            manifestSHA256: manifestSHA256,
            source: source,
            identity: identity
        )
    }
}

public enum AnalysisDeviceCapturePlanIssueCode: String, Codable, Hashable, Sendable {
    case invalidPlan = "INVALID_CAPTURE_PLAN"
    case invalidSampling = "INVALID_CAPTURE_SAMPLING"
    case invalidCancellationPlan = "INVALID_CANCELLATION_CAPTURE_PLAN"
    case profileBindingMismatch = "CAPTURE_PROFILE_BINDING_MISMATCH"
    case workloadPolicyBindingMismatch = "CAPTURE_WORKLOAD_POLICY_BINDING_MISMATCH"
}

public struct AnalysisDeviceCapturePlanIssue: Codable, Equatable, Sendable {
    public let code: AnalysisDeviceCapturePlanIssueCode
    public let detail: String

    public init(code: AnalysisDeviceCapturePlanIssueCode, detail: String) {
        self.code = code
        self.detail = detail
    }
}

public struct AnalysisDeviceCapturePlanValidationReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let runID: String
    public let valid: Bool
    public let issues: [AnalysisDeviceCapturePlanIssue]

    public init(schemaVersion: Int = 1, runID: String, valid: Bool, issues: [AnalysisDeviceCapturePlanIssue]) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.valid = valid
        self.issues = issues
    }
}

public enum AnalysisDeviceCapturePlanValidator {
    public static func validate(
        _ plan: AnalysisDeviceCapturePlan,
        workloadPolicy: AnalysisDeviceWorkloadPolicy,
        performanceProfile: AnalysisDevicePerformanceAcceptanceProfile
    ) -> AnalysisDeviceCapturePlanValidationReport {
        var issues: [AnalysisDeviceCapturePlanIssue] = []
        let trim: (String) -> String = { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        if plan.schemaVersion != 1
            || plan.authority != "HQ_LATE_INTEGRATION"
            || trim(plan.approvalReference).isEmpty
            || trim(plan.runID).isEmpty
            || trim(plan.manifestID).isEmpty
            || !isSHA256(plan.manifestSHA256)
            || !validSource(plan.source)
            || [plan.identity.analyzerID, plan.identity.analyzerVersion, plan.identity.analysisConfigurationID, plan.identity.buildIdentity].contains(where: { trim($0).isEmpty }) {
            issues.append(.init(code: .invalidPlan, detail: "capture plan requires schema 1, HQ authority, nonempty approval/run/manifest/identity fields and a valid source binding"))
        }

        if !plan.telemetrySampleIntervalSeconds.isFinite
            || plan.telemetrySampleIntervalSeconds <= 0
            || plan.maximumTelemetrySampleCount < 1
            || plan.maximumTelemetrySampleCount > 100_000 {
            issues.append(.init(code: .invalidSampling, detail: "telemetry sample interval must be finite and > 0; maximum sample count must be 1...100000"))
        }

        switch plan.runKind {
        case .completeAnalysis:
            if plan.cancellation != nil {
                issues.append(.init(code: .invalidCancellationPlan, detail: "complete Analysis capture must not carry cancellation timing instructions"))
            }
        case .cancellationProbe:
            guard let cancellation = plan.cancellation,
                  cancellation.delayAfterObservedSourceWorkSeconds.isFinite,
                  cancellation.delayAfterObservedSourceWorkSeconds >= 0,
                  cancellation.sourceWorkPollIntervalSeconds.isFinite,
                  cancellation.sourceWorkPollIntervalSeconds > 0,
                  cancellation.maximumWaitForObservedSourceWorkSeconds.isFinite,
                  cancellation.maximumWaitForObservedSourceWorkSeconds > 0 else {
                issues.append(.init(code: .invalidCancellationPlan, detail: "cancellation capture requires HQ-supplied finite delay >= 0, poll interval > 0 and source-work wait limit > 0"))
                break
            }
        }

        let matchingRuns = performanceProfile.plannedRuns.filter { $0.runID == plan.runID }
        let planned = matchingRuns.count == 1 ? matchingRuns[0] : nil
        let expectedDuration = performanceProfile.expectedFixtureDurationsSeconds[plan.source.fixtureID]
        let profileMatches = performanceProfile.authority == "HQ_LATE_INTEGRATION"
            && performanceProfile.expectedManifestID == plan.manifestID
            && performanceProfile.expectedManifestSHA256.lowercased() == plan.manifestSHA256
            && planned?.fixtureID == plan.source.fixtureID
            && planned?.runKind == plan.runKind
            && performanceProfile.requiredFixtureIDs.contains(plan.source.fixtureID)
            && expectedDuration.map { abs($0 - plan.source.sourceDurationSeconds) <= max(0.001, plan.source.sourceDurationSeconds * 0.001) } == true
        if !profileMatches {
            issues.append(.init(code: .profileBindingMismatch, detail: "capture run/fixture/kind/duration/manifest must be predeclared exactly once by the HQ W24 profile"))
        }

        let policySource = workloadPolicy.fixtures[plan.source.fixtureID]
        let policyMatches = workloadPolicy.authority == "HQ_LATE_INTEGRATION"
            && workloadPolicy.manifestID == plan.manifestID
            && workloadPolicy.manifestSHA256.lowercased() == plan.manifestSHA256
            && workloadPolicy.identity == plan.identity
            && policySource == plan.source
        if !policyMatches {
            issues.append(.init(code: .workloadPolicyBindingMismatch, detail: "capture manifest/source/analyzer/config/build identity must match the exact HQ W25 workload policy"))
        }

        issues.sort { ($0.code.rawValue, $0.detail) < ($1.code.rawValue, $1.detail) }
        return .init(runID: plan.runID, valid: issues.isEmpty, issues: issues)
    }

    private static func validSource(_ source: AnalysisDeviceWorkloadSourceBinding) -> Bool {
        !source.fixtureID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && isSHA256(source.sourceSHA256)
            && source.sourceDurationSeconds.isFinite
            && source.sourceDurationSeconds > 0
            && source.sourceSampleRate.isFinite
            && source.sourceSampleRate > 0
            && source.sourceChannelCount > 0
    }

    private static func isSHA256(_ text: String) -> Bool {
        text.count == 64 && text.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 48...57, 65...70, 97...102: return true
            default: return false
            }
        }
    }
}

public enum AnalysisDeviceCaptureCancellationCoordination: String, Codable, Equatable, Sendable {
    case notApplicable = "NOT_APPLICABLE"
    case requestedAfterObservedSourceWork = "REQUESTED_AFTER_OBSERVED_SOURCE_WORK"
    case workloadFinishedBeforeRequest = "WORKLOAD_FINISHED_BEFORE_REQUEST"
    case sourceWorkWaitExpired = "SOURCE_WORK_WAIT_EXPIRED"
}

public struct AnalysisDeviceCaptureTelemetrySamplingSummary: Codable, Equatable, Sendable {
    public let samplingAttempts: Int
    public let periodicSamplesCaptured: Int
    public let sampleCapReached: Bool
    public let samplerTerminated: Bool

    public init(samplingAttempts: Int, periodicSamplesCaptured: Int, sampleCapReached: Bool, samplerTerminated: Bool) {
        self.samplingAttempts = samplingAttempts
        self.periodicSamplesCaptured = periodicSamplesCaptured
        self.sampleCapReached = sampleCapReached
        self.samplerTerminated = samplerTerminated
    }
}

public struct AnalysisDeviceCaptureExecutionIntegrityEvidence: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let runID: String
    public let runKind: AnalysisDevicePerformanceRunKind
    public let performanceRunID: String
    public let workloadRunID: String
    public let workloadExecutionID: String
    public let algorithmRunID: String?
    public let algorithmWorkloadExecutionID: String?
    public let sourceMemoryContract: AnalysisChunkedSourceMemoryContract
    public let workloadOutcome: AnalysisDeviceWorkloadExecutionOutcome
    public let observedSourceSampleCount: Int64
    public let cancellationCoordination: AnalysisDeviceCaptureCancellationCoordination
    public let cancellationRequestedOffsetSeconds: Double?
    public let cancellationObservedOffsetSeconds: Double?
    public let requestedSampleIntervalSeconds: Double
    public let captureWallSeconds: Double
    public let telemetrySampling: AnalysisDeviceCaptureTelemetrySamplingSummary
    public let cancellationTaskTerminated: Bool
    public let performanceLimitations: [String]

    public init(
        schemaVersion: Int = 1,
        runID: String,
        runKind: AnalysisDevicePerformanceRunKind,
        performanceRunID: String,
        workloadRunID: String,
        workloadExecutionID: String,
        algorithmRunID: String?,
        algorithmWorkloadExecutionID: String?,
        sourceMemoryContract: AnalysisChunkedSourceMemoryContract,
        workloadOutcome: AnalysisDeviceWorkloadExecutionOutcome,
        observedSourceSampleCount: Int64,
        cancellationCoordination: AnalysisDeviceCaptureCancellationCoordination,
        cancellationRequestedOffsetSeconds: Double?,
        cancellationObservedOffsetSeconds: Double?,
        requestedSampleIntervalSeconds: Double,
        captureWallSeconds: Double,
        telemetrySampling: AnalysisDeviceCaptureTelemetrySamplingSummary,
        cancellationTaskTerminated: Bool,
        performanceLimitations: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.runKind = runKind
        self.performanceRunID = performanceRunID
        self.workloadRunID = workloadRunID
        self.workloadExecutionID = workloadExecutionID
        self.algorithmRunID = algorithmRunID
        self.algorithmWorkloadExecutionID = algorithmWorkloadExecutionID
        self.sourceMemoryContract = sourceMemoryContract
        self.workloadOutcome = workloadOutcome
        self.observedSourceSampleCount = observedSourceSampleCount
        self.cancellationCoordination = cancellationCoordination
        self.cancellationRequestedOffsetSeconds = cancellationRequestedOffsetSeconds
        self.cancellationObservedOffsetSeconds = cancellationObservedOffsetSeconds
        self.requestedSampleIntervalSeconds = requestedSampleIntervalSeconds
        self.captureWallSeconds = captureWallSeconds
        self.telemetrySampling = telemetrySampling
        self.cancellationTaskTerminated = cancellationTaskTerminated
        self.performanceLimitations = performanceLimitations.sorted()
    }
}

public enum AnalysisDeviceCaptureExecutionIntegrityIssueCode: String, Codable, Hashable, Sendable {
    case invalidSchema = "INVALID_W37_EXECUTION_SCHEMA"
    case runBindingMismatch = "W37_RUN_BINDING_MISMATCH"
    case reusedExecution = "W37_REUSED_EXECUTION"
    case nonBoundedSource = "W37_NON_BOUNDED_SOURCE"
    case invalidTelemetryLifecycle = "W37_INVALID_TELEMETRY_LIFECYCLE"
    case telemetrySampleCapReached = "W37_TELEMETRY_SAMPLE_CAP_REACHED"
    case missingPeriodicTelemetry = "W37_MISSING_PERIODIC_TELEMETRY"
    case cancellationTaskNotTerminated = "W37_CANCELLATION_TASK_NOT_TERMINATED"
    case invalidCancellationSemantics = "W37_INVALID_CANCELLATION_SEMANTICS"
    case invalidCancellationTiming = "W37_INVALID_CANCELLATION_TIMING"
    case duplicateRunID = "W37_DUPLICATE_RUN_ID"
}

public struct AnalysisDeviceCaptureExecutionIntegrityIssue: Codable, Equatable, Sendable {
    public let code: AnalysisDeviceCaptureExecutionIntegrityIssueCode
    public let detail: String

    public init(code: AnalysisDeviceCaptureExecutionIntegrityIssueCode, detail: String) {
        self.code = code
        self.detail = detail
    }
}

public struct AnalysisDeviceCaptureExecutionIntegrityReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let runID: String
    public let valid: Bool
    public let issues: [AnalysisDeviceCaptureExecutionIntegrityIssue]

    public init(schemaVersion: Int = 1, runID: String, valid: Bool, issues: [AnalysisDeviceCaptureExecutionIntegrityIssue]) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.valid = valid
        self.issues = issues
    }
}

public enum AnalysisDeviceCaptureExecutionIntegrityValidator {
    public static func validate(_ evidence: AnalysisDeviceCaptureExecutionIntegrityEvidence) -> AnalysisDeviceCaptureExecutionIntegrityReport {
        var issues: [AnalysisDeviceCaptureExecutionIntegrityIssue] = []
        let trimmedRunID = evidence.runID.trimmingCharacters(in: .whitespacesAndNewlines)

        if evidence.schemaVersion != 1 || trimmedRunID.isEmpty || evidence.workloadExecutionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(code: .invalidSchema, detail: "W37 execution evidence requires schema 1 plus nonempty run and workload execution IDs"))
        }

        if evidence.performanceRunID != evidence.runID
            || evidence.workloadRunID != evidence.runID
            || evidence.algorithmRunID != evidence.runID
            || evidence.algorithmWorkloadExecutionID != evidence.workloadExecutionID {
            issues.append(.init(code: .runBindingMismatch, detail: "W23/W25/W35/W36 must bind to one run ID and one W36 execution ID"))
        }

        if evidence.sourceMemoryContract != .boundedPull {
            issues.append(.init(code: .nonBoundedSource, detail: "W37 physical P021 capture requires BOUNDED_PULL_CONTRACT"))
        }

        let telemetry = evidence.telemetrySampling
        if telemetry.samplingAttempts < 0
            || telemetry.periodicSamplesCaptured < 0
            || telemetry.periodicSamplesCaptured > telemetry.samplingAttempts
            || !telemetry.samplerTerminated
            || !evidence.requestedSampleIntervalSeconds.isFinite
            || evidence.requestedSampleIntervalSeconds <= 0
            || !evidence.captureWallSeconds.isFinite
            || evidence.captureWallSeconds < 0 {
            issues.append(.init(code: .invalidTelemetryLifecycle, detail: "telemetry sampling counters/timing must be valid and the sampler must terminate before capture finalization"))
        }
        if telemetry.sampleCapReached || evidence.performanceLimitations.contains("TELEMETRY_SAMPLE_CAP_REACHED") {
            issues.append(.init(code: .telemetrySampleCapReached, detail: "telemetry sample cap cannot be a silent W37 success"))
        }
        if evidence.captureWallSeconds >= evidence.requestedSampleIntervalSeconds
            && telemetry.periodicSamplesCaptured == 0 {
            issues.append(.init(code: .missingPeriodicTelemetry, detail: "a capture lasting at least one requested interval must contain a periodic sample beyond start/final snapshots"))
        }
        if !evidence.cancellationTaskTerminated {
            issues.append(.init(code: .cancellationTaskNotTerminated, detail: "cancellation coordination task must be terminated and joined before finalization"))
        }

        switch evidence.runKind {
        case .completeAnalysis:
            if evidence.workloadOutcome != .completed
                || evidence.cancellationCoordination != .notApplicable
                || evidence.cancellationRequestedOffsetSeconds != nil
                || evidence.cancellationObservedOffsetSeconds != nil {
                issues.append(.init(code: .invalidCancellationSemantics, detail: "complete run must complete normally without cancellation coordination timestamps"))
            }
        case .cancellationProbe:
            if evidence.cancellationCoordination != .requestedAfterObservedSourceWork
                || evidence.workloadOutcome != .cancelled
                || evidence.observedSourceSampleCount <= 0 {
                issues.append(.init(code: .invalidCancellationSemantics, detail: "planned cancellation requires observed source work, an actual request, and W36 CANCELLED outcome"))
            }
            guard let requested = evidence.cancellationRequestedOffsetSeconds,
                  let observed = evidence.cancellationObservedOffsetSeconds,
                  requested.isFinite, observed.isFinite,
                  requested >= 0, observed >= requested,
                  observed <= evidence.captureWallSeconds + 1e-6 else {
                issues.append(.init(code: .invalidCancellationTiming, detail: "cancellationRequested must precede cancellationObserved inside the same capture"))
                break
            }
        }

        issues.sort { ($0.code.rawValue, $0.detail) < ($1.code.rawValue, $1.detail) }
        return .init(runID: evidence.runID, valid: issues.isEmpty, issues: issues)
    }

    public static func validateBatch(_ values: [AnalysisDeviceCaptureExecutionIntegrityEvidence]) -> [AnalysisDeviceCaptureExecutionIntegrityIssue] {
        var issues: [AnalysisDeviceCaptureExecutionIntegrityIssue] = []
        let runGroups = Dictionary(grouping: values, by: \.runID)
        for runID in runGroups.keys.sorted() where (runGroups[runID]?.count ?? 0) > 1 {
            issues.append(.init(code: .duplicateRunID, detail: "run ID \(runID) appears more than once in one W37 capture batch"))
        }

        let executionGroups = Dictionary(grouping: values, by: \.workloadExecutionID)
        for executionID in executionGroups.keys.sorted() {
            let grouped = executionGroups[executionID] ?? []
            let distinctRuns = Set(grouped.map(\.runID))
            if distinctRuns.count > 1 {
                issues.append(.init(code: .reusedExecution, detail: "W36 execution ID \(executionID) is reused across distinct W37 run IDs"))
            }
        }
        issues.sort { ($0.code.rawValue, $0.detail) < ($1.code.rawValue, $1.detail) }
        return issues
    }
}

public enum AnalysisDeviceCaptureExecutionIntegrityCodec {
    public static func encodeEvidence(_ value: AnalysisDeviceCaptureExecutionIntegrityEvidence) throws -> Data { try encoder().encode(value) }
    public static func decodeEvidence(_ data: Data) throws -> AnalysisDeviceCaptureExecutionIntegrityEvidence { try decoder().decode(AnalysisDeviceCaptureExecutionIntegrityEvidence.self, from: data) }
    public static func encodeReport(_ value: AnalysisDeviceCaptureExecutionIntegrityReport) throws -> Data { try encoder().encode(value) }
    public static func decodeReport(_ data: Data) throws -> AnalysisDeviceCaptureExecutionIntegrityReport { try decoder().decode(AnalysisDeviceCaptureExecutionIntegrityReport.self, from: data) }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    private static func decoder() -> JSONDecoder { JSONDecoder() }
}
