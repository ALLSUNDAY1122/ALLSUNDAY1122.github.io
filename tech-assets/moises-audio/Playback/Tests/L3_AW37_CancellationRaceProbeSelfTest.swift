import Foundation

private actor AW37ProbeDriver: Lane3CancellationRaceProbeDriving {
    private var completed = 0
    private var snapshotCalls = 0

    func submitProbeOperation(index: Int) async -> Lane3CancellationRaceProbeOutcome {
        await Task.yield()
        completed += 1
        if Task.isCancelled {
            return .cancelledBeforeDispatch
        }
        return .executed(callerCancellationObservedAfterDispatch: false)
    }

    func cancellationRaceProbeSnapshot() async -> Lane3CancellationRaceProbeSnapshot {
        snapshotCalls += 1
        return Lane3CancellationRaceProbeSnapshot(
            pendingOperationCount: 0,
            executionInFlight: false,
            admittingTicketCount: 0,
            cancelledBeforeEnqueueTicketCount: 0,
            lateRetiredCancellationIgnored: UInt64(completed / 8),
            cancellationCounterOverflowed: false,
            admissionInvariantHolds: true
        )
    }
}

private actor AW37DelayedQuiescenceDriver: Lane3CancellationRaceProbeDriving {
    private var snapshotCalls = 0

    func submitProbeOperation(index: Int) async -> Lane3CancellationRaceProbeOutcome {
        .executed(callerCancellationObservedAfterDispatch: false)
    }

    func cancellationRaceProbeSnapshot() async -> Lane3CancellationRaceProbeSnapshot {
        snapshotCalls += 1
        let pending = snapshotCalls >= 4 ? 0 : 1
        return Lane3CancellationRaceProbeSnapshot(
            pendingOperationCount: pending,
            executionInFlight: false,
            admittingTicketCount: 0,
            cancelledBeforeEnqueueTicketCount: 0,
            lateRetiredCancellationIgnored: 0,
            cancellationCounterOverflowed: false,
            admissionInvariantHolds: true
        )
    }
}

private actor AW37CounterRegressionDriver: Lane3CancellationRaceProbeDriving {
    private var snapshotCalls = 0

    func submitProbeOperation(index: Int) async -> Lane3CancellationRaceProbeOutcome {
        .executed(callerCancellationObservedAfterDispatch: false)
    }

    func cancellationRaceProbeSnapshot() async -> Lane3CancellationRaceProbeSnapshot {
        snapshotCalls += 1
        return Lane3CancellationRaceProbeSnapshot(
            pendingOperationCount: 0,
            executionInFlight: false,
            admittingTicketCount: 0,
            cancelledBeforeEnqueueTicketCount: 0,
            lateRetiredCancellationIgnored: snapshotCalls == 1 ? 10 : 9,
            cancellationCounterOverflowed: false,
            admissionInvariantHolds: true
        )
    }
}

@main
struct L3AW37CancellationRaceProbeSelfTest {
    static func main() async {
        let driver = AW37ProbeDriver()
        let report = await Lane3CancellationRaceProbe.run(
            driver: driver,
            policy: Lane3CancellationRaceProbePolicy(
                iterations: 4_096,
                batchSize: 64,
                quiescencePollLimit: 100
            )
        )
        precondition(report.schemaVersion == 1)
        precondition(report.evidenceScope == "LANE3_AW37_ACTUAL_AUTHORITY_CANCELLATION_RACE_NON_PARITY")
        precondition(report.iterations == 4_096)
        precondition(report.cancellationRequests == 3_072)
        precondition(report.accountingComplete)
        precondition(report.executed + report.cancelledBeforeDispatch == 4_096)
        precondition(report.supersededBeforeToken == 0)
        precondition(report.rejectedBeforeToken == 0)
        precondition(report.failedAfterDispatch == 0)
        precondition(report.finalSnapshot.isQuiescent)
        precondition(report.boundednessPass)
        precondition(!report.parityPromotionAllowed)

        let delayed = await Lane3CancellationRaceProbe.run(
            driver: AW37DelayedQuiescenceDriver(),
            policy: Lane3CancellationRaceProbePolicy(
                iterations: 1,
                batchSize: 1,
                quiescencePollLimit: 10
            )
        )
        precondition(delayed.accountingComplete)
        precondition(delayed.boundednessPass)
        precondition(delayed.quiescencePolls >= 1)

        let regressed = await Lane3CancellationRaceProbe.run(
            driver: AW37CounterRegressionDriver(),
            policy: Lane3CancellationRaceProbePolicy(
                iterations: 1,
                batchSize: 1,
                quiescencePollLimit: 10
            )
        )
        precondition(regressed.counterRegressionDetected)
        precondition(!regressed.boundednessPass)

        print("L3-AW37 cancellation race probe self-test PASS iterations=\(report.iterations) cancelled=\(report.cancelledBeforeDispatch) executed=\(report.executed)")
    }
}
