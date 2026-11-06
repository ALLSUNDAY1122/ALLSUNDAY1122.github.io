import Foundation

public enum Lane3PhysicalEvidenceSessionCompletionGateIssueKind: String, Codable, Sendable {
    case baselineCompletionNotReady
    case fixtureMismatch
    case duplicateCandidateResourceTrace
    case duplicateCurrentMoisesResourceTrace
    case negativeThermalCounter
    case thermalSampleCoverageMismatch
}

public struct Lane3PhysicalEvidenceSessionCompletionGateIssue: Equatable, Codable, Sendable {
    public let kind: Lane3PhysicalEvidenceSessionCompletionGateIssueKind
    public let subject: Lane3PhysicalEvidenceResourceSubject?
    public let detail: String

    public init(
        kind: Lane3PhysicalEvidenceSessionCompletionGateIssueKind,
        subject: Lane3PhysicalEvidenceResourceSubject? = nil,
        detail: String
    ) {
        self.kind = kind
        self.subject = subject
        self.detail = detail
    }
}

public struct Lane3PhysicalEvidenceSessionCompletionGateReport: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let baseline: Lane3PhysicalEvidenceSessionCompletionReport
    public let strictIssues: [Lane3PhysicalEvidenceSessionCompletionGateIssue]
    public let readyForHQReview: Bool
    public let parityPromotionAllowed: Bool

    public init(
        baseline: Lane3PhysicalEvidenceSessionCompletionReport,
        strictIssues: [Lane3PhysicalEvidenceSessionCompletionGateIssue]
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW51_PHYSICAL_DEVICE_SESSION_STRICT_COMPLETION_NON_PARITY"
        self.baseline = baseline
        self.strictIssues = strictIssues
        self.readyForHQReview = baseline.readyForHQReview && strictIssues.isEmpty
        self.parityPromotionAllowed = false
    }
}

/// Authoritative AW51 completion gate.
///
/// `Lane3PhysicalEvidenceSessionOrchestrator.evaluateCompletion` remains the low-level AW24/AW51
/// aggregation primitive. HQ-facing evidence must pass this stricter gate so a valid-looking bundle
/// cannot escape fixture/session binding, duplicate resource-trace, or signed-counter/coverage checks.
public enum Lane3PhysicalEvidenceSessionCompletionGate {
    public static func evaluate(
        plan: Lane3PhysicalEvidenceSessionPlan,
        deviceBundle: Lane3DeviceEvidenceBundle,
        resourceTraces: [Lane3PhysicalEvidenceResourceTraceReceipt]
    ) -> Lane3PhysicalEvidenceSessionCompletionGateReport {
        let baseline = Lane3PhysicalEvidenceSessionOrchestrator.evaluateCompletion(
            plan: plan,
            deviceBundle: deviceBundle,
            resourceTraces: resourceTraces
        )
        var issues: [Lane3PhysicalEvidenceSessionCompletionGateIssue] = []

        if !baseline.readyForHQReview {
            issues.append(.init(
                kind: .baselineCompletionNotReady,
                detail: "lower-level AW24/AW51 completion did not satisfy all required evidence"
            ))
        }

        if deviceBundle.cases.contains(where: { $0.fixtureID != plan.fixtureID }) {
            issues.append(.init(
                kind: .fixtureMismatch,
                detail: "every AW24 case must use the fixture frozen by the AW51 preflight plan"
            ))
        }

        let candidateMatches = matchingTraces(
            subject: .candidate,
            sessionIdentifier: plan.sessionIdentifier,
            traces: resourceTraces
        )
        if candidateMatches.count > 1 {
            issues.append(.init(
                kind: .duplicateCandidateResourceTrace,
                subject: .candidate,
                detail: "exactly one candidate resource trace is allowed for the session"
            ))
        }

        let referenceMatches = matchingTraces(
            subject: .currentMoisesReference,
            sessionIdentifier: plan.sessionIdentifier,
            traces: resourceTraces
        )
        if referenceMatches.count > 1 {
            issues.append(.init(
                kind: .duplicateCurrentMoisesResourceTrace,
                subject: .currentMoisesReference,
                detail: "exactly one current-Moises resource trace is allowed for the session"
            ))
        }

        for trace in candidateMatches + referenceMatches {
            if hasNegativeThermalCounter(trace) {
                issues.append(.init(
                    kind: .negativeThermalCounter,
                    subject: trace.subject,
                    detail: "thermal sample counters must be non-negative"
                ))
                continue
            }
            let thermalSamples = trace.thermalNominalSamples
                + trace.thermalFairSamples
                + trace.thermalSeriousSamples
                + trace.thermalCriticalSamples
            if thermalSamples != trace.sampleCount {
                issues.append(.init(
                    kind: .thermalSampleCoverageMismatch,
                    subject: trace.subject,
                    detail: "every resource sample must carry exactly one thermal-state observation"
                ))
            }
        }

        return Lane3PhysicalEvidenceSessionCompletionGateReport(
            baseline: baseline,
            strictIssues: issues
        )
    }

    private static func matchingTraces(
        subject: Lane3PhysicalEvidenceResourceSubject,
        sessionIdentifier: String,
        traces: [Lane3PhysicalEvidenceResourceTraceReceipt]
    ) -> [Lane3PhysicalEvidenceResourceTraceReceipt] {
        traces.filter {
            $0.subject == subject && $0.sessionIdentifier == sessionIdentifier
        }
    }

    private static func hasNegativeThermalCounter(
        _ trace: Lane3PhysicalEvidenceResourceTraceReceipt
    ) -> Bool {
        trace.thermalNominalSamples < 0
            || trace.thermalFairSamples < 0
            || trace.thermalSeriousSamples < 0
            || trace.thermalCriticalSamples < 0
    }
}
