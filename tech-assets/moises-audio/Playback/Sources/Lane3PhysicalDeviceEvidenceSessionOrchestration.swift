import Foundation

public enum Lane3PhysicalEvidenceSessionStepKind: String, Codable, Sendable {
    case candidateExecution
    case currentMoisesReferenceExecution
    case humanListeningReview
    case candidateLongTrackResourceTrace
    case currentMoisesLongTrackResourceTrace
    case finalizeDeviceEvidenceBundle
}

public enum Lane3PhysicalEvidenceResourceSubject: String, Codable, Sendable {
    case candidate
    case currentMoisesReference
}

public enum Lane3PhysicalEvidenceSessionPreflightIssueKind: String, Codable, Sendable {
    case invalidSessionIdentifier
    case invalidBuildCommitSHA
    case invalidDeviceContext
    case timingRouteUnsupported
    case privacyBoundaryViolation
    case fixtureNotRightsClearedRealAudio
    case insufficientLongTrackFixture
    case missingCurrentMoisesReference
    case missingScenarioHarness
    case timingInstrumentationUnavailable
    case externalAudibleMarkerUnavailable
    case candidateCaptureUnavailable
    case currentMoisesCaptureUnavailable
    case humanListeningUnavailable
    case interruptionTriggerUnavailable
    case processRSSSamplerUnavailable
    case thermalSamplerUnavailable
    case batterySamplerUnavailable
    case batteryDrainMeasurementModeUnavailable
    case currentMoisesResourceSamplingUnavailable
}

public struct Lane3PhysicalEvidenceSessionPreflightIssue: Equatable, Codable, Sendable {
    public let kind: Lane3PhysicalEvidenceSessionPreflightIssueKind
    public let scenario: Lane3DeviceEvidenceScenario?
    public let detail: String

    public init(
        kind: Lane3PhysicalEvidenceSessionPreflightIssueKind,
        scenario: Lane3DeviceEvidenceScenario? = nil,
        detail: String
    ) {
        self.kind = kind
        self.scenario = scenario
        self.detail = detail
    }
}

public struct Lane3PhysicalEvidenceSessionPreflightInput: Equatable, Codable, Sendable {
    public let sessionIdentifier: String
    public let appBuildCommitSHA: String
    public let deviceModel: String
    public let osVersion: String
    public let audioRoute: Lane3DeviceEvidenceAudioRoute
    public let physicalIPhone: Bool
    public let selectedXcodeBuild: Bool
    public let fixtureID: String
    public let fixtureDurationSeconds: Double
    public let rightsClearedRealAudio: Bool
    public let currentMoisesReferenceSnapshotID: String
    public let currentMoisesVersion: String
    public let privacy: Lane3DeviceEvidencePrivacySnapshot
    public let availableScenarioHarnesses: [Lane3DeviceEvidenceScenario]
    public let timingInstrumentationReady: Bool
    public let externalAudibleMarkerReady: Bool
    public let candidateCaptureReady: Bool
    public let currentMoisesCaptureReady: Bool
    public let humanListeningReady: Bool
    public let interruptionTriggerReady: Bool
    public let processRSSSamplingReady: Bool
    public let thermalSamplingReady: Bool
    public let batterySamplingReady: Bool
    public let batteryDrainMeasurementModeReady: Bool
    public let currentMoisesResourceSamplingReady: Bool

    public init(
        sessionIdentifier: String,
        appBuildCommitSHA: String,
        deviceModel: String,
        osVersion: String,
        audioRoute: Lane3DeviceEvidenceAudioRoute,
        physicalIPhone: Bool,
        selectedXcodeBuild: Bool,
        fixtureID: String,
        fixtureDurationSeconds: Double,
        rightsClearedRealAudio: Bool,
        currentMoisesReferenceSnapshotID: String,
        currentMoisesVersion: String,
        privacy: Lane3DeviceEvidencePrivacySnapshot = Lane3DeviceEvidencePrivacySnapshot(),
        availableScenarioHarnesses: [Lane3DeviceEvidenceScenario],
        timingInstrumentationReady: Bool,
        externalAudibleMarkerReady: Bool,
        candidateCaptureReady: Bool,
        currentMoisesCaptureReady: Bool,
        humanListeningReady: Bool,
        interruptionTriggerReady: Bool,
        processRSSSamplingReady: Bool,
        thermalSamplingReady: Bool,
        batterySamplingReady: Bool,
        batteryDrainMeasurementModeReady: Bool,
        currentMoisesResourceSamplingReady: Bool
    ) {
        self.sessionIdentifier = sessionIdentifier
        self.appBuildCommitSHA = appBuildCommitSHA
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.audioRoute = audioRoute
        self.physicalIPhone = physicalIPhone
        self.selectedXcodeBuild = selectedXcodeBuild
        self.fixtureID = fixtureID
        self.fixtureDurationSeconds = fixtureDurationSeconds
        self.rightsClearedRealAudio = rightsClearedRealAudio
        self.currentMoisesReferenceSnapshotID = currentMoisesReferenceSnapshotID
        self.currentMoisesVersion = currentMoisesVersion
        self.privacy = privacy
        self.availableScenarioHarnesses = availableScenarioHarnesses
        self.timingInstrumentationReady = timingInstrumentationReady
        self.externalAudibleMarkerReady = externalAudibleMarkerReady
        self.candidateCaptureReady = candidateCaptureReady
        self.currentMoisesCaptureReady = currentMoisesCaptureReady
        self.humanListeningReady = humanListeningReady
        self.interruptionTriggerReady = interruptionTriggerReady
        self.processRSSSamplingReady = processRSSSamplingReady
        self.thermalSamplingReady = thermalSamplingReady
        self.batterySamplingReady = batterySamplingReady
        self.batteryDrainMeasurementModeReady = batteryDrainMeasurementModeReady
        self.currentMoisesResourceSamplingReady = currentMoisesResourceSamplingReady
    }
}

public struct Lane3PhysicalEvidenceSessionStep: Equatable, Codable, Sendable {
    public let ordinal: Int
    public let kind: Lane3PhysicalEvidenceSessionStepKind
    public let scenario: Lane3DeviceEvidenceScenario?
    public let minimumRepetitions: Int
    public let minimumDurationSeconds: Double
    public let targetedParityRows: [String]
    public let requiredArtifactRoles: [String]

    public init(
        ordinal: Int,
        kind: Lane3PhysicalEvidenceSessionStepKind,
        scenario: Lane3DeviceEvidenceScenario?,
        minimumRepetitions: Int,
        minimumDurationSeconds: Double,
        targetedParityRows: [String],
        requiredArtifactRoles: [String]
    ) {
        self.ordinal = ordinal
        self.kind = kind
        self.scenario = scenario
        self.minimumRepetitions = minimumRepetitions
        self.minimumDurationSeconds = minimumDurationSeconds
        self.targetedParityRows = targetedParityRows
        self.requiredArtifactRoles = requiredArtifactRoles
    }
}

public struct Lane3PhysicalEvidenceSessionPlan: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let sessionIdentifier: String
    public let appBuildCommitSHA: String
    public let deviceModel: String
    public let osVersion: String
    public let audioRoute: Lane3DeviceEvidenceAudioRoute
    public let currentMoisesReferenceSnapshotID: String
    public let currentMoisesVersion: String
    public let fixtureID: String
    public let preflightIssues: [Lane3PhysicalEvidenceSessionPreflightIssue]
    public let steps: [Lane3PhysicalEvidenceSessionStep]
    public let targetedParityRows: [String]
    public let sessionStartAllowed: Bool
    public let parityPromotionAllowed: Bool

    public init(
        input: Lane3PhysicalEvidenceSessionPreflightInput,
        issues: [Lane3PhysicalEvidenceSessionPreflightIssue],
        steps: [Lane3PhysicalEvidenceSessionStep],
        targetedParityRows: [String]
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW51_PHYSICAL_DEVICE_SESSION_PLAN_NON_PARITY"
        self.sessionIdentifier = input.sessionIdentifier
        self.appBuildCommitSHA = input.appBuildCommitSHA
        self.deviceModel = input.deviceModel
        self.osVersion = input.osVersion
        self.audioRoute = input.audioRoute
        self.currentMoisesReferenceSnapshotID = input.currentMoisesReferenceSnapshotID
        self.currentMoisesVersion = input.currentMoisesVersion
        self.fixtureID = input.fixtureID
        self.preflightIssues = issues
        self.steps = steps
        self.targetedParityRows = targetedParityRows
        self.sessionStartAllowed = issues.isEmpty
        self.parityPromotionAllowed = false
    }
}

public struct Lane3PhysicalEvidenceResourceTraceReceipt: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let sessionIdentifier: String
    public let subject: Lane3PhysicalEvidenceResourceSubject
    public let scenario: Lane3DeviceEvidenceScenario
    public let observedDurationSeconds: Double
    public let sampleCount: Int
    public let maximumSampleIntervalSeconds: Double
    public let peakRSSBytes: UInt64
    public let thermalNominalSamples: Int
    public let thermalFairSamples: Int
    public let thermalSeriousSamples: Int
    public let thermalCriticalSamples: Int
    public let batteryStartLevel: Double
    public let batteryEndLevel: Double
    public let externalPowerConnectedDuringBatteryWindow: Bool
    public let traceArtifactSHA256: String
    public let parityPromotionAllowed: Bool

    public init(
        sessionIdentifier: String,
        subject: Lane3PhysicalEvidenceResourceSubject,
        scenario: Lane3DeviceEvidenceScenario = .longTrackStability,
        observedDurationSeconds: Double,
        sampleCount: Int,
        maximumSampleIntervalSeconds: Double,
        peakRSSBytes: UInt64,
        thermalNominalSamples: Int,
        thermalFairSamples: Int,
        thermalSeriousSamples: Int,
        thermalCriticalSamples: Int,
        batteryStartLevel: Double,
        batteryEndLevel: Double,
        externalPowerConnectedDuringBatteryWindow: Bool,
        traceArtifactSHA256: String
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW51_RESOURCE_TRACE_NON_PARITY"
        self.sessionIdentifier = sessionIdentifier
        self.subject = subject
        self.scenario = scenario
        self.observedDurationSeconds = observedDurationSeconds
        self.sampleCount = sampleCount
        self.maximumSampleIntervalSeconds = maximumSampleIntervalSeconds
        self.peakRSSBytes = peakRSSBytes
        self.thermalNominalSamples = thermalNominalSamples
        self.thermalFairSamples = thermalFairSamples
        self.thermalSeriousSamples = thermalSeriousSamples
        self.thermalCriticalSamples = thermalCriticalSamples
        self.batteryStartLevel = batteryStartLevel
        self.batteryEndLevel = batteryEndLevel
        self.externalPowerConnectedDuringBatteryWindow = externalPowerConnectedDuringBatteryWindow
        self.traceArtifactSHA256 = traceArtifactSHA256
        self.parityPromotionAllowed = false
    }
}

public enum Lane3PhysicalEvidenceSessionCompletionIssueKind: String, Codable, Sendable {
    case planNotStartable
    case deviceBundleNotReadyForHQReview
    case sessionMetadataMismatch
    case missingCandidateResourceTrace
    case missingCurrentMoisesResourceTrace
    case invalidResourceTraceEnvelope
    case invalidResourceTraceDuration
    case invalidResourceTraceSampling
    case invalidRSSMeasurement
    case invalidThermalMeasurement
    case invalidBatteryMeasurement
    case batteryWindowExternallyPowered
    case invalidResourceTraceDigest
}

public struct Lane3PhysicalEvidenceSessionCompletionIssue: Equatable, Codable, Sendable {
    public let kind: Lane3PhysicalEvidenceSessionCompletionIssueKind
    public let subject: Lane3PhysicalEvidenceResourceSubject?
    public let detail: String

    public init(
        kind: Lane3PhysicalEvidenceSessionCompletionIssueKind,
        subject: Lane3PhysicalEvidenceResourceSubject? = nil,
        detail: String
    ) {
        self.kind = kind
        self.subject = subject
        self.detail = detail
    }
}

public struct Lane3PhysicalEvidenceSessionCompletionReport: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let issues: [Lane3PhysicalEvidenceSessionCompletionIssue]
    public let aw24DeviceBundleReadyForHQReview: Bool
    public let candidateResourceTraceValid: Bool
    public let currentMoisesResourceTraceValid: Bool
    public let readyForHQReview: Bool
    public let parityPromotionAllowed: Bool

    public init(
        issues: [Lane3PhysicalEvidenceSessionCompletionIssue],
        aw24DeviceBundleReadyForHQReview: Bool,
        candidateResourceTraceValid: Bool,
        currentMoisesResourceTraceValid: Bool
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW51_PHYSICAL_DEVICE_SESSION_COMPLETION_NON_PARITY"
        self.issues = issues
        self.aw24DeviceBundleReadyForHQReview = aw24DeviceBundleReadyForHQReview
        self.candidateResourceTraceValid = candidateResourceTraceValid
        self.currentMoisesResourceTraceValid = currentMoisesResourceTraceValid
        self.readyForHQReview = issues.isEmpty
            && aw24DeviceBundleReadyForHQReview
            && candidateResourceTraceValid
            && currentMoisesResourceTraceValid
        self.parityPromotionAllowed = false
    }
}

public enum Lane3PhysicalEvidenceSessionOrchestrator {
    public static let targetedParityRows = [
        "MOI-P006", "MOI-P007", "MOI-P008", "MOI-P010",
        "MOI-P012", "MOI-P014", "MOI-P015", "MOI-P021"
    ]

    public static func makePlan(
        input: Lane3PhysicalEvidenceSessionPreflightInput
    ) -> Lane3PhysicalEvidenceSessionPlan {
        var issues: [Lane3PhysicalEvidenceSessionPreflightIssue] = []
        let trimmedSessionID = input.sessionIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSessionID.isEmpty || trimmedSessionID.count > 128 {
            issues.append(.init(kind: .invalidSessionIdentifier, detail: "sessionIdentifier must be non-empty and <=128 characters"))
        }
        if !isLowercaseHex(input.appBuildCommitSHA, length: 40) {
            issues.append(.init(kind: .invalidBuildCommitSHA, detail: "appBuildCommitSHA must be a lowercase 40-character Git SHA"))
        }
        if input.deviceModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || input.osVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !input.physicalIPhone
            || !input.selectedXcodeBuild {
            issues.append(.init(kind: .invalidDeviceContext, detail: "physical iPhone + selected Xcode build + non-empty device metadata are required"))
        }
        if !input.audioRoute.supportsTimingEvidence {
            issues.append(.init(kind: .timingRouteUnsupported, detail: "Bluetooth A2DP is not accepted for timing evidence"))
        }
        if !input.privacy.isSafe {
            issues.append(.init(kind: .privacyBoundaryViolation, detail: "session manifest would capture prohibited raw/path/device-identifying data"))
        }
        if input.fixtureID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !input.rightsClearedRealAudio {
            issues.append(.init(kind: .fixtureNotRightsClearedRealAudio, detail: "a named rights-cleared real-audio fixture is required"))
        }
        if !input.fixtureDurationSeconds.isFinite || input.fixtureDurationSeconds < 1_800 {
            issues.append(.init(kind: .insufficientLongTrackFixture, scenario: .longTrackStability, detail: "the session fixture must provide at least 1800 seconds for P021 evidence"))
        }
        if input.currentMoisesReferenceSnapshotID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || input.currentMoisesVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(kind: .missingCurrentMoisesReference, detail: "current-iPhone Moises snapshot ID and version are required"))
        }

        let available = Set(input.availableScenarioHarnesses)
        for scenario in Lane3DeviceEvidenceScenario.allCases where !available.contains(scenario) {
            issues.append(.init(kind: .missingScenarioHarness, scenario: scenario, detail: "AW24 final bundle requires every device-evidence scenario"))
        }
        if !input.timingInstrumentationReady {
            issues.append(.init(kind: .timingInstrumentationUnavailable, detail: "timing summaries cannot be produced"))
        }
        if !input.externalAudibleMarkerReady {
            issues.append(.init(kind: .externalAudibleMarkerUnavailable, scenario: .seekLoop, detail: "seek/loop physical latency requires an external audible marker"))
        }
        if !input.candidateCaptureReady {
            issues.append(.init(kind: .candidateCaptureUnavailable, detail: "candidate capture digest cannot be produced"))
        }
        if !input.currentMoisesCaptureReady {
            issues.append(.init(kind: .currentMoisesCaptureUnavailable, detail: "current-Moises capture digest cannot be produced"))
        }
        if !input.humanListeningReady {
            issues.append(.init(kind: .humanListeningUnavailable, detail: "AW24 requires listening review for every scenario"))
        }
        if !input.interruptionTriggerReady {
            issues.append(.init(kind: .interruptionTriggerUnavailable, scenario: .interruptionRecovery, detail: "interruption recovery requires a reproducible physical trigger"))
        }
        if !input.processRSSSamplingReady {
            issues.append(.init(kind: .processRSSSamplerUnavailable, scenario: .longTrackStability, detail: "P021 resource trace requires process RSS sampling"))
        }
        if !input.thermalSamplingReady {
            issues.append(.init(kind: .thermalSamplerUnavailable, scenario: .longTrackStability, detail: "P021 resource trace requires thermal-state sampling"))
        }
        if !input.batterySamplingReady {
            issues.append(.init(kind: .batterySamplerUnavailable, scenario: .longTrackStability, detail: "P021 resource trace requires battery-level sampling"))
        }
        if !input.batteryDrainMeasurementModeReady {
            issues.append(.init(kind: .batteryDrainMeasurementModeUnavailable, scenario: .longTrackStability, detail: "battery window must be measurable without external power"))
        }
        if !input.currentMoisesResourceSamplingReady {
            issues.append(.init(kind: .currentMoisesResourceSamplingUnavailable, scenario: .longTrackStability, detail: "P021 requires a comparable current-Moises resource trace"))
        }

        return Lane3PhysicalEvidenceSessionPlan(
            input: input,
            issues: issues,
            steps: buildSteps(),
            targetedParityRows: targetedParityRows
        )
    }

    public static func evaluateCompletion(
        plan: Lane3PhysicalEvidenceSessionPlan,
        deviceBundle: Lane3DeviceEvidenceBundle,
        resourceTraces: [Lane3PhysicalEvidenceResourceTraceReceipt]
    ) -> Lane3PhysicalEvidenceSessionCompletionReport {
        var issues: [Lane3PhysicalEvidenceSessionCompletionIssue] = []
        if !plan.sessionStartAllowed {
            issues.append(.init(kind: .planNotStartable, detail: "preflight issues were present"))
        }

        let aw24Validation = Lane3DeviceEvidenceValidator.validate(deviceBundle)
        if !aw24Validation.readyForHQParityReview {
            issues.append(.init(kind: .deviceBundleNotReadyForHQReview, detail: "AW24 device bundle validator reported issues"))
        }
        if deviceBundle.appBuildCommitSHA != plan.appBuildCommitSHA
            || deviceBundle.deviceModel != plan.deviceModel
            || deviceBundle.osVersion != plan.osVersion
            || deviceBundle.audioRoute != plan.audioRoute
            || deviceBundle.currentMoisesReferenceSnapshotID != plan.currentMoisesReferenceSnapshotID
            || deviceBundle.currentMoisesVersion != plan.currentMoisesVersion {
            issues.append(.init(kind: .sessionMetadataMismatch, detail: "device bundle metadata does not match the preflight plan"))
        }

        let candidate = uniqueTrace(.candidate, sessionIdentifier: plan.sessionIdentifier, traces: resourceTraces)
        let reference = uniqueTrace(.currentMoisesReference, sessionIdentifier: plan.sessionIdentifier, traces: resourceTraces)
        if candidate == nil {
            issues.append(.init(kind: .missingCandidateResourceTrace, subject: .candidate, detail: "exactly one candidate long-track resource trace is required"))
        }
        if reference == nil {
            issues.append(.init(kind: .missingCurrentMoisesResourceTrace, subject: .currentMoisesReference, detail: "exactly one current-Moises long-track resource trace is required"))
        }

        let candidateValid = candidate.map { validateResourceTrace($0, issues: &issues) } ?? false
        let referenceValid = reference.map { validateResourceTrace($0, issues: &issues) } ?? false
        return Lane3PhysicalEvidenceSessionCompletionReport(
            issues: issues,
            aw24DeviceBundleReadyForHQReview: aw24Validation.readyForHQParityReview,
            candidateResourceTraceValid: candidateValid,
            currentMoisesResourceTraceValid: referenceValid
        )
    }

    private static func buildSteps() -> [Lane3PhysicalEvidenceSessionStep] {
        var result: [Lane3PhysicalEvidenceSessionStep] = []
        var ordinal = 1
        for scenario in Lane3DeviceEvidenceScenario.allCases {
            if scenario == .longTrackStability {
                result.append(.init(
                    ordinal: ordinal,
                    kind: .candidateLongTrackResourceTrace,
                    scenario: scenario,
                    minimumRepetitions: 1,
                    minimumDurationSeconds: 1_800,
                    targetedParityRows: parityRows(for: scenario),
                    requiredArtifactRoles: ["candidate_resource_trace_sha256"]
                ))
                ordinal += 1
            }
            result.append(.init(
                ordinal: ordinal,
                kind: .candidateExecution,
                scenario: scenario,
                minimumRepetitions: minimumRepetitions(for: scenario),
                minimumDurationSeconds: scenario == .longTrackStability ? 1_800 : 0,
                targetedParityRows: parityRows(for: scenario),
                requiredArtifactRoles: ["candidate_capture_sha256", "timing_summary", "runtime_health"]
            ))
            ordinal += 1
            if scenario == .longTrackStability {
                result.append(.init(
                    ordinal: ordinal,
                    kind: .currentMoisesLongTrackResourceTrace,
                    scenario: scenario,
                    minimumRepetitions: 1,
                    minimumDurationSeconds: 1_800,
                    targetedParityRows: parityRows(for: scenario),
                    requiredArtifactRoles: ["current_moises_resource_trace_sha256"]
                ))
                ordinal += 1
            }
            result.append(.init(
                ordinal: ordinal,
                kind: .currentMoisesReferenceExecution,
                scenario: scenario,
                minimumRepetitions: minimumRepetitions(for: scenario),
                minimumDurationSeconds: scenario == .longTrackStability ? 1_800 : 0,
                targetedParityRows: parityRows(for: scenario),
                requiredArtifactRoles: ["current_moises_capture_sha256"]
            ))
            ordinal += 1
            result.append(.init(
                ordinal: ordinal,
                kind: .humanListeningReview,
                scenario: scenario,
                minimumRepetitions: 3,
                minimumDurationSeconds: 0,
                targetedParityRows: parityRows(for: scenario),
                requiredArtifactRoles: ["listening_review"]
            ))
            ordinal += 1
        }
        result.append(.init(
            ordinal: ordinal,
            kind: .finalizeDeviceEvidenceBundle,
            scenario: nil,
            minimumRepetitions: 1,
            minimumDurationSeconds: 0,
            targetedParityRows: targetedParityRows,
            requiredArtifactRoles: ["aw24_device_bundle", "aw51_completion_report"]
        ))
        return result
    }

    private static func parityRows(for scenario: Lane3DeviceEvidenceScenario) -> [String] {
        switch scenario {
        case .mixerGainRamp: return ["MOI-P006"]
        case .seekLoop: return ["MOI-P007", "MOI-P008"]
        case .tempo: return ["MOI-P008", "MOI-P010"]
        case .pitch: return ["MOI-P012"]
        case .metronome: return ["MOI-P014"]
        case .countIn: return ["MOI-P015"]
        case .interruptionRecovery: return []
        case .longTrackStability: return ["MOI-P007", "MOI-P021"]
        }
    }

    private static func minimumRepetitions(for scenario: Lane3DeviceEvidenceScenario) -> Int {
        switch scenario {
        case .longTrackStability: return 1
        case .interruptionRecovery: return 5
        case .mixerGainRamp, .seekLoop, .tempo, .pitch, .metronome, .countIn: return 10
        }
    }

    private static func uniqueTrace(
        _ subject: Lane3PhysicalEvidenceResourceSubject,
        sessionIdentifier: String,
        traces: [Lane3PhysicalEvidenceResourceTraceReceipt]
    ) -> Lane3PhysicalEvidenceResourceTraceReceipt? {
        let matches = traces.filter {
            $0.subject == subject && $0.sessionIdentifier == sessionIdentifier
        }
        return matches.count == 1 ? matches[0] : nil
    }

    @discardableResult
    private static func validateResourceTrace(
        _ trace: Lane3PhysicalEvidenceResourceTraceReceipt,
        issues: inout [Lane3PhysicalEvidenceSessionCompletionIssue]
    ) -> Bool {
        var valid = true
        if trace.schemaVersion != 1
            || trace.evidenceScope != "LANE3_AW51_RESOURCE_TRACE_NON_PARITY"
            || trace.parityPromotionAllowed
            || trace.scenario != .longTrackStability {
            issues.append(.init(kind: .invalidResourceTraceEnvelope, subject: trace.subject, detail: "invalid AW51 resource-trace envelope"))
            valid = false
        }
        if !trace.observedDurationSeconds.isFinite || trace.observedDurationSeconds < 1_800 {
            issues.append(.init(kind: .invalidResourceTraceDuration, subject: trace.subject, detail: "resource trace must span at least 1800 seconds"))
            valid = false
        }
        if trace.sampleCount < 60
            || !trace.maximumSampleIntervalSeconds.isFinite
            || trace.maximumSampleIntervalSeconds <= 0
            || trace.maximumSampleIntervalSeconds > 30 {
            issues.append(.init(kind: .invalidResourceTraceSampling, subject: trace.subject, detail: "need >=60 samples and maximum sampling interval <=30 seconds"))
            valid = false
        }
        if trace.peakRSSBytes == 0 {
            issues.append(.init(kind: .invalidRSSMeasurement, subject: trace.subject, detail: "peak RSS must be captured"))
            valid = false
        }
        let thermalSamples = trace.thermalNominalSamples
            + trace.thermalFairSamples
            + trace.thermalSeriousSamples
            + trace.thermalCriticalSamples
        if thermalSamples <= 0 || thermalSamples > trace.sampleCount {
            issues.append(.init(kind: .invalidThermalMeasurement, subject: trace.subject, detail: "thermal-state samples are missing or exceed trace sample count"))
            valid = false
        }
        if !trace.batteryStartLevel.isFinite
            || !trace.batteryEndLevel.isFinite
            || !(0...1).contains(trace.batteryStartLevel)
            || !(0...1).contains(trace.batteryEndLevel) {
            issues.append(.init(kind: .invalidBatteryMeasurement, subject: trace.subject, detail: "battery levels must be finite values in 0...1"))
            valid = false
        }
        if trace.externalPowerConnectedDuringBatteryWindow {
            issues.append(.init(kind: .batteryWindowExternallyPowered, subject: trace.subject, detail: "battery-drain window cannot be externally powered"))
            valid = false
        }
        if !isLowercaseHex(trace.traceArtifactSHA256, length: 64) {
            issues.append(.init(kind: .invalidResourceTraceDigest, subject: trace.subject, detail: "resource trace artifact must have a lowercase SHA-256 digest"))
            valid = false
        }
        return valid
    }

    private static func isLowercaseHex(_ value: String, length: Int) -> Bool {
        guard value.count == length else { return false }
        return value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}
