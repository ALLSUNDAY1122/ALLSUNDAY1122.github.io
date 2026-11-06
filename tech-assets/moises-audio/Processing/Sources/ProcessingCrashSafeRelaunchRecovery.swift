import Foundation

/// Minimal relaunch seam so Processing can compose durable lifecycle recovery with the optional
/// stable-idempotent start resolver without changing the frozen Shared provider contract.
public protocol ProcessingLifecycleRelaunchRecovering: Sendable {
    func recoverAfterRelaunch(projectID: ProjectID) async throws -> ProcessingRecoveryAction
    func recoveryAction(projectID: ProjectID) async throws -> ProcessingRecoveryAction
}

extension ProcessingLifecycleCoordinator: ProcessingLifecycleRelaunchRecovering {}

public protocol ProcessingAmbiguousStartResolving: Sendable {
    func resolve(projectID: ProjectID) async throws -> AmbiguousStartResolution
}

extension ProcessingAmbiguousStartResolver: ProcessingAmbiguousStartResolving {}

/// Crash-safe relaunch front door for P020 processing lifecycle recovery.
///
/// `ProcessingLifecycleCoordinator` can reconnect once a provider job ID is durably bound. A
/// cancellation requested while `start()` is still in flight is different: the durable record may
/// contain `.cancellationRequested` with no job ID when the app is terminated. The remote start may
/// nevertheless have succeeded, so treating that record as a missing binding or blindly retrying
/// could either strand billable work or create a duplicate job.
///
/// This orchestrator recognizes that state as start ambiguity. When a stable-idempotent resolver is
/// available it reuses the same generation key, allowing the existing resolver to recover the job
/// and preserve cancellation intent. Without that capability it fails closed as `.ambiguousStart`.
public actor ProcessingCrashSafeRelaunchRecovery {
    private let lifecycle: any ProcessingLifecycleRelaunchRecovering
    private let stateStore: any ProcessingLifecycleStateStoring
    private let ambiguousStartResolver: (any ProcessingAmbiguousStartResolving)?

    public init(
        lifecycle: any ProcessingLifecycleRelaunchRecovering,
        stateStore: any ProcessingLifecycleStateStoring,
        ambiguousStartResolver: (any ProcessingAmbiguousStartResolving)? = nil
    ) {
        self.lifecycle = lifecycle
        self.stateStore = stateStore
        self.ambiguousStartResolver = ambiguousStartResolver
    }

    @discardableResult
    public func recover(projectID: ProjectID) async throws -> ProcessingRecoveryAction {
        guard let record = try await stateStore.load(projectID: projectID) else { return .none }
        guard needsAmbiguousStartResolution(record) else {
            return try await lifecycle.recoverAfterRelaunch(projectID: projectID)
        }

        guard let ambiguousStartResolver else {
            return .ambiguousStart
        }

        let resolution = try await ambiguousStartResolver.resolve(projectID: projectID)
        switch resolution {
        case .stillAmbiguous:
            return .ambiguousStart
        case .notNeeded, .rebound, .cancellationCompleted:
            // The resolver persists any rebound/cancellation terminal state before returning.
            // Delegate once more so the canonical lifecycle decides whether the result is now
            // reconnect, retry-required, completion, or no-op.
            return try await lifecycle.recoverAfterRelaunch(projectID: projectID)
        }
    }

    /// Non-mutating UI/startup preview. A cancellation intent without a bound job is deliberately
    /// surfaced as ambiguity rather than the generic `PROC_JOB_BINDING_MISSING` path.
    public func recoveryAction(projectID: ProjectID) async throws -> ProcessingRecoveryAction {
        guard let record = try await stateStore.load(projectID: projectID) else { return .none }
        if needsAmbiguousStartResolution(record) {
            return .ambiguousStart
        }
        return try await lifecycle.recoveryAction(projectID: projectID)
    }

    private func needsAmbiguousStartResolution(_ record: DurableProcessingRecord) -> Bool {
        switch record.state {
        case .starting, .startAmbiguous:
            return record.jobID == nil
        case .cancellationRequested:
            return record.jobID == nil
        default:
            return false
        }
    }
}
