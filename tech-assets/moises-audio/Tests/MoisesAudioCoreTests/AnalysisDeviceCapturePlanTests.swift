import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisDeviceCapturePlanTests: XCTestCase {
    private let manifestSHA = String(repeating: "b", count: 64)
    private let sourceSHA = String(repeating: "a", count: 64)

    private var source: AnalysisDeviceWorkloadSourceBinding {
        .init(fixtureID: "long-a", sourceSHA256: sourceSHA, sourceDurationSeconds: 3_600, sourceSampleRate: 44_100, sourceChannelCount: 2)
    }

    private var identity: AnalysisDeviceWorkloadIdentity {
        .init(analyzerID: "ProjectOwnedMusicAnalyzer", analyzerVersion: "w37", analysisConfigurationID: "product-baseline-v1", buildIdentity: "build-101")
    }

    private func policy(source: AnalysisDeviceWorkloadSourceBinding? = nil, manifestSHA256: String? = nil) -> AnalysisDeviceWorkloadPolicy {
        let selected = source ?? self.source
        return .init(
            authority: "HQ_LATE_INTEGRATION", approvalReference: "HQ-W37",
            manifestID: "manifest-1", manifestSHA256: manifestSHA256 ?? manifestSHA,
            identity: identity, fixtures: [selected.fixtureID: selected]
        )
    }

    private func profile(
        runID: String = "run-1",
        kind: AnalysisDevicePerformanceRunKind = .completeAnalysis,
        source: AnalysisDeviceWorkloadSourceBinding? = nil,
        manifestSHA256: String? = nil
    ) -> AnalysisDevicePerformanceAcceptanceProfile {
        let selected = source ?? self.source
        return .init(
            profileID: "p37", authority: "HQ_LATE_INTEGRATION", approvalReference: "HQ-P021-W37",
            expectedBatchID: "b37", expectedDeviceModel: "iPhone17,3", expectedOSVersion: "26.6",
            expectedAppBundleIdentifier: "example.moises", expectedAppVersion: "1", expectedBuildVersion: "101",
            expectedManifestID: "manifest-1", expectedManifestSHA256: manifestSHA256 ?? manifestSHA,
            requiredFixtureIDs: [selected.fixtureID], expectedFixtureDurationsSeconds: [selected.fixtureID: selected.sourceDurationSeconds],
            minimumCompleteRunsPerFixture: 1, minimumCancellationRunsPerFixture: 1,
            plannedRuns: [.init(runID: runID, fixtureID: selected.fixtureID, runKind: kind)],
            maximumCompleteWallSeconds: 10_000,
            maximumPeakResidentBytes: UInt64.max, maximumPeakPhysicalFootprintBytes: UInt64.max,
            maximumStartingThermalState: .fair, maximumWorstThermalState: .serious,
            maximumBatteryDrainFraction: 1, maximumMemoryPressureEventCount: Int.max,
            maximumCancellationLatencySeconds: 10_000, requireUnpluggedBatteryForCompleteRuns: false
        )
    }

    private func plan(
        runID: String = "run-1",
        kind: AnalysisDevicePerformanceRunKind = .completeAnalysis,
        source: AnalysisDeviceWorkloadSourceBinding? = nil,
        manifestSHA256: String? = nil,
        interval: Double = 1,
        cap: Int = 4_096,
        cancellation: AnalysisDeviceCancellationCapturePlan? = nil,
        authority: String = "HQ_LATE_INTEGRATION"
    ) -> AnalysisDeviceCapturePlan {
        .init(
            authority: authority, approvalReference: "HQ-W37-APPROVED", runID: runID, runKind: kind,
            manifestID: "manifest-1", manifestSHA256: manifestSHA256 ?? manifestSHA,
            source: source ?? self.source, identity: identity,
            telemetrySampleIntervalSeconds: interval, maximumTelemetrySampleCount: cap,
            cancellation: cancellation
        )
    }

    private func validIntegrity(
        runID: String = "run-1",
        executionID: String = "exec-1",
        kind: AnalysisDevicePerformanceRunKind = .completeAnalysis
    ) -> AnalysisDeviceCaptureExecutionIntegrityEvidence {
        let cancelling = kind == .cancellationProbe
        return .init(
            runID: runID, runKind: kind,
            performanceRunID: runID, workloadRunID: runID, workloadExecutionID: executionID,
            algorithmRunID: runID, algorithmWorkloadExecutionID: executionID,
            sourceMemoryContract: .boundedPull,
            workloadOutcome: cancelling ? .cancelled : .completed,
            observedSourceSampleCount: cancelling ? 4_096 : 8_192,
            cancellationCoordination: cancelling ? .requestedAfterObservedSourceWork : .notApplicable,
            cancellationRequestedOffsetSeconds: cancelling ? 1.0 : nil,
            cancellationObservedOffsetSeconds: cancelling ? 1.1 : nil,
            requestedSampleIntervalSeconds: 1,
            captureWallSeconds: 2,
            telemetrySampling: .init(samplingAttempts: 1, periodicSamplesCaptured: 1, sampleCapReached: false, samplerTerminated: true),
            cancellationTaskTerminated: true,
            performanceLimitations: []
        )
    }

    func testValidHQBoundCompleteAndCancellationPlansPass() {
        XCTAssertTrue(AnalysisDeviceCapturePlanValidator.validate(plan(), workloadPolicy: policy(), performanceProfile: profile()).valid)

        let cancel = AnalysisDeviceCancellationCapturePlan(
            delayAfterObservedSourceWorkSeconds: 0.25,
            sourceWorkPollIntervalSeconds: 0.01,
            maximumWaitForObservedSourceWorkSeconds: 5
        )
        let p = plan(kind: .cancellationProbe, cancellation: cancel)
        XCTAssertTrue(AnalysisDeviceCapturePlanValidator.validate(p, workloadPolicy: policy(), performanceProfile: profile(kind: .cancellationProbe)).valid)
    }

    func testMalformedPlanSamplingAndCancellationFailClosed() {
        let wrongAuthority = AnalysisDeviceCapturePlanValidator.validate(
            plan(authority: "WORKER_DEFINED"), workloadPolicy: policy(), performanceProfile: profile()
        )
        XCTAssertTrue(wrongAuthority.issues.contains { $0.code == .invalidPlan })

        let invalidSampling = AnalysisDeviceCapturePlanValidator.validate(
            plan(interval: .infinity, cap: 0), workloadPolicy: policy(), performanceProfile: profile()
        )
        XCTAssertTrue(invalidSampling.issues.contains { $0.code == .invalidSampling })

        let illegalCompleteCancellation = AnalysisDeviceCapturePlanValidator.validate(
            plan(cancellation: .init(delayAfterObservedSourceWorkSeconds: 0, sourceWorkPollIntervalSeconds: 0.01, maximumWaitForObservedSourceWorkSeconds: 1)),
            workloadPolicy: policy(), performanceProfile: profile()
        )
        XCTAssertTrue(illegalCompleteCancellation.issues.contains { $0.code == .invalidCancellationPlan })

        let missingCancellation = AnalysisDeviceCapturePlanValidator.validate(
            plan(kind: .cancellationProbe), workloadPolicy: policy(), performanceProfile: profile(kind: .cancellationProbe)
        )
        XCTAssertTrue(missingCancellation.issues.contains { $0.code == .invalidCancellationPlan })
    }

    func testRunKindFixtureManifestAndSourceMetadataMismatchesFailClosed() {
        let cancel = AnalysisDeviceCancellationCapturePlan(delayAfterObservedSourceWorkSeconds: 0, sourceWorkPollIntervalSeconds: 0.01, maximumWaitForObservedSourceWorkSeconds: 1)
        let kindMismatch = AnalysisDeviceCapturePlanValidator.validate(
            plan(kind: .cancellationProbe, cancellation: cancel), workloadPolicy: policy(), performanceProfile: profile(kind: .completeAnalysis)
        )
        XCTAssertTrue(kindMismatch.issues.contains { $0.code == .profileBindingMismatch })

        let wrongSource = AnalysisDeviceWorkloadSourceBinding(
            fixtureID: "long-a", sourceSHA256: sourceSHA,
            sourceDurationSeconds: 3_599, sourceSampleRate: 48_000, sourceChannelCount: 1
        )
        let sourceMismatch = AnalysisDeviceCapturePlanValidator.validate(
            plan(source: wrongSource), workloadPolicy: policy(), performanceProfile: profile()
        )
        XCTAssertTrue(sourceMismatch.issues.contains { $0.code == .profileBindingMismatch })
        XCTAssertTrue(sourceMismatch.issues.contains { $0.code == .workloadPolicyBindingMismatch })

        let wrongManifest = String(repeating: "c", count: 64)
        let manifestMismatch = AnalysisDeviceCapturePlanValidator.validate(
            plan(manifestSHA256: wrongManifest), workloadPolicy: policy(), performanceProfile: profile()
        )
        XCTAssertTrue(manifestMismatch.issues.contains { $0.code == .profileBindingMismatch })
        XCTAssertTrue(manifestMismatch.issues.contains { $0.code == .workloadPolicyBindingMismatch })
    }

    func testExecutionIntegrityAcceptsOnlyBoundCurrentChain() throws {
        let good = validIntegrity()
        let report = AnalysisDeviceCaptureExecutionIntegrityValidator.validate(good)
        XCTAssertTrue(report.valid)
        XCTAssertEqual(report.issues, [])

        let encoded = try AnalysisDeviceCaptureExecutionIntegrityCodec.encodeEvidence(good)
        XCTAssertEqual(try AnalysisDeviceCaptureExecutionIntegrityCodec.decodeEvidence(encoded), good)
        XCTAssertEqual(encoded, try AnalysisDeviceCaptureExecutionIntegrityCodec.encodeEvidence(good))
    }

    func testTelemetryCapSamplerLeakAndMissingPeriodicityFailClosed() {
        var value = validIntegrity()
        value = .init(
            runID: value.runID, runKind: value.runKind,
            performanceRunID: value.performanceRunID, workloadRunID: value.workloadRunID, workloadExecutionID: value.workloadExecutionID,
            algorithmRunID: value.algorithmRunID, algorithmWorkloadExecutionID: value.algorithmWorkloadExecutionID,
            sourceMemoryContract: value.sourceMemoryContract, workloadOutcome: value.workloadOutcome, observedSourceSampleCount: value.observedSourceSampleCount,
            cancellationCoordination: value.cancellationCoordination,
            cancellationRequestedOffsetSeconds: value.cancellationRequestedOffsetSeconds, cancellationObservedOffsetSeconds: value.cancellationObservedOffsetSeconds,
            requestedSampleIntervalSeconds: 1, captureWallSeconds: 2,
            telemetrySampling: .init(samplingAttempts: 1, periodicSamplesCaptured: 0, sampleCapReached: true, samplerTerminated: false),
            cancellationTaskTerminated: true, performanceLimitations: ["TELEMETRY_SAMPLE_CAP_REACHED"]
        )
        let report = AnalysisDeviceCaptureExecutionIntegrityValidator.validate(value)
        XCTAssertTrue(report.issues.contains { $0.code == .telemetrySampleCapReached })
        XCTAssertTrue(report.issues.contains { $0.code == .invalidTelemetryLifecycle })
        XCTAssertTrue(report.issues.contains { $0.code == .missingPeriodicTelemetry })
    }

    func testCancellationAdversarialOrderingAndNormalCompletionFailClosed() {
        let good = validIntegrity(kind: .cancellationProbe)
        XCTAssertTrue(AnalysisDeviceCaptureExecutionIntegrityValidator.validate(good).valid)

        let completed = AnalysisDeviceCaptureExecutionIntegrityEvidence(
            runID: good.runID, runKind: .cancellationProbe,
            performanceRunID: good.performanceRunID, workloadRunID: good.workloadRunID, workloadExecutionID: good.workloadExecutionID,
            algorithmRunID: good.algorithmRunID, algorithmWorkloadExecutionID: good.algorithmWorkloadExecutionID,
            sourceMemoryContract: .boundedPull, workloadOutcome: .completed, observedSourceSampleCount: 0,
            cancellationCoordination: .workloadFinishedBeforeRequest,
            cancellationRequestedOffsetSeconds: nil, cancellationObservedOffsetSeconds: nil,
            requestedSampleIntervalSeconds: 1, captureWallSeconds: 2,
            telemetrySampling: good.telemetrySampling, cancellationTaskTerminated: true, performanceLimitations: []
        )
        let completedReport = AnalysisDeviceCaptureExecutionIntegrityValidator.validate(completed)
        XCTAssertTrue(completedReport.issues.contains { $0.code == .invalidCancellationSemantics })
        XCTAssertTrue(completedReport.issues.contains { $0.code == .invalidCancellationTiming })

        let reversed = AnalysisDeviceCaptureExecutionIntegrityEvidence(
            runID: good.runID, runKind: .cancellationProbe,
            performanceRunID: good.performanceRunID, workloadRunID: good.workloadRunID, workloadExecutionID: good.workloadExecutionID,
            algorithmRunID: good.algorithmRunID, algorithmWorkloadExecutionID: good.algorithmWorkloadExecutionID,
            sourceMemoryContract: .boundedPull, workloadOutcome: .cancelled, observedSourceSampleCount: 1,
            cancellationCoordination: .requestedAfterObservedSourceWork,
            cancellationRequestedOffsetSeconds: 1.5, cancellationObservedOffsetSeconds: 1.4,
            requestedSampleIntervalSeconds: 1, captureWallSeconds: 2,
            telemetrySampling: good.telemetrySampling, cancellationTaskTerminated: true, performanceLimitations: []
        )
        XCTAssertTrue(AnalysisDeviceCaptureExecutionIntegrityValidator.validate(reversed).issues.contains { $0.code == .invalidCancellationTiming })
    }

    func testNonBoundedBindingMismatchTaskLeakDuplicateAndReusedExecutionFailClosed() {
        let base = validIntegrity()
        let broken = AnalysisDeviceCaptureExecutionIntegrityEvidence(
            runID: "run-1", runKind: .completeAnalysis,
            performanceRunID: "run-other", workloadRunID: "run-1", workloadExecutionID: "exec-shared",
            algorithmRunID: "run-1", algorithmWorkloadExecutionID: "exec-other",
            sourceMemoryContract: .wholeSignalCompatibilityMaterialized,
            workloadOutcome: .completed, observedSourceSampleCount: 1,
            cancellationCoordination: .notApplicable,
            cancellationRequestedOffsetSeconds: nil, cancellationObservedOffsetSeconds: nil,
            requestedSampleIntervalSeconds: 1, captureWallSeconds: 2,
            telemetrySampling: base.telemetrySampling, cancellationTaskTerminated: false, performanceLimitations: []
        )
        let report = AnalysisDeviceCaptureExecutionIntegrityValidator.validate(broken)
        XCTAssertTrue(report.issues.contains { $0.code == .runBindingMismatch })
        XCTAssertTrue(report.issues.contains { $0.code == .nonBoundedSource })
        XCTAssertTrue(report.issues.contains { $0.code == .cancellationTaskNotTerminated })

        let duplicate = AnalysisDeviceCaptureExecutionIntegrityValidator.validateBatch([base, base])
        XCTAssertTrue(duplicate.contains { $0.code == .duplicateRunID })

        let other = validIntegrity(runID: "run-2", executionID: base.workloadExecutionID)
        let reused = AnalysisDeviceCaptureExecutionIntegrityValidator.validateBatch([base, other])
        XCTAssertTrue(reused.contains { $0.code == .reusedExecution })
    }

    func testIntegrityValidatorRepeatedStressIsDeterministic() {
        let value = validIntegrity()
        for _ in 0..<2_000 {
            let report = AnalysisDeviceCaptureExecutionIntegrityValidator.validate(value)
            XCTAssertTrue(report.valid)
            XCTAssertTrue(report.issues.isEmpty)
        }
    }
}
