import Foundation

public struct AnalysisDevicePerformancePlannedRun: Codable, Equatable, Sendable {
    public let runID: String
    public let fixtureID: String
    public let runKind: AnalysisDevicePerformanceRunKind
    public init(runID: String, fixtureID: String, runKind: AnalysisDevicePerformanceRunKind) {
        self.runID = runID; self.fixtureID = fixtureID; self.runKind = runKind
    }
}

public struct AnalysisDevicePerformanceAcceptanceProfile: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let profileID, authority, approvalReference, expectedBatchID: String
    public let expectedDeviceModel, expectedOSVersion, expectedAppBundleIdentifier: String
    public let expectedAppVersion, expectedBuildVersion, expectedManifestID, expectedManifestSHA256: String
    public let requiredFixtureIDs: [String]
    public let expectedFixtureDurationsSeconds: [String: Double]
    public let minimumCompleteRunsPerFixture, minimumCancellationRunsPerFixture: Int
    public let plannedRuns: [AnalysisDevicePerformancePlannedRun]
    public let maximumCompleteWallSeconds: Double
    public let maximumPeakResidentBytes, maximumPeakPhysicalFootprintBytes: UInt64
    public let maximumStartingThermalState, maximumWorstThermalState: AnalysisDeviceThermalState
    public let maximumBatteryDrainFraction: Double
    public let maximumMemoryPressureEventCount: Int
    public let maximumCancellationLatencySeconds: Double
    public let requireUnpluggedBatteryForCompleteRuns: Bool

    public init(
        schemaVersion: Int = 1, profileID: String, authority: String, approvalReference: String,
        expectedBatchID: String, expectedDeviceModel: String, expectedOSVersion: String,
        expectedAppBundleIdentifier: String, expectedAppVersion: String, expectedBuildVersion: String,
        expectedManifestID: String, expectedManifestSHA256: String, requiredFixtureIDs: [String],
        expectedFixtureDurationsSeconds: [String: Double], minimumCompleteRunsPerFixture: Int,
        minimumCancellationRunsPerFixture: Int, plannedRuns: [AnalysisDevicePerformancePlannedRun],
        maximumCompleteWallSeconds: Double, maximumPeakResidentBytes: UInt64,
        maximumPeakPhysicalFootprintBytes: UInt64, maximumStartingThermalState: AnalysisDeviceThermalState,
        maximumWorstThermalState: AnalysisDeviceThermalState, maximumBatteryDrainFraction: Double,
        maximumMemoryPressureEventCount: Int, maximumCancellationLatencySeconds: Double,
        requireUnpluggedBatteryForCompleteRuns: Bool
    ) {
        self.schemaVersion = schemaVersion; self.profileID = profileID; self.authority = authority
        self.approvalReference = approvalReference; self.expectedBatchID = expectedBatchID
        self.expectedDeviceModel = expectedDeviceModel; self.expectedOSVersion = expectedOSVersion
        self.expectedAppBundleIdentifier = expectedAppBundleIdentifier; self.expectedAppVersion = expectedAppVersion
        self.expectedBuildVersion = expectedBuildVersion; self.expectedManifestID = expectedManifestID
        self.expectedManifestSHA256 = expectedManifestSHA256.lowercased(); self.requiredFixtureIDs = requiredFixtureIDs
        self.expectedFixtureDurationsSeconds = expectedFixtureDurationsSeconds
        self.minimumCompleteRunsPerFixture = minimumCompleteRunsPerFixture
        self.minimumCancellationRunsPerFixture = minimumCancellationRunsPerFixture; self.plannedRuns = plannedRuns
        self.maximumCompleteWallSeconds = maximumCompleteWallSeconds; self.maximumPeakResidentBytes = maximumPeakResidentBytes
        self.maximumPeakPhysicalFootprintBytes = maximumPeakPhysicalFootprintBytes
        self.maximumStartingThermalState = maximumStartingThermalState; self.maximumWorstThermalState = maximumWorstThermalState
        self.maximumBatteryDrainFraction = maximumBatteryDrainFraction
        self.maximumMemoryPressureEventCount = maximumMemoryPressureEventCount
        self.maximumCancellationLatencySeconds = maximumCancellationLatencySeconds
        self.requireUnpluggedBatteryForCompleteRuns = requireUnpluggedBatteryForCompleteRuns
    }
}

public struct AnalysisDevicePerformanceEvidenceBatch: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let batchID, profileID: String
    public let runs: [AnalysisDevicePerformanceEvidence]
    public init(schemaVersion: Int = 1, batchID: String, profileID: String, runs: [AnalysisDevicePerformanceEvidence]) {
        self.schemaVersion = schemaVersion; self.batchID = batchID; self.profileID = profileID; self.runs = runs
    }
}

public enum AnalysisDevicePerformanceAcceptanceIssueCode: String, Codable, Hashable, Sendable {
    case invalidProfile = "INVALID_PROFILE", invalidBatch = "INVALID_BATCH", duplicateRunID = "DUPLICATE_RUN_ID"
    case missingPlannedRun = "MISSING_PLANNED_RUN", unexpectedRun = "UNEXPECTED_RUN", bindingMismatch = "BINDING_MISMATCH"
    case nonPhysicalRun = "NON_PHYSICAL_RUN", structurallyIncompleteRun = "STRUCTURALLY_INCOMPLETE_RUN"
    case failedCompleteAnalysis = "FAILED_COMPLETE_ANALYSIS", invalidBatteryPrecondition = "INVALID_BATTERY_PRECONDITION"
    case invalidThermalPrecondition = "INVALID_THERMAL_PRECONDITION", telemetryUnavailable = "TELEMETRY_UNAVAILABLE"
    case approvedLimitExceeded = "APPROVED_LIMIT_EXCEEDED"
}

public struct AnalysisDevicePerformanceAcceptanceIssue: Codable, Equatable, Sendable {
    public let code: AnalysisDevicePerformanceAcceptanceIssueCode
    public let fixtureID, runID, metric: String?
    public let detail: String
}

public struct AnalysisDevicePerformanceWorstValue: Codable, Equatable, Sendable {
    public let metric: String
    public let value, limit: Double
    public let runID: String
    public let withinApprovedLimit: Bool
}

public struct AnalysisDevicePerformanceFixtureAcceptance: Codable, Equatable, Sendable {
    public let fixtureID: String
    public let completeRunIDs, cancellationRunIDs: [String]
    public let worstMetrics: [AnalysisDevicePerformanceWorstValue]
    public let withinApprovedLimits: Bool
}

public enum AnalysisDevicePerformanceAcceptanceStatus: String, Codable, Sendable {
    case invalidProfile = "INVALID_PROFILE"
    case incompleteEvidence = "INCOMPLETE_PHYSICAL_DEVICE_EVIDENCE"
    case outsideApprovedLimits = "OUTSIDE_HQ_APPROVED_LIMITS"
    case withinApprovedLimitsPendingHQ = "WITHIN_HQ_APPROVED_LIMITS_PENDING_HQ"
}

public struct AnalysisDevicePerformanceAcceptanceReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let generatedAt: Date
    public let profileID, batchID: String
    public let status: AnalysisDevicePerformanceAcceptanceStatus
    public let completePlannedRunSet: Bool
    public let fixtureDiagnostics: [AnalysisDevicePerformanceFixtureAcceptance]
    public let issues: [AnalysisDevicePerformanceAcceptanceIssue]
}

public enum AnalysisDevicePerformanceAcceptanceEvaluator {
    public static func evaluate(
        batch: AnalysisDevicePerformanceEvidenceBatch,
        profile: AnalysisDevicePerformanceAcceptanceProfile,
        evaluatedAt: Date = Date()
    ) -> AnalysisDevicePerformanceAcceptanceReport {
        var issues = validateProfile(profile)
        if !issues.isEmpty { return report(profile, batch, .invalidProfile, false, [], issues, evaluatedAt) }

        if batch.schemaVersion != 1 || trimmed(batch.batchID).isEmpty || batch.batchID != profile.expectedBatchID || batch.profileID != profile.profileID {
            issues.append(issue(.invalidBatch, detail: "batch must use schema 1 and match the HQ-approved batch/profile identifiers"))
        }
        let plannedByRun = firstByRunID(profile.plannedRuns)
        let plannedByFixture = groupPlanned(profile.plannedRuns)
        var actualByRun: [String: AnalysisDevicePerformanceEvidence] = [:]
        var duplicates = Set<String>()
        for run in batch.runs {
            let id = run.provenance.runID
            if actualByRun[id] == nil { actualByRun[id] = run } else { duplicates.insert(id) }
        }
        for id in duplicates.sorted() { issues.append(issue(.duplicateRunID, runID: id, detail: "run ID appears more than once")) }

        let plannedIDs = Set(plannedByRun.keys), actualIDs = Set(actualByRun.keys)
        for id in plannedIDs.subtracting(actualIDs).sorted() {
            issues.append(issue(.missingPlannedRun, fixtureID: plannedByRun[id]?.fixtureID, runID: id, detail: "predeclared run is missing; unfavorable planned runs cannot be dropped"))
        }
        for id in actualIDs.subtracting(plannedIDs).sorted() {
            issues.append(issue(.unexpectedRun, fixtureID: actualByRun[id]?.provenance.fixtureID, runID: id, detail: "run was not predeclared by HQ"))
        }

        var validated: [String: AnalysisDevicePerformanceValidationReport] = [:]
        for id in actualIDs.intersection(plannedIDs).sorted() {
            guard let run = actualByRun[id], let planned = plannedByRun[id] else { continue }
            let v = AnalysisDevicePerformanceEvidenceValidator.validate(run, expectedManifestID: profile.expectedManifestID, expectedManifestSHA256: profile.expectedManifestSHA256, evaluatedAt: evaluatedAt)
            validated[id] = v
            validateBinding(run, planned, profile, &issues)
            if run.provenance.runtimeClass != .physicalIOSDevice || !v.physicalDeviceClaim {
                issues.append(issue(.nonPhysicalRun, fixtureID: planned.fixtureID, runID: id, detail: "physical iOS device evidence is required"))
            }
            if v.status != .structurallyCompletePendingHQ {
                issues.append(issue(.structurallyIncompleteRun, fixtureID: planned.fixtureID, runID: id, detail: "W23 structural validation must be complete"))
            }
            if planned.runKind == .completeAnalysis {
                if !run.completedNormally { issues.append(issue(.failedCompleteAnalysis, fixtureID: planned.fixtureID, runID: id, detail: "complete-analysis run did not complete normally")) }
                validatePreconditions(run, profile, &issues)
            }
        }

        let incomplete: Set<AnalysisDevicePerformanceAcceptanceIssueCode> = [
            .invalidBatch, .duplicateRunID, .missingPlannedRun, .unexpectedRun, .bindingMismatch, .nonPhysicalRun,
            .structurallyIncompleteRun, .failedCompleteAnalysis, .invalidBatteryPrecondition,
            .invalidThermalPrecondition, .telemetryUnavailable
        ]
        if issues.contains(where: { incomplete.contains($0.code) }) {
            return report(profile, batch, .incompleteEvidence, false, [], issues, evaluatedAt)
        }

        var diagnostics: [AnalysisDevicePerformanceFixtureAcceptance] = []
        for fixtureID in profile.requiredFixtureIDs.sorted() {
            diagnostics.append(aggregate(fixtureID, plannedByFixture[fixtureID] ?? [], profile, actualByRun, validated, &issues))
        }
        let complete = !issues.contains(where: { incomplete.contains($0.code) })
        let status: AnalysisDevicePerformanceAcceptanceStatus = !complete ? .incompleteEvidence :
            (issues.contains(where: { $0.code == .approvedLimitExceeded }) ? .outsideApprovedLimits : .withinApprovedLimitsPendingHQ)
        return report(profile, batch, status, complete, diagnostics, issues, evaluatedAt)
    }

    private static func validateProfile(_ p: AnalysisDevicePerformanceAcceptanceProfile) -> [AnalysisDevicePerformanceAcceptanceIssue] {
        var out: [AnalysisDevicePerformanceAcceptanceIssue] = []
        let text = [p.profileID, p.approvalReference, p.expectedBatchID, p.expectedDeviceModel, p.expectedOSVersion,
                    p.expectedAppBundleIdentifier, p.expectedAppVersion, p.expectedBuildVersion, p.expectedManifestID]
        if p.schemaVersion != 1 || p.authority != "HQ_LATE_INTEGRATION" || text.contains(where: { trimmed($0).isEmpty }) || !isSHA256(p.expectedManifestSHA256) {
            out.append(issue(.invalidProfile, detail: "profile requires schema 1, HQ authority, nonempty bindings and valid manifest SHA-256"))
        }
        if p.minimumCompleteRunsPerFixture < 2 || p.minimumCancellationRunsPerFixture < 2 {
            out.append(issue(.invalidProfile, detail: "repeatability requires at least two complete and two cancellation runs per fixture"))
        }
        let required = Set(p.requiredFixtureIDs)
        if p.requiredFixtureIDs.isEmpty || required.count != p.requiredFixtureIDs.count || p.requiredFixtureIDs.contains(where: { trimmed($0).isEmpty }) {
            out.append(issue(.invalidProfile, detail: "required fixture IDs must be nonempty and unique"))
        }
        if Set(p.expectedFixtureDurationsSeconds.keys) != required || p.expectedFixtureDurationsSeconds.values.contains(where: { !$0.isFinite || $0 <= 0 }) {
            out.append(issue(.invalidProfile, detail: "fixture durations must exactly cover required fixtures with finite positive values"))
        }
        if !p.maximumCompleteWallSeconds.isFinite || p.maximumCompleteWallSeconds <= 0 || p.maximumPeakResidentBytes == 0 || p.maximumPeakPhysicalFootprintBytes == 0 ||
            !p.maximumBatteryDrainFraction.isFinite || p.maximumBatteryDrainFraction < 0 || p.maximumBatteryDrainFraction > 1 || p.maximumMemoryPressureEventCount < 0 ||
            !p.maximumCancellationLatencySeconds.isFinite || p.maximumCancellationLatencySeconds <= 0 || p.maximumStartingThermalState == .unavailable ||
            p.maximumWorstThermalState == .unavailable || thermalRank(p.maximumStartingThermalState) > thermalRank(p.maximumWorstThermalState) {
            out.append(issue(.invalidProfile, detail: "HQ-approved limits are invalid or incomplete"))
        }
        if p.plannedRuns.isEmpty { out.append(issue(.invalidProfile, detail: "exact run plan must be predeclared")) }
        var seen = Set<String>(), counts: [String: (Int, Int)] = [:]
        for x in p.plannedRuns {
            if trimmed(x.runID).isEmpty || trimmed(x.fixtureID).isEmpty || !required.contains(x.fixtureID) || !seen.insert(x.runID).inserted {
                out.append(issue(.invalidProfile, fixtureID: x.fixtureID, runID: x.runID, detail: "planned runs require unique IDs and required fixtures"))
            }
            var c = counts[x.fixtureID] ?? (0, 0)
            if x.runKind == .completeAnalysis { c.0 += 1 } else { c.1 += 1 }
            counts[x.fixtureID] = c
        }
        for id in p.requiredFixtureIDs {
            let c = counts[id] ?? (0, 0)
            if c.0 < p.minimumCompleteRunsPerFixture || c.1 < p.minimumCancellationRunsPerFixture {
                out.append(issue(.invalidProfile, fixtureID: id, detail: "predeclared plan does not satisfy minimum repetitions"))
            }
        }
        return out.sorted(by: sortIssue)
    }

    private static func validateBinding(_ run: AnalysisDevicePerformanceEvidence, _ planned: AnalysisDevicePerformancePlannedRun, _ p: AnalysisDevicePerformanceAcceptanceProfile, _ issues: inout [AnalysisDevicePerformanceAcceptanceIssue]) {
        let x = run.provenance
        let durationOK = p.expectedFixtureDurationsSeconds[planned.fixtureID].map { abs(x.fixtureDurationSeconds - $0) <= 0.001 } ?? false
        let ok = x.runID == planned.runID && x.fixtureID == planned.fixtureID && x.runKind == planned.runKind && durationOK &&
            x.deviceModel == p.expectedDeviceModel && x.osVersion == p.expectedOSVersion && x.appBundleIdentifier == p.expectedAppBundleIdentifier &&
            x.appVersion == p.expectedAppVersion && x.buildVersion == p.expectedBuildVersion && x.manifestID == p.expectedManifestID &&
            x.manifestSHA256.lowercased() == p.expectedManifestSHA256.lowercased()
        if !ok { issues.append(issue(.bindingMismatch, fixtureID: planned.fixtureID, runID: planned.runID, detail: "run kind, fixture/duration, build, device, OS or manifest binding differs")) }
    }

    private static func validatePreconditions(_ run: AnalysisDevicePerformanceEvidence, _ p: AnalysisDevicePerformanceAcceptanceProfile, _ issues: inout [AnalysisDevicePerformanceAcceptanceIssue]) {
        let f = run.provenance.fixtureID, id = run.provenance.runID
        if let start = run.thermalSamples.first(where: { $0.state != .unavailable })?.state, thermalRank(start) > thermalRank(p.maximumStartingThermalState) {
            issues.append(issue(.invalidThermalPrecondition, fixtureID: f, runID: id, metric: "starting_thermal_state", detail: "run started above approved thermal precondition"))
        }
        if p.requireUnpluggedBatteryForCompleteRuns {
            let states = run.batterySamples.filter { $0.levelFraction != nil && $0.state != .unavailable }.map(\.state)
            if states.isEmpty || states.contains(where: { $0 != .unplugged }) {
                issues.append(issue(.invalidBatteryPrecondition, fixtureID: f, runID: id, metric: "battery_state", detail: "battery-drain runs must remain UNPLUGGED"))
            }
        }
    }

    private static func aggregate(_ fixtureID: String, _ planned: [AnalysisDevicePerformancePlannedRun], _ p: AnalysisDevicePerformanceAcceptanceProfile,
                                  _ actual: [String: AnalysisDevicePerformanceEvidence], _ validated: [String: AnalysisDevicePerformanceValidationReport],
                                  _ issues: inout [AnalysisDevicePerformanceAcceptanceIssue]) -> AnalysisDevicePerformanceFixtureAcceptance {
        let complete = planned.filter { $0.runKind == .completeAnalysis }.map(\.runID).sorted()
        let cancel = planned.filter { $0.runKind == .cancellationProbe }.map(\.runID).sorted()
        var worst: [AnalysisDevicePerformanceWorstValue] = []
        func add(_ metric: String, _ limit: Double, _ candidates: [(String, Double)]) {
            guard let x = candidates.max(by: { $0.1 == $1.1 ? $0.0 > $1.0 : $0.1 < $1.1 }) else {
                issues.append(issue(.telemetryUnavailable, fixtureID: fixtureID, metric: metric, detail: "planned runs do not expose required telemetry")); return
            }
            let within = x.1 <= limit
            worst.append(.init(metric: metric, value: x.1, limit: limit, runID: x.0, withinApprovedLimit: within))
            if !within { issues.append(issue(.approvedLimitExceeded, fixtureID: fixtureID, runID: x.0, metric: metric, detail: "worst value \(x.1) exceeds approved limit \(limit)")) }
        }
        add("complete_wall_seconds", p.maximumCompleteWallSeconds, complete.compactMap { id in actual[id].map { (id, $0.wallSeconds) } })
        add("peak_resident_bytes", Double(p.maximumPeakResidentBytes), complete.compactMap { id in validated[id]?.peakResidentBytes.map { (id, Double($0)) } })
        add("peak_physical_footprint_bytes", Double(p.maximumPeakPhysicalFootprintBytes), complete.compactMap { id in validated[id]?.peakPhysicalFootprintBytes.map { (id, Double($0)) } })
        add("worst_thermal_rank", Double(thermalRank(p.maximumWorstThermalState)), complete.compactMap { id in validated[id]?.worstThermalState.map { (id, Double(thermalRank($0))) } })
        add("battery_drain_fraction", p.maximumBatteryDrainFraction, complete.compactMap { id in validated[id]?.batteryDrainFraction.map { (id, $0) } })
        add("memory_pressure_event_count", Double(p.maximumMemoryPressureEventCount), complete.compactMap { id in validated[id].map { (id, Double($0.memoryPressureEventCount)) } })
        add("cancellation_latency_seconds", p.maximumCancellationLatencySeconds, cancel.compactMap { id in validated[id]?.cancellationLatencySeconds.map { (id, $0) } })
        worst.sort { $0.metric < $1.metric }
        return .init(fixtureID: fixtureID, completeRunIDs: complete, cancellationRunIDs: cancel, worstMetrics: worst,
                     withinApprovedLimits: worst.count == 7 && worst.allSatisfy(\.withinApprovedLimit))
    }

    private static func firstByRunID(_ xs: [AnalysisDevicePerformancePlannedRun]) -> [String: AnalysisDevicePerformancePlannedRun] {
        var out: [String: AnalysisDevicePerformancePlannedRun] = [:]; for x in xs where out[x.runID] == nil { out[x.runID] = x }; return out
    }
    private static func groupPlanned(_ xs: [AnalysisDevicePerformancePlannedRun]) -> [String: [AnalysisDevicePerformancePlannedRun]] {
        var out: [String: [AnalysisDevicePerformancePlannedRun]] = [:]; for x in xs { out[x.fixtureID, default: []].append(x) }; return out
    }
    private static func thermalRank(_ x: AnalysisDeviceThermalState) -> Int {
        switch x { case .nominal: 0; case .fair: 1; case .serious: 2; case .critical: 3; case .unavailable: Int.max }
    }
    private static func isSHA256(_ s: String) -> Bool { s.count == 64 && s.unicodeScalars.allSatisfy { (48...57).contains($0.value) || (65...70).contains($0.value) || (97...102).contains($0.value) } }
    private static func trimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }
    private static func issue(_ code: AnalysisDevicePerformanceAcceptanceIssueCode, fixtureID: String? = nil, runID: String? = nil, metric: String? = nil, detail: String) -> AnalysisDevicePerformanceAcceptanceIssue { .init(code: code, fixtureID: fixtureID, runID: runID, metric: metric, detail: detail) }
    private static func sortIssue(_ a: AnalysisDevicePerformanceAcceptanceIssue, _ b: AnalysisDevicePerformanceAcceptanceIssue) -> Bool {
        (a.code.rawValue, a.fixtureID ?? "", a.runID ?? "", a.metric ?? "") < (b.code.rawValue, b.fixtureID ?? "", b.runID ?? "", b.metric ?? "")
    }
    private static func report(_ p: AnalysisDevicePerformanceAcceptanceProfile, _ b: AnalysisDevicePerformanceEvidenceBatch, _ s: AnalysisDevicePerformanceAcceptanceStatus,
                               _ complete: Bool, _ d: [AnalysisDevicePerformanceFixtureAcceptance], _ i: [AnalysisDevicePerformanceAcceptanceIssue], _ date: Date) -> AnalysisDevicePerformanceAcceptanceReport {
        .init(schemaVersion: 1, generatedAt: date, profileID: p.profileID, batchID: b.batchID, status: s, completePlannedRunSet: complete,
              fixtureDiagnostics: d.sorted { $0.fixtureID < $1.fixtureID }, issues: i.sorted(by: sortIssue))
    }
}

public enum AnalysisDevicePerformanceAcceptanceCodec {
    public static func encodeProfile(_ x: AnalysisDevicePerformanceAcceptanceProfile) throws -> Data { try enc().encode(x) }
    public static func decodeProfile(_ x: Data) throws -> AnalysisDevicePerformanceAcceptanceProfile { try dec().decode(AnalysisDevicePerformanceAcceptanceProfile.self, from: x) }
    public static func encodeBatch(_ x: AnalysisDevicePerformanceEvidenceBatch) throws -> Data { try enc().encode(x) }
    public static func decodeBatch(_ x: Data) throws -> AnalysisDevicePerformanceEvidenceBatch { try dec().decode(AnalysisDevicePerformanceEvidenceBatch.self, from: x) }
    public static func encodeReport(_ x: AnalysisDevicePerformanceAcceptanceReport) throws -> Data { try enc().encode(x) }
    public static func decodeReport(_ x: Data) throws -> AnalysisDevicePerformanceAcceptanceReport { try dec().decode(AnalysisDevicePerformanceAcceptanceReport.self, from: x) }
    private static func enc() -> JSONEncoder { let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]; e.dateEncodingStrategy = .iso8601; return e }
    private static func dec() -> JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }
}
