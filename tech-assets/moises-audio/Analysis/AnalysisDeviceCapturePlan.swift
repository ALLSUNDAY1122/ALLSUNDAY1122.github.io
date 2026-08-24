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
