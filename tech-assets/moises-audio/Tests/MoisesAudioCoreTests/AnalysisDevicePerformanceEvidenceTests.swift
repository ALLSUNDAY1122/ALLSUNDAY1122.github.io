import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisDevicePerformanceEvidenceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_787_533_200)
    private let manifestSHA = String(repeating: "a", count: 64)

    private func provenance(runtime: AnalysisDeviceRuntimeClass = .physicalIOSDevice, kind: AnalysisDevicePerformanceRunKind = .completeAnalysis) -> AnalysisDevicePerformanceProvenance {
        .init(runID: "run-1", runKind: kind, startedAt: now, runtimeClass: runtime, deviceModel: "iPhone17,1", osVersion: "19.0", appBundleIdentifier: "com.example.analysis", appVersion: "1.0", buildVersion: "100", manifestID: "golden-v1", manifestSHA256: manifestSHA, fixtureID: "long-track", fixtureDurationSeconds: 3600)
    }

    private func evidence(runtime: AnalysisDeviceRuntimeClass = .physicalIOSDevice) -> AnalysisDevicePerformanceEvidence {
        .init(
            provenance: provenance(runtime: runtime), finishedAt: now.addingTimeInterval(10), wallSeconds: 10,
            requestedSampleIntervalSeconds: 1, maximumSampleCount: 100,
            memoryTelemetry: .availableChannel, thermalTelemetry: .availableChannel, batteryTelemetry: .availableChannel, memoryPressureObservation: .availableChannel,
            memorySamples: [.init(offsetSeconds: 0, residentBytes: 100, physicalFootprintBytes: 90), .init(offsetSeconds: 10, residentBytes: 140, physicalFootprintBytes: 125)],
            thermalSamples: [.init(offsetSeconds: 0, state: .nominal), .init(offsetSeconds: 10, state: .serious)],
            batterySamples: [.init(offsetSeconds: 0, levelFraction: 0.90, state: .unplugged), .init(offsetSeconds: 10, levelFraction: 0.86, state: .unplugged)],
            memoryPressureEvents: [.init(offsetSeconds: 6, source: "UIApplication.didReceiveMemoryWarningNotification", detail: "MEMORY_WARNING")],
            cancellation: .init(requestedOffsetSeconds: nil, observedTerminationOffsetSeconds: nil), completedNormally: true
        )
    }

    func testPhysicalClaimProducesStructuralSummaryButNotParity() {
        let report = AnalysisDevicePerformanceEvidenceValidator.validate(evidence(), expectedManifestID: "golden-v1", expectedManifestSHA256: manifestSHA, evaluatedAt: now)
        XCTAssertEqual(report.status, .structurallyCompletePendingHQ)
        XCTAssertEqual(report.peakResidentBytes, 140)
        XCTAssertEqual(report.peakPhysicalFootprintBytes, 125)
        XCTAssertEqual(report.worstThermalState, .serious)
        XCTAssertEqual(report.thermalTransitionCount, 1)
        XCTAssertEqual(report.memoryPressureEventCount, 1)
        XCTAssertEqual(report.batteryDrainFraction ?? -1, 0.04, accuracy: 1e-12)
    }

    func testSimulatorCanNeverBecomePhysicalDeviceEvidence() {
        let report = AnalysisDevicePerformanceEvidenceValidator.validate(evidence(runtime: .iOSSimulator), expectedManifestID: "golden-v1", expectedManifestSHA256: manifestSHA, evaluatedAt: now)
        XCTAssertEqual(report.status, .nonPhysicalRuntime)
    }

    func testUnavailableMemoryIsExplicitIncompleteInsteadOfZero() {
        let base = evidence()
        let value = AnalysisDevicePerformanceEvidence(
            provenance: base.provenance, finishedAt: base.finishedAt, wallSeconds: base.wallSeconds, requestedSampleIntervalSeconds: 1, maximumSampleCount: 100,
            memoryTelemetry: .unavailable("TASK_INFO_UNAVAILABLE"), thermalTelemetry: base.thermalTelemetry, batteryTelemetry: base.batteryTelemetry, memoryPressureObservation: base.memoryPressureObservation,
            memorySamples: [.init(offsetSeconds: 0, residentBytes: nil, residentUnavailableReason: "TASK_INFO_UNAVAILABLE", physicalFootprintBytes: nil, physicalFootprintUnavailableReason: "TASK_INFO_UNAVAILABLE")],
            thermalSamples: base.thermalSamples, batterySamples: base.batterySamples, memoryPressureEvents: [], cancellation: base.cancellation, completedNormally: true)
        let report = AnalysisDevicePerformanceEvidenceValidator.validate(value, expectedManifestID: "golden-v1", expectedManifestSHA256: manifestSHA, evaluatedAt: now)
        XCTAssertEqual(report.status, .telemetryIncompletePendingHQ)
        XCTAssertNil(report.peakResidentBytes)
        XCTAssertNil(report.peakPhysicalFootprintBytes)
        XCTAssertTrue(report.issues.contains { $0.code == .unavailableRequiredTelemetry })
    }

    func testCancellationLatencyIsDerivedFromMonotonicOffsets() {
        let base = evidence()
        let value = AnalysisDevicePerformanceEvidence(
            provenance: provenance(kind: .cancellationProbe), finishedAt: now.addingTimeInterval(4), wallSeconds: 4, requestedSampleIntervalSeconds: 1, maximumSampleCount: 100,
            memoryTelemetry: base.memoryTelemetry, thermalTelemetry: base.thermalTelemetry, batteryTelemetry: base.batteryTelemetry, memoryPressureObservation: base.memoryPressureObservation,
            memorySamples: [.init(offsetSeconds: 0, residentBytes: 100, physicalFootprintBytes: 90)], thermalSamples: [.init(offsetSeconds: 0, state: .nominal)],
            batterySamples: [.init(offsetSeconds: 0, levelFraction: 0.9, state: .unplugged), .init(offsetSeconds: 4, levelFraction: 0.9, state: .unplugged)],
            memoryPressureEvents: [], cancellation: .init(requestedOffsetSeconds: 2, observedTerminationOffsetSeconds: 2.125), completedNormally: false)
        let report = AnalysisDevicePerformanceEvidenceValidator.validate(value, expectedManifestID: "golden-v1", expectedManifestSHA256: manifestSHA, evaluatedAt: now)
        XCTAssertEqual(report.cancellationLatencySeconds ?? -1, 0.125, accuracy: 1e-12)
    }

    func testInvalidTelemetryAndManifestSwapFailClosed() {
        let base = evidence()
        let zeroMemory = AnalysisDevicePerformanceEvidence(
            provenance: base.provenance, finishedAt: base.finishedAt, wallSeconds: base.wallSeconds, requestedSampleIntervalSeconds: 1, maximumSampleCount: 100,
            memoryTelemetry: .availableChannel, thermalTelemetry: base.thermalTelemetry, batteryTelemetry: base.batteryTelemetry, memoryPressureObservation: base.memoryPressureObservation,
            memorySamples: [.init(offsetSeconds: 0, residentBytes: 0, physicalFootprintBytes: 1)], thermalSamples: base.thermalSamples, batterySamples: base.batterySamples,
            memoryPressureEvents: [], cancellation: base.cancellation, completedNormally: true)
        let invalid = AnalysisDevicePerformanceEvidenceValidator.validate(zeroMemory, expectedManifestID: "other-manifest", expectedManifestSHA256: manifestSHA, evaluatedAt: now)
        XCTAssertEqual(invalid.status, .invalid)
        XCTAssertTrue(invalid.issues.contains { $0.code == .invalidMemorySample })
        XCTAssertTrue(invalid.issues.contains { $0.code == .manifestBindingMismatch })
    }

    func testCodecRoundTripsDeterministically() throws {
        let value = evidence()
        let a = try AnalysisDevicePerformanceEvidenceCodec.encodeEvidence(value)
        let b = try AnalysisDevicePerformanceEvidenceCodec.encodeEvidence(value)
        XCTAssertEqual(a, b)
        XCTAssertEqual(try AnalysisDevicePerformanceEvidenceCodec.decodeEvidence(a), value)
    }
}
