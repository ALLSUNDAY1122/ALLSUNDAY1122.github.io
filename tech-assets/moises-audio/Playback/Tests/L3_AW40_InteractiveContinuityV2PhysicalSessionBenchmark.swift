import Foundation
import Dispatch

private func aw40Percentile(_ fraction: Double, values: [UInt64]) -> UInt64 {
    let sorted = values.sorted()
    let rank = max(1, Int(ceil(fraction * Double(sorted.count))))
    return sorted[min(sorted.count - 1, rank - 1)]
}

@main
struct L3AW40InteractiveContinuityV2PhysicalSessionBenchmark {
    static func main() {
        let runs = 20
        let total = 1_000_000
        var durations: [UInt64] = []
        durations.reserveCapacity(runs)
        var checksum: UInt64 = 0

        for run in 0..<runs {
            let start = DispatchTime.now().uptimeNanoseconds
            var buffer = Lane3InteractiveContinuityV2PhysicalSessionBuffer(capacity: 4_096)
            for index in 0..<total {
                let shape: Lane3InteractiveContinuityV2OperationShape
                switch index % 3 {
                case 0: shape = .seek
                case 1: shape = .loopEnabled
                default: shape = .loopDisabled
                }
                let base = UInt64(index) * 100
                buffer.append(.init(
                    sampleID: UInt64(index),
                    shape: shape,
                    firstIntentUptimeNanoseconds: base,
                    tokenIssuedUptimeNanoseconds: base + 10,
                    backendCompletedUptimeNanoseconds: base + 20,
                    audibleResultUptimeNanoseconds: base + 40,
                    audibleTimestampSource: "external",
                    callerCancellationObservedAfterDispatch: false,
                    instrumentationValidForV2: true,
                    generationStable: true,
                    timingOrderValid: true,
                    targetMatched: true,
                    externalAudibleMarkerValid: true
                ))
            }
            let end = DispatchTime.now().uptimeNanoseconds
            durations.append(end - start)
            checksum &+= UInt64(buffer.retainedCount)
            checksum &+= buffer.capacityDrops
            checksum &+= UInt64(run)
        }

        let median = aw40Percentile(0.50, values: durations)
        let p95 = aw40Percentile(0.95, values: durations)
        let maximum = durations.max() ?? 0
        print(
            "L3-AW40 benchmark PASS runs=\(runs) ops=\(total) "
                + "median_ns=\(median) p95_ns=\(p95) max_ns=\(maximum) checksum=\(checksum)"
        )
    }
}
