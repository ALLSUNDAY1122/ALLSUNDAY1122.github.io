import Foundation

private actor AW37BenchmarkProbeDriver: Lane3CancellationRaceProbeDriving {
    private var completed: UInt64 = 0

    func submitProbeOperation(index: Int) async -> Lane3CancellationRaceProbeOutcome {
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
            lateRetiredCancellationIgnored: completed / 32,
            cancellationCounterOverflowed: false,
            admissionInvariantHolds: true
        )
    }
}

@main
struct L3AW37CancellationRaceProbeBenchmark {
    static func main() async {
        var timings: [Double] = []
        timings.reserveCapacity(20)
        var checksum = 0

        for _ in 0..<20 {
            let start = DispatchTime.now().uptimeNanoseconds
            let report = await Lane3CancellationRaceProbe.run(
                driver: AW37BenchmarkProbeDriver(),
                policy: Lane3CancellationRaceProbePolicy(
                    iterations: 20_000,
                    batchSize: 128,
                    postOperationSettlementYields: 8,
                    quiescencePollLimit: 100
                )
            )
            let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            precondition(report.accountingComplete)
            precondition(report.boundednessPass)
            timings.append(elapsedMs)
            checksum &+= report.executed
            checksum &+= report.cancelledBeforeDispatch
            checksum &+= Int(report.lateRetiredCancellationDelta)
        }

        timings.sort()
        let median = timings[timings.count / 2]
        let p95 = timings[Int(Double(timings.count - 1) * 0.95)]
        let maxValue = timings.last!
        print(
            String(
                format: "L3-AW37 probe benchmark PASS rounds=20 ops=20000 medianMs=%.3f p95Ms=%.3f maxMs=%.3f checksum=%d",
                median,
                p95,
                maxValue,
                checksum
            )
        )
    }
}
