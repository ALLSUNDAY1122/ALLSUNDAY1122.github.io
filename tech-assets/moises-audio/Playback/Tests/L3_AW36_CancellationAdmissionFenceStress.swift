import Foundation

@main
struct L3AW36CancellationAdmissionFenceStress {
    static func main() {
        var fence = Lane3UnifiedCancellationAdmissionFence()
        let total = 1_000_000
        var preEnqueue = 0
        var late = 0

        for raw in 1...total {
            let ticket = UInt64(raw)
            fence.beginAdmission(ticket: ticket)
            if raw % 5 == 0 {
                precondition(fence.markCancellationIfAdmitting(ticket: ticket))
                precondition(fence.consumeAdmission(ticket: ticket))
                preEnqueue += 1
            } else {
                precondition(!fence.consumeAdmission(ticket: ticket))
                if raw % 2 == 0 {
                    precondition(!fence.markCancellationIfAdmitting(ticket: ticket))
                    fence.noteLateRetiredCancellationIgnored()
                    late += 1
                }
            }
        }

        let snapshot = fence.snapshot()
        precondition(snapshot.admittingTicketCount == 0)
        precondition(snapshot.cancelledBeforeEnqueueTicketCount == 0)
        precondition(snapshot.lateRetiredCancellationIgnored == UInt64(late))
        precondition(snapshot.invariantHolds)
        precondition(preEnqueue == 200_000)
        precondition(late == 400_000)
        print("L3-AW36 stress PASS total=\(total) preEnqueue=\(preEnqueue) lateIgnored=\(late) retained=0")
    }
}
