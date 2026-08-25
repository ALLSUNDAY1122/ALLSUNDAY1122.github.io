import Foundation

public struct AnalysisCurrentDeviceWorkloadLifecycleSnapshot: Equatable, Sendable {
    public let sourceWorkBegan: Bool
    public let firstObservedChunkSampleCount: Int
    public let finished: Bool
    public let outcome: AnalysisDeviceWorkloadExecutionOutcome?

    public init(
        sourceWorkBegan: Bool,
        firstObservedChunkSampleCount: Int,
        finished: Bool,
        outcome: AnalysisDeviceWorkloadExecutionOutcome?
    ) {
        self.sourceWorkBegan = sourceWorkBegan
        self.firstObservedChunkSampleCount = firstObservedChunkSampleCount
        self.finished = finished
        self.outcome = outcome
    }
}

public protocol AnalysisCurrentDeviceWorkloadLifecycleReporting: Sendable {
    func sourceWorkDidBegin(firstChunkSampleCount: Int) async
    func workloadDidFinish(outcome: AnalysisDeviceWorkloadExecutionOutcome) async
}

/// Low-overhead W37 coordination probe. W36 notifies only once when the first
/// non-empty source chunk is actually returned and once immediately before the
/// runner returns. The probe is orchestration evidence, not a performance timer.
public actor AnalysisCurrentDeviceWorkloadLifecycleProbe: AnalysisCurrentDeviceWorkloadLifecycleReporting {
    private var sourceWorkBegan = false
    private var firstObservedChunkSampleCount = 0
    private var finished = false
    private var outcome: AnalysisDeviceWorkloadExecutionOutcome?

    public init() {}

    public func sourceWorkDidBegin(firstChunkSampleCount: Int) {
        guard !sourceWorkBegan, firstChunkSampleCount > 0 else { return }
        sourceWorkBegan = true
        self.firstObservedChunkSampleCount = firstChunkSampleCount
    }

    public func workloadDidFinish(outcome: AnalysisDeviceWorkloadExecutionOutcome) {
        guard !finished else { return }
        finished = true
        self.outcome = outcome
    }

    public func snapshot() -> AnalysisCurrentDeviceWorkloadLifecycleSnapshot {
        .init(
            sourceWorkBegan: sourceWorkBegan,
            firstObservedChunkSampleCount: firstObservedChunkSampleCount,
            finished: finished,
            outcome: outcome
        )
    }
}
