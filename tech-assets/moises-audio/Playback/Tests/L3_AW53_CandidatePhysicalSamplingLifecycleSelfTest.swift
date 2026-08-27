import Foundation

@main
enum L3AW53CandidatePhysicalSamplingLifecycleSelfTest {
    static func main() throws {
        var stable = Lane3CandidatePhysicalSamplingLifecycle()
        try stable.start(firstSampleUptimeSeconds: 10_000)
        for index in 1...120 {
            try stable.acceptSample(uptimeSeconds: 10_000 + Double(index) * 15)
        }
        precondition(stable.state == .running)
        precondition(stable.acceptedSamples == 121)
        precondition(stable.maximumObservedGapSeconds == 15)
        precondition(stable.firstSampleUptimeSeconds == 10_000)
        precondition(stable.lastSampleUptimeSeconds == 11_800)
        try stable.complete()
        precondition(stable.state == .completed)
        precondition(stable.isTerminal)
        precondition(stable.abortReason == nil)

        try expect(.notRunning) {
            var value = Lane3CandidatePhysicalSamplingLifecycle()
            try value.acceptSample(uptimeSeconds: 1)
        }
        try expect(.alreadyStarted) {
            var value = Lane3CandidatePhysicalSamplingLifecycle()
            try value.start(firstSampleUptimeSeconds: 1)
            try value.start(firstSampleUptimeSeconds: 2)
        }
        try expectNonMonotonic {
            var value = Lane3CandidatePhysicalSamplingLifecycle()
            try value.start(firstSampleUptimeSeconds: 100)
            try value.acceptSample(uptimeSeconds: 100)
        }

        var exactMaximum = Lane3CandidatePhysicalSamplingLifecycle()
        try exactMaximum.start(firstSampleUptimeSeconds: 0)
        try exactMaximum.acceptSample(uptimeSeconds: 30)
        precondition(exactMaximum.maximumObservedGapSeconds == 30)

        try expectCadenceGap {
            var value = Lane3CandidatePhysicalSamplingLifecycle()
            try value.start(firstSampleUptimeSeconds: 0)
            try value.acceptSample(uptimeSeconds: 30.000_001)
        }

        for reason in [
            Lane3CandidatePhysicalSamplingAbortReason.hostCancelled,
            .applicationWillResignActive,
            .applicationDidEnterBackground,
            .applicationWillTerminate,
            .samplingFailed,
            .cadenceGapExceeded
        ] {
            var value = Lane3CandidatePhysicalSamplingLifecycle()
            try value.start(firstSampleUptimeSeconds: 1)
            value.abort(reason)
            precondition(value.state == .aborted)
            precondition(value.abortReason == reason)
            precondition(value.isTerminal)
            value.abort(.hostCancelled)
            precondition(value.abortReason == reason)
        }

        var preparedAbort = Lane3CandidatePhysicalSamplingLifecycle()
        preparedAbort.abort(.hostCancelled)
        precondition(preparedAbort.state == .aborted)
        precondition(preparedAbort.acceptedSamples == 0)

        do {
            try stable.acceptSample(uptimeSeconds: 12_000)
            preconditionFailure("completed lifecycle accepted another sample")
        } catch Lane3CandidatePhysicalSamplingLifecycleError.terminalState(.completed) {
            // expected
        }

        print("L3_AW53_CandidatePhysicalSamplingLifecycleSelfTest PASS samples=121 maxGap=15 abortReasons=6")
    }

    private static func expect(
        _ expected: Lane3CandidatePhysicalSamplingLifecycleError,
        _ body: () throws -> Void
    ) throws {
        do {
            try body()
            preconditionFailure("expected \(expected)")
        } catch let error as Lane3CandidatePhysicalSamplingLifecycleError {
            precondition(error == expected, "expected \(expected), got \(error)")
        }
    }

    private static func expectNonMonotonic(_ body: () throws -> Void) throws {
        do {
            try body()
            preconditionFailure("expected nonMonotonicTick")
        } catch Lane3CandidatePhysicalSamplingLifecycleError.nonMonotonicTick {
            return
        }
    }

    private static func expectCadenceGap(_ body: () throws -> Void) throws {
        do {
            try body()
            preconditionFailure("expected cadenceGapExceeded")
        } catch Lane3CandidatePhysicalSamplingLifecycleError.cadenceGapExceeded {
            return
        }
    }
}
