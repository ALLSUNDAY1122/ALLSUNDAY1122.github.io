import Foundation

public struct AnalysisCurrentDeviceWorkloadExecution: Sendable {
    public let outcome: AnalysisDeviceWorkloadExecutionOutcome
    public let snapshot: AnalysisSnapshot?
    public let receipt: AnalysisDeviceWorkloadReceipt
    public let algorithmEvidence: AnalysisDeviceAlgorithmExecutionEvidence?
    public let inputDiagnostics: AnalysisChunkedInputDiagnostics?
    public let featureDiagnostics: AnalysisSinglePassPreparedFeatureDiagnostics?
    public let boundedSourceContractAccepted: Bool
    public let failureDescription: String?

    public init(
        outcome: AnalysisDeviceWorkloadExecutionOutcome,
        snapshot: AnalysisSnapshot?,
        receipt: AnalysisDeviceWorkloadReceipt,
        algorithmEvidence: AnalysisDeviceAlgorithmExecutionEvidence?,
        inputDiagnostics: AnalysisChunkedInputDiagnostics?,
        featureDiagnostics: AnalysisSinglePassPreparedFeatureDiagnostics?,
        boundedSourceContractAccepted: Bool,
        failureDescription: String?
    ) {
        self.outcome = outcome
        self.snapshot = snapshot
        self.receipt = receipt
        self.algorithmEvidence = algorithmEvidence
        self.inputDiagnostics = inputDiagnostics
        self.featureDiagnostics = featureDiagnostics
        self.boundedSourceContractAccepted = boundedSourceContractAccepted
        self.failureDescription = failureDescription
    }
}

public enum AnalysisCurrentDeviceWorkloadRunnerError: Error, Equatable, Sendable {
    case nonBoundedSourceContract(AnalysisChunkedSourceMemoryContract)
    case invalidSourceDescriptor
    case sourceMetadataMismatch
    case cancellationProbeCompletedWithoutCancellation
}

/// W36 physical workload runner.
///
/// Unlike the historical W25 runner, this executes the same W30-W34 chunked
/// runtime used by `ProjectOwnedMusicAnalyzer` when a chunked loader is present.
/// One execution ID binds the W25 receipt and W35 algorithm companion.
///
/// `SIGNAL_PREPARATION` now honestly includes pull/decode-side PCM consumption,
/// W30 resampling, W29-W32 shared feature extraction and W33/W34 Chord spectral
/// preclassification. The later CHORD stage finalizes the preclassified timeline;
/// W36 does not pretend that the heavy spectral work happened there.
public enum AnalysisCurrentDeviceWorkloadRunner {
    public static func run(
        signal: AnalysisChunkedSignal,
        context: AnalysisDeviceWorkloadRunContext,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) async -> AnalysisCurrentDeviceWorkloadExecution {
        let executionID = UUID().uuidString.lowercased()
        let workloadStartedAt = Date()
        let recorder = AnalysisCurrentDeviceWorkloadStageRecorder()
        let boundedSourceContractAccepted = signal.sourceMemoryContract == .boundedPull

        var outcome: AnalysisDeviceWorkloadExecutionOutcome = .failed
        var finalSnapshot: AnalysisSnapshot?
        var snapshotData: Data?
        var snapshotHash: String?
        var outputSummary: AnalysisDeviceWorkloadOutputSummary?
        var inputDiagnostics: AnalysisChunkedInputDiagnostics?
        var featureDiagnostics: AnalysisSinglePassPreparedFeatureDiagnostics?
        var failureDescription: String?

        let descriptor = signal.descriptor
        let descriptorValid = descriptor.sampleRate.isFinite
            && descriptor.sampleRate > 0
            && descriptor.sampleCount >= 0
            && descriptor.sampleCount <= Int64(Int.max)
        let durationTolerance = max(0.001, context.source.sourceDurationSeconds * 0.001)
        let metadataMatches = descriptorValid
            && abs(descriptor.durationSeconds - context.source.sourceDurationSeconds) <= durationTolerance
            && abs(descriptor.sampleRate - context.source.sourceSampleRate) <= 0.001

        if !boundedSourceContractAccepted {
            failureDescription = String(describing: AnalysisCurrentDeviceWorkloadRunnerError.nonBoundedSourceContract(signal.sourceMemoryContract))
        } else if !descriptorValid {
            failureDescription = String(describing: AnalysisCurrentDeviceWorkloadRunnerError.invalidSourceDescriptor)
        } else if !metadataMatches {
            failureDescription = String(describing: AnalysisCurrentDeviceWorkloadRunnerError.sourceMetadataMismatch)
        } else {
            do {
                let extracted = try await recorder.runAsync(stage: .signalPreparation) {
                    try await AnalysisCurrentChunkedProductRuntime.extract(
                        signal: signal,
                        configuration: configuration
                    )
                }
                inputDiagnostics = extracted.inputDiagnostics
                featureDiagnostics = extracted.features.diagnostics

                let tempo = try recorder.run(stage: .tempo) {
                    try AnalysisCurrentChunkedProductRuntime.finalizeTempo(
                        features: extracted.features,
                        configuration: configuration
                    )
                }
                _ = try recorder.run(stage: .beat) {
                    try AnalysisCurrentChunkedProductRuntime.observeBeatCount(tempo)
                }
                let key = try recorder.run(stage: .key) {
                    try AnalysisCurrentChunkedProductRuntime.finalizeKey(
                        features: extracted.features,
                        configuration: configuration
                    )
                }
                let chords = try recorder.run(stage: .chord) {
                    try AnalysisCurrentChunkedProductRuntime.finalizeChords(
                        features: extracted.features,
                        configuration: configuration
                    )
                }
                let sections = try recorder.run(stage: .section) {
                    try AnalysisCurrentChunkedProductRuntime.finalizeSections(
                        features: extracted.features,
                        chords: chords,
                        configuration: configuration
                    )
                }
                let publication = try recorder.run(stage: .finalSnapshotPublication) { () throws -> (AnalysisSnapshot, Data, String, AnalysisDeviceWorkloadOutputSummary) in
                    let snapshot = try AnalysisCurrentChunkedProductRuntime.publishSnapshot(
                        features: extracted.features,
                        tempo: tempo,
                        key: key,
                        chords: chords,
                        sections: sections,
                        configuration: configuration
                    )
                    let data = try AnalysisSnapshotRobustness.canonicalJSON(snapshot)
                    let hash = AnalysisDeviceWorkloadSHA256.hexDigest(data)
                    return (snapshot, data, hash, AnalysisDeviceWorkloadOutputSummary(snapshot: snapshot))
                }

                if context.runKind == .completeAnalysis {
                    outcome = .completed
                    finalSnapshot = publication.0
                    snapshotData = publication.1
                    snapshotHash = publication.2
                    outputSummary = publication.3
                } else {
                    outcome = .failed
                    failureDescription = String(describing: AnalysisCurrentDeviceWorkloadRunnerError.cancellationProbeCompletedWithoutCancellation)
                }
            } catch is CancellationError {
                outcome = .cancelled
            } catch {
                outcome = .failed
                failureDescription = String(describing: error)
            }
        }

        let binding = AnalysisDeviceWorkloadReceiptValidator.executionBindingSHA256(
            runID: context.runID,
            performanceEvidenceRunID: context.runID,
            runKind: context.runKind,
            manifestID: context.manifestID,
            manifestSHA256: context.manifestSHA256,
            source: context.source,
            identity: context.identity,
            executionID: executionID,
            workloadStartedAt: workloadStartedAt,
            stages: recorder.events,
            snapshotSHA256: snapshotHash,
            outputSummary: outputSummary
        )
        let receipt = AnalysisDeviceWorkloadReceipt(
            runID: context.runID,
            performanceEvidenceRunID: context.runID,
            runKind: context.runKind,
            manifestID: context.manifestID,
            manifestSHA256: context.manifestSHA256,
            source: context.source,
            identity: context.identity,
            executionID: executionID,
            workloadStartedAt: workloadStartedAt,
            stages: recorder.events,
            snapshotCanonicalJSON: snapshotData,
            snapshotSHA256: snapshotHash,
            outputSummary: outputSummary,
            executionBindingSHA256: binding
        )

        let algorithmEvidence: AnalysisDeviceAlgorithmExecutionEvidence?
        if context.runKind == .completeAnalysis,
           outcome == .completed,
           let featureDiagnostics {
            algorithmEvidence = try? AnalysisDeviceAlgorithmExecutionEvidenceBuilder.finalized(
                receipt: receipt,
                diagnostics: featureDiagnostics,
                sourceInputContract: signal.sourceMemoryContract
            )
        } else if context.runKind == .cancellationProbe,
                  outcome == .cancelled,
                  boundedSourceContractAccepted {
            algorithmEvidence = AnalysisDeviceAlgorithmExecutionEvidenceBuilder.cancelledBeforeFinalization(
                receipt: receipt,
                sourceInputContract: signal.sourceMemoryContract
            )
        } else {
            algorithmEvidence = nil
        }

        return .init(
            outcome: outcome,
            snapshot: finalSnapshot,
            receipt: receipt,
            algorithmEvidence: algorithmEvidence,
            inputDiagnostics: inputDiagnostics,
            featureDiagnostics: featureDiagnostics,
            boundedSourceContractAccepted: boundedSourceContractAccepted,
            failureDescription: failureDescription
        )
    }
}

private final class AnalysisCurrentDeviceWorkloadStageRecorder {
    private let startedUptime = ProcessInfo.processInfo.systemUptime
    private(set) var events: [AnalysisDeviceWorkloadStageEvent] = []

    func run<T>(
        stage: AnalysisDeviceWorkloadStage,
        operation: () throws -> T
    ) throws -> T {
        let started = elapsed()
        do {
            try AnalysisCancellationPolicy.check()
            let value = try operation()
            try AnalysisCancellationPolicy.check()
            events.append(.init(
                stage: stage,
                startedOffsetSeconds: started,
                endedOffsetSeconds: elapsed(),
                status: .completed
            ))
            return value
        } catch is CancellationError {
            events.append(.init(
                stage: stage,
                startedOffsetSeconds: started,
                endedOffsetSeconds: elapsed(),
                status: .cancelled
            ))
            throw CancellationError()
        } catch {
            events.append(.init(
                stage: stage,
                startedOffsetSeconds: started,
                endedOffsetSeconds: elapsed(),
                status: .failed
            ))
            throw error
        }
    }

    func runAsync<T>(
        stage: AnalysisDeviceWorkloadStage,
        operation: () async throws -> T
    ) async throws -> T {
        let started = elapsed()
        do {
            try AnalysisCancellationPolicy.check()
            let value = try await operation()
            try AnalysisCancellationPolicy.check()
            events.append(.init(
                stage: stage,
                startedOffsetSeconds: started,
                endedOffsetSeconds: elapsed(),
                status: .completed
            ))
            return value
        } catch is CancellationError {
            events.append(.init(
                stage: stage,
                startedOffsetSeconds: started,
                endedOffsetSeconds: elapsed(),
                status: .cancelled
            ))
            throw CancellationError()
        } catch {
            events.append(.init(
                stage: stage,
                startedOffsetSeconds: started,
                endedOffsetSeconds: elapsed(),
                status: .failed
            ))
            throw error
        }
    }

    private func elapsed() -> Double {
        max(0, ProcessInfo.processInfo.systemUptime - startedUptime)
    }
}
