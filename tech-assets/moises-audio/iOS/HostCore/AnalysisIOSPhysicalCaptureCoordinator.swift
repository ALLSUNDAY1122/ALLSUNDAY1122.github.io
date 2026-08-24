#if canImport(UIKit) && canImport(Darwin)
import Foundation
import UIKit
import Darwin

public enum AnalysisIOSPhysicalCaptureStatus: String, Codable, Sendable {
    case invalidPlan = "INVALID_CAPTURE_PLAN"
    case nonPhysicalRuntime = "NON_PHYSICAL_RUNTIME_NON_PARITY"
    case telemetryIncompletePendingHQ = "PHYSICAL_TELEMETRY_INCOMPLETE_PENDING_HQ"
    case invalidExecution = "INVALID_CAPTURE_EXECUTION"
    case structurallyCompletePendingHQ = "PHYSICAL_CAPTURE_STRUCTURALLY_COMPLETE_PENDING_HQ"
}

public enum AnalysisIOSCancellationCoordinationResult: String, Codable, Sendable {
    case notApplicable = "NOT_APPLICABLE"
    case requestedAfterObservedSourceWork = "REQUESTED_AFTER_OBSERVED_SOURCE_WORK"
    case workloadFinishedBeforeRequest = "WORKLOAD_FINISHED_BEFORE_REQUEST"
    case sourceWorkWaitExpired = "SOURCE_WORK_WAIT_EXPIRED"
}

public struct AnalysisIOSPhysicalCaptureResult: Sendable {
    public let status: AnalysisIOSPhysicalCaptureStatus
    public let planValidation: AnalysisDeviceCapturePlanValidationReport
    public let cancellationCoordination: AnalysisIOSCancellationCoordinationResult
    public let performanceEvidence: AnalysisDevicePerformanceEvidence?
    public let performanceValidation: AnalysisDevicePerformanceValidationReport?
    public let workloadExecution: AnalysisCurrentDeviceWorkloadExecution?
    public let workloadValidation: AnalysisDeviceWorkloadValidationReport?
    public let algorithmEvidence: AnalysisDeviceAlgorithmExecutionEvidence?
    public let issues: [String]

    public init(
        status: AnalysisIOSPhysicalCaptureStatus,
        planValidation: AnalysisDeviceCapturePlanValidationReport,
        cancellationCoordination: AnalysisIOSCancellationCoordinationResult,
        performanceEvidence: AnalysisDevicePerformanceEvidence?,
        performanceValidation: AnalysisDevicePerformanceValidationReport?,
        workloadExecution: AnalysisCurrentDeviceWorkloadExecution?,
        workloadValidation: AnalysisDeviceWorkloadValidationReport?,
        algorithmEvidence: AnalysisDeviceAlgorithmExecutionEvidence?,
        issues: [String]
    ) {
        self.status = status
        self.planValidation = planValidation
        self.cancellationCoordination = cancellationCoordination
        self.performanceEvidence = performanceEvidence
        self.performanceValidation = performanceValidation
        self.workloadExecution = workloadExecution
        self.workloadValidation = workloadValidation
        self.algorithmEvidence = algorithmEvidence
        self.issues = issues
    }
}

@MainActor
public enum AnalysisIOSPhysicalCaptureCoordinator {
    public static func capture(
        signal: AnalysisChunkedSignal,
        plan: AnalysisDeviceCapturePlan,
        workloadPolicy: AnalysisDeviceWorkloadPolicy,
        performanceProfile: AnalysisDevicePerformanceAcceptanceProfile,
        analysisConfiguration: MusicAnalysisConfiguration = .productBaseline
    ) async -> AnalysisIOSPhysicalCaptureResult {
        let planValidation = AnalysisDeviceCapturePlanValidator.validate(
            plan,
            workloadPolicy: workloadPolicy,
            performanceProfile: performanceProfile
        )
        var preflightIssues = planValidation.issues.map { $0.code.rawValue + ":" + $0.detail }
        guard planValidation.valid else {
            return .init(
                status: .invalidPlan,
                planValidation: planValidation,
                cancellationCoordination: .notApplicable,
                performanceEvidence: nil,
                performanceValidation: nil,
                workloadExecution: nil,
                workloadValidation: nil,
                algorithmEvidence: nil,
                issues: preflightIssues.sorted()
            )
        }
        guard signal.sourceMemoryContract == .boundedPull else {
            preflightIssues.append("SOURCE_INPUT_CONTRACT_NOT_BOUNDED_PULL")
            return .init(
                status: .invalidPlan,
                planValidation: planValidation,
                cancellationCoordination: .notApplicable,
                performanceEvidence: nil,
                performanceValidation: nil,
                workloadExecution: nil,
                workloadValidation: nil,
                algorithmEvidence: nil,
                issues: preflightIssues.sorted()
            )
        }
        guard let telemetrySleep = nanoseconds(plan.telemetrySampleIntervalSeconds) else {
            preflightIssues.append("TELEMETRY_INTERVAL_NOT_SLEEP_ENCODABLE")
            return invalidPreflight(planValidation, issues: preflightIssues)
        }

        let session = AnalysisIOSDevicePerformanceSession(
            runID: plan.runID,
            runKind: plan.runKind,
            manifestID: plan.manifestID,
            manifestSHA256: plan.manifestSHA256,
            fixtureID: plan.source.fixtureID,
            fixtureDurationSeconds: plan.source.sourceDurationSeconds,
            configuration: .init(
                sampleIntervalSeconds: plan.telemetrySampleIntervalSeconds,
                maximumSampleCount: plan.maximumTelemetrySampleCount
            )
        )
        let lifecycle = AnalysisCurrentDeviceWorkloadLifecycleProbe()
        let context = plan.workloadContext

        let workloadTask = Task.detached(priority: .userInitiated) {
            await AnalysisCurrentDeviceWorkloadRunner.run(
                signal: signal,
                context: context,
                configuration: analysisConfiguration,
                lifecycleReporter: lifecycle
            )
        }

        let telemetryTask = Task { @MainActor in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: telemetrySleep)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                session.sample()
            }
        }

        let cancellationTask: Task<AnalysisIOSCancellationCoordinationResult, Never>?
        if plan.runKind == .cancellationProbe, let cancellation = plan.cancellation {
            cancellationTask = Task { @MainActor in
                guard let pollSleep = nanoseconds(cancellation.sourceWorkPollIntervalSeconds),
                      let delaySleep = nanoseconds(cancellation.delayAfterObservedSourceWorkSeconds) else {
                    workloadTask.cancel()
                    return .sourceWorkWaitExpired
                }
                let deadline = ProcessInfo.processInfo.systemUptime + cancellation.maximumWaitForObservedSourceWorkSeconds

                while true {
                    let state = await lifecycle.snapshot()
                    if state.finished {
                        return .workloadFinishedBeforeRequest
                    }
                    if state.sourceWorkBegan {
                        if delaySleep > 0 {
                            do {
                                try await Task.sleep(nanoseconds: delaySleep)
                            } catch {
                                return .workloadFinishedBeforeRequest
                            }
                        }
                        let beforeRequest = await lifecycle.snapshot()
                        if beforeRequest.finished {
                            return .workloadFinishedBeforeRequest
                        }
                        session.recordCancellationRequested()
                        workloadTask.cancel()
                        return .requestedAfterObservedSourceWork
                    }
                    if ProcessInfo.processInfo.systemUptime >= deadline {
                        // Cleanup cancellation is intentionally NOT recorded as the
                        // W23 evidence request because no source work was observed.
                        // The resulting capture must fail closed.
                        workloadTask.cancel()
                        return .sourceWorkWaitExpired
                    }
                    do {
                        try await Task.sleep(nanoseconds: pollSleep)
                    } catch {
                        return .workloadFinishedBeforeRequest
                    }
                }
            }
        } else {
            cancellationTask = nil
        }

        let workload = await workloadTask.value
        telemetryTask.cancel()
        await telemetryTask.value

        let cancellationCoordination: AnalysisIOSCancellationCoordinationResult
        if let cancellationTask {
            cancellationCoordination = await cancellationTask.value
        } else {
            cancellationCoordination = .notApplicable
        }

        if plan.runKind == .cancellationProbe,
           cancellationCoordination == .requestedAfterObservedSourceWork,
           workload.outcome == .cancelled {
            session.recordCancellationObserved()
        }

        let completedNormally = plan.runKind == .completeAnalysis && workload.outcome == .completed
        let failureDescription = performanceFailureDescription(
            runKind: plan.runKind,
            workload: workload,
            cancellationCoordination: cancellationCoordination
        )
        let performance = session.finish(
            completedNormally: completedNormally,
            failureDescription: failureDescription
        )
        let performanceValidation = AnalysisDevicePerformanceEvidenceValidator.validate(
            performance,
            expectedManifestID: plan.manifestID,
            expectedManifestSHA256: plan.manifestSHA256
        )
        let workloadValidation = AnalysisDeviceWorkloadReceiptValidator.validate(
            workload.receipt,
            performanceEvidence: performance,
            policy: workloadPolicy
        )

        var issues: [String] = []
        if performance.provenance.runID != plan.runID
            || performance.provenance.runKind != plan.runKind
            || performance.provenance.fixtureID != plan.source.fixtureID
            || performance.provenance.manifestID != plan.manifestID
            || performance.provenance.manifestSHA256.lowercased() != plan.manifestSHA256.lowercased() {
            issues.append("W23_PROVENANCE_BINDING_MISMATCH")
        }
        if workload.receipt.runID != plan.runID
            || workload.receipt.performanceEvidenceRunID != plan.runID
            || workload.receipt.runKind != plan.runKind
            || workload.receipt.manifestID != plan.manifestID
            || workload.receipt.manifestSHA256.lowercased() != plan.manifestSHA256.lowercased()
            || workload.receipt.source != plan.source
            || workload.receipt.identity != plan.identity {
            issues.append("W36_WORKLOAD_BINDING_MISMATCH")
        }

        let algorithm = workload.algorithmEvidence
        if algorithm?.runID != plan.runID
            || algorithm?.performanceEvidenceRunID != plan.runID
            || algorithm?.workloadExecutionID != workload.receipt.executionID
            || algorithm?.source != plan.source
            || algorithm?.identity != plan.identity
            || algorithm?.sourceInputContract != .boundedPull {
            issues.append("W35_W36_ALGORITHM_BINDING_MISMATCH")
        }

        let expectedWorkloadStatus: AnalysisDeviceWorkloadValidationStatus = plan.runKind == .completeAnalysis
            ? .fullWorkloadCompletePendingHQ
            : .realWorkCancellationPendingHQ
        if workloadValidation.status != expectedWorkloadStatus {
            issues.append("W25_WORKLOAD_VALIDATION_NOT_READY")
        }

        switch plan.runKind {
        case .completeAnalysis:
            if workload.outcome != .completed
                || cancellationCoordination != .notApplicable
                || workload.snapshot == nil
                || algorithm?.captureState != .finalized {
                issues.append("COMPLETE_RUN_SEMANTICS_INVALID")
            }
        case .cancellationProbe:
            if cancellationCoordination != .requestedAfterObservedSourceWork
                || workload.outcome != .cancelled
                || workload.observedSourceSampleCount <= 0
                || workload.snapshot != nil
                || algorithm?.captureState != .cancelledBeforeFinalization {
                issues.append("CANCELLATION_RUN_SEMANTICS_INVALID")
            }
        }

        let status: AnalysisIOSPhysicalCaptureStatus
        if !issues.isEmpty || performanceValidation.status == .invalid {
            status = .invalidExecution
        } else if performanceValidation.status == .nonPhysicalRuntime {
            status = .nonPhysicalRuntime
        } else if performanceValidation.status == .telemetryIncompletePendingHQ {
            status = .telemetryIncompletePendingHQ
        } else if performanceValidation.status == .structurallyCompletePendingHQ {
            status = .structurallyCompletePendingHQ
        } else {
            status = .invalidExecution
        }

        return .init(
            status: status,
            planValidation: planValidation,
            cancellationCoordination: cancellationCoordination,
            performanceEvidence: performance,
            performanceValidation: performanceValidation,
            workloadExecution: workload,
            workloadValidation: workloadValidation,
            algorithmEvidence: algorithm,
            issues: issues.sorted()
        )
    }

    private static func invalidPreflight(
        _ validation: AnalysisDeviceCapturePlanValidationReport,
        issues: [String]
    ) -> AnalysisIOSPhysicalCaptureResult {
        .init(
            status: .invalidPlan,
            planValidation: validation,
            cancellationCoordination: .notApplicable,
            performanceEvidence: nil,
            performanceValidation: nil,
            workloadExecution: nil,
            workloadValidation: nil,
            algorithmEvidence: nil,
            issues: issues.sorted()
        )
    }

    private static func performanceFailureDescription(
        runKind: AnalysisDevicePerformanceRunKind,
        workload: AnalysisCurrentDeviceWorkloadExecution,
        cancellationCoordination: AnalysisIOSCancellationCoordinationResult
    ) -> String? {
        switch runKind {
        case .completeAnalysis:
            if workload.outcome == .completed { return nil }
            return workload.failureDescription ?? "W37_COMPLETE_ANALYSIS_DID_NOT_COMPLETE"
        case .cancellationProbe:
            if cancellationCoordination == .requestedAfterObservedSourceWork,
               workload.outcome == .cancelled {
                return nil
            }
            if cancellationCoordination == .sourceWorkWaitExpired {
                return "W37_SOURCE_WORK_WAIT_EXPIRED_BEFORE_EVIDENCE_CANCELLATION"
            }
            if cancellationCoordination == .workloadFinishedBeforeRequest {
                return "W37_WORKLOAD_FINISHED_BEFORE_PLANNED_CANCELLATION_REQUEST"
            }
            return workload.failureDescription ?? "W37_CANCELLATION_PROBE_DID_NOT_CANCEL"
        }
    }

    private static func nanoseconds(_ seconds: Double) -> UInt64? {
        guard seconds.isFinite, seconds >= 0 else { return nil }
        let value = seconds * 1_000_000_000
        guard value.isFinite, value >= 0, value <= Double(UInt64.max) else { return nil }
        return UInt64(value.rounded())
    }
}
#endif
