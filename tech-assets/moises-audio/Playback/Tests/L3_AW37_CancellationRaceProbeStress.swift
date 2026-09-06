import Foundation

private actor AW37StressProbeDriver: Lane3CancellationRaceProbeDriving {
    private var completed: UInt64 = 0

    func submitProbeOperation(index: Int) async -> Lane3CancellationRaceProbeOutcome {
        if index % 8 == 0 { await Task.yield() }
        completed &+= 1
        if Task.isCancelled { return .cancelledBeforeDispatch }
        return .executed(callerCancellationObservedAfterDispatch: false)
    }

    func cancellationRaceProbeSnapshot() async -> Lane3CancellationRaceProbeSnapshot {
        Lane3CancellationRaceProbeSnapshot(
            pendingOperationCount: 0,
            executionInFlight: false,
            admittingTicketCount: 0,
            cancelledBeforeEnqueueTicketCount: 0,
            lateRetiredCancellationIgnored: completed / 16,
            cancellationCounterOverflowed: false,
            admissionInvariantHolds: true
        )
    }
}

@main
struct L3AW37CancellationRaceProbeStress {
    static func main() async {
        let start = DispatchTime.now().uptimeNanoseconds
        let report = await Lane3CancellationRaceProbe.run(
            driver: AW37StressProbeDriver(),
            policy: Lane3CancellationRaceProbePolicy(
                iterations: 1_000_000,
                batchSize: 256,
                postOperationSettlementYields: 32,
                quiescencePollLimit: 1_000
            )
        )
        let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000

        precondition(report.cancellationRequests == 750_000)
        precondition(report.accountingComplete)
        precondition(report.boundednessPass)
        precondition(report.executed + report.cancelledBeforeDispatch == 1_000_000)
        precondition(report.supersededBeforeToken == 0)
        precondition(report.rejectedBeforeToken == 0)
        precondition(report.failedAfterDispatch == 0)
        precondition(report.finalSnapshot.isQuiescent)
        precondition(report.finalSnapshot.admissionInvariantHolds)

        print(
            "L3-AW37 probe stress PASS events=\(report.iterations) "
            + "cancelRequests=\(report.cancellationRequests) cancelled=\(report.cancelledBeforeDispatch) "
            + "executed=\(report.executed) elapsedMs=\(elapsedMs)"
        )
    }
}
