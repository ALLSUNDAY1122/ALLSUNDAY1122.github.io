import Foundation

public enum AnalysisDeviceWorkloadExecutionOutcome: String, Codable, Sendable {
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"
    case failed = "FAILED"
}

public struct AnalysisDeviceWorkloadExecution: Sendable {
    public let outcome: AnalysisDeviceWorkloadExecutionOutcome
    public let snapshot: AnalysisSnapshot?
    public let receipt: AnalysisDeviceWorkloadReceipt
    public let failureDescription: String?

    public init(outcome: AnalysisDeviceWorkloadExecutionOutcome, snapshot: AnalysisSnapshot?, receipt: AnalysisDeviceWorkloadReceipt, failureDescription: String?) {
        self.outcome = outcome
        self.snapshot = snapshot
        self.receipt = receipt
        self.failureDescription = failureDescription
    }
}

public struct AnalysisDeviceWorkloadRunContext: Sendable {
    public let runID: String
    public let runKind: AnalysisDevicePerformanceRunKind
    public let manifestID: String
    public let manifestSHA256: String
    public let source: AnalysisDeviceWorkloadSourceBinding
    public let identity: AnalysisDeviceWorkloadIdentity

    public init(runID: String, runKind: AnalysisDevicePerformanceRunKind, manifestID: String, manifestSHA256: String, source: AnalysisDeviceWorkloadSourceBinding, identity: AnalysisDeviceWorkloadIdentity) {
        self.runID = runID
        self.runKind = runKind
        self.manifestID = manifestID
        self.manifestSHA256 = manifestSHA256.lowercased()
        self.source = source
        self.identity = identity
    }
}

public enum AnalysisCanonicalProductPipeline {
    public typealias StageObserver = (AnalysisDeviceWorkloadStageEvent) -> Void

    public static func analyze(
        signal sourceSignal: AnalysisSignal,
        configuration: MusicAnalysisConfiguration = .productBaseline,
        stageObserver: StageObserver? = nil
    ) throws -> AnalysisSnapshot {
        let startUptime = ProcessInfo.processInfo.systemUptime
        func elapsed() -> Double { max(0, ProcessInfo.processInfo.systemUptime - startUptime) }
        func stage<T>(_ id: AnalysisDeviceWorkloadStage, _ operation: () throws -> T) throws -> T {
            let started = elapsed()
            do {
                try AnalysisCancellationPolicy.check()
                let value = try operation()
                try AnalysisCancellationPolicy.check()
                stageObserver?(.init(stage: id, startedOffsetSeconds: started, endedOffsetSeconds: elapsed(), status: .completed))
                return value
            } catch is CancellationError {
                stageObserver?(.init(stage: id, startedOffsetSeconds: started, endedOffsetSeconds: elapsed(), status: .cancelled))
                throw CancellationError()
            } catch {
                stageObserver?(.init(stage: id, startedOffsetSeconds: started, endedOffsetSeconds: elapsed(), status: .failed))
                throw error
            }
        }

        let prepared = try stage(.signalPreparation) {
            try AnalysisWorkingSetPolicy.prepareCancellable(signal: sourceSignal)
        }
        let signal = prepared.signal
        guard signal.durationSeconds >= configuration.minimumDurationSeconds else {
            return AnalysisSnapshot(tempo: nil, key: nil, chords: [], sections: [])
        }

        let tempo = try stage(.tempo) {
            try BoundedTempoBeatAnalyzer.analyzeCancellable(signal: signal, configuration: configuration)
        }
        _ = try stage(.beat) { () -> Int in
            try AnalysisCancellationPolicy.check()
            return tempo?.beatTimesSeconds.count ?? 0
        }
        let key = try stage(.key) {
            try BoundedMusicalKeyAnalyzer.analyzeCancellable(signal: signal, configuration: configuration)
        }
        let chords = try stage(.chord) {
            try BoundedChordTimelineAnalyzer.analyzeCancellable(signal: signal, configuration: configuration)
        }
        let sections = try stage(.section) {
            let detected = try CancellableSongSectionPipeline.analyze(signal: signal, chords: chords, configuration: configuration)
            return try SongSectionBoundaryHardener.harden(sections: detected, signal: signal, chords: chords, configuration: configuration)
        }
        return try stage(.finalSnapshotPublication) {
            let raw = AnalysisSnapshot(tempo: tempo, key: key, chords: chords, sections: sections)
            return try AnalysisSnapshotRobustness.hardenCancellable(snapshot: raw, duration: signal.durationSeconds, configuration: configuration)
        }
    }
}

public enum AnalysisDeviceWorkloadRunner {
    public static func run(
        signal sourceSignal: AnalysisSignal,
        context: AnalysisDeviceWorkloadRunContext,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> AnalysisDeviceWorkloadExecution {
        let executionID = UUID().uuidString.lowercased()
        let workloadStartedAt = Date()
        var events: [AnalysisDeviceWorkloadStageEvent] = []
        var finalSnapshot: AnalysisSnapshot?
        var failureDescription: String?
        var outcome: AnalysisDeviceWorkloadExecutionOutcome = .failed

        let sourceMetadataMatches = abs(sourceSignal.durationSeconds - context.source.sourceDurationSeconds) <= max(0.001, context.source.sourceDurationSeconds * 0.001)
            && abs(sourceSignal.sampleRate - context.source.sourceSampleRate) <= 0.001

        if !sourceMetadataMatches {
            failureDescription = String(describing: AnalysisDeviceWorkloadRunnerError.sourceMetadataMismatch)
        } else {
            do {
                finalSnapshot = try AnalysisCanonicalProductPipeline.analyze(
                    signal: sourceSignal,
                    configuration: configuration,
                    stageObserver: { event in events.append(event) }
                )
                if events.map(\.stage) == AnalysisDeviceWorkloadStage.requiredCompleteOrder,
                   events.allSatisfy({ $0.status == .completed }) {
                    outcome = .completed
                } else {
                    outcome = .failed
                    failureDescription = String(describing: AnalysisDeviceWorkloadRunnerError.incompleteCanonicalPipeline)
                }
            } catch is CancellationError {
                outcome = .cancelled
            } catch {
                outcome = .failed
                failureDescription = String(describing: error)
            }
        }

        var snapshotData: Data?
        var snapshotHash: String?
        var summary: AnalysisDeviceWorkloadOutputSummary?
        if outcome == .completed, let finalSnapshot {
            snapshotData = try? AnalysisSnapshotRobustness.canonicalJSON(finalSnapshot)
            if let snapshotData { snapshotHash = AnalysisDeviceWorkloadSHA256.hexDigest(snapshotData) }
            summary = AnalysisDeviceWorkloadOutputSummary(snapshot: finalSnapshot)
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
            stages: events,
            snapshotSHA256: snapshotHash,
            outputSummary: summary
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
            stages: events,
            snapshotCanonicalJSON: snapshotData,
            snapshotSHA256: snapshotHash,
            outputSummary: summary,
            executionBindingSHA256: binding
        )
        return .init(outcome: outcome, snapshot: finalSnapshot, receipt: receipt, failureDescription: failureDescription)
    }
}

public enum AnalysisDeviceWorkloadRunnerError: Error, Equatable, Sendable {
    case sourceMetadataMismatch
    case incompleteCanonicalPipeline
}
