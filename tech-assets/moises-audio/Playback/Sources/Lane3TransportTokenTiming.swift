import Dispatch
import Foundation

public protocol Lane3UptimeNanosecondClock: Sendable {
    func nowUptimeNanoseconds() -> UInt64
}

public struct Lane3SystemUptimeNanosecondClock: Lane3UptimeNanosecondClock {
    public init() {}

    public func nowUptimeNanoseconds() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }
}

public enum Lane3TransportAppliedTarget: Equatable, Codable, Sendable {
    case seek(positionSeconds: Double)
    case loop(startSeconds: Double, endSeconds: Double)
    case loopDisabled

    public var isFiniteAndValid: Bool {
        switch self {
        case .seek(let positionSeconds):
            return positionSeconds.isFinite && positionSeconds >= 0
        case .loop(let startSeconds, let endSeconds):
            return startSeconds.isFinite && endSeconds.isFinite && startSeconds >= 0 && endSeconds > startSeconds
        case .loopDisabled:
            return true
        }
    }
}

public struct Lane3TransportTokenTimingSample: Equatable, Codable, Sendable {
    public let generation: UInt64
    public let reason: PlaybackTransportDiscontinuityReason
    public let issuedUptimeNanoseconds: UInt64
    public let backendCompletedUptimeNanoseconds: UInt64?
    public let appliedTarget: Lane3TransportAppliedTarget?

    public init(
        generation: UInt64,
        reason: PlaybackTransportDiscontinuityReason,
        issuedUptimeNanoseconds: UInt64,
        backendCompletedUptimeNanoseconds: UInt64? = nil,
        appliedTarget: Lane3TransportAppliedTarget? = nil
    ) {
        self.generation = generation
        self.reason = reason
        self.issuedUptimeNanoseconds = issuedUptimeNanoseconds
        self.backendCompletedUptimeNanoseconds = backendCompletedUptimeNanoseconds
        self.appliedTarget = appliedTarget
    }
}

public struct Lane3TransportTokenTimingLedgerSnapshot: Equatable, Codable, Sendable {
    public let capacity: Int
    public let retainedCount: Int
    public let capacityDrops: UInt64
    public let completionMissesAfterEviction: UInt64
    public let counterOverflowed: Bool
    public let parityPromotionAllowed: Bool

    public init(
        capacity: Int,
        retainedCount: Int,
        capacityDrops: UInt64,
        completionMissesAfterEviction: UInt64,
        counterOverflowed: Bool
    ) {
        self.capacity = capacity
        self.retainedCount = retainedCount
        self.capacityDrops = capacityDrops
        self.completionMissesAfterEviction = completionMissesAfterEviction
        self.counterOverflowed = counterOverflowed
        self.parityPromotionAllowed = false
    }
}

/// AW38 bounded sidecar for exact transport-generation timing. The issuance timestamp is recorded
/// synchronously in `RescheduleFencedPlaybackBackend` immediately after the fence creates a new
/// generation and before the underlying backend is invoked. Completion/target information is only
/// attached after that backend call succeeds. Old generations are overwritten rather than retained
/// without bound during long seek/loop drag sessions.
public struct Lane3TransportTokenTimingLedger: Sendable {
    public let capacity: Int

    private var order: [UInt64?]
    private var samples: [UInt64: Lane3TransportTokenTimingSample] = [:]
    private var count = 0
    private var nextOverwriteIndex = 0
    private var capacityDrops: UInt64 = 0
    private var completionMissesAfterEviction: UInt64 = 0
    private var counterOverflowed = false

    public init(capacity: Int = 4_096) {
        let normalized = min(max(capacity, 64), 65_536)
        self.capacity = normalized
        self.order = Array(repeating: nil, count: normalized)
        self.samples.reserveCapacity(normalized)
    }

    public mutating func recordIssued(
        token: PlaybackTransportRescheduleToken,
        uptimeNanoseconds: UInt64
    ) {
        precondition(samples[token.generation] == nil, "duplicate transport timing generation")

        if count < capacity {
            order[count] = token.generation
            count += 1
            if count == capacity { nextOverwriteIndex = 0 }
        } else {
            if let evicted = order[nextOverwriteIndex] {
                samples.removeValue(forKey: evicted)
            }
            order[nextOverwriteIndex] = token.generation
            nextOverwriteIndex += 1
            if nextOverwriteIndex == capacity { nextOverwriteIndex = 0 }
            increment(&capacityDrops)
        }

        samples[token.generation] = Lane3TransportTokenTimingSample(
            generation: token.generation,
            reason: token.reason,
            issuedUptimeNanoseconds: uptimeNanoseconds
        )
    }

    @discardableResult
    public mutating func markBackendCompleted(
        generation: UInt64,
        uptimeNanoseconds: UInt64,
        appliedTarget: Lane3TransportAppliedTarget?
    ) -> Bool {
        guard let existing = samples[generation] else {
            increment(&completionMissesAfterEviction)
            return false
        }
        samples[generation] = Lane3TransportTokenTimingSample(
            generation: existing.generation,
            reason: existing.reason,
            issuedUptimeNanoseconds: existing.issuedUptimeNanoseconds,
            backendCompletedUptimeNanoseconds: uptimeNanoseconds,
            appliedTarget: appliedTarget
        )
        return true
    }

    public func sample(generation: UInt64) -> Lane3TransportTokenTimingSample? {
        samples[generation]
    }

    public func snapshot() -> Lane3TransportTokenTimingLedgerSnapshot {
        Lane3TransportTokenTimingLedgerSnapshot(
            capacity: capacity,
            retainedCount: samples.count,
            capacityDrops: capacityDrops,
            completionMissesAfterEviction: completionMissesAfterEviction,
            counterOverflowed: counterOverflowed
        )
    }

    private mutating func increment(_ value: inout UInt64) {
        let next = value.addingReportingOverflow(1)
        if next.overflow {
            value = UInt64.max
            counterOverflowed = true
        } else {
            value = next.partialValue
        }
    }
}
