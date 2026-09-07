import Foundation

public struct Lane3UnifiedCancellationAdmissionSnapshot: Equatable, Sendable {
    public let admittingTicketCount: Int
    public let cancelledBeforeEnqueueTicketCount: Int
    public let lateRetiredCancellationIgnored: UInt64
    public let counterOverflowed: Bool
    public let invariantHolds: Bool
    public let parityPromotionAllowed: Bool
}

/// AW36 bounds cancellation bookkeeping to tickets that are still inside the actor admission window.
/// A cancellation delivered after a ticket has been enqueued, superseded, or completed is telemetry
/// only and is never retained as a future pre-enqueue marker.
public struct Lane3UnifiedCancellationAdmissionFence: Sendable {
    private var admittingTickets: Set<UInt64> = []
    private var cancelledBeforeEnqueueTickets: Set<UInt64> = []
    private var lateRetiredCancellationIgnored: UInt64 = 0
    private var counterOverflowed = false

    public init() {}

    public mutating func beginAdmission(ticket: UInt64) {
        precondition(admittingTickets.insert(ticket).inserted, "duplicate cancellation admission ticket")
    }

    /// Returns true when cancellation was delivered before the enqueue closure consumed admission.
    @discardableResult
    public mutating func consumeAdmission(ticket: UInt64) -> Bool {
        precondition(admittingTickets.remove(ticket) != nil, "missing cancellation admission ticket")
        return cancelledBeforeEnqueueTickets.remove(ticket) != nil
    }

    public mutating func abandonAdmission(ticket: UInt64) {
        admittingTickets.remove(ticket)
        cancelledBeforeEnqueueTickets.remove(ticket)
    }

    /// Returns true only for a ticket that is still allowed to enqueue later.
    @discardableResult
    public mutating func markCancellationIfAdmitting(ticket: UInt64) -> Bool {
        guard admittingTickets.contains(ticket) else { return false }
        cancelledBeforeEnqueueTickets.insert(ticket)
        return true
    }

    public mutating func noteLateRetiredCancellationIgnored() {
        let next = lateRetiredCancellationIgnored.addingReportingOverflow(1)
        if next.overflow {
            lateRetiredCancellationIgnored = UInt64.max
            counterOverflowed = true
        } else {
            lateRetiredCancellationIgnored = next.partialValue
        }
    }

    public func snapshot() -> Lane3UnifiedCancellationAdmissionSnapshot {
        Lane3UnifiedCancellationAdmissionSnapshot(
            admittingTicketCount: admittingTickets.count,
            cancelledBeforeEnqueueTicketCount: cancelledBeforeEnqueueTickets.count,
            lateRetiredCancellationIgnored: lateRetiredCancellationIgnored,
            counterOverflowed: counterOverflowed,
            invariantHolds: cancelledBeforeEnqueueTickets.isSubset(of: admittingTickets),
            parityPromotionAllowed: false
        )
    }
}
