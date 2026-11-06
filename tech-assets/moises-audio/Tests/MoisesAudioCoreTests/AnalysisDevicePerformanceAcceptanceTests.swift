import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisDevicePerformanceAcceptanceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_787_533_800)
    private let sha = String(repeating: "a", count: 64)

    private func plan(_ fixture: String = "long-a") -> [AnalysisDevicePerformancePlannedRun] {
        [
            .init(runID: "\(fixture)-c1", fixtureID: fixture, runKind: .completeAnalysis),
            .init(runID: "\(fixture)-c2", fixtureID: fixture, runKind: .completeAnalysis),
            .init(runID: "\(fixture)-x1", fixtureID: fixture, runKind: .cancellationProbe),
            .init(runID: "\(fixture)-x2", fixtureID: fixture, runKind: .cancellationProbe)
        ]
    }

    private func profile(plannedRuns: [AnalysisDevicePerformancePlannedRun]? = nil) -> AnalysisDevicePerformanceAcceptanceProfile {
        .init(
            profileID: "p1", authority: "HQ_LATE_INTEGRATION", approvalReference: "HQ-P021-001",
            expectedBatchID: "b1", expectedDeviceModel: "iPhone17,3", expectedOSVersion: "20.0",
            expectedAppBundleIdentifier: "com.example.moises", expectedAppVersion: "1.0", expectedBuildVersion: "100",
            expectedManifestID: "golden-v1", expectedManifestSHA256: sha,
            requiredFixtureIDs: ["long-a"], expectedFixtureDurationsSeconds: ["long-a": 3600],
            minimumCompleteRunsPerFixture: 2, minimumCancellationRunsPerFixture: 2,
            plannedRuns: plannedRuns ?? plan(), maximumCompleteWallSeconds: 12,
            maximumPeakResidentBytes: 300_000_000, maximumPeakPhysicalFootprintBytes: 400_000_000,
            maximumStartingThermalState: .fair, maximumWorstThermalState: .serious,
            maximumBatteryDrainFraction: 0.05, maximumMemoryPressureEventCount: 0,
            maximumCancellationLatencySeconds: 0.25, requireUnpluggedBatteryForCompleteRuns: true
        )
    }

    private func evidence(
        _ runID: String,
        kind: AnalysisDevicePerformanceRunKind,
        wall: Double = 10,
        resident: UInt64 = 200_000_000,
        footprint: UInt64 = 250_000_000,
        startThermal: AnalysisDeviceThermalState = .nominal,
        worstThermal: AnalysisDeviceThermalState = .fair,
        drain: Double = 0.02,
        pressureEvents: Int = 0,
        cancellationLatency: Double = 0.1,
        runtime: AnalysisDeviceRuntimeClass = .physicalIOSDevice,
        build: String = "100",
        duration: Double = 3600,
        completed: Bool = true,
        batteryState: AnalysisDeviceBatteryState = .unplugged,
        telemetryAvailable: Bool = true
    ) -> AnalysisDevicePerformanceEvidence {
        let provenance = AnalysisDevicePerformanceProvenance(
            runID: runID, runKind: kind, startedAt: now, runtimeClass: runtime,
            deviceModel: "iPhone17,3", osVersion: "20.0", appBundleIdentifier: "com.example.moises",
            appVersion: "1.0", buildVersion: build, manifestID: "golden-v1", manifestSHA256: sha,
            fixtureID: "long-a", fixtureDurationSeconds: duration
        )
        let available = AnalysisTelemetryChannelAvailability.availableChannel
        let unavailable = AnalysisTelemetryChannelAvailability.unavailable("test unavailable")
        let memory = telemetryAvailable
            ? [AnalysisDeviceMemorySample(offsetSeconds: 0, residentBytes: resident, physicalFootprintBytes: footprint)]
            : [AnalysisDeviceMemorySample(offsetSeconds: 0, residentBytes: nil, residentUnavailableReason: "test", physicalFootprintBytes: nil, physicalFootprintUnavailableReason: "test")]
        let thermal = telemetryAvailable
            ? [AnalysisDeviceThermalSample(offsetSeconds: 0, state: startThermal), AnalysisDeviceThermalSample(offsetSeconds: wall, state: worstThermal)]
            : [AnalysisDeviceThermalSample(offsetSeconds: 0, state: .unavailable, unavailableReason: "test")]
        let battery = telemetryAvailable
            ? [AnalysisDeviceBatterySample(offsetSeconds: 0, levelFraction: 0.8, state: batteryState), AnalysisDeviceBatterySample(offsetSeconds: wall, levelFraction: 0.8 - drain, state: batteryState)]
            : [AnalysisDeviceBatterySample(offsetSeconds: 0, levelFraction: nil, state: .unavailable, unavailableReason: "test")]
        let pressure = (0..<pressureEvents).map { AnalysisDeviceMemoryPressureEvent(offsetSeconds: min(wall, Double($0) + 0.5), source: "UIApplication", detail: "memory warning") }
        let cancellation: AnalysisDeviceCancellationTelemetry = kind == .cancellationProbe
            ? .init(requestedOffsetSeconds: 1, observedTerminationOffsetSeconds: 1 + cancellationLatency)
            : .init(requestedOffsetSeconds: nil, observedTerminationOffsetSeconds: nil)
        return .init(
            provenance: provenance, finishedAt: now.addingTimeInterval(wall), wallSeconds: wall,
            requestedSampleIntervalSeconds: 1, maximumSampleCount: 100,
            memoryTelemetry: telemetryAvailable ? available : unavailable,
            thermalTelemetry: telemetryAvailable ? available : unavailable,
            batteryTelemetry: telemetryAvailable ? available : unavailable,
            memoryPressureObservation: available,
            memorySamples: memory, thermalSamples: thermal, batterySamples: battery,
            memoryPressureEvents: pressure, cancellation: cancellation,
            completedNormally: completed, failureDescription: completed ? nil : (kind == .completeAnalysis ? "failed" : nil)
        )
    }

    private func goodRuns() -> [AnalysisDevicePerformanceEvidence] {
        plan().map { evidence($0.runID, kind: $0.runKind, completed: $0.runKind == .completeAnalysis) }
    }

    private func batch(_ runs: [AnalysisDevicePerformanceEvidence]) -> AnalysisDevicePerformanceEvidenceBatch {
        .init(batchID: "b1", profileID: "p1", runs: runs)
    }

    func testApprovedRepeatedPhysicalRunsRemainPendingHQRatherThanParity() {
        let result = AnalysisDevicePerformanceAcceptanceEvaluator.evaluate(batch: batch(goodRuns()), profile: profile(), evaluatedAt: now)
        XCTAssertEqual(result.status, .withinApprovedLimitsPendingHQ)
        XCTAssertTrue(result.completePlannedRunSet)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.fixtureDiagnostics.first?.worstMetrics.count, 7)
    }

    func testWorstRunIsUsedInsteadOfMeanAndPreservesRunProvenance() {
        var runs = goodRuns()
        runs[0] = evidence("long-a-c1", kind: .completeAnalysis, wall: 11)
        runs[1] = evidence("long-a-c2", kind: .completeAnalysis, wall: 20)
        let result = AnalysisDevicePerformanceAcceptanceEvaluator.evaluate(batch: batch(runs), profile: profile(), evaluatedAt: now)
        XCTAssertEqual(result.status, .outsideApprovedLimits)
        let wall = result.fixtureDiagnostics[0].worstMetrics.first { $0.metric == "complete_wall_seconds" }
        XCTAssertEqual(wall?.runID, "long-a-c2")
        XCTAssertEqual(wall?.value, 20)
        XCTAssertFalse(wall?.withinApprovedLimit ?? true)
    }

    func testMissingUnexpectedAndDuplicateRunsFailClosed() {
        let missing = AnalysisDevicePerformanceAcceptanceEvaluator.evaluate(batch: batch(Array(goodRuns().dropLast())), profile: profile(), evaluatedAt: now)
        XCTAssertEqual(missing.status, .incompleteEvidence)
        XCTAssertTrue(missing.issues.contains { $0.code == .missingPlannedRun })

        let extra = AnalysisDevicePerformanceAcceptanceEvaluator.evaluate(batch: batch(goodRuns() + [evidence("extra", kind: .completeAnalysis)]), profile: profile(), evaluatedAt: now)
        XCTAssertTrue(extra.issues.contains { $0.code == .unexpectedRun })

        let duplicate = AnalysisDevicePerformanceAcceptanceEvaluator.evaluate(batch: batch(goodRuns() + [goodRuns()[0]]), profile: profile(), evaluatedAt: now)
        XCTAssertTrue(duplicate.issues.contains { $0.code == .duplicateRunID })
    }

    func testBuildRuntimeDurationAndTelemetryBindingFailClosed() {
        var mixed = goodRuns()
        mixed[0] = evidence("long-a-c1", kind: .completeAnalysis, build: "101")
        XCTAssertTrue(AnalysisDevicePerformanceAcceptanceEvaluator.evaluate(batch: batch(mixed), profile: profile()).issues.contains { $0.code == .bindingMismatch })

        var simulator = goodRuns()
        simulator[0] = evidence("long-a-c1", kind: .completeAnalysis, runtime: .iOSSimulator)
        XCTAssertTrue(AnalysisDevicePerformanceAcceptanceEvaluator.evaluate(batch: batch(simulator), profile: profile()).issues.contains { $0.code == .nonPhysicalRun })

        var duration = goodRuns()
        duration[0] = evidence("long-a-c1", kind: .completeAnalysis, duration: 3599)
        XCTAssertTrue(AnalysisDevicePerformanceAcceptanceEvaluator.evaluate(batch: batch(duration), profile: profile()).issues.contains { $0.code == .bindingMismatch })

        var unavailable = goodRuns()
        unavailable[0] = evidence("long-a-c1", kind: .completeAnalysis, telemetryAvailable: false)
        XCTAssertTrue(AnalysisDevicePerformanceAcceptanceEvaluator.evaluate(batch: batch(unavailable), profile: profile()).issues.contains { $0.code == .structurallyIncompleteRun })
    }

    func testCompleteRunPreconditionsAndFailuresCannotBeAveragedAway() {
        var failed = goodRuns()
        failed[0] = evidence("long-a-c1", kind: .completeAnalysis, completed: false)
        XCTAssertTrue(AnalysisDevicePerformanceAcceptanceEvaluator.evaluate(batch: batch(failed), profile: profile()).issues.contains { $0.code == .failedCompleteAnalysis })

        var charging = goodRuns()
        charging[0] = evidence("long-a-c1", kind: .completeAnalysis, batteryState: .charging)
        XCTAssertTrue(AnalysisDevicePerformanceAcceptanceEvaluator.evaluate(batch: batch(charging), profile: profile()).issues.contains { $0.code == .invalidBatteryPrecondition })

        var hot = goodRuns()
        hot[0] = evidence("long-a-c1", kind: .completeAnalysis, startThermal: .serious, worstThermal: .serious)
        XCTAssertTrue(AnalysisDevicePerformanceAcceptanceEvaluator.evaluate(batch: batch(hot), profile: profile()).issues.contains { $0.code == .invalidThermalPrecondition })
    }

    func testAllApprovedLimitsUseWorstObservedValues() {
        var runs = goodRuns()
        runs[0] = evidence("long-a-c1", kind: .completeAnalysis, resident: 350_000_000)
        runs[1] = evidence("long-a-c2", kind: .completeAnalysis, footprint: 450_000_000, worstThermal: .critical, drain: 0.08, pressureEvents: 1)
        runs[2] = evidence("long-a-x1", kind: .cancellationProbe, cancellationLatency: 0.4, completed: false)
        let result = AnalysisDevicePerformanceAcceptanceEvaluator.evaluate(batch: batch(runs), profile: profile(), evaluatedAt: now)
        XCTAssertEqual(result.status, .outsideApprovedLimits)
        XCTAssertGreaterThanOrEqual(result.issues.filter { $0.code == .approvedLimitExceeded }.count, 6)
    }

    func testProfileRequiresPredeclaredRepeatedRunPlanAndCodecIsDeterministic() throws {
        let invalid = profile(plannedRuns: [
            .init(runID: "long-a-c1", fixtureID: "long-a", runKind: .completeAnalysis),
            .init(runID: "long-a-x1", fixtureID: "long-a", runKind: .cancellationProbe)
        ])
        XCTAssertEqual(AnalysisDevicePerformanceAcceptanceEvaluator.evaluate(batch: batch([]), profile: invalid).status, .invalidProfile)

        let value = profile()
        let a = try AnalysisDevicePerformanceAcceptanceCodec.encodeProfile(value)
        let b = try AnalysisDevicePerformanceAcceptanceCodec.encodeProfile(value)
        XCTAssertEqual(a, b)
        XCTAssertEqual(try AnalysisDevicePerformanceAcceptanceCodec.decodeProfile(a), value)
    }

    func testEqualWorstValuesUseDeterministicLexicographicRunID() {
        var runs = goodRuns()
        runs[0] = evidence("long-a-c1", kind: .completeAnalysis, wall: 11)
        runs[1] = evidence("long-a-c2", kind: .completeAnalysis, wall: 11)
        let result = AnalysisDevicePerformanceAcceptanceEvaluator.evaluate(batch: batch(runs), profile: profile())
        XCTAssertEqual(result.fixtureDiagnostics[0].worstMetrics.first { $0.metric == "complete_wall_seconds" }?.runID, "long-a-c1")
    }
}
