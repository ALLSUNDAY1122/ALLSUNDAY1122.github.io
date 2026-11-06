import Foundation
import XCTest
@testable import MoisesAudioCore

#if canImport(UIKit) && canImport(Darwin)
@MainActor
final class AnalysisIOSPhysicalCaptureArtifactMaterializerTests: XCTestCase {
    func testNonStructurallyCompleteCaptureCannotMaterializeArtifacts() {
        let validation = AnalysisDeviceCapturePlanValidationReport(
            runID: "run-39",
            valid: false,
            issues: [.init(code: .invalidPlan, detail: "test")]
        )
        let result = AnalysisIOSPhysicalCaptureResult(
            status: .invalidPlan,
            planValidation: validation,
            cancellationCoordination: .notApplicable,
            performanceEvidence: nil,
            performanceValidation: nil,
            workloadExecution: nil,
            workloadValidation: nil,
            algorithmEvidence: nil,
            executionIntegrityEvidence: nil,
            executionIntegrityValidation: nil,
            issues: ["INVALID_CAPTURE_PLAN"]
        )
        let source = AnalysisDeviceWorkloadSourceBinding(
            fixtureID: "fixture",
            sourceSHA256: String(repeating: "a", count: 64),
            sourceDurationSeconds: 60,
            sourceSampleRate: 44_100,
            sourceChannelCount: 2
        )
        let identity = AnalysisDeviceWorkloadIdentity(
            analyzerID: "ProjectOwnedMusicAnalyzer",
            analyzerVersion: "w39",
            analysisConfigurationID: "baseline",
            buildIdentity: "build"
        )
        let plan = AnalysisDeviceCapturePlan(
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W39",
            runID: "run-39",
            runKind: .completeAnalysis,
            manifestID: "manifest",
            manifestSHA256: String(repeating: "b", count: 64),
            source: source,
            identity: identity,
            telemetrySampleIntervalSeconds: 1,
            maximumTelemetrySampleCount: 100,
            cancellation: nil
        )
        let policy = AnalysisDeviceWorkloadPolicy(
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W39",
            manifestID: "manifest",
            manifestSHA256: String(repeating: "b", count: 64),
            identity: identity,
            fixtures: [source.fixtureID: source]
        )
        let profile = AnalysisDevicePerformanceAcceptanceProfile(
            profileID: "profile",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W39",
            expectedBatchID: "batch",
            expectedDeviceModel: "iPhone17,3",
            expectedOSVersion: "26.6",
            expectedAppBundleIdentifier: "example.moises",
            expectedAppVersion: "1",
            expectedBuildVersion: "1",
            expectedManifestID: "manifest",
            expectedManifestSHA256: String(repeating: "b", count: 64),
            requiredFixtureIDs: [source.fixtureID],
            expectedFixtureDurationsSeconds: [source.fixtureID: 60],
            minimumCompleteRunsPerFixture: 1,
            minimumCancellationRunsPerFixture: 0,
            plannedRuns: [.init(runID: "run-39", fixtureID: source.fixtureID, runKind: .completeAnalysis)],
            maximumCompleteWallSeconds: 1_000,
            maximumPeakResidentBytes: UInt64.max,
            maximumPeakPhysicalFootprintBytes: UInt64.max,
            maximumStartingThermalState: .fair,
            maximumWorstThermalState: .serious,
            maximumBatteryDrainFraction: 1,
            maximumMemoryPressureEventCount: Int.max,
            maximumCancellationLatencySeconds: 10,
            requireUnpluggedBatteryForCompleteRuns: false
        )

        XCTAssertThrowsError(
            try AnalysisIOSPhysicalCaptureArtifactMaterializer.materialize(
                plan: plan,
                captureResult: result,
                workloadPolicy: policy,
                performanceProfile: profile
            )
        ) { error in
            XCTAssertEqual(
                error as? AnalysisIOSPhysicalCaptureArtifactMaterializerError,
                .captureNotStructurallyComplete
            )
        }
    }
}
#endif
