import Foundation

private struct L3AW41BenchmarkCorrelator: Lane3LeaseStampedContinuityCorrelating {
    func correlateLeaseStamped(
        sampleID: UInt64,
        stamped: Lane3SelectedTransportGenerationStampedOutcome,
        firstIntentUptimeNanoseconds: UInt64,
        requestedTarget: Lane3InteractiveContinuityMeasuredTarget,
        audibleResultUptimeNanoseconds: UInt64?,
        audibleTimestampSource: String?
    ) async -> Lane3LeaseStampedContinuityCorrelation {
        .nonExecuted(slotGeneration: stamped.slotGeneration, outcome: stamped.outcome)
    }
}

private func l3aw41BenchmarkNonExecuted(
    ticket: UInt64
) -> Lane3SelectedTransportGenerationStampedOutcome {
    .init(
        slotGeneration: 1,
        outcome: .transport(.cancelledBeforeDispatch(ticket: ticket, kind: .loop))
    )
}

private func l3aw41NearestRank(_ values: [UInt64], percentile: Double) -> UInt64 {
    let sorted = values.sorted()
    let rank = max(1, Int(ceil(percentile * Double(sorted.count))))
    return sorted[min(sorted.count - 1, rank - 1)]
}

@main
struct L3AW41StagedPhysicalCaptureBenchmark {
    static func main() async {
        let runs = 20
        let operationsPerRun = 10_000
        var durations: [UInt64] = []
        durations.reserveCapacity(runs)
        var checksum: UInt64 = 0

        for run in 0..<runs {
            let coordinator = Lane3InteractiveContinuityV2StagedCaptureCoordinator(
                correlator: L3AW41BenchmarkCorrelator(),
                sessionCapacity: 4_096,
                pendingCapacity: 4_096,
                issueDetailCapacity: 16,
                retiredIdentityCapacity: 4_096
            )
            let start = DispatchTime.now().uptimeNanoseconds
            for index in 0..<operationsPerRun {
                let id = UInt64((run * operationsPerRun) + index)
                _ = await coordinator.beginSample(
                    sampleID: id,
                    firstIntentUptimeNanoseconds: id,
                    requestedTarget: .loopDisabled
                )
                _ = await coordinator.recordStampedOutcome(
                    sampleID: id,
                    stamped: l3aw41BenchmarkNonExecuted(ticket: id)
                )
            }
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            durations.append(elapsed)
            let snapshot = await coordinator.snapshot()
            checksum &+= snapshot.finalizedNonExecutedCount
            checksum &+= snapshot.retiredIdentityDrops
            checksum &+= snapshot.issueCount
        }

        let median = l3aw41NearestRank(durations, percentile: 0.50)
        let p95 = l3aw41NearestRank(durations, percentile: 0.95)
        let maximum = durations.max() ?? 0
        print(
            "L3-AW41 benchmark PASS runs=\(runs) perRun=\(operationsPerRun) medianNs=\(median) "
                + "p95Ns=\(p95) maxNs=\(maximum) checksum=\(checksum)"
        )
    }
}
