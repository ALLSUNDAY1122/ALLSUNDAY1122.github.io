import Foundation

public enum ProcessingRecoveryAction: Equatable, Sendable {
    case none
    case reconnect(jobID: ProcessingJobID)
    case retryRequired(stableErrorCode: String?)
    case ambiguousStart
}

/// Coordinates the canonical SourceSeparationProviding contract with durable processing state.
///
/// Key safety rules:
/// - a project has one durable processing generation at a time;
/// - an observed active job is reused instead of starting a duplicate;
/// - a start request that may have reached the server but lost its response is never auto-retried;
/// - provider progress may advance but may not regress;
/// - cancelled/failed generations rollback partial local stem output;
/// - result finalization is two-phase so relaunch can resume after files or DB state were written.
public actor ProcessingLifecycleCoordinator {
    private let provider: SourceSeparationProviding
    private let projectPersistence: ProjectPersisting
    private let stateStore: ProcessingLifecycleStateStoring
    private let outputTransaction: ProcessingOutputTransacting
    private let now: @Sendable () -> Date
    private var inFlightStartGenerations = Set<UUID>()

    public init(
        provider: SourceSeparationProviding,
        projectPersistence: ProjectPersisting,
        stateStore: ProcessingLifecycleStateStoring,
        outputTransaction: ProcessingOutputTransacting,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.provider = provider
        self.projectPersistence = projectPersistence
        self.stateStore = stateStore
        self.outputTransaction = outputTransaction
        self.now = now
    }

    /// Starts a new generation or returns the already-bound job for the same request.
    /// It never retries an ambiguous server start automatically.
    public func startOrReconnect(_ request: SeparationRequest) async throws -> ProcessingJobID {
        if let record = try await stateStore.load(projectID: request.projectID) {
            guard record.request == request else {
                switch record.state {
                case .failed, .cancelled, .completed:
                    throw DomainFailure.processingFailed(code: "PROC_NEW_REQUEST_REQUIRES_EXPLICIT_RETRY", retryable: false)
                default:
                    throw DomainFailure.processingFailed(code: "PROC_DIFFERENT_REQUEST_ACTIVE", retryable: false)
                }
            }

            switch record.state {
            case .active, .cancellationRequested, .ready, .resultStaged, .resultPersisted, .completed:
                guard let jobID = record.jobID else {
                    throw DomainFailure.processingFailed(code: "PROC_JOB_BINDING_MISSING", retryable: false)
                }
                return jobID
            case .starting:
                if inFlightStartGenerations.contains(record.generationID) {
                    throw DomainFailure.processingFailed(code: "PROC_START_IN_FLIGHT", retryable: true)
                }
                throw DomainFailure.processingFailed(code: "PROC_START_AMBIGUOUS", retryable: false)
            case .startAmbiguous:
                throw DomainFailure.processingFailed(code: "PROC_START_AMBIGUOUS", retryable: false)
            case .failed, .cancelled:
                throw DomainFailure.processingFailed(code: record.stableErrorCode ?? "PROC_RETRY_REQUIRED", retryable: record.retryable)
            }
        }

        return try await startNew(request: request, retryCount: 0)
    }

    /// Reads authoritative server state and durably mirrors it into ProjectPersisting.
    @discardableResult
    public func poll(projectID: ProjectID) async throws -> ProcessingSnapshot {
        guard var record = try await stateStore.load(projectID: projectID) else {
            throw DomainFailure.processingFailed(code: "PROC_STATE_MISSING", retryable: false)
        }

        switch record.state {
        case .resultStaged, .resultPersisted, .completed:
            guard let snapshot = record.lastSnapshot else {
                throw DomainFailure.processingFailed(code: "PROC_SNAPSHOT_MISSING", retryable: false)
            }
            return snapshot
        case .starting, .startAmbiguous:
            throw DomainFailure.processingFailed(code: "PROC_JOB_BINDING_UNKNOWN", retryable: false)
        default:
            break
        }

        guard let jobID = record.jobID else {
            throw DomainFailure.processingFailed(code: "PROC_JOB_BINDING_MISSING", retryable: false)
        }

        var snapshot = try await provider.snapshot(jobID: jobID)
        snapshot = try normalized(snapshot: snapshot, previous: record.lastSnapshot)

        if record.state == .cancellationRequested, snapshot.phase == .ready {
            let cancelled = ProcessingSnapshot(
                jobID: jobID,
                phase: .cancelled,
                fractionComplete: snapshot.fractionComplete,
                retryable: true,
                stableErrorCode: "PROC_CANCEL_RACE_SERVER_COMPLETED"
            )
            record = record.replacing(
                state: .cancelled,
                lastSnapshot: cancelled,
                retryable: true,
                stableErrorCode: cancelled.stableErrorCode,
                preserveErrorWhenNil: false,
                updatedAt: now()
            )
            try await stateStore.save(record)
            try await projectPersistence.recordProcessing(projectID: projectID, snapshot: cancelled)
            try await outputTransaction.rollback(projectID: projectID, generationID: record.generationID)
            return cancelled
        }

        let nextState: DurableProcessingState
        switch snapshot.phase {
        case .ready:
            nextState = .ready
        case .failed:
            nextState = .failed
        case .cancelled:
            nextState = .cancelled
        default:
            nextState = record.state == .cancellationRequested ? .cancellationRequested : .active
        }

        record = record.replacing(
            state: nextState,
            lastSnapshot: snapshot,
            retryable: snapshot.retryable,
            stableErrorCode: snapshot.stableErrorCode,
            preserveErrorWhenNil: false,
            updatedAt: now()
        )
        try await stateStore.save(record)
        try await projectPersistence.recordProcessing(projectID: projectID, snapshot: snapshot)

        if nextState == .failed || nextState == .cancelled {
            try await outputTransaction.rollback(projectID: projectID, generationID: record.generationID)
        }

        return snapshot
    }

    /// Marks cancellation intent durably before issuing the non-throwing provider cancel call.
    /// A relaunch will reconnect until the provider confirms a terminal state.
    public func requestCancel(projectID: ProjectID) async throws {
        guard var record = try await stateStore.load(projectID: projectID) else { return }

        switch record.state {
        case .failed, .cancelled, .completed:
            return
        case .ready, .resultStaged, .resultPersisted:
            try await outputTransaction.rollback(projectID: projectID, generationID: record.generationID)
            if let jobID = record.jobID {
                let cancelled = ProcessingSnapshot(
                    jobID: jobID,
                    phase: .cancelled,
                    fractionComplete: record.lastSnapshot?.fractionComplete,
                    retryable: true,
                    stableErrorCode: "PROC_CANCELLED_AFTER_READY"
                )
                record = record.replacing(
                    state: .cancelled,
                    lastSnapshot: cancelled,
                    resultArtifacts: nil,
                    preserveArtifactsWhenNil: false,
                    retryable: true,
                    stableErrorCode: cancelled.stableErrorCode,
                    preserveErrorWhenNil: false,
                    updatedAt: now()
                )
                try await stateStore.save(record)
                try await projectPersistence.recordProcessing(projectID: projectID, snapshot: cancelled)
            }
            return
        case .starting:
            record = record.replacing(
                state: .cancellationRequested,
                retryable: true,
                stableErrorCode: "PROC_CANCEL_REQUESTED_DURING_START",
                preserveErrorWhenNil: false,
                updatedAt: now()
            )
            try await stateStore.save(record)
            return
        case .startAmbiguous:
            throw DomainFailure.processingFailed(code: "PROC_CANCEL_UNAVAILABLE_AMBIGUOUS_START", retryable: false)
        case .active, .cancellationRequested:
            break
        }

        guard let jobID = record.jobID else {
            throw DomainFailure.processingFailed(code: "PROC_JOB_BINDING_MISSING", retryable: false)
        }
        record = record.replacing(
            state: .cancellationRequested,
            retryable: true,
            stableErrorCode: "PROC_CANCEL_REQUESTED",
            preserveErrorWhenNil: false,
            updatedAt: now()
        )
        try await stateStore.save(record)
        await provider.cancel(jobID: jobID)
    }

    /// Finalizes a ready job. The staged/resultPersisted states close crash windows between
    /// provider file creation, DB persistence and rollback-backup deletion.
    public func finish(projectID: ProjectID) async throws -> [StemArtifact] {
        guard var record = try await stateStore.load(projectID: projectID) else {
            throw DomainFailure.processingFailed(code: "PROC_STATE_MISSING", retryable: false)
        }

        if record.state == .resultPersisted || record.state == .completed {
            guard let artifacts = record.resultArtifacts else {
                throw DomainFailure.processingFailed(code: "PROC_RESULT_JOURNAL_MISSING", retryable: false)
            }
            try await outputTransaction.validateFinalArtifacts(artifacts, projectID: projectID)
            if record.state == .resultPersisted {
                try await outputTransaction.commit(projectID: projectID, generationID: record.generationID)
                record = record.replacing(state: .completed, retryable: false, updatedAt: now())
                try await stateStore.save(record)
            }
            return artifacts
        }

        if record.state == .resultStaged {
            return try await persistStagedResult(record)
        }

        if record.state != .ready {
            let snapshot = try await poll(projectID: projectID)
            guard snapshot.phase == .ready else {
                throw DomainFailure.processingFailed(code: "PROC_RESULT_NOT_READY", retryable: true)
            }
            guard let refreshed = try await stateStore.load(projectID: projectID) else {
                throw DomainFailure.processingFailed(code: "PROC_STATE_MISSING_AFTER_POLL", retryable: false)
            }
            record = refreshed
        }

        guard let jobID = record.jobID else {
            throw DomainFailure.processingFailed(code: "PROC_JOB_BINDING_MISSING", retryable: false)
        }

        do {
            let artifacts = try await provider.result(jobID: jobID)
            try validateResultArtifacts(artifacts, record: record)
            try await outputTransaction.validateFinalArtifacts(artifacts, projectID: projectID)

            let staged = record.replacing(
                state: .resultStaged,
                resultArtifacts: artifacts,
                preserveArtifactsWhenNil: false,
                retryable: true,
                stableErrorCode: nil,
                preserveErrorWhenNil: false,
                updatedAt: now()
            )
            try await stateStore.save(staged)
            return try await persistStagedResult(staged)
        } catch {
            let classification = classify(error)
            if classification.retryable {
                let ready = record.replacing(
                    state: .ready,
                    retryable: true,
                    stableErrorCode: classification.code,
                    preserveErrorWhenNil: false,
                    updatedAt: now()
                )
                try? await stateStore.save(ready)
                throw DomainFailure.processingFailed(code: classification.code, retryable: true)
            }

            let failedSnapshot = ProcessingSnapshot(
                jobID: jobID,
                phase: .failed,
                fractionComplete: record.lastSnapshot?.fractionComplete,
                retryable: false,
                stableErrorCode: classification.code
            )
            let failed = record.replacing(
                state: .failed,
                lastSnapshot: failedSnapshot,
                resultArtifacts: nil,
                preserveArtifactsWhenNil: false,
                retryable: false,
                stableErrorCode: classification.code,
                preserveErrorWhenNil: false,
                updatedAt: now()
            )
            try? await stateStore.save(failed)
            try? await projectPersistence.recordProcessing(projectID: projectID, snapshot: failedSnapshot)
            try? await outputTransaction.rollback(projectID: projectID, generationID: record.generationID)
            throw DomainFailure.processingFailed(code: classification.code, retryable: false)
        }
    }

    /// Creates a new generation only after a terminal/retryable state. Ambiguous starts require
    /// explicit opt-in because the canonical SourceSeparationProviding.start contract cannot pass a
    /// deterministic client idempotency key to the backend.
    public func retry(
        _ request: SeparationRequest,
        allowPotentialDuplicateStart: Bool = false
    ) async throws -> ProcessingJobID {
        guard let record = try await stateStore.load(projectID: request.projectID) else {
            return try await startNew(request: request, retryCount: 0)
        }

        switch record.state {
        case .startAmbiguous, .starting:
            guard allowPotentialDuplicateStart else {
                throw DomainFailure.processingFailed(code: "PROC_AMBIGUOUS_RETRY_REQUIRES_CONFIRMATION", retryable: false)
            }
        case .failed, .cancelled:
            guard record.retryable else {
                throw DomainFailure.processingFailed(code: record.stableErrorCode ?? "PROC_FAILURE_NOT_RETRYABLE", retryable: false)
            }
        case .completed:
            break
        default:
            throw DomainFailure.processingFailed(code: "PROC_RETRY_WHILE_ACTIVE", retryable: false)
        }

        try await outputTransaction.rollback(projectID: record.projectID, generationID: record.generationID)
        return try await startNew(request: request, retryCount: record.retryCount + 1)
    }

    /// Safe relaunch recovery. Active jobs reconnect, ready jobs finish immediately so expiring
    /// result URLs are captured, and two-phase local finalization resumes without re-running AI.
    @discardableResult
    public func recoverAfterRelaunch(projectID: ProjectID) async throws -> ProcessingRecoveryAction {
        guard let record = try await stateStore.load(projectID: projectID) else { return .none }

        switch record.state {
        case .completed:
            return .none
        case .startAmbiguous, .starting:
            return .ambiguousStart
        case .failed, .cancelled:
            return .retryRequired(stableErrorCode: record.stableErrorCode)
        case .resultStaged:
            _ = try await persistStagedResult(record)
            return .none
        case .resultPersisted:
            _ = try await finish(projectID: projectID)
            return .none
        case .ready:
            _ = try await finish(projectID: projectID)
            return .none
        case .active, .cancellationRequested:
            let snapshot = try await poll(projectID: projectID)
            switch snapshot.phase {
            case .ready:
                _ = try await finish(projectID: projectID)
                return .none
            case .failed, .cancelled:
                return .retryRequired(stableErrorCode: snapshot.stableErrorCode)
            default:
                return .reconnect(jobID: snapshot.jobID)
            }
        }
    }

    public func recoveryAction(projectID: ProjectID) async throws -> ProcessingRecoveryAction {
        guard let record = try await stateStore.load(projectID: projectID) else { return .none }
        switch record.state {
        case .completed:
            return .none
        case .starting, .startAmbiguous:
            return .ambiguousStart
        case .failed, .cancelled:
            return .retryRequired(stableErrorCode: record.stableErrorCode)
        case .active, .cancellationRequested, .ready, .resultStaged, .resultPersisted:
            guard let jobID = record.jobID else {
                throw DomainFailure.processingFailed(code: "PROC_JOB_BINDING_MISSING", retryable: false)
            }
            return .reconnect(jobID: jobID)
        }
    }

    private func startNew(request: SeparationRequest, retryCount: Int) async throws -> ProcessingJobID {
        let generationID = UUID()
        var record = DurableProcessingRecord(
            projectID: request.projectID,
            request: request,
            generationID: generationID,
            jobID: nil,
            state: .starting,
            lastSnapshot: nil,
            resultArtifacts: nil,
            retryCount: retryCount,
            retryable: true,
            stableErrorCode: nil,
            updatedAt: now()
        )
        inFlightStartGenerations.insert(generationID)
        defer { inFlightStartGenerations.remove(generationID) }

        try await stateStore.save(record)
        do {
            try await outputTransaction.begin(projectID: request.projectID, generationID: generationID)
        } catch {
            let classification = classify(error)
            record = record.replacing(
                state: .failed,
                retryable: classification.retryable,
                stableErrorCode: classification.code,
                preserveErrorWhenNil: false,
                updatedAt: now()
            )
            try? await stateStore.save(record)
            throw error
        }

        do {
            let jobID = try await provider.start(request)

            if let latest = try await stateStore.load(projectID: request.projectID),
               latest.generationID == generationID,
               latest.state == .cancellationRequested {
                await provider.cancel(jobID: jobID)
                let cancelled = ProcessingSnapshot(
                    jobID: jobID,
                    phase: .cancelled,
                    fractionComplete: nil,
                    retryable: true,
                    stableErrorCode: "PROC_CANCELLED_DURING_START"
                )
                record = latest.replacing(
                    jobID: jobID,
                    state: .cancelled,
                    lastSnapshot: cancelled,
                    retryable: true,
                    stableErrorCode: cancelled.stableErrorCode,
                    preserveErrorWhenNil: false,
                    updatedAt: now()
                )
                try await stateStore.save(record)
                try await projectPersistence.recordProcessing(projectID: request.projectID, snapshot: cancelled)
                try await outputTransaction.rollback(projectID: request.projectID, generationID: generationID)
                return jobID
            }

            let queued = ProcessingSnapshot(
                jobID: jobID,
                phase: .queued,
                fractionComplete: 0,
                retryable: true,
                stableErrorCode: nil
            )
            record = record.replacing(
                jobID: jobID,
                state: .active,
                lastSnapshot: queued,
                retryable: true,
                stableErrorCode: nil,
                preserveErrorWhenNil: false,
                updatedAt: now()
            )
            try await stateStore.save(record)
            try await projectPersistence.recordProcessing(projectID: request.projectID, snapshot: queued)
            return jobID
        } catch {
            if let latest = try? await stateStore.load(projectID: request.projectID),
               latest?.generationID == generationID,
               latest?.state == .cancelled {
                throw DomainFailure.cancelled
            }

            let classification = classifyStart(error)
            record = record.replacing(
                state: classification.ambiguous ? .startAmbiguous : .failed,
                retryable: classification.retryable,
                stableErrorCode: classification.code,
                preserveErrorWhenNil: false,
                updatedAt: now()
            )
            try? await stateStore.save(record)
            try? await outputTransaction.rollback(projectID: request.projectID, generationID: generationID)
            throw DomainFailure.processingFailed(code: classification.code, retryable: classification.retryable)
        }
    }

    private func persistStagedResult(_ staged: DurableProcessingRecord) async throws -> [StemArtifact] {
        guard staged.state == .resultStaged,
              let artifacts = staged.resultArtifacts,
              let jobID = staged.jobID else {
            throw DomainFailure.processingFailed(code: "PROC_STAGED_RESULT_INVALID", retryable: false)
        }
        try await outputTransaction.validateFinalArtifacts(artifacts, projectID: staged.projectID)
        try validateResultArtifacts(artifacts, record: staged)

        try await projectPersistence.recordStems(projectID: staged.projectID, stems: artifacts)
        var persisted = staged.replacing(
            state: .resultPersisted,
            retryable: true,
            stableErrorCode: nil,
            preserveErrorWhenNil: false,
            updatedAt: now()
        )
        try await stateStore.save(persisted)
        try await outputTransaction.commit(projectID: staged.projectID, generationID: staged.generationID)

        let readySnapshot = staged.lastSnapshot ?? ProcessingSnapshot(
            jobID: jobID,
            phase: .ready,
            fractionComplete: 1,
            retryable: false,
            stableErrorCode: nil
        )
        persisted = persisted.replacing(
            state: .completed,
            lastSnapshot: readySnapshot,
            retryable: false,
            stableErrorCode: nil,
            preserveErrorWhenNil: false,
            updatedAt: now()
        )
        try await stateStore.save(persisted)
        return artifacts
    }

    private func validateResultArtifacts(_ artifacts: [StemArtifact], record: DurableProcessingRecord) throws {
        guard !artifacts.isEmpty else {
            throw DomainFailure.processingFailed(code: "PROC_RESULT_EMPTY", retryable: false)
        }
        let roles = Set(artifacts.map(\.role))
        guard roles == record.request.requestedRoles else {
            throw DomainFailure.processingFailed(code: "PROC_RESULT_ROLE_SET_MISMATCH", retryable: false)
        }
        guard artifacts.allSatisfy({ $0.projectID == record.projectID }) else {
            throw DomainFailure.processingFailed(code: "PROC_RESULT_PROJECT_MISMATCH", retryable: false)
        }
        guard Set(artifacts.map(\.id)).count == artifacts.count,
              Set(artifacts.map(\.relativePath)).count == artifacts.count else {
            throw DomainFailure.processingFailed(code: "PROC_RESULT_DUPLICATE_ARTIFACT", retryable: false)
        }
    }

    private func normalized(snapshot: ProcessingSnapshot, previous: ProcessingSnapshot?) throws -> ProcessingSnapshot {
        guard let previous else { return snapshot }
        guard snapshot.jobID == previous.jobID else {
            throw DomainFailure.processingFailed(code: "PROC_JOB_ID_CHANGED", retryable: false)
        }

        let previousRank = phaseRank(previous.phase)
        let nextRank = phaseRank(snapshot.phase)
        if !isTerminal(previous.phase), !isTerminal(snapshot.phase), nextRank < previousRank {
            throw DomainFailure.processingFailed(code: "PROC_PHASE_REGRESSION", retryable: false)
        }

        var fraction = snapshot.fractionComplete
        if let old = previous.fractionComplete, let new = fraction, new + 0.000_001 < old, !isTerminal(snapshot.phase) {
            throw DomainFailure.processingFailed(code: "PROC_PROGRESS_REGRESSION", retryable: false)
        }
        if fraction == nil, let old = previous.fractionComplete, !isTerminal(snapshot.phase) {
            fraction = old
        }

        return ProcessingSnapshot(
            jobID: snapshot.jobID,
            phase: snapshot.phase,
            fractionComplete: fraction,
            retryable: snapshot.retryable,
            stableErrorCode: snapshot.stableErrorCode
        )
    }

    private func phaseRank(_ phase: ProcessingPhase) -> Int {
        switch phase {
        case .queued: return 0
        case .uploading: return 1
        case .separating: return 2
        case .finalizing: return 3
        case .ready: return 4
        case .cancelled, .failed: return 5
        }
    }

    private func isTerminal(_ phase: ProcessingPhase) -> Bool {
        phase == .ready || phase == .cancelled || phase == .failed
    }

    private func classifyStart(_ error: Error) -> (code: String, retryable: Bool, ambiguous: Bool) {
        let base = classify(error)
        switch error {
        case DomainFailure.networkUnavailable,
             DomainFailure.networkTimeout,
             DomainFailure.providerUnavailable,
             DomainFailure.cancelled:
            return (base.code, false, true)
        case DomainFailure.processingFailed(_, let retryable) where retryable:
            return (base.code, false, true)
        default:
            return (base.code, base.retryable, false)
        }
    }

    private func classify(_ error: Error) -> (code: String, retryable: Bool) {
        guard let failure = error as? DomainFailure else {
            return ("PROC_UNKNOWN_FAILURE", true)
        }
        switch failure {
        case .accessDenied:
            return ("PROC_ACCESS_DENIED", false)
        case .providerUnavailable:
            return ("PROC_PROVIDER_UNAVAILABLE", true)
        case .networkUnavailable:
            return ("PROC_NETWORK_UNAVAILABLE", true)
        case .networkTimeout:
            return ("PROC_NETWORK_TIMEOUT", true)
        case .unsupportedMedia:
            return ("PROC_UNSUPPORTED_MEDIA", false)
        case .protectedMedia:
            return ("PROC_PROTECTED_MEDIA", false)
        case .corruptMedia:
            return ("PROC_CORRUPT_MEDIA", false)
        case .noAudioTrack:
            return ("PROC_NO_AUDIO_TRACK", false)
        case .insufficientStorage:
            return ("PROC_INSUFFICIENT_STORAGE", true)
        case .cancelled:
            return ("PROC_CANCELLED", true)
        case .processingFailed(let code, let retryable):
            return (code, retryable)
        case .exportFailed(let code):
            return ("PROC_EXPORT_" + code, true)
        }
    }
}
