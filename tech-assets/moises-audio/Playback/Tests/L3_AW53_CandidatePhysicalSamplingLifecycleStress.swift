import Foundation

@main
enum L3AW53CandidatePhysicalSamplingLifecycleStress {
    static func main() throws {
        let cadences: [Double] = [10, 12, 15, 20, 25, 30]
        var validCells = 0
        for round in 0..<1_000 {
            let cadence = cadences[round % cadences.count]
            var lifecycle = Lane3CandidatePhysicalSamplingLifecycle()
            let base = 50_000 + Double(round) * 5_000
            try lifecycle.start(firstSampleUptimeSeconds: base)
            for index in 1...120 {
                try lifecycle.acceptSample(uptimeSeconds: base + Double(index) * cadence)
            }
            try lifecycle.complete()
            precondition(lifecycle.state == .completed)
            precondition(lifecycle.acceptedSamples == 121)
            precondition(lifecycle.maximumObservedGapSeconds == cadence)
            validCells += 1
        }

        var gapRejected = 0
        for round in 0..<1_000 {
            var lifecycle = Lane3CandidatePhysicalSamplingLifecycle()
            let base = Double(round) * 100
            try lifecycle.start(firstSampleUptimeSeconds: base)
            do {
                try lifecycle.acceptSample(uptimeSeconds: base + 30.000_001 + Double(round % 7) * 0.001)
                preconditionFailure("gap cell accepted")
            } catch Lane3CandidatePhysicalSamplingLifecycleError.cadenceGapExceeded {
                gapRejected += 1
            }
        }

        var nonMonotonicRejected = 0
        for round in 0..<1_000 {
            var lifecycle = Lane3CandidatePhysicalSamplingLifecycle()
            let base = 100_000 + Double(round)
            try lifecycle.start(firstSampleUptimeSeconds: base)
            do {
                try lifecycle.acceptSample(uptimeSeconds: base - Double(round % 2))
                preconditionFailure("non-monotonic cell accepted")
            } catch Lane3CandidatePhysicalSamplingLifecycleError.nonMonotonicTick {
                nonMonotonicRejected += 1
            }
        }

        var abortCells = 0
        let reasons: [Lane3CandidatePhysicalSamplingAbortReason] = [
            .hostCancelled, .applicationWillResignActive, .applicationDidEnterBackground,
            .applicationWillTerminate, .samplingFailed, .cadenceGapExceeded
        ]
        for round in 0..<1_002 {
            var lifecycle = Lane3CandidatePhysicalSamplingLifecycle()
            try lifecycle.start(firstSampleUptimeSeconds: Double(round + 1))
            let reason = reasons[round % reasons.count]
            lifecycle.abort(reason)
            precondition(lifecycle.state == .aborted)
            precondition(lifecycle.abortReason == reason)
            abortCells += 1
        }

        print("L3_AW53_CandidatePhysicalSamplingLifecycleStress PASS valid=\(validCells) gapRejected=\(gapRejected) nonMonotonicRejected=\(nonMonotonicRejected) abort=\(abortCells)")
    }
}
