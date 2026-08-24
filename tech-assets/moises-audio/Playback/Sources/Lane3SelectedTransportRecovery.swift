import Foundation

public enum Lane3SelectedTransportRecoveryReason: String, Codable, Sendable {
    case tempoBoundaryCommitFailure
    case tempoBoundaryCancelFailure
    case playbackBoundaryBackendPoisoned
    case admissionCounterOverflow
}

/// Selected Playback implementations that can enter a permanent poison state expose only this
/// boolean recovery boundary. The facade does not inspect Apple-specific error types and never tries
/// to reset the backend in place.
public protocol Lane3SelectedStackRecoveryReporting: Sendable {
    func selectedStackRequiresReconstruction() async -> Bool
}

public struct Lane3SelectedTransportRecoveryTicket: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let reason: Lane3SelectedTransportRecoveryReason
    public let failedTempoSerial: UInt64
    public let failedBoundarySerial: UInt64?
    public let parityPromotionAllowed: Bool

    public init(
        reason: Lane3SelectedTransportRecoveryReason,
        failedTempoSerial: UInt64,
        failedBoundarySerial: UInt64?
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW33_SELECTED_STACK_RECONSTRUCTION_NON_PARITY"
        self.reason = reason
        self.failedTempoSerial = failedTempoSerial
        self.failedBoundarySerial = failedBoundarySerial
        self.parityPromotionAllowed = false
    }
}

/// One-way recovery latch for one selected facade instance. A poisoned facade is never reset in
/// place. Recovery means constructing a fresh selected stack/facade and atomically replacing the
/// facade in `Lane3SelectedTransportReconstructionSlot`.
public struct Lane3SelectedTransportRecoveryState: Equatable, Sendable {
    public private(set) var ticket: Lane3SelectedTransportRecoveryTicket?

    public init(ticket: Lane3SelectedTransportRecoveryTicket? = nil) {
        self.ticket = ticket
    }

    public var requiresReconstruction: Bool { ticket != nil }

    @discardableResult
    public mutating func latch(
        reason: Lane3SelectedTransportRecoveryReason,
        failedTempoSerial: UInt64,
        failedBoundarySerial: UInt64?
    ) -> Lane3SelectedTransportRecoveryTicket {
        if let ticket { return ticket }
        let created = Lane3SelectedTransportRecoveryTicket(
            reason: reason,
            failedTempoSerial: failedTempoSerial,
            failedBoundarySerial: failedBoundarySerial
        )
        ticket = created
        return created
    }
}

public struct Lane3SelectedTransportRecoverySnapshot: Equatable, Sendable {
    public let requiresReconstruction: Bool
    public let ticket: Lane3SelectedTransportRecoveryTicket?

    public init(state: Lane3SelectedTransportRecoveryState) {
        self.requiresReconstruction = state.requiresReconstruction
        self.ticket = state.ticket
    }
}

public enum Lane3SelectedTransportReconstructionSlotError: Error, Equatable, Sendable {
    case reconstructionNotRequired
    case staleRecoveryTicket
    case replacementFacadeAlreadyRequiresReconstruction
    case slotGenerationOverflow
    case slotPoisoned
    case leaseCounterOverflow
}

public struct Lane3SelectedTransportReplacementReceipt: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let oldSlotGeneration: UInt64
    public let newSlotGeneration: UInt64
    public let consumedTicket: Lane3SelectedTransportRecoveryTicket
    public let oldFacadeReused: Bool
    public let parityPromotionAllowed: Bool

    public init(
        oldSlotGeneration: UInt64,
        newSlotGeneration: UInt64,
        consumedTicket: Lane3SelectedTransportRecoveryTicket
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW33_SELECTED_STACK_REPLACEMENT_NON_PARITY"
        self.oldSlotGeneration = oldSlotGeneration
        self.newSlotGeneration = newSlotGeneration
        self.consumedTicket = consumedTicket
        self.oldFacadeReused = false
        self.parityPromotionAllowed = false
    }
}

public struct Lane3SelectedTransportReconstructionSlotSnapshot: Equatable, Sendable {
    public let slotGeneration: UInt64
    public let inFlightOperations: UInt64
    public let replacementRequested: Bool
    public let replacementActive: Bool
    public let pendingRecoveryTicket: Lane3SelectedTransportRecoveryTicket?
    public let slotPoisoned: Bool
}

/// Selected App/HQ-facing holder for the AW31+ transport facade after AW33.
///
/// The slot never exposes its current facade. Product operations obtain a shared lease internally.
/// Reconstruction is exclusive: it closes admission, drains already-issued operations, validates the
/// exact one-way recovery ticket, verifies the replacement facade is clean, advances a generation,
/// and only then reopens admission. A stale replacement therefore cannot revive or swap around a
/// newer selected stack.
public actor Lane3SelectedTransportReconstructionSlot {
    private var facade: Lane3TempoBoundarySelectedTransportFacade
    private var slotGeneration: UInt64
    private var inFlightOperations: UInt64 = 0
    private var replacementRequested = false
    private var replacementActive = false
    private var pendingRecoveryTicket: Lane3SelectedTransportRecoveryTicket?
    private var slotPoisoned = false

    private var sharedWaiters: [CheckedContinuation<Void, Never>] = []
    private var drainWaiters: [CheckedContinuation<Void, Never>] = []
    private var replacementTurnWaiters: [CheckedContinuation<Void, Never>] = []

    public init(
        initialFacade: Lane3TempoBoundarySelectedTransportFacade,
        initialSlotGeneration: UInt64 = 1
    ) {
        self.facade = initialFacade
        self.slotGeneration = initialSlotGeneration
    }

    public func snapshot() async -> Lane3SelectedTransportReconstructionSlotSnapshot {
        await refreshRecoveryTicket(from: facade)
        return Lane3SelectedTransportReconstructionSlotSnapshot(
            slotGeneration: slotGeneration,
            inFlightOperations: inFlightOperations,
            replacementRequested: replacementRequested,
            replacementActive: replacementActive,
            pendingRecoveryTicket: pendingRecoveryTicket,
            slotPoisoned: slotPoisoned
        )
    }

    public func installReconstructedFacade(
        _ replacement: Lane3TempoBoundarySelectedTransportFacade,
        expectedTicket: Lane3SelectedTransportRecoveryTicket
    ) async throws -> Lane3SelectedTransportReplacementReceipt {
        await enterReplacementExclusive()
        defer { leaveReplacementExclusive() }

        guard !slotPoisoned else {
            throw Lane3SelectedTransportReconstructionSlotError.slotPoisoned
        }
        await refreshRecoveryTicket(from: facade)
        guard let pendingRecoveryTicket else {
            throw Lane3SelectedTransportReconstructionSlotError.reconstructionNotRequired
        }
        guard pendingRecoveryTicket == expectedTicket else {
            throw Lane3SelectedTransportReconstructionSlotError.staleRecoveryTicket
        }
        let replacementSnapshot = await replacement.recoverySnapshot()
        guard !replacementSnapshot.requiresReconstruction else {
            throw Lane3SelectedTransportReconstructionSlotError.replacementFacadeAlreadyRequiresReconstruction
        }

        let next = slotGeneration.addingReportingOverflow(1)
        guard !next.overflow else {
            slotPoisoned = true
            throw Lane3SelectedTransportReconstructionSlotError.slotGenerationOverflow
        }
        let oldGeneration = slotGeneration
        slotGeneration = next.partialValue
        facade = replacement
        self.pendingRecoveryTicket = nil
        return Lane3SelectedTransportReplacementReceipt(
            oldSlotGeneration: oldGeneration,
            newSlotGeneration: slotGeneration,
            consumedTicket: pendingRecoveryTicket
        )
    }

    public func submitSeek(
        to positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws -> Lane3InterruptionGuardedOutcome {
        try await withFacade { facade in
            try await facade.submitSeek(to: positionSeconds, resume: resume, loop: loop)
        }
    }

    public func submitLoop(_ loop: PlaybackLoopRange?) async throws -> Lane3InterruptionGuardedOutcome {
        try await withFacade { facade in
            try await facade.submitLoop(loop)
        }
    }

    public func submitMediaLoad(_ asset: LocalAudioAsset) async throws -> Lane3InterruptionGuardedOutcome {
        try await withFacade { facade in
            try await facade.submitMediaLoad(asset)
        }
    }

    public func submitMediaReplacement(
        stems: [StemArtifact],
        positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws -> Lane3InterruptionGuardedOutcome {
        try await withFacade { facade in
            try await facade.submitMediaReplacement(
                stems: stems,
                positionSeconds: positionSeconds,
                resume: resume,
                loop: loop
            )
        }
    }

    public func submitPlay() async throws -> Lane3InterruptionGuardedOutcome {
        try await withFacade { facade in try await facade.submitPlay() }
    }

    public func submitPause() async throws -> Lane3InterruptionGuardedOutcome {
        try await withFacade { facade in try await facade.submitPause() }
    }

    public func submitRecovery() async throws -> Lane3InterruptionGuardedOutcome {
        try await withFacade { facade in try await facade.submitRecovery() }
    }

    public func submitInterruptionBegan() async throws -> Lane3SerializedInterruptionBeginEnvelope {
        try await withFacade { facade in try await facade.submitInterruptionBegan() }
    }

    public func submitInterruptionEnded(
        shouldResume: Bool
    ) async throws -> Lane3PracticeInterruptionEndEnvelope {
        try await withFacade { facade in
            try await facade.submitInterruptionEnded(shouldResume: shouldResume)
        }
    }

    public func retryEndedInterruptionRecovery() async throws -> Lane3PracticeInterruptionEndEnvelope {
        try await withFacade { facade in try await facade.retryEndedInterruptionRecovery() }
    }

    public func submitTempoRatio(_ ratio: Double) async throws -> Lane3TempoBoundarySelectedOutcome {
        try await withFacade { facade in try await facade.submitTempoRatio(ratio) }
    }

    private func withFacade<T: Sendable>(
        _ operation: @Sendable (Lane3TempoBoundarySelectedTransportFacade) async throws -> T
    ) async throws -> T {
        let leasedFacade = try await acquireSharedLease()
        do {
            let result = try await operation(leasedFacade)
            await refreshRecoveryTicket(from: leasedFacade)
            releaseSharedLease()
            return result
        } catch {
            await refreshRecoveryTicket(from: leasedFacade)
            releaseSharedLease()
            throw error
        }
    }

    private func acquireSharedLease() async throws -> Lane3TempoBoundarySelectedTransportFacade {
        while replacementRequested || replacementActive {
            await withCheckedContinuation { sharedWaiters.append($0) }
        }
        guard !slotPoisoned else {
            throw Lane3SelectedTransportReconstructionSlotError.slotPoisoned
        }
        let next = inFlightOperations.addingReportingOverflow(1)
        guard !next.overflow else {
            slotPoisoned = true
            throw Lane3SelectedTransportReconstructionSlotError.leaseCounterOverflow
        }
        inFlightOperations = next.partialValue
        return facade
    }

    private func releaseSharedLease() {
        precondition(inFlightOperations > 0)
        inFlightOperations -= 1
        if inFlightOperations == 0 {
            let waiters = drainWaiters
            drainWaiters.removeAll(keepingCapacity: true)
            for waiter in waiters { waiter.resume() }
        }
    }

    private func enterReplacementExclusive() async {
        while replacementRequested || replacementActive {
            await withCheckedContinuation { replacementTurnWaiters.append($0) }
        }
        replacementRequested = true
        while inFlightOperations > 0 {
            await withCheckedContinuation { drainWaiters.append($0) }
        }
        replacementRequested = false
        replacementActive = true
    }

    private func leaveReplacementExclusive() {
        replacementActive = false

        let replacementWaiters = replacementTurnWaiters
        replacementTurnWaiters.removeAll(keepingCapacity: true)
        for waiter in replacementWaiters { waiter.resume() }

        let waiters = sharedWaiters
        sharedWaiters.removeAll(keepingCapacity: true)
        for waiter in waiters { waiter.resume() }
    }

    private func refreshRecoveryTicket(
        from candidate: Lane3TempoBoundarySelectedTransportFacade
    ) async {
        let snapshot = await candidate.recoverySnapshot()
        if let ticket = snapshot.ticket {
            if pendingRecoveryTicket == nil {
                pendingRecoveryTicket = ticket
            }
        }
    }
}
