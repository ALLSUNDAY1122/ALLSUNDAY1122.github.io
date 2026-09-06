import Foundation
import Dispatch

@main
struct L3AW31TempoBoundaryClockBenchmark {
    static func main() throws {
        var samples: [Double] = []
        var checksum = 0.0

        for round in 0..<20 {
            let started = DispatchTime.now().uptimeNanoseconds
            for index in 0..<500_000 {
                let ratio = 0.5 + Double((index + round) % 151) / 100.0
                let loop: PlaybackLoopRange? = index.isMultiple(of: 3)
                    ? PlaybackLoopRange(startSeconds: 10, endSeconds: 18)
                    : nil
                checksum += try PlaybackTempoClockMath.projectPosition(
                    anchorProjectSeconds: Double(index % 17),
                    elapsedHostSeconds: Double(index % 97) / 1_000,
                    tempoRatio: ratio,
                    durationSeconds: 900,
                    loop: loop
                )
                checksum += try PlaybackTempoClockMath.hostDuration(
                    forProjectDuration: Double(index % 31) / 10,
                    tempoRatio: ratio
                )
            }
            let ended = DispatchTime.now().uptimeNanoseconds
            samples.append(Double(ended - started) / 1_000_000)
        }

        let sorted = samples.sorted()
        func percentile(_ fraction: Double) -> Double {
            let raw = Int(ceil(Double(sorted.count) * fraction)) - 1
            return sorted[min(sorted.count - 1, max(0, raw))]
        }

        print(String(
            format: "L3-AW31 clock benchmark rounds=20 opsPerRound=1000000 median=%.3fms p95=%.3fms max=%.3fms checksum=%.6f",
            percentile(0.50),
            percentile(0.95),
            sorted.last ?? 0,
            checksum
        ))
    }
}
