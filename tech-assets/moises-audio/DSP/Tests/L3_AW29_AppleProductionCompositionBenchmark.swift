import Foundation

@main
struct L3AW29AppleProductionCompositionBenchmark {
    static func main() throws {
        let receipt = Lane3AppleDSPProductionCompositionReceipt(
            telemetryWrapped: true,
            transactionalConformance: true,
            tempoTransitionConformance: true,
            pitchTransitionConformance: true,
            backendNodeIdentityShared: true,
            directBackendAccessExposed: false
        )
        var samples: [Double] = []
        var checksum = 0
        for _ in 0..<20 {
            let start = ContinuousClock.now
            for _ in 0..<100_000 {
                let validated = try Lane3AppleDSPProductionCompositionValidator.validate(receipt)
                checksum &+= validated.schemaVersion
            }
            let duration = start.duration(to: .now)
            let seconds = Double(duration.components.seconds)
                + Double(duration.components.attoseconds) / 1_000_000_000_000_000_000
            samples.append(seconds * 1_000)
        }
        samples.sort()
        let median = samples[samples.count / 2]
        let p95 = samples[Int(Double(samples.count - 1) * 0.95)]
        let maximum = samples.last ?? 0
        print(String(
            format: "L3-AW29 composition benchmark median=%.3fms p95=%.3fms max=%.3fms checksum=%d",
            median,
            p95,
            maximum,
            checksum
        ))
    }
}
