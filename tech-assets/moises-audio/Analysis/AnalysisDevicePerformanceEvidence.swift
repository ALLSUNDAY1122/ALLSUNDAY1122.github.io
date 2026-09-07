import Foundation

public enum AnalysisDeviceRuntimeClass: String, Codable, Sendable {
    case physicalIOSDevice = "PHYSICAL_IOS_DEVICE"
    case iOSSimulator = "IOS_SIMULATOR"
    case portableNonIOS = "PORTABLE_NON_IOS"
}

public enum AnalysisDevicePerformanceRunKind: String, Codable, Sendable {
    case completeAnalysis = "COMPLETE_ANALYSIS"
    case cancellationProbe = "CANCELLATION_PROBE"
}

public enum AnalysisDeviceThermalState: String, Codable, CaseIterable, Sendable {
    case nominal = "NOMINAL"
    case fair = "FAIR"
    case serious = "SERIOUS"
    case critical = "CRITICAL"
    case unavailable = "UNAVAILABLE"

    fileprivate var rank: Int {
        switch self {
        case .nominal: return 0
        case .fair: return 1
        case .serious: return 2
        case .critical: return 3
        case .unavailable: return -1
        }
    }
}

public enum AnalysisDeviceBatteryState: String, Codable, Sendable {
    case unknown = "UNKNOWN"
    case unplugged = "UNPLUGGED"
    case charging = "CHARGING"
    case full = "FULL"
    case unavailable = "UNAVAILABLE"
}

public struct AnalysisTelemetryChannelAvailability: Codable, Equatable, Sendable {
    public let available: Bool
    public let unavailableReason: String?

    public init(available: Bool, unavailableReason: String? = nil) {
        self.available = available
        self.unavailableReason = unavailableReason
    }

    public static var availableChannel: Self { .init(available: true) }
    public static func unavailable(_ reason: String) -> Self { .init(available: false, unavailableReason: reason) }
}

public struct AnalysisDevicePerformanceProvenance: Codable, Equatable, Sendable {
    public let runID: String
    public let runKind: AnalysisDevicePerformanceRunKind
    public let startedAt: Date
    public let runtimeClass: AnalysisDeviceRuntimeClass
    public let deviceModel: String
    public let osVersion: String
    public let appBundleIdentifier: String
    public let appVersion: String
    public let buildVersion: String
    public let manifestID: String
    public let manifestSHA256: String
    public let fixtureID: String
    public let fixtureDurationSeconds: Double

    public init(
        runID: String,
        runKind: AnalysisDevicePerformanceRunKind,
        startedAt: Date,
        runtimeClass: AnalysisDeviceRuntimeClass,
        deviceModel: String,
        osVersion: String,
        appBundleIdentifier: String,
        appVersion: String,
        buildVersion: String,
        manifestID: String,
        manifestSHA256: String,
        fixtureID: String,
        fixtureDurationSeconds: Double
    ) {
        self.runID = runID
        self.runKind = runKind
        self.startedAt = startedAt
        self.runtimeClass = runtimeClass
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.appBundleIdentifier = appBundleIdentifier
        self.appVersion = appVersion
        self.buildVersion = buildVersion
        self.manifestID = manifestID
        self.manifestSHA256 = manifestSHA256.lowercased()
        self.fixtureID = fixtureID
        self.fixtureDurationSeconds = fixtureDurationSeconds
    }
}

public struct AnalysisDeviceMemorySample: Codable, Equatable, Sendable {
    public let offsetSeconds: Double
    public let residentBytes: UInt64?
    public let residentUnavailableReason: String?
    public let physicalFootprintBytes: UInt64?
    public let physicalFootprintUnavailableReason: String?

    public init(
        offsetSeconds: Double,
        residentBytes: UInt64?,
        residentUnavailableReason: String? = nil,
        physicalFootprintBytes: UInt64?,
        physicalFootprintUnavailableReason: String? = nil
    ) {
        self.offsetSeconds = offsetSeconds
        self.residentBytes = residentBytes
        self.residentUnavailableReason = residentUnavailableReason
        self.physicalFootprintBytes = physicalFootprintBytes
        self.physicalFootprintUnavailableReason = physicalFootprintUnavailableReason
    }
}

public struct AnalysisDeviceThermalSample: Codable, Equatable, Sendable {
    public let offsetSeconds: Double
    public let state: AnalysisDeviceThermalState
    public let unavailableReason: String?

    public init(offsetSeconds: Double, state: AnalysisDeviceThermalState, unavailableReason: String? = nil) {
        self.offsetSeconds = offsetSeconds
        self.state = state
        self.unavailableReason = unavailableReason
    }
}

public struct AnalysisDeviceBatterySample: Codable, Equatable, Sendable {
    public let offsetSeconds: Double
    public let levelFraction: Double?
    public let state: AnalysisDeviceBatteryState
    public let unavailableReason: String?

    public init(offsetSeconds: Double, levelFraction: Double?, state: AnalysisDeviceBatteryState, unavailableReason: String? = nil) {
        self.offsetSeconds = offsetSeconds
        self.levelFraction = levelFraction
        self.state = state
        self.unavailableReason = unavailableReason
    }
}

public struct AnalysisDeviceMemoryPressureEvent: Codable, Equatable, Sendable {
    public let offsetSeconds: Double
    public let source: String
    public let detail: String

    public init(offsetSeconds: Double, source: String, detail: String) {
        self.offsetSeconds = offsetSeconds
        self.source = source
        self.detail = detail
    }
}

public struct AnalysisDeviceCancellationTelemetry: Codable, Equatable, Sendable {
    public let requestedOffsetSeconds: Double?
    public let observedTerminationOffsetSeconds: Double?

    public init(requestedOffsetSeconds: Double?, observedTerminationOffsetSeconds: Double?) {
        self.requestedOffsetSeconds = requestedOffsetSeconds
        self.observedTerminationOffsetSeconds = observedTerminationOffsetSeconds
    }
}

public struct AnalysisDevicePerformanceEvidence: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let provenance: AnalysisDevicePerformanceProvenance
    public let finishedAt: Date
    public let wallSeconds: Double
    public let requestedSampleIntervalSeconds: Double
    public let maximumSampleCount: Int
    public let memoryTelemetry: AnalysisTelemetryChannelAvailability
    public let thermalTelemetry: AnalysisTelemetryChannelAvailability
    public let batteryTelemetry: AnalysisTelemetryChannelAvailability
    public let memoryPressureObservation: AnalysisTelemetryChannelAvailability
    public let memorySamples: [AnalysisDeviceMemorySample]
    public let thermalSamples: [AnalysisDeviceThermalSample]
    public let batterySamples: [AnalysisDeviceBatterySample]
    public let memoryPressureEvents: [AnalysisDeviceMemoryPressureEvent]
    public let cancellation: AnalysisDeviceCancellationTelemetry
    public let completedNormally: Bool
    public let failureDescription: String?
    public let limitations: [String]

    public init(
        schemaVersion: Int = 1,
        provenance: AnalysisDevicePerformanceProvenance,
        finishedAt: Date,
        wallSeconds: Double,
        requestedSampleIntervalSeconds: Double,
        maximumSampleCount: Int,
        memoryTelemetry: AnalysisTelemetryChannelAvailability,
        thermalTelemetry: AnalysisTelemetryChannelAvailability,
        batteryTelemetry: AnalysisTelemetryChannelAvailability,
        memoryPressureObservation: AnalysisTelemetryChannelAvailability,
        memorySamples: [AnalysisDeviceMemorySample],
        thermalSamples: [AnalysisDeviceThermalSample],
        batterySamples: [AnalysisDeviceBatterySample],
        memoryPressureEvents: [AnalysisDeviceMemoryPressureEvent],
        cancellation: AnalysisDeviceCancellationTelemetry,
        completedNormally: Bool,
        failureDescription: String? = nil,
        limitations: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.provenance = provenance
        self.finishedAt = finishedAt
        self.wallSeconds = wallSeconds
        self.requestedSampleIntervalSeconds = requestedSampleIntervalSeconds
        self.maximumSampleCount = maximumSampleCount
        self.memoryTelemetry = memoryTelemetry
        self.thermalTelemetry = thermalTelemetry
        self.batteryTelemetry = batteryTelemetry
        self.memoryPressureObservation = memoryPressureObservation
        self.memorySamples = memorySamples
        self.thermalSamples = thermalSamples
        self.batterySamples = batterySamples
        self.memoryPressureEvents = memoryPressureEvents
        self.cancellation = cancellation
        self.completedNormally = completedNormally
        self.failureDescription = failureDescription
        self.limitations = limitations
    }
}

public enum AnalysisDevicePerformanceIssueCode: String, Codable, Hashable, Sendable {
    case invalidSchema = "INVALID_SCHEMA"
    case invalidProvenance = "INVALID_PROVENANCE"
    case manifestBindingMismatch = "MANIFEST_BINDING_MISMATCH"
    case invalidTiming = "INVALID_TIMING"
    case invalidSamplingConfiguration = "INVALID_SAMPLING_CONFIGURATION"
    case invalidMemorySample = "INVALID_MEMORY_SAMPLE"
    case invalidThermalSample = "INVALID_THERMAL_SAMPLE"
    case invalidBatterySample = "INVALID_BATTERY_SAMPLE"
    case invalidPressureEvent = "INVALID_PRESSURE_EVENT"
    case unavailableRequiredTelemetry = "UNAVAILABLE_REQUIRED_TELEMETRY"
    case missingRequiredSamples = "MISSING_REQUIRED_SAMPLES"
    case incompleteCancellationProbe = "INCOMPLETE_CANCELLATION_PROBE"
    case inconsistentCompletionState = "INCONSISTENT_COMPLETION_STATE"
}

public struct AnalysisDevicePerformanceIssue: Codable, Equatable, Sendable {
    public let code: AnalysisDevicePerformanceIssueCode
    public let field: String?
    public let detail: String

    public init(code: AnalysisDevicePerformanceIssueCode, field: String? = nil, detail: String) {
        self.code = code
        self.field = field
        self.detail = detail
    }
}

public enum AnalysisDevicePerformanceValidationStatus: String, Codable, Sendable {
    case invalid = "INVALID"
    case nonPhysicalRuntime = "NON_PHYSICAL_RUNTIME_NON_PARITY"
    case telemetryIncompletePendingHQ = "PHYSICAL_DEVICE_TELEMETRY_INCOMPLETE_PENDING_HQ"
    case structurallyCompletePendingHQ = "PHYSICAL_DEVICE_EVIDENCE_STRUCTURALLY_COMPLETE_PENDING_HQ"
}

public struct AnalysisDevicePerformanceValidationReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let generatedAt: Date
    public let runID: String
    public let status: AnalysisDevicePerformanceValidationStatus
    public let structurallyValid: Bool
    public let physicalDeviceClaim: Bool
    public let peakResidentBytes: UInt64?
    public let peakPhysicalFootprintBytes: UInt64?
    public let worstThermalState: AnalysisDeviceThermalState?
    public let batteryLevelDelta: Double?
    public let batteryDrainFraction: Double?
    public let memoryPressureEventCount: Int
    public let thermalTransitionCount: Int
    public let cancellationLatencySeconds: Double?
    public let issues: [AnalysisDevicePerformanceIssue]
    public let limitations: [String]

    public init(
        schemaVersion: Int = 1,
        generatedAt: Date,
        runID: String,
        status: AnalysisDevicePerformanceValidationStatus,
        structurallyValid: Bool,
        physicalDeviceClaim: Bool,
        peakResidentBytes: UInt64?,
        peakPhysicalFootprintBytes: UInt64?,
        worstThermalState: AnalysisDeviceThermalState?,
        batteryLevelDelta: Double?,
        batteryDrainFraction: Double?,
        memoryPressureEventCount: Int,
        thermalTransitionCount: Int,
        cancellationLatencySeconds: Double?,
        issues: [AnalysisDevicePerformanceIssue],
        limitations: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.runID = runID
        self.status = status
        self.structurallyValid = structurallyValid
        self.physicalDeviceClaim = physicalDeviceClaim
        self.peakResidentBytes = peakResidentBytes
        self.peakPhysicalFootprintBytes = peakPhysicalFootprintBytes
        self.worstThermalState = worstThermalState
        self.batteryLevelDelta = batteryLevelDelta
        self.batteryDrainFraction = batteryDrainFraction
        self.memoryPressureEventCount = memoryPressureEventCount
        self.thermalTransitionCount = thermalTransitionCount
        self.cancellationLatencySeconds = cancellationLatencySeconds
        self.issues = issues
        self.limitations = limitations
    }
}

public enum AnalysisDevicePerformanceEvidenceValidator {
    public static func validate(
        _ evidence: AnalysisDevicePerformanceEvidence,
        expectedManifestID: String,
        expectedManifestSHA256: String,
        evaluatedAt: Date = Date()
    ) -> AnalysisDevicePerformanceValidationReport {
        var issues: [AnalysisDevicePerformanceIssue] = []
        let p = evidence.provenance

        if evidence.schemaVersion != 1 {
            issues.append(.init(code: .invalidSchema, field: "schemaVersion", detail: "device performance evidence schema must be version 1"))
        }

        let requiredStrings: [(String, String)] = [
            ("runID", p.runID), ("deviceModel", p.deviceModel), ("osVersion", p.osVersion),
            ("appBundleIdentifier", p.appBundleIdentifier), ("appVersion", p.appVersion),
            ("buildVersion", p.buildVersion), ("manifestID", p.manifestID), ("fixtureID", p.fixtureID)
        ]
        for (field, value) in requiredStrings where trimmed(value).isEmpty {
            issues.append(.init(code: .invalidProvenance, field: field, detail: "required provenance field is empty"))
        }
        if !p.fixtureDurationSeconds.isFinite || p.fixtureDurationSeconds <= 0 {
            issues.append(.init(code: .invalidProvenance, field: "fixtureDurationSeconds", detail: "fixture duration must be finite and > 0"))
        }
        if !isSHA256(p.manifestSHA256) || !isSHA256(expectedManifestSHA256) || p.manifestID != expectedManifestID || p.manifestSHA256.lowercased() != expectedManifestSHA256.lowercased() {
            issues.append(.init(code: .manifestBindingMismatch, field: "manifest", detail: "evidence must bind to the exact HQ-selected manifest ID and SHA-256"))
        }

        if evidence.finishedAt < p.startedAt || !evidence.wallSeconds.isFinite || evidence.wallSeconds <= 0 {
            issues.append(.init(code: .invalidTiming, field: "wallSeconds", detail: "finish time and monotonic wall duration are inconsistent"))
        }
        if !evidence.requestedSampleIntervalSeconds.isFinite || evidence.requestedSampleIntervalSeconds <= 0 || evidence.maximumSampleCount < 1 || evidence.maximumSampleCount > 100_000 {
            issues.append(.init(code: .invalidSamplingConfiguration, detail: "sampling interval must be finite and > 0; maximum sample count must be 1...100000"))
        }
        if evidence.memorySamples.count > evidence.maximumSampleCount + 1 || evidence.thermalSamples.count > evidence.maximumSampleCount + 1 || evidence.batterySamples.count > evidence.maximumSampleCount + 1 {
            issues.append(.init(code: .invalidSamplingConfiguration, detail: "telemetry arrays exceed the configured bounded sample count"))
        }

        validateAvailability(evidence.memoryTelemetry, field: "memoryTelemetry", issues: &issues)
        validateAvailability(evidence.thermalTelemetry, field: "thermalTelemetry", issues: &issues)
        validateAvailability(evidence.batteryTelemetry, field: "batteryTelemetry", issues: &issues)
        validateAvailability(evidence.memoryPressureObservation, field: "memoryPressureObservation", issues: &issues)

        validateMemorySamples(evidence.memorySamples, wallSeconds: evidence.wallSeconds, issues: &issues)
        validateThermalSamples(evidence.thermalSamples, wallSeconds: evidence.wallSeconds, issues: &issues)
        validateBatterySamples(evidence.batterySamples, wallSeconds: evidence.wallSeconds, issues: &issues)
        validatePressureEvents(evidence.memoryPressureEvents, wallSeconds: evidence.wallSeconds, issues: &issues)

        let physical = p.runtimeClass == .physicalIOSDevice
        if physical {
            let requiredAvailability: [(String, AnalysisTelemetryChannelAvailability)] = [
                ("memoryTelemetry", evidence.memoryTelemetry),
                ("thermalTelemetry", evidence.thermalTelemetry),
                ("batteryTelemetry", evidence.batteryTelemetry),
                ("memoryPressureObservation", evidence.memoryPressureObservation)
            ]
            for (field, channel) in requiredAvailability where !channel.available {
                issues.append(.init(code: .unavailableRequiredTelemetry, field: field, detail: "physical-device evidence must expose this channel or remain incomplete"))
            }
            let usableMemory = evidence.memorySamples.contains { $0.residentBytes != nil && $0.physicalFootprintBytes != nil }
            let usableThermal = evidence.thermalSamples.contains { $0.state != .unavailable }
            let usableBattery = evidence.batterySamples.filter { $0.levelFraction != nil && $0.state != .unavailable }.count >= 2
            if !usableMemory || !usableThermal || !usableBattery {
                issues.append(.init(code: .missingRequiredSamples, detail: "physical-device evidence requires usable memory and thermal samples plus usable battery start/end samples"))
            }
        }

        var cancellationLatency: Double?
        let requested = evidence.cancellation.requestedOffsetSeconds
        let observed = evidence.cancellation.observedTerminationOffsetSeconds
        switch p.runKind {
        case .cancellationProbe:
            guard let request = requested, let termination = observed,
                  request.isFinite, termination.isFinite,
                  request >= 0, termination >= request, termination <= evidence.wallSeconds + 1e-6 else {
                issues.append(.init(code: .incompleteCancellationProbe, detail: "cancellation probe requires ordered request and observed-termination offsets within the run"))
                break
            }
            cancellationLatency = termination - request
        case .completeAnalysis:
            if requested != nil || observed != nil {
                issues.append(.init(code: .inconsistentCompletionState, detail: "complete-analysis runs must not contain cancellation probe timestamps"))
            }
        }

        if evidence.completedNormally {
            if !trimmed(evidence.failureDescription ?? "").isEmpty {
                issues.append(.init(code: .inconsistentCompletionState, detail: "completed run cannot also carry a failure description"))
            }
        } else if p.runKind == .completeAnalysis && trimmed(evidence.failureDescription ?? "").isEmpty {
            issues.append(.init(code: .inconsistentCompletionState, detail: "failed complete-analysis run must explain the failure"))
        }

        let peakResident = evidence.memorySamples.compactMap(\.residentBytes).max()
        let peakFootprint = evidence.memorySamples.compactMap(\.physicalFootprintBytes).max()
        let thermal = evidence.thermalSamples.map(\.state).filter { $0 != .unavailable }.max { $0.rank < $1.rank }
        let validBatteryLevels = evidence.batterySamples.compactMap(\.levelFraction)
        let batteryDelta: Double? = validBatteryLevels.count >= 2 ? validBatteryLevels.last! - validBatteryLevels.first! : nil
        let drain = batteryDelta.map { max(0, -$0) }
        let availableThermalStates = evidence.thermalSamples.map(\.state).filter { $0 != .unavailable }
        let thermalTransitions = zip(availableThermalStates, availableThermalStates.dropFirst()).filter { $0.0 != $0.1 }.count

        issues.sort {
            if $0.code.rawValue != $1.code.rawValue { return $0.code.rawValue < $1.code.rawValue }
            return ($0.field ?? "") < ($1.field ?? "")
        }

        let hardInvalidCodes: Set<AnalysisDevicePerformanceIssueCode> = [
            .invalidSchema, .invalidProvenance, .manifestBindingMismatch, .invalidTiming,
            .invalidSamplingConfiguration, .invalidMemorySample, .invalidThermalSample,
            .invalidBatterySample, .invalidPressureEvent, .incompleteCancellationProbe,
            .inconsistentCompletionState
        ]
        let hardInvalid = issues.contains { hardInvalidCodes.contains($0.code) }
        let telemetryIncomplete = issues.contains { $0.code == .unavailableRequiredTelemetry || $0.code == .missingRequiredSamples }

        let status: AnalysisDevicePerformanceValidationStatus
        if hardInvalid {
            status = .invalid
        } else if !physical {
            status = .nonPhysicalRuntime
        } else if telemetryIncomplete {
            status = .telemetryIncompletePendingHQ
        } else {
            status = .structurallyCompletePendingHQ
        }

        return .init(
            generatedAt: evaluatedAt,
            runID: p.runID,
            status: status,
            structurallyValid: !hardInvalid,
            physicalDeviceClaim: physical,
            peakResidentBytes: peakResident,
            peakPhysicalFootprintBytes: peakFootprint,
            worstThermalState: thermal,
            batteryLevelDelta: batteryDelta,
            batteryDrainFraction: drain,
            memoryPressureEventCount: evidence.memoryPressureEvents.count,
            thermalTransitionCount: thermalTransitions,
            cancellationLatencySeconds: cancellationLatency,
            issues: issues,
            limitations: evidence.limitations.sorted()
        )
    }

    private static func validateAvailability(_ value: AnalysisTelemetryChannelAvailability, field: String, issues: inout [AnalysisDevicePerformanceIssue]) {
        let reason = trimmed(value.unavailableReason ?? "")
        if value.available && !reason.isEmpty {
            issues.append(.init(code: .invalidProvenance, field: field, detail: "available channel must not carry an unavailable reason"))
        }
        if !value.available && reason.isEmpty {
            issues.append(.init(code: .invalidProvenance, field: field, detail: "unavailable channel must state the reason instead of fabricating zero telemetry"))
        }
    }

    private static func validateMemorySamples(_ values: [AnalysisDeviceMemorySample], wallSeconds: Double, issues: inout [AnalysisDevicePerformanceIssue]) {
        var previous = -Double.infinity
        for sample in values {
            if !sample.offsetSeconds.isFinite || sample.offsetSeconds < 0 || sample.offsetSeconds + 1e-6 < previous || sample.offsetSeconds > wallSeconds + 1e-6 {
                issues.append(.init(code: .invalidMemorySample, field: "offsetSeconds", detail: "memory sample offsets must be finite, monotonic and inside the run")); return
            }
            previous = sample.offsetSeconds
            if let value = sample.residentBytes {
                if value == 0 || !trimmed(sample.residentUnavailableReason ?? "").isEmpty {
                    issues.append(.init(code: .invalidMemorySample, field: "residentBytes", detail: "available resident memory must be > 0 and have no unavailable reason")); return
                }
            } else if trimmed(sample.residentUnavailableReason ?? "").isEmpty {
                issues.append(.init(code: .invalidMemorySample, field: "residentBytes", detail: "missing resident memory requires an explicit unavailable reason")); return
            }
            if let value = sample.physicalFootprintBytes {
                if value == 0 || !trimmed(sample.physicalFootprintUnavailableReason ?? "").isEmpty {
                    issues.append(.init(code: .invalidMemorySample, field: "physicalFootprintBytes", detail: "available physical footprint must be > 0 and have no unavailable reason")); return
                }
            } else if trimmed(sample.physicalFootprintUnavailableReason ?? "").isEmpty {
                issues.append(.init(code: .invalidMemorySample, field: "physicalFootprintBytes", detail: "missing physical footprint requires an explicit unavailable reason")); return
            }
        }
    }

    private static func validateThermalSamples(_ values: [AnalysisDeviceThermalSample], wallSeconds: Double, issues: inout [AnalysisDevicePerformanceIssue]) {
        var previous = -Double.infinity
        for sample in values {
            if !sample.offsetSeconds.isFinite || sample.offsetSeconds < 0 || sample.offsetSeconds + 1e-6 < previous || sample.offsetSeconds > wallSeconds + 1e-6 {
                issues.append(.init(code: .invalidThermalSample, field: "offsetSeconds", detail: "thermal sample offsets must be finite, monotonic and inside the run")); return
            }
            previous = sample.offsetSeconds
            let reason = trimmed(sample.unavailableReason ?? "")
            if sample.state == .unavailable && reason.isEmpty {
                issues.append(.init(code: .invalidThermalSample, field: "state", detail: "unavailable thermal state requires an explicit reason")); return
            }
            if sample.state != .unavailable && !reason.isEmpty {
                issues.append(.init(code: .invalidThermalSample, field: "state", detail: "available thermal state must not carry an unavailable reason")); return
            }
        }
    }

    private static func validateBatterySamples(_ values: [AnalysisDeviceBatterySample], wallSeconds: Double, issues: inout [AnalysisDevicePerformanceIssue]) {
        var previous = -Double.infinity
        for sample in values {
            if !sample.offsetSeconds.isFinite || sample.offsetSeconds < 0 || sample.offsetSeconds + 1e-6 < previous || sample.offsetSeconds > wallSeconds + 1e-6 {
                issues.append(.init(code: .invalidBatterySample, field: "offsetSeconds", detail: "battery sample offsets must be finite, monotonic and inside the run")); return
            }
            previous = sample.offsetSeconds
            let reason = trimmed(sample.unavailableReason ?? "")
            if let level = sample.levelFraction {
                if !level.isFinite || level < 0 || level > 1 || sample.state == .unavailable || !reason.isEmpty {
                    issues.append(.init(code: .invalidBatterySample, field: "levelFraction", detail: "available battery level must be finite in 0...1 with an available state")); return
                }
            } else if reason.isEmpty {
                issues.append(.init(code: .invalidBatterySample, field: "levelFraction", detail: "missing battery level requires an explicit unavailable reason")); return
            }
        }
    }

    private static func validatePressureEvents(_ values: [AnalysisDeviceMemoryPressureEvent], wallSeconds: Double, issues: inout [AnalysisDevicePerformanceIssue]) {
        var previous = -Double.infinity
        for event in values {
            if !event.offsetSeconds.isFinite || event.offsetSeconds < 0 || event.offsetSeconds + 1e-6 < previous || event.offsetSeconds > wallSeconds + 1e-6 || trimmed(event.source).isEmpty || trimmed(event.detail).isEmpty {
                issues.append(.init(code: .invalidPressureEvent, detail: "memory-pressure events must be ordered, bounded and carry source/detail")); return
            }
            previous = event.offsetSeconds
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
}

public enum AnalysisDevicePerformanceEvidenceCodec {
    public static func encodeEvidence(_ value: AnalysisDevicePerformanceEvidence) throws -> Data { try encoder().encode(value) }
    public static func decodeEvidence(_ data: Data) throws -> AnalysisDevicePerformanceEvidence { try decoder().decode(AnalysisDevicePerformanceEvidence.self, from: data) }
    public static func encodeReport(_ value: AnalysisDevicePerformanceValidationReport) throws -> Data { try encoder().encode(value) }
    public static func decodeReport(_ data: Data) throws -> AnalysisDevicePerformanceValidationReport { try decoder().decode(AnalysisDevicePerformanceValidationReport.self, from: data) }

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
