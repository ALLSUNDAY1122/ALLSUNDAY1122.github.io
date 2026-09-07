import Foundation

private let aw42BenchmarkBlockedCapability = PlaybackRepeatedLoopSeamCapabilityInput(
    exactFutureSampleTimeSchedulingImplemented: false,
    revocationMechanism: .none,
    staleEventRevocationOrIsolationProven: false,
    seekInvalidationConnected: false,
    tempoInvalidationConnected: false,
    lifecycleInvalidationConnected: false,
    revocationPathAudiblySafe: false,
    selectedIntegrationExecutionPresent: false,
    physicalDeviceAudibilityValidationPresent: false
)

@main
struct L3AW42RepeatedLoopSeamSafetyBenchmark {
    static func main() {
        let runs = 20
        let iterations = 1_000_000
        var times: [UInt64] = []
        times.reserveCapacity(runs)
        var checksum: UInt64 = 0
        for _ in 0..<runs {
            var gate = PlaybackRepeatedLoopSeamSafetyGate(capability: aw42BenchmarkBlockedCapability)
            let start = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<iterations {
                do {
                    _ = try gate.requestAuthorization()
                    preconditionFailure("unsafe authorization")
                } catch PlaybackRepeatedLoopSeamSafetyGateError.capabilityBlocked {
                } catch {
                    preconditionFailure("unexpected error")
                }
            }
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            times.append(elapsed)
            checksum &+= gate.snapshot.blockedAttempts
        }
        let sorted = times.sorted()
        func percentile(_ p: Double) -> UInt64 {
            let rank = max(1, Int(ceil(p * Double(sorted.count))))
            return sorted[min(sorted.count - 1, rank - 1)]
        }
        print(
            "L3-AW42 benchmark PASS medianNs=\(percentile(0.5)) "
                + "p95Ns=\(percentile(0.95)) maxNs=\(sorted.last!) checksum=\(checksum)"
        )
    }
}
