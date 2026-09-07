import Foundation

@main
struct L3AW30LongTrackExecutionBenchmark {
    static func main() throws {
        let rounds = 20
        let operationsPerRound = 100_000
        var samples: [Double] = []
        var checksum: UInt64 = 0

        for _ in 0..<rounds {
            let controller = Lane3LongTrackEvidenceExecutionController()
            let start = DispatchTime.now().uptimeNanoseconds
            for index in 0..<operationsPerRound {
                try controller.recordSuccessfulRead(
                    role: (index & 1) == 0 ? .reference : .observed,
                    frameCount: 256
                )
                if index % 1_000 == 0 {
                    let checkpoint = controller.checkpoint()
                    precondition(checkpoint.state == .running)
                    checksum &+= checkpoint.checkpointSerial
                }
            }
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            samples.append(Double(elapsed) / 1_000_000)
            let checkpoint = controller.checkpoint()
            checksum &+= checkpoint.referenceReadCalls
            checksum &+= checkpoint.observedReadCalls
        }

        samples.sort()
        let median = samples[samples.count / 2]
        let p95Index = min(samples.count - 1, Int(ceil(Double(samples.count) * 0.95)) - 1)
        let p95 = samples[p95Index]
        let maximum = samples.last!
        print(String(format: "L3-AW30 benchmark PASS rounds=%d ops=%d median=%.3fms p95=%.3fms max=%.3fms checksum=%llu", rounds, operationsPerRound, median, p95, maximum, checksum))
    }
}
