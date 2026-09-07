import Foundation

/// Optional lane-local capability for providers that can guarantee that repeated start requests
/// using the same key resolve to the same provider job. This intentionally does not modify the
/// frozen HQ `SourceSeparationProviding` contract.
public protocol StableIdempotentSeparationStarting: Sendable {
    func start(_ request: SeparationRequest, idempotencyKey: String) async throws -> ProcessingJobID
}

public struct ClosureStableIdempotentSeparationStarter: StableIdempotentSeparationStarting, Sendable {
    private let operation: @Sendable (SeparationRequest, String) async throws -> ProcessingJobID

    public init(operation: @escaping @Sendable (SeparationRequest, String) async throws -> ProcessingJobID) {
        self.operation = operation
    }

    public func start(_ request: SeparationRequest, idempotencyKey: String) async throws -> ProcessingJobID {
        try await operation(request, idempotencyKey)
    }
}

public enum StableProcessingIdempotencyKey {
    public static func value(generationID: UUID) -> String {
        "proc-" + generationID.uuidString.lowercased()
    }
}

public enum AmbiguousStartResolution: Equatable, Sendable {
    case notNeeded
    case rebound(jobID: ProcessingJobID)
    case cancellationCompleted(jobID: ProcessingJobID)
    case stillAmbiguous(stableErrorCode: String)
}

/// Resolves only the start-response-loss gap that the frozen Shared contract cannot express.
///
/// If a selected provider offers a stable idempotent start operation, the durable processing
/// generation UUID becomes the caller key. The same generation therefore reuses the same provider
/// job across network retry or app relaunch. Providers without this capability continue to use the
/// fail-closed `PROC_START_AMBIGUOUS` path in `ProcessingLifecycleCoordinator`.
public actor ProcessingAmbiguousStartResolver {
    private let provider: any SourceSeparationProviding
    private let stableStarter: any StableIdempotentSeparationStarting
    private let stateStore: any ProcessingLifecycleStateStoring
    private let projectPersistence: any ProjectPersisting
    private let outputTransaction: any ProcessingOutputTransacting
    private let now: @Sendable () -> Date

    public init(
        provider: any SourceSeparationProviding,
        stableStarter: any StableIdempotentSeparationStarting,
        stateStore: any ProcessingLifecycleStateStoring,
        projectPersistence: any ProjectPersisting,
        outputTransaction: any ProcessingOutputTransacting,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.provider = provider
        self.stableStarter = stableStarter
        self.stateStore = stateStore
        self.projectPersistence = projectPersistence
        self.outputTransaction = outputTransaction
        self.now = now
    }

    @discardableResult
    public func resolve(projectID: ProjectID) async throws -> AmbiguousStartResolution {
        guard let record = try await stateStore.load(projectID: projectID) else { return .notNeeded }

        let cancellationIntent: Bool
        switch record.state {
        case .starting, .startAmbiguous:
            cancellationIntent = false
        case .cancellationRequested where record.jobID == nil:
            cancellationIntent = true
        default:
            return .notNeeded
        }

        guard record.jobID == nil else { return .notNeeded }
        let key = StableProcessingIdempotencyKey.value(generationID: record.generationID)

        let jobID: ProcessingJobID
        do {
            jobID = try await stableStarter.start(record.request, idempotencyKey: key)
        } catch {
            let classification = classifyStableStart(error)
            if classification.definitiveFailure {
                let failed = record.replacing(
                    state: .failed,
                    retryable: classification.retryable,
                    stableErrorCode: classification.code,
                    preserveErrorWhenNil: false,
                    updatedAt: now()
                )
                try await stateStore.save(failed)
                try? await outputTransaction.rollback(projectID: projectID, generationID: record.generationID)
                throw DomainFailure.processingFailed(code: classification.code, retryable: classification.retryable)
            }

            let ambiguous = record.replacing(
                state: cancellationIntent ? .cancellationRequested : .startAmbiguous,
                retryable: true,
                stableErrorCode: classification.code,
                preserveErrorWhenNil: false,
                updatedAt: now()
            )
            try await stateStore.save(ambiguous)
            return .stillAmbiguous(stableErrorCode: classification.code)
        }

        guard let latest = try await stateStore.load(projectID: projectID),
              latest.generationID == record.generationID else {
            await provider.cancel(jobID: jobID)
            throw DomainFailure.processingFailed(code: "PROC_IDEMPOTENT_REBIND_SUPERSEDED", retryable: false)
        }

        if latest.state == .cancellationRequested {
            // Persist the recovered job binding before remote cancellation or local cleanup. If
            // either later operation fails, relaunch still has enough information to reconnect and
            // repeat the idempotent cancel/rollback path instead of losing the provider job.
            let boundCancellation = latest.replacing(
                jobID: jobID,
                state: .cancellationRequested,
                retryable: true,
                stableErrorCode: "PROC_CANCEL_REBOUND_PENDING_CLEANUP",
                preserveErrorWhenNil: false,
                updatedAt: now()
            )
            try await stateStore.save(boundCancellation)
            await provider.cancel(jobID: jobID)
            try await outputTransaction.rollback(projectID: projectID, generationID: latest.generationID)

            let cancelledSnapshot = ProcessingSnapshot(
                jobID: jobID,
                phase: .cancelled,
                fractionComplete: latest.lastSnapshot?.fractionComplete,
                retryable: true,
                stableErrorCode: "PROC_CANCELLED_AFTER_IDEMPOTENT_REBIND"
            )
            let cancelled = boundCancellation.replacing(
                state: .cancelled,
                lastSnapshot: cancelledSnapshot,
                retryable: true,
                stableErrorCode: cancelledSnapshot.stableErrorCode,
                preserveErrorWhenNil: false,
                updatedAt: now()
            )
            try await stateStore.save(cancelled)
            try await projectPersistence.recordProcessing(projectID: projectID, snapshot: cancelledSnapshot)
            return .cancellationCompleted(jobID: jobID)
        }

        guard latest.state == .starting || latest.state == .startAmbiguous else {
            await provider.cancel(jobID: jobID)
            throw DomainFailure.processingFailed(code: "PROC_IDEMPOTENT_REBIND_STATE_CHANGED", retryable: false)
        }

        let queued = ProcessingSnapshot(
            jobID: jobID,
            phase: .queued,
            fractionComplete: 0,
            retryable: true,
            stableErrorCode: nil
        )
        let rebound = latest.replacing(
            jobID: jobID,
            state: .active,
            lastSnapshot: queued,
            retryable: true,
            stableErrorCode: nil,
            preserveErrorWhenNil: false,
            updatedAt: now()
        )
        try await stateStore.save(rebound)

        // The durable job binding is canonical before the secondary project-persistence seam.
        // If this call fails, relaunch can reconnect to the same job and replay the write.
        try await projectPersistence.recordProcessing(projectID: projectID, snapshot: queued)
        return .rebound(jobID: jobID)
    }

    private func classifyStableStart(_ error: Error) -> (code: String, retryable: Bool, definitiveFailure: Bool) {
        guard let failure = error as? DomainFailure else {
            return ("PROC_IDEMPOTENT_START_UNKNOWN", true, false)
        }
        switch failure {
        case .accessDenied:
            return ("PROC_ACCESS_DENIED", false, true)
        case .unsupportedMedia:
            return ("PROC_UNSUPPORTED_MEDIA", false, true)
        case .protectedMedia:
            return ("PROC_PROTECTED_MEDIA", false, true)
        case .corruptMedia:
            return ("PROC_CORRUPT_MEDIA", false, true)
        case .noAudioTrack:
            return ("PROC_NO_AUDIO_TRACK", false, true)
        case .insufficientStorage:
            return ("PROC_INSUFFICIENT_STORAGE", true, true)
        case .cancelled:
            return ("PROC_IDEMPOTENT_START_CANCELLED", true, false)
        case .providerUnavailable:
            return ("PROC_PROVIDER_UNAVAILABLE", true, false)
        case .networkUnavailable:
            return ("PROC_NETWORK_UNAVAILABLE", true, false)
        case .networkTimeout:
            return ("PROC_NETWORK_TIMEOUT", true, false)
        case .processingFailed(let code, let retryable):
            return (code, retryable, !retryable)
        case .exportFailed(let code):
            return ("PROC_EXPORT_" + code, false, true)
        }
    }
}
