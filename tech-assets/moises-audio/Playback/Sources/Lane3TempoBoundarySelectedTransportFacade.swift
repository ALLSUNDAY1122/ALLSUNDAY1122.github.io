import Foundation

public enum Lane3TempoBoundarySelectedTransportError: Error, Sendable {
    case tempoBoundaryPrepareFailed(String)
    case tempoBoundaryCommitFailed(String)
    case tempoBoundaryCancelFailed(String)
    case admissionCounterOverflow
}

public enum Lane3TempoBoundarySelectedOutcome: Equatable, Sendable {
    case transport(
        guarded: Lane3InterruptionGuardedOutcome,
        boundary: PlaybackTempoBoundaryReceipt?
    )
    case supersededBeforeBoundary(serial: UInt64, bySerial: UInt64)
    case cancelledBeforeBoundary(serial: UInt64)
}

/// App-facing AW31 transport facade. Existing AW17/AW18 remain the generation/lifecycle authority;
/// this layer only brackets tempo with a Playback source-clock boundary transaction. Non-tempo
/// transport and interruption calls share an admission lane. Tempo closes admission, waits existing
/// calls out, freezes Playback at the old source position, executes the existing AW18->AW17 tempo
/// route (therefore exactly one external Playback token), then resumes at the committed new ratio.
public actor Lane3TempoBoundarySelectedTransportFacade {
    private let projectID: ProjectID
    private let transportGate: Lane3InterruptionLifecycleGate
    private let serializedClickGate: Lane3SerializedPracticeClickGate
    private let tempoBackend: any PlaybackTempoBoundaryRescheduling
    private let tempoQuietPeriod: Duration

    private var sharedInFlight: UInt64 = 0
    private var exclusiveRequested = false
    private var exclusiveActive = false
    private var sharedWaiters: [CheckedContinuation<Void, Never>] = []
    private var drainWaiters: [CheckedContinuation<Void, Never>] = []
    private var tempoSerial: UInt64 = 0
    private var latestTempoSerial: UInt64 = 0

    public init(
        projectID: ProjectID,
        transportGate: Lane3InterruptionLifecycleGate,
        serializedClickGate: Lane3SerializedPracticeClickGate,
        tempoBackend: any PlaybackTempoBoundaryRescheduling,
        tempoQuietPeriod: Duration = .milliseconds(16)
    ) {
        self.projectID = projectID
        self.transportGate = transportGate
        self.serializedClickGate = serializedClickGate
        self.tempoBackend = tempoBackend
        self.tempoQuietPeriod = tempoQuietPeriod
    }

    public func submitSeek(
        to positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws -> Lane3InterruptionGuardedOutcome {
        try await enterShared()
        let result = await transportGate.submitSeek(to: positionSeconds, resume: resume, loop: loop)
        leaveShared()
        return result
    }

    public func submitLoop(_ loop: PlaybackLoopRange?) async throws -> Lane3InterruptionGuardedOutcome {
        try await enterShared()
        let result = await transportGate.submitLoop(loop)
        leaveShared()
        return result
    }

    public func submitMediaLoad(_ asset: LocalAudioAsset) async throws -> Lane3InterruptionGuardedOutcome {
        try await enterShared()
        let result = await transportGate.submitMediaLoad(asset)
        leaveShared()
        return result
    }

    public func submitMediaReplacement(
        stems: [StemArtifact],
        positionSeconds: Double,
        resume: Bool,
        loop: PlaybackLoopRange?
    ) async throws -> Lane3InterruptionGuardedOutcome {
        try await enterShared()
        let result = await transportGate.submitMediaReplacement(
            stems: stems,
            positionSeconds: positionSeconds,
            resume: resume,
            loop: loop
        )
        leaveShared()
        return result
    }

    public func submitPlay() async throws -> Lane3InterruptionGuardedOutcome {
        try await enterShared()
        let result = await transportGate.submitPlay()
        leaveShared()
        return result
    }

    public func submitPause() async throws -> Lane3InterruptionGuardedOutcome {
        try await enterShared()
        let result = await transportGate.submitPause()
        leaveShared()
        return result
    }

    public func submitRecovery() async throws -> Lane3InterruptionGuardedOutcome {
        try await enterShared()
        let result = await transportGate.submitRecovery()
        leaveShared()
        return result
    }

    public func submitInterruptionBegan() async throws -> Lane3SerializedInterruptionBeginEnvelope {
        try await enterShared()
        let result = await serializedClickGate.submitInterruptionBegan()
        leaveShared()
        return result
    }

    public func submitInterruptionEnded(
        shouldResume: Bool
    ) async throws -> Lane3PracticeInterruptionEndEnvelope {
        try await enterShared()
        let result = await serializedClickGate.submitInterruptionEnded(shouldResume: shouldResume)
        leaveShared()
        return result
    }

    public func retryEndedInterruptionRecovery() async throws -> Lane3PracticeInterruptionEndEnvelope {
        try await enterShared()
        let result = await serializedClickGate.retryEndedInterruptionRecovery()
        leaveShared()
        return result
    }

    public func submitTempoRatio(_ ratio: Double) async throws -> Lane3TempoBoundarySelectedOutcome {
        let serial = try allocateTempoSerial()
        latestTempoSerial = serial
        do {
            try await Task.sleep(for: tempoQuietPeriod)
        } catch {
            return .cancelledBeforeBoundary(serial: serial)
        }
        guard serial == latestTempoSerial else {
            return .supersededBeforeBoundary(serial: serial, bySerial: latestTempoSerial)
        }

        await enterExclusive()
        defer { leaveExclusive() }
        guard serial == latestTempoSerial else {
            return .supersededBeforeBoundary(serial: serial, bySerial: latestTempoSerial)
        }

        let lifecycle = await transportGate.snapshot()
        guard lifecycle.phase == .idle else {
            return .transport(
                guarded: await transportGate.submitTempoRatio(ratio),
                boundary: nil
            )
        }

        let boundary: PlaybackTempoBoundaryReceipt
        do {
            boundary = try await tempoBackend.prepareTempoBoundary(
                projectID: projectID,
                toTempoRatio: ratio
            )
        } catch {
            throw Lane3TempoBoundarySelectedTransportError.tempoBoundaryPrepareFailed(
                String(describing: error)
            )
        }

        let guarded = await transportGate.submitTempoRatio(ratio)
        if Self.executed(guarded) {
            do {
                try await tempoBackend.commitTempoBoundary(
                    projectID: projectID,
                    receipt: boundary
                )
            } catch {
                throw Lane3TempoBoundarySelectedTransportError.tempoBoundaryCommitFailed(
                    String(describing: error)
                )
            }
        } else {
            do {
                try await tempoBackend.cancelTempoBoundary(
                    projectID: projectID,
                    receipt: boundary
                )
            } catch {
                throw Lane3TempoBoundarySelectedTransportError.tempoBoundaryCancelFailed(
                    String(describing: error)
                )
            }
        }
        return .transport(guarded: guarded, boundary: boundary)
    }

    private func enterShared() async throws {
        while exclusiveRequested || exclusiveActive {
            await withCheckedContinuation { sharedWaiters.append($0) }
        }
        let next = sharedInFlight.addingReportingOverflow(1)
        guard !next.overflow else {
            throw Lane3TempoBoundarySelectedTransportError.admissionCounterOverflow
        }
        sharedInFlight = next.partialValue
    }

    private func leaveShared() {
        precondition(sharedInFlight > 0)
        sharedInFlight -= 1
        if sharedInFlight == 0 {
            let waiters = drainWaiters
            drainWaiters.removeAll(keepingCapacity: true)
            for waiter in waiters { waiter.resume() }
        }
    }

    private func enterExclusive() async {
        exclusiveRequested = true
        while sharedInFlight > 0 || exclusiveActive {
            await withCheckedContinuation { drainWaiters.append($0) }
        }
        exclusiveRequested = false
        exclusiveActive = true
    }

    private func leaveExclusive() {
        exclusiveActive = false
        let waiters = sharedWaiters
        sharedWaiters.removeAll(keepingCapacity: true)
        for waiter in waiters { waiter.resume() }
        let exclusiveWaiters = drainWaiters
        drainWaiters.removeAll(keepingCapacity: true)
        for waiter in exclusiveWaiters { waiter.resume() }
    }

    private func allocateTempoSerial() throws -> UInt64 {
        let next = tempoSerial.addingReportingOverflow(1)
        guard !next.overflow else {
            throw Lane3TempoBoundarySelectedTransportError.admissionCounterOverflow
        }
        tempoSerial = next.partialValue
        return tempoSerial
    }

    private static func executed(_ guarded: Lane3InterruptionGuardedOutcome) -> Bool {
        guard case .transport(let transport) = guarded,
              case .executed = transport else {
            return false
        }
        return true
    }
}
