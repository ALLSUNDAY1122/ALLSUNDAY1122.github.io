import Foundation

public enum ProcessingRecoveryAction: Equatable, Sendable {
    case none
    case reconnect(jobID: ProcessingJobID)
    case retryRequired(stableErrorCode: String?)
    case ambiguousStart
}

/// Durable orchestration around the canonical `SourceSeparationProviding` contract.
///
/// Safety properties:
/// - one durable generation per project;
/// - observed jobs are reused rather than duplicated;
/// - an uncertain `start()` outcome is never auto-retried;
/// - progress/phase regressions are rejected;
/// - cancel/failure rolls back partial local output;
/// - result finalization uses `resultStaged -> resultPersisted -> completed` so relaunch can resume
///   without re-running separation or corrupting the previous stem set.
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
                throw DomainFailure.processingFailed(
                    code: record.stableErrorCode ?? "PROC_RETRY_REQUIRED",
                    retryable: record.retryable
                )
            }
        }

        return try await startNew(request: request, retryCount: 0)
    }

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
        case .failed, .cancelled:
            if let snapshot = record.lastSnapshot { return snapshot }
            throw DomainFailure.processingFailed(
                code: record.stableErrorCode ?? "PROC_TERMINAL_WITHOUT_SNAPSHOT",
                retryable: record.retryable
            )
        case .starting, .startAmbiguous:
            throw DomainFailure.processingFailed(code: "PROC_JOB_BINDING_UNKNOWN", retryable: false)
        case .active, .cancellationRequested, .ready:
            break
        }

        guard let jobID = record.jobID else {
            throw DomainFailure.processingFailed(code: "PROC_JOB_BINDING_MISSING", retryable: false)
        }

        var snapshot = try await provider.snapshot(jobID: jobID)
        snapshot = try normalized(snapshot: snapshot, previous: record.lastSnapshot)

        // User cancellation wins a race with a server that reaches ready before DELETE takes effect.
        // We do not download the newly completed outputs in that case.
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
            try await outputTransaction.rollback(projectID: projectID, generationID: record.generationID)
            try await projectPersistence.recordProcessing(projectID: projectID, snapshot: cancelled)
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
        if nextState == .failed || nextState == .cancelled {
            try await outputTransaction.rollback(projectID: projectID, generationID: record.generationID)
        }
        try await projectPersistence.recordProcessing(projectID: projectID, snapshot: snapshot)
        return snapshot
    }

    /// Persists cancellation intent before touching the provider. `cancel` is expected to be
    /// idempotent; relaunch reconnects until a terminal provider state is observed.
    public func requestCancel(projectID: ProjectID) async throws {
        guard var record = try await stateStore.load(projectID: projectID) else { return }

        switch record.state {
        case .failed, .cancelled, .completed:
            return
        case .resultPersisted:
            // DB already points at the new artifacts. Complete the local transaction rather than
            // restoring old bytes under paths the DB now considers current.
            guard let artifacts = record.resultArtifacts else {
                throw DomainFailure.processingFailed(code: "PROC_RESULT_JOURNAL_MISSING", retryable: false)
            }
            try await outputTransaction.validateFinalArtifacts(artifacts, projectID: projectID)
            try await outputTransaction.commit(projectID: projectID, generationID: record.generationID)
            record = record.replacing(state: .completed, retryable: false, updatedAt: now())
            try await stateStore.save(record)
            return
        case .ready, .resultStaged:
            try await outputTransaction.rollback(projectID: projectID, generationID: record.generationID)
            guard let jobID = record.jobID else {
                throw DomainFailure.processingFailed(code: "PROC_JOB_BINDING_MISSING", retryable: false)
            }
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

    public func finish(projectID: ProjectID) async throws -> [StemArtifact] {
        guard var record = try await stateStore.load(projectID: projectID) else {
            throw DomainFailure.processingFailed(code: "PROC_STATE_MISSING", retryable: false)
        }

        if record.state == .completed {
            guard let artifacts = record.resultArtifacts else {
                throw DomainFailure.processingFailed(code: "PROC_RESULT_JOURNAL_MISSING", retryable: false)
            }
            try await outputTransaction.validateFinalArtifacts(artifacts, projectID: projectID)
            return artifacts
        }

        if record.state == .resultPersisted {
            guard let artifacts = record.resultArtifacts else {
                throw DomainFailure.processingFailed(code: "PROC_RESULT_JOURNAL_MISSING", retryable: false)
            }
            try await outputTransaction.validateFinalArtifacts(artifacts, projectID: projectID)
            try await outputTransaction.commit(projectID: projectID, generationID: record.generationID)
            record = record.replacing(state: .completed, retryable: false, updatedAt: now())
            try await stateStore.save(record)
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

        let staged: DurableProcessingRecord
        do {
            let artifacts = try await provider.result(jobID: jobID)
            try validateResultArtifacts(artifacts, record: record)
            try await outputTransaction.validateFinalArtifacts(artifacts, projectID: projectID)
            staged = record.replacing(
                state: .resultStaged,
                resultArtifacts: artifacts,
                preserveArtifactsWhenNil: false,
                retryable: true,
                stableErrorCode: nil,
                preserveErrorWhenNil: false,
                updatedAt: now()
            )
            try await stateStore.save(staged)
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
            try? await outputTransaction.rollback(projectID: projectID, generationID: record.generationID)
            try? await projectPersistence.recordProcessing(projectID: projectID, snapshot: failedSnapshot)
            throw DomainFailure.processingFailed(code: classification.code, retryable: false)
        }

        // Persistence errors after this point intentionally leave `resultStaged` durable so a
        // relaunch can repeat the idempotent recordStems write without re-downloading outputs.
        return try await persistStagedResult(staged)
    }

    public func retry(
        _ request: SeparationRequest,
        allowPotentialDuplicateStart: Bool = false
    ) async throws -> ProcessingJobID {
        guard let record = try await stateStore.load(projectID: request.projectID) else {
            return try await startNew(request: request, retryCount: 0)
        }

        switch record.state {
        case .starting:
            if inFlightStartGenerations.contains(record.generationID) {
                throw DomainFailure.processingFailed(code: "PROC_START_IN_FLIGHT", retryable: true)
            }
            guard allowPotentialDuplicateStart else {
                throw DomainFailure.processingFailed(code: "PROC_AMBIGUOUS_RETRY_REQUIRES_CONFIRMATION", retryable: false)
            }
        case .startAmbiguous:
            guard allowPotentialDuplicateStart else {
                throw DomainFailure.processingFailed(code: "PROC_AMBIGUOUS_RETRY_REQUIRES_CONFIRMATION", retryable: false)
            }
        case .failed, .cancelled:
            guard record.retryable else {
                throw DomainFailure.processingFailed(
                    code: record.stableErrorCode ?? "PROC_FAILURE_NOT_RETRYABLE",
                    retryable: false
                )
            }
        case .completed:
            break
        default:
            throw DomainFailure.processingFailed(code: "PROC_RETRY_WHILE_ACTIVE", retryable: false)
        }

        try await outputTransaction.rollback(projectID: record.projectID, generationID: record.generationID)
        return try await startNew(request: request, retryCount: record.retryCount + 1)
    }

    @discardableResult
    public func recoverAfterRelaunch(projectID: ProjectID) async throws -> ProcessingRecoveryAction {
        guard let record = try await stateStore.load(projectID: projectID) else { return .none }

        switch record.state {
        case .completed:
            return .none
        case .starting, .startAmbiguous:
            return .ambiguousStart
        case .failed, .cancelled:
            return .retryRequired(stableErrorCode: record.stableErrorCode)
        case .resultStaged, .resultPersisted, .ready:
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
            throw DomainFailure.processingFailed(code: classification.code, retryable: classification.retryable)
        }

        let jobID: ProcessingJobID
        do {
            jobID = try await provider.start(request)
        } catch {
            if let latest = try? await stateStore.load(projectID: request.projectID),
               latest.generationID == generationID,
               latest.state == .cancellationRequested {
                let cancelled = latest.replacing(
                    state: .cancelled,
                    retryable: true,
                    stableErrorCode: "PROC_CANCELLED_DURING_START_NO_JOB",
                    preserveErrorWhenNil: false,
                    updatedAt: now()
                )
                try? await stateStore.save(cancelled)
                try? await outputTransaction.rollback(projectID: request.projectID, generationID: generationID)
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

        guard let latest = try await stateStore.load(projectID: request.projectID),
              latest.generationID == generationID else {
            await provider.cancel(jobID: jobID)
            try? await outputTransaction.rollback(projectID: request.projectID, generationID: generationID)
            throw DomainFailure.processingFailed(code: "PROC_START_SUPERSEDED", retryable: false)
        }

        if latest.state == .cancellationRequested {
            await provider.cancel(jobID: jobID)
            let cancelledSnapshot = ProcessingSnapshot(
                jobID: jobID,
                phase: .cancelled,
                fractionComplete: nil,
                retryable: true,
                stableErrorCode: "PROC_CANCELLED_DURING_START"
            )
            let cancelled = latest.replacing(
                jobID: jobID,
                state: .cancelled,
                lastSnapshot: cancelledSnapshot,
                retryable: true,
                stableErrorCode: cancelledSnapshot.stableErrorCode,
                preserveErrorWhenNil: false,
                updatedAt: now()
            )
            try await stateStore.save(cancelled)
            try await outputTransaction.rollback(projectID: request.projectID, generationID: generationID)
            try await projectPersistence.recordProcessing(projectID: request.projectID, snapshot: cancelledSnapshot)
            throw DomainFailure.cancelled
        }

        guard latest.state == .starting else {
            await provider.cancel(jobID: jobID)
            try? await outputTransaction.rollback(projectID: request.projectID, generationID: generationID)
            throw DomainFailure.processingFailed(code: "PROC_START_STATE_CHANGED", retryable: false)
        }

        let queued = ProcessingSnapshot(
            jobID: jobID,
            phase: .queued,
            fractionComplete: 0,
            retryable: true,
            stableErrorCode: nil
        )
        record = latest.replacing(
            jobID: jobID,
            state: .active,
            lastSnapshot: queued,
            retryable: true,
            stableErrorCode: nil,
            preserveErrorWhenNil: false,
            updatedAt: now()
        )

        do {
            try await stateStore.save(record)
        } catch {
            await provider.cancel(jobID: jobID)
            try? await outputTransaction.rollback(projectID: request.projectID, generationID: generationID)
            let failed = latest.replacing(
                state: .failed,
                retryable: true,
                stableErrorCode: "PROC_JOB_BINDING_PERSIST_FAILED",
                preserveErrorWhenNil: false,
                updatedAt: now()
            )
            try? await stateStore.save(failed)
            throw DomainFailure.processingFailed(code: "PROC_JOB_BINDING_PERSIST_FAILED", retryable: true)
        }

        // If this persistence seam fails, keep the durable job binding. Relaunch can reconnect and
        // replay recordProcessing without starting a duplicate server job.
        try await projectPersistence.recordProcessing(projectID: request.projectID, snapshot: queued)
        return jobID
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
        if isTerminal(previous.phase), snapshot.phase != previous.phase {
            throw DomainFailure.processingFailed(code: "PROC_TERMINAL_STATE_CHANGED", retryable: false)
        }
        if !isTerminal(previous.phase), !isTerminal(snapshot.phase), phaseRank(snapshot.phase) < phaseRank(previous.phase) {
            throw DomainFailure.processingFailed(code: "PROC_PHASE_REGRESSION", retryable: false)
        }

        var fraction = snapshot.fractionComplete
        if let old = previous.fractionComplete, let new = fraction,
           new + 0.000_001 < old, !isTerminal(snapshot.phase) {
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
        guard let failure = error as? DomainFailure else {
            return (base.code, false, true)
        }
        switch failure {
        case .accessDenied, .unsupportedMedia, .protectedMedia, .corruptMedia, .noAudioTrack, .insufficientStorage:
            return (base.code, base.retryable, false)
        default:
            // The shared start contract exposes no caller-supplied deterministic idempotency key.
            // Conservatively assume any other error may have happened after server acceptance.
            return (base.code, false, true)
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
