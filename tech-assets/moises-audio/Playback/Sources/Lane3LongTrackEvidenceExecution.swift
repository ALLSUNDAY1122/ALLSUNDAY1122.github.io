import Foundation

public enum Lane3LongTrackEvidenceExecutionPhase: String, Codable, Sendable, CaseIterable {
    case validatingInputs
    case timeDomain
    case spectral
    case envelope
    case assemblingCore
    case pcmIdentity
    case finalizing
    case completed
}

public enum Lane3LongTrackEvidenceExecutionState: String, Codable, Sendable {
    case running
    case completed
    case cancelled
    case failed
}

public enum Lane3LongTrackEvidenceSourceRole: String, Codable, Sendable {
    case reference
    case observed
}

public enum Lane3LongTrackEvidenceCheckpointResumeMode: String, Codable, Sendable {
    case restartRequired
}

public enum Lane3LongTrackEvidenceExecutionError: Error, Equatable, Sendable {
    case cancelled
    case invalidPhaseTransition(from: Lane3LongTrackEvidenceExecutionPhase, to: Lane3LongTrackEvidenceExecutionPhase)
    case executionNotRunning(Lane3LongTrackEvidenceExecutionState)
    case counterOverflow
    case completionUnavailable
    case invalidCompletionReceipt
}

public struct Lane3LongTrackEvidenceCheckpoint: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let state: Lane3LongTrackEvidenceExecutionState
    public let phase: Lane3LongTrackEvidenceExecutionPhase
    public let cancellationRequested: Bool
    public let progressLowerBoundPermille: Int
    public let checkpointSerial: UInt64
    public let referenceReadCalls: UInt64
    public let observedReadCalls: UInt64
    public let referenceFramesRequested: UInt64
    public let observedFramesRequested: UInt64
    public let counterOverflowed: Bool
    public let resumeMode: Lane3LongTrackEvidenceCheckpointResumeMode
    public let partialMetricsIncluded: Bool
    public let rawPCMIncluded: Bool
    public let sourcePathIncluded: Bool
    public let authoritativeEvidenceAllowed: Bool
    public let parityPromotionAllowed: Bool
}

public struct Lane3LongTrackEvidenceCompletionReceipt: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let runBindingSHA256: String
    public let finalCheckpointSerial: UInt64
    public let referenceReadCalls: UInt64
    public let observedReadCalls: UInt64
    public let referenceFramesRequested: UInt64
    public let observedFramesRequested: UInt64
    public let counterOverflowed: Bool
    public let progressPermille: Int
    public let finalReportConstructedBeforeCompletion: Bool
    public let rawPCMIncluded: Bool
    public let sourcePathIncluded: Bool
    public let parityPromotionAllowed: Bool
}

public enum Lane3LongTrackEvidenceCompletionValidator {
    @discardableResult
    public static func validate(
        _ receipt: Lane3LongTrackEvidenceCompletionReceipt
    ) throws -> Lane3LongTrackEvidenceCompletionReceipt {
        guard receipt.schemaVersion == 1,
              receipt.evidenceScope == "LANE3_AW30_LONG_TRACK_EXECUTION_COMPLETION_NON_PARITY",
              receipt.runBindingSHA256.count == 64,
              receipt.runBindingSHA256.unicodeScalars.allSatisfy({ scalar in
                  (48...57).contains(scalar.value) || (97...102).contains(scalar.value)
              }),
              !receipt.counterOverflowed,
              receipt.progressPermille == 1_000,
              receipt.finalReportConstructedBeforeCompletion,
              !receipt.rawPCMIncluded,
              !receipt.sourcePathIncluded,
              !receipt.parityPromotionAllowed else {
            throw Lane3LongTrackEvidenceExecutionError.invalidCompletionReceipt
        }
        return receipt
    }
}

public final class Lane3LongTrackEvidenceExecutionController: @unchecked Sendable {
    private struct MutableState {
        var state: Lane3LongTrackEvidenceExecutionState = .running
        var phase: Lane3LongTrackEvidenceExecutionPhase = .validatingInputs
        var cancellationRequested = false
        var progressLowerBoundPermille = 0
        var checkpointSerial: UInt64 = 0
        var referenceReadCalls: UInt64 = 0
        var observedReadCalls: UInt64 = 0
        var referenceFramesRequested: UInt64 = 0
        var observedFramesRequested: UInt64 = 0
        var counterOverflowed = false
        var runBindingSHA256: String?
    }

    private let lock = NSLock()
    private var mutable = MutableState()

    public init() {}

    public func requestCancellation() {
        lock.lock()
        if mutable.state == .running, !mutable.cancellationRequested {
            mutable.cancellationRequested = true
            bumpCheckpointSerialLocked()
        }
        lock.unlock()
    }

    public func checkpoint() -> Lane3LongTrackEvidenceCheckpoint {
        lock.lock()
        defer { lock.unlock() }
        return checkpointLocked()
    }

    public func begin(_ phase: Lane3LongTrackEvidenceExecutionPhase) throws {
        try throwIfCancellationRequested()
        lock.lock()
        defer { lock.unlock() }
        guard mutable.state == .running else {
            throw Lane3LongTrackEvidenceExecutionError.executionNotRunning(mutable.state)
        }
        let currentIndex = Self.order(mutable.phase)
        let nextIndex = Self.order(phase)
        guard phase != .completed, nextIndex >= currentIndex, nextIndex <= currentIndex + 1 else {
            throw Lane3LongTrackEvidenceExecutionError.invalidPhaseTransition(from: mutable.phase, to: phase)
        }
        mutable.phase = phase
        mutable.progressLowerBoundPermille = max(mutable.progressLowerBoundPermille, Self.lowerBoundPermille(for: phase))
        bumpCheckpointSerialLocked()
    }

    public func throwIfCancellationRequested() throws {
        let taskCancelled = Self.currentTaskCancelled()
        lock.lock()
        let shouldCancel = mutable.cancellationRequested || taskCancelled
        if shouldCancel, mutable.state == .running {
            mutable.cancellationRequested = true
            mutable.state = .cancelled
            bumpCheckpointSerialLocked()
        }
        let state = mutable.state
        lock.unlock()
        if shouldCancel || state == .cancelled {
            throw Lane3LongTrackEvidenceExecutionError.cancelled
        }
        guard state == .running else {
            throw Lane3LongTrackEvidenceExecutionError.executionNotRunning(state)
        }
    }

    public func recordSuccessfulRead(
        role: Lane3LongTrackEvidenceSourceRole,
        frameCount: Int
    ) throws {
        guard frameCount >= 0 else { throw Lane3LongTrackEvidenceExecutionError.counterOverflow }
        lock.lock()
        defer { lock.unlock() }
        guard mutable.state == .running else {
            throw Lane3LongTrackEvidenceExecutionError.executionNotRunning(mutable.state)
        }
        let frames = UInt64(frameCount)
        switch role {
        case .reference:
            guard addLocked(&mutable.referenceReadCalls, 1), addLocked(&mutable.referenceFramesRequested, frames) else {
                mutable.counterOverflowed = true
                mutable.state = .failed
                bumpCheckpointSerialLocked()
                throw Lane3LongTrackEvidenceExecutionError.counterOverflow
            }
        case .observed:
            guard addLocked(&mutable.observedReadCalls, 1), addLocked(&mutable.observedFramesRequested, frames) else {
                mutable.counterOverflowed = true
                mutable.state = .failed
                bumpCheckpointSerialLocked()
                throw Lane3LongTrackEvidenceExecutionError.counterOverflow
            }
        }
        bumpCheckpointSerialLocked()
    }

    public func markFailed() {
        lock.lock()
        if mutable.state == .running {
            mutable.state = .failed
            bumpCheckpointSerialLocked()
        }
        lock.unlock()
    }

    public func markCompleted(runBindingSHA256: String) throws {
        try throwIfCancellationRequested()
        lock.lock()
        defer { lock.unlock() }
        guard mutable.state == .running else {
            throw Lane3LongTrackEvidenceExecutionError.executionNotRunning(mutable.state)
        }
        guard mutable.phase == .finalizing else {
            throw Lane3LongTrackEvidenceExecutionError.invalidPhaseTransition(from: mutable.phase, to: .completed)
        }
        guard Self.isLowercaseSHA256(runBindingSHA256) else {
            throw Lane3LongTrackEvidenceExecutionError.invalidCompletionReceipt
        }
        mutable.phase = .completed
        mutable.state = .completed
        mutable.progressLowerBoundPermille = 1_000
        mutable.runBindingSHA256 = runBindingSHA256
        bumpCheckpointSerialLocked()
    }

    public func completionReceipt() throws -> Lane3LongTrackEvidenceCompletionReceipt {
        lock.lock()
        defer { lock.unlock() }
        guard mutable.state == .completed,
              mutable.phase == .completed,
              let binding = mutable.runBindingSHA256 else {
            throw Lane3LongTrackEvidenceExecutionError.completionUnavailable
        }
        let receipt = Lane3LongTrackEvidenceCompletionReceipt(
            schemaVersion: 1,
            evidenceScope: "LANE3_AW30_LONG_TRACK_EXECUTION_COMPLETION_NON_PARITY",
            runBindingSHA256: binding,
            finalCheckpointSerial: mutable.checkpointSerial,
            referenceReadCalls: mutable.referenceReadCalls,
            observedReadCalls: mutable.observedReadCalls,
            referenceFramesRequested: mutable.referenceFramesRequested,
            observedFramesRequested: mutable.observedFramesRequested,
            counterOverflowed: mutable.counterOverflowed,
            progressPermille: 1_000,
            finalReportConstructedBeforeCompletion: true,
            rawPCMIncluded: false,
            sourcePathIncluded: false,
            parityPromotionAllowed: false
        )
        return try Lane3LongTrackEvidenceCompletionValidator.validate(receipt)
    }

    private func checkpointLocked() -> Lane3LongTrackEvidenceCheckpoint {
        Lane3LongTrackEvidenceCheckpoint(
            schemaVersion: 1,
            evidenceScope: "LANE3_AW30_LONG_TRACK_EXECUTION_CHECKPOINT_NON_PARITY",
            state: mutable.state,
            phase: mutable.phase,
            cancellationRequested: mutable.cancellationRequested,
            progressLowerBoundPermille: mutable.progressLowerBoundPermille,
            checkpointSerial: mutable.checkpointSerial,
            referenceReadCalls: mutable.referenceReadCalls,
            observedReadCalls: mutable.observedReadCalls,
            referenceFramesRequested: mutable.referenceFramesRequested,
            observedFramesRequested: mutable.observedFramesRequested,
            counterOverflowed: mutable.counterOverflowed,
            resumeMode: .restartRequired,
            partialMetricsIncluded: false,
            rawPCMIncluded: false,
            sourcePathIncluded: false,
            authoritativeEvidenceAllowed: false,
            parityPromotionAllowed: false
        )
    }

    private func addLocked(_ value: inout UInt64, _ delta: UInt64) -> Bool {
        let next = value.addingReportingOverflow(delta)
        guard !next.overflow else { return false }
        value = next.partialValue
        return true
    }

    private func bumpCheckpointSerialLocked() {
        let next = mutable.checkpointSerial.addingReportingOverflow(1)
        if next.overflow {
            mutable.counterOverflowed = true
            mutable.state = .failed
        } else {
            mutable.checkpointSerial = next.partialValue
        }
    }

    private static func order(_ phase: Lane3LongTrackEvidenceExecutionPhase) -> Int {
        switch phase {
        case .validatingInputs: 0
        case .timeDomain: 1
        case .spectral: 2
        case .envelope: 3
        case .assemblingCore: 4
        case .pcmIdentity: 5
        case .finalizing: 6
        case .completed: 7
        }
    }

    private static func lowerBoundPermille(for phase: Lane3LongTrackEvidenceExecutionPhase) -> Int {
        switch phase {
        case .validatingInputs: 0
        case .timeDomain: 50
        case .spectral: 300
        case .envelope: 500
        case .assemblingCore: 700
        case .pcmIdentity: 780
        case .finalizing: 950
        case .completed: 1_000
        }
    }

    private static func isLowercaseSHA256(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy { scalar in
            (48...57).contains(scalar.value) || (97...102).contains(scalar.value)
        }
    }

    private static func currentTaskCancelled() -> Bool {
        var cancelled = false
        withUnsafeCurrentTask { task in
            cancelled = task?.isCancelled ?? false
        }
        return cancelled
    }
}

public struct Lane3CancellationAwarePCMChunkSource: Lane3PCMChunkReadable, @unchecked Sendable {
    public let base: any Lane3PCMChunkReadable
    public let role: Lane3LongTrackEvidenceSourceRole
    public let controller: Lane3LongTrackEvidenceExecutionController

    public init(
        base: any Lane3PCMChunkReadable,
        role: Lane3LongTrackEvidenceSourceRole,
        controller: Lane3LongTrackEvidenceExecutionController
    ) {
        self.base = base
        self.role = role
        self.controller = controller
    }

    public var channels: Int { base.channels }
    public var sampleRate: Double { base.sampleRate }
    public var frameCount: Int64 { base.frameCount }

    public func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        try controller.throwIfCancellationRequested()
        let samples = try base.readInterleavedFrames(startFrame: startFrame, frameCount: frameCount)
        try controller.recordSuccessfulRead(role: role, frameCount: frameCount)
        try controller.throwIfCancellationRequested()
        return samples
    }
}
