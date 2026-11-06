import Foundation

private struct AW34FixedWindowBenchmarkModel {
    let windowNanoseconds: UInt64
    private var deadline: UInt64?
    private var latestTicket: UInt64?
    private(set) var executed: UInt64 = 0
    private(set) var superseded: UInt64 = 0

    init(windowNanoseconds: UInt64) {
        self.windowNanoseconds = windowNanoseconds
    }

    @inline(never)
    mutating func submit(ticket: UInt64, at now: UInt64) {
        if let deadline, deadline <= now, latestTicket != nil {
            executed &+= 1
            self.deadline = nil
            latestTicket = nil
        }
        if latestTicket != nil { superseded &+= 1 }
        latestTicket = ticket
        if deadline == nil { deadline = now &+ windowNanoseconds }
    }

    @inline(never)
    mutating func finish(at now: UInt64) {
        if let deadline, deadline <= now, latestTicket != nil {
            executed &+= 1
            self.deadline = nil
            latestTicket = nil
        }
    }
}

@main
struct L3AW34FixedWindowCoalescingBenchmark {
    static func main() {
        let rounds = 20
        let operations = 1_000_000
        let window: UInt64 = 16_000_000
        let clock = ContinuousClock()
        var samples: [Double] = []
        var checksum: UInt64 = 0

        for round in 0..<rounds {
            var model = AW34FixedWindowBenchmarkModel(windowNanoseconds: window)
            var now: UInt64 = 0
            var jitter = UInt64(round + 1) &* 0x9E3779B97F4A7C15
            let start = clock.now
            for index in 1...operations {
                // Runtime-dependent monotonic spacing plus no-inline state mutation prevents the
                // optimizer from folding the benchmark into a closed-form counter calculation.
                jitter ^= jitter << 13
                jitter ^= jitter >> 7
                jitter ^= jitter << 17
                now &+= 100_000 &+ (jitter % 50_001)
                model.submit(ticket: UInt64(index) ^ jitter, at: now)
            }
            model.finish(at: now &+ window)
            let elapsed = start.duration(to: clock.now).components
            let ms = Double(elapsed.seconds) * 1_000
                + Double(elapsed.attoseconds) / 1_000_000_000_000_000
            samples.append(ms)
            precondition(model.executed + model.superseded == UInt64(operations))
            checksum &+= model.executed &* 31 &+ model.superseded &+ jitter
        }

        samples.sort()
        func percentile(_ fraction: Double) -> Double {
            let index = min(
                samples.count - 1,
                Int((Double(samples.count - 1) * fraction).rounded())
            )
            return samples[index]
        }

        print(String(format:
            "L3-AW34 fixed-window model benchmark 20x1000000 median %.3fms p95 %.3fms max %.3fms checksum %llu",
            percentile(0.50),
            percentile(0.95),
            samples.last!,
            checksum
        ))
    }
}
