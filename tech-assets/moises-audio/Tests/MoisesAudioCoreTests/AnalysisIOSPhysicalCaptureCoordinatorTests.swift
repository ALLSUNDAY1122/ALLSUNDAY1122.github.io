#if canImport(UIKit) && canImport(Darwin)
import XCTest
import UIKit
@testable import MoisesAudioCore

@MainActor
final class AnalysisIOSPhysicalCaptureCoordinatorTests: XCTestCase {
    private let sha = String(repeating: "a", count: 64)

    func testTelemetryCapIsExplicitAndFinishRestoresBatteryMonitoring() {
        let originalBatteryMonitoring = UIDevice.current.isBatteryMonitoringEnabled
        let session = AnalysisIOSDevicePerformanceSession(
            runID: "w37-cap",
            runKind: .completeAnalysis,
            manifestID: "manifest",
            manifestSHA256: sha,
            fixtureID: "fixture",
            fixtureDurationSeconds: 60,
            configuration: .init(sampleIntervalSeconds: 60, maximumSampleCount: 1)
        )

        XCTAssertEqual(session.sample(), .capReached)
        let evidence = session.finish(completedNormally: true)
        XCTAssertTrue(evidence.limitations.contains("TELEMETRY_SAMPLE_CAP_REACHED"))
        XCTAssertEqual(session.sample(), .finished)
        XCTAssertEqual(UIDevice.current.isBatteryMonitoringEnabled, originalBatteryMonitoring)
    }

    func testForcedFinishProducesBoundedFinalSnapshotWithoutHidingCap() {
        let session = AnalysisIOSDevicePerformanceSession(
            runID: "w37-final",
            runKind: .completeAnalysis,
            manifestID: "manifest",
            manifestSHA256: sha,
            fixtureID: "fixture",
            fixtureDurationSeconds: 60,
            configuration: .init(sampleIntervalSeconds: 60, maximumSampleCount: 1)
        )
        XCTAssertEqual(session.sample(), .capReached)
        let evidence = session.finish(completedNormally: true)
        XCTAssertLessThanOrEqual(evidence.memorySamples.count, evidence.maximumSampleCount + 1)
        XCTAssertEqual(evidence.memorySamples.count, evidence.thermalSamples.count)
        XCTAssertEqual(evidence.memorySamples.count, evidence.batterySamples.count)
        XCTAssertTrue(evidence.limitations.contains("TELEMETRY_SAMPLE_CAP_REACHED"))
    }
}
#endif
