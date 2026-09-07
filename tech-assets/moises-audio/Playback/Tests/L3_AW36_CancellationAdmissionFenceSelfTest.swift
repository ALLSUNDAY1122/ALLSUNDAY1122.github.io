import Foundation

@main
struct L3AW36CancellationAdmissionFenceSelfTest {
    static func main() {
        var fence = Lane3UnifiedCancellationAdmissionFence()

        fence.beginAdmission(ticket: 1)
        precondition(fence.markCancellationIfAdmitting(ticket: 1))
        var snapshot = fence.snapshot()
        precondition(snapshot.admittingTicketCount == 1)
        precondition(snapshot.cancelledBeforeEnqueueTicketCount == 1)
        precondition(snapshot.invariantHolds)
        precondition(fence.consumeAdmission(ticket: 1))

        fence.beginAdmission(ticket: 2)
        precondition(!fence.consumeAdmission(ticket: 2))
        precondition(!fence.markCancellationIfAdmitting(ticket: 2))
        fence.noteLateRetiredCancellationIgnored()

        fence.beginAdmission(ticket: 3)
        fence.abandonAdmission(ticket: 3)
        precondition(!fence.markCancellationIfAdmitting(ticket: 3))
        fence.noteLateRetiredCancellationIgnored()

        snapshot = fence.snapshot()
        precondition(snapshot.admittingTicketCount == 0)
        precondition(snapshot.cancelledBeforeEnqueueTicketCount == 0)
        precondition(snapshot.lateRetiredCancellationIgnored == 2)
        precondition(snapshot.invariantHolds)
        precondition(!snapshot.parityPromotionAllowed)

        print("L3-AW36 cancellation fence PASS lateIgnored=\(snapshot.lateRetiredCancellationIgnored)")
    }
}
