import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalCaptureArtifactMaterializationTests: XCTestCase {
    private let manifestSHA = String(repeating: "b", count: 64)
    private let sourceSHA = String(repeating: "a", count: 64)

    private struct Fixture {
        let input: AnalysisPhysicalCaptureMaterializationInput
        let runtime: AnalysisCurrentDeviceWorkloadArchiveEvidence
    }

    private func fixture(runID: String = "run-39", executionID: String = "exec-39") -> Fixture {
        let source = AnalysisDeviceWorkloadSourceBinding(
            fixtureID: "long-a",
            sourceSHA256: sourceSHA,
            sourceDurationSeconds: 60,
            sourceSampleRate: 44_100,
            sourceChannelCount: 2
        )
        let identity = AnalysisDeviceWorkloadIdentity(
            analyzerID: "ProjectOwnedMusicAnalyzer",
            analyzerVersion: "w39",
            analysisConfigurationID: "product-baseline-v1",
            buildIdentity: "build-101"
        )
        let policy = AnalysisDeviceWorkloadPolicy(
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W39",
            manifestID: "manifest-1",
            manifestSHA256: manifestSHA,
            identity: identity,
            fixtures: [source.fixtureID: source]
        )
        let profile = AnalysisDevicePerformanceAcceptanceProfile(
            profileID: "p39",
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-P021-W39",
            expectedBatchID: "b39",
            expectedDeviceModel: "iPhone17,3",
            expectedOSVersion: "26.6",
            expectedAppBundleIdentifier: "example.moises",
            expectedAppVersion: "1",
            expectedBuildVersion: "101",
            expectedManifestID: "manifest-1",
            expectedManifestSHA256: manifestSHA,
            requiredFixtureIDs: [source.fixtureID],
            expectedFixtureDurationsSeconds: [source.fixtureID: 60],
            minimumCompleteRunsPerFixture: 0,
            minimumCancellationRunsPerFixture: 1,
            plannedRuns: [.init(runID: runID, fixtureID: source.fixtureID, runKind: .cancellationProbe)],
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
        let plan = AnalysisDeviceCapturePlan(
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W39-PLAN",
            runID: runID,
            runKind: .cancellationProbe,
            manifestID: "manifest-1",
            manifestSHA256: manifestSHA,
            source: source,
            identity: identity,
            telemetrySampleIntervalSeconds: 0.1,
            maximumTelemetrySampleCount: 10,
            cancellation: .init(
                delayAfterObservedSourceWorkSeconds: 0,
                sourceWorkPollIntervalSeconds: 0.01,
                maximumWaitForObservedSourceWorkSeconds: 5
            )
        )
        let started = Date(timeIntervalSince1970: 1_000)
        let performance = AnalysisDevicePerformanceEvidence(
            provenance: .init(
                runID: runID,
                runKind: .cancellationProbe,
                startedAt: started,
                runtimeClass: .physicalIOSDevice,
                deviceModel: "iPhone17,3",
                osVersion: "26.6",
                appBundleIdentifier: "example.moises",
                appVersion: "1",
                buildVersion: "101",
                manifestID: "manifest-1",
                manifestSHA256: manifestSHA,
                fixtureID: source.fixtureID,
                fixtureDurationSeconds: 60
            ),
            finishedAt: started.addingTimeInterval(0.5),
            wallSeconds: 0.5,
            requestedSampleIntervalSeconds: 0.1,
            maximumSampleCount: 10,
            memoryTelemetry: .availableChannel,
            thermalTelemetry: .availableChannel,
            batteryTelemetry: .availableChannel,
            memoryPressureObservation: .availableChannel,
            memorySamples: [
                .init(offsetSeconds: 0, residentBytes: 10_000, physicalFootprintBytes: 20_000),
                .init(offsetSeconds: 0.5, residentBytes: 11_000, physicalFootprintBytes: 21_000)
            ],
            thermalSamples: [
                .init(offsetSeconds: 0, state: .nominal),
                .init(offsetSeconds: 0.5, state: .fair)
            ],
            batterySamples: [
                .init(offsetSeconds: 0, levelFraction: 0.9, state: .unplugged),
                .init(offsetSeconds: 0.5, levelFraction: 0.89, state: .unplugged)
            ],
            memoryPressureEvents: [],
            cancellation: .init(requestedOffsetSeconds: 0.2, observedTerminationOffsetSeconds: 0.4),
            completedNormally: false,
            failureDescription: nil,
            limitations: []
        )
        let performanceReport = AnalysisDevicePerformanceEvidenceValidator.validate(
            performance,
            expectedManifestID: "manifest-1",
            expectedManifestSHA256: manifestSHA,
            evaluatedAt: started.addingTimeInterval(1)
        )

        let stages: [AnalysisDeviceWorkloadStageEvent] = [
            .init(stage: .signalPreparation, startedOffsetSeconds: 0, endedOffsetSeconds: 0.4, status: .cancelled)
        ]
        let executionBinding = AnalysisDeviceWorkloadReceiptValidator.executionBindingSHA256(
            runID: runID,
            performanceEvidenceRunID: runID,
            runKind: .cancellationProbe,
            manifestID: "manifest-1",
            manifestSHA256: manifestSHA,
            source: source,
            identity: identity,
            executionID: executionID,
            workloadStartedAt: started,
            stages: stages,
            snapshotSHA256: nil,
            outputSummary: nil
        )
        let receipt = AnalysisDeviceWorkloadReceipt(
            runID: runID,
            performanceEvidenceRunID: runID,
            runKind: .cancellationProbe,
            manifestID: "manifest-1",
            manifestSHA256: manifestSHA,
            source: source,
            identity: identity,
            executionID: executionID,
            workloadStartedAt: started,
            stages: stages,
            snapshotCanonicalJSON: nil,
            snapshotSHA256: nil,
            outputSummary: nil,
            executionBindingSHA256: executionBinding
        )
        let workloadReport = AnalysisDeviceWorkloadReceiptValidator.validate(
            receipt,
            performanceEvidence: performance,
            policy: policy
        )
        let algorithm = AnalysisDeviceAlgorithmExecutionEvidence(
            runID: runID,
            performanceEvidenceRunID: runID,
            runKind: .cancellationProbe,
            workloadExecutionID: executionID,
            manifestID: "manifest-1",
            manifestSHA256: manifestSHA,
            source: source,
            identity: identity,
            sourceInputContract: .boundedPull,
            snapshotSHA256: nil,
            captureState: .cancelledBeforeFinalization,
            runtimeIdentity: nil,
            runtimeIdentitySHA256: nil
        )
        let runtime = AnalysisCurrentDeviceWorkloadArchiveEvidence(
            runID: runID,
            performanceEvidenceRunID: runID,
            runKind: .cancellationProbe,
            workloadExecutionID: executionID,
            sourceMemoryContract: .boundedPull,
            boundedSourceContractAccepted: true,
            observedSourceChunkCount: 2,
            observedSourceSampleCount: 4_096,
            outcome: .cancelled,
            snapshotSHA256: nil,
            algorithmRunID: runID,
            algorithmWorkloadExecutionID: executionID
        )
        let integrity = AnalysisDeviceCaptureExecutionIntegrityEvidence(
            runID: runID,
            runKind: .cancellationProbe,
            performanceRunID: runID,
            workloadRunID: runID,
            workloadExecutionID: executionID,
            algorithmRunID: runID,
            algorithmWorkloadExecutionID: executionID,
            sourceMemoryContract: .boundedPull,
            workloadOutcome: .cancelled,
            observedSourceSampleCount: 4_096,
            cancellationCoordination: .requestedAfterObservedSourceWork,
            cancellationRequestedOffsetSeconds: 0.2,
            cancellationObservedOffsetSeconds: 0.4,
            requestedSampleIntervalSeconds: 0.1,
            captureWallSeconds: 0.5,
            telemetrySampling: .init(
                samplingAttempts: 4,
                periodicSamplesCaptured: 4,
                sampleCapReached: false,
                samplerTerminated: true
            ),
            cancellationTaskTerminated: true,
            performanceLimitations: []
        )
        let integrityReport = AnalysisDeviceCaptureExecutionIntegrityValidator.validate(integrity)
        return Fixture(
            input: .init(
                plan: plan,
                performanceEvidence: performance,
                performanceValidation: performanceReport,
                workloadReceipt: receipt,
                workloadValidation: workloadReport,
                algorithmEvidence: algorithm,
                currentRuntimeEvidence: runtime,
                executionIntegrityEvidence: integrity,
                executionIntegrityValidation: integrityReport,
                performanceProfile: profile,
                workloadPolicy: policy
            ),
            runtime: runtime
        )
    }

    func testValidPhysicalCancellationChainMaterializesExactArchiveProjections() throws {
        let value = fixture()
        XCTAssertEqual(value.input.performanceValidation.status, .structurallyCompletePendingHQ)
        XCTAssertEqual(value.input.workloadValidation.status, .realWorkCancellationPendingHQ)
        XCTAssertTrue(value.input.executionIntegrityValidation.valid)

        let bundle = try AnalysisPhysicalCaptureArtifactMaterializer.materialize(value.input)
        XCTAssertEqual(bundle.artifacts.count, 9)
        XCTAssertEqual(bundle.legacyW27Entries.count, 4)
        XCTAssertEqual(bundle.w38Entries.count, 5)
        XCTAssertEqual(bundle.runID, "run-39")
        XCTAssertEqual(bundle.workloadExecutionID, "exec-39")
        XCTAssertTrue(AnalysisPhysicalCaptureArtifactBundleValidator.validate(bundle).valid)
    }

    func testNonBoundedCurrentRuntimeFailsClosed() {
        let value = fixture()
        let badRuntime = AnalysisCurrentDeviceWorkloadArchiveEvidence(
            runID: value.runtime.runID,
            performanceEvidenceRunID: value.runtime.performanceEvidenceRunID,
            runKind: value.runtime.runKind,
            workloadExecutionID: value.runtime.workloadExecutionID,
            sourceMemoryContract: .wholeSignalCompatibilityMaterialized,
            boundedSourceContractAccepted: false,
            observedSourceChunkCount: value.runtime.observedSourceChunkCount,
            observedSourceSampleCount: value.runtime.observedSourceSampleCount,
            outcome: value.runtime.outcome,
            snapshotSHA256: value.runtime.snapshotSHA256,
            algorithmRunID: value.runtime.algorithmRunID,
            algorithmWorkloadExecutionID: value.runtime.algorithmWorkloadExecutionID
        )
        let input = AnalysisPhysicalCaptureMaterializationInput(
            plan: value.input.plan,
            performanceEvidence: value.input.performanceEvidence,
            performanceValidation: value.input.performanceValidation,
            workloadReceipt: value.input.workloadReceipt,
            workloadValidation: value.input.workloadValidation,
            algorithmEvidence: value.input.algorithmEvidence,
            currentRuntimeEvidence: badRuntime,
            executionIntegrityEvidence: value.input.executionIntegrityEvidence,
            executionIntegrityValidation: value.input.executionIntegrityValidation,
            performanceProfile: value.input.performanceProfile,
            workloadPolicy: value.input.workloadPolicy
        )
        XCTAssertThrowsError(try AnalysisPhysicalCaptureArtifactMaterializer.materialize(input)) { error in
            XCTAssertEqual(error as? AnalysisPhysicalCaptureArtifactMaterializationError, .nonBoundedCurrentRuntime)
        }
    }

    func testCrossExecutionRebindingFailsClosed() {
        let value = fixture()
        let badRuntime = AnalysisCurrentDeviceWorkloadArchiveEvidence(
            runID: value.runtime.runID,
            performanceEvidenceRunID: value.runtime.performanceEvidenceRunID,
            runKind: value.runtime.runKind,
            workloadExecutionID: "exec-other",
            sourceMemoryContract: .boundedPull,
            boundedSourceContractAccepted: true,
            observedSourceChunkCount: value.runtime.observedSourceChunkCount,
            observedSourceSampleCount: value.runtime.observedSourceSampleCount,
            outcome: value.runtime.outcome,
            snapshotSHA256: value.runtime.snapshotSHA256,
            algorithmRunID: value.runtime.algorithmRunID,
            algorithmWorkloadExecutionID: "exec-other"
        )
        let input = AnalysisPhysicalCaptureMaterializationInput(
            plan: value.input.plan,
            performanceEvidence: value.input.performanceEvidence,
            performanceValidation: value.input.performanceValidation,
            workloadReceipt: value.input.workloadReceipt,
            workloadValidation: value.input.workloadValidation,
            algorithmEvidence: value.input.algorithmEvidence,
            currentRuntimeEvidence: badRuntime,
            executionIntegrityEvidence: value.input.executionIntegrityEvidence,
            executionIntegrityValidation: value.input.executionIntegrityValidation,
            performanceProfile: value.input.performanceProfile,
            workloadPolicy: value.input.workloadPolicy
        )
        XCTAssertThrowsError(try AnalysisPhysicalCaptureArtifactMaterializer.materialize(input)) { error in
            XCTAssertEqual(error as? AnalysisPhysicalCaptureArtifactMaterializationError, .captureChainBindingMismatch)
        }
    }

    func testFilesystemUnsafeRunIDFailsBeforeEncoding() {
        let value = fixture(runID: "../escape", executionID: "exec-bad")
        XCTAssertThrowsError(try AnalysisPhysicalCaptureArtifactMaterializer.materialize(value.input)) { error in
            XCTAssertEqual(error as? AnalysisPhysicalCaptureArtifactMaterializationError, .unsafeRunID)
        }
    }
}
