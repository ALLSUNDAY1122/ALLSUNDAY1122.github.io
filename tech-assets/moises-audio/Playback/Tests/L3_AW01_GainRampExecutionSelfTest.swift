import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private func expectThrow<T>(
    _ expected: PlaybackGainRampExecutionError,
    _ body: () throws -> T,
    _ label: String
) {
    do {
        _ = try body()
        fputs("FAIL: expected throw \(label)\n", stderr)
        exit(1)
    } catch let error as PlaybackGainRampExecutionError {
        require(error == expected, "\(label): wrong error \(error)")
    } catch {
        fputs("FAIL: \(label): unexpected error \(error)\n", stderr)
        exit(1)
    }
}

@main
struct L3AW01GainRampExecutionSelfTestMain {
    static func main() throws {
        let a = StemID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        let b = StemID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
        let c = StemID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!)
        let unknown = StemID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!)

        let plan = try PlaybackGainRampExecutionPlanner.plan(
            currentGains: [a: 1, b: 0.5, c: 0],
            targetGains: [a: 0, b: 0.5, c: 1],
            renderSampleRates: [a: 48_000, b: 44_100, c: 96_000]
        )
        require(plan.steps.count == 2, "unchanged stem must not schedule redundant automation")
        require(plan.steps[0].stemID == a, "steps must be deterministic by StemID")
        require(plan.steps[0].frameCount == 576, "12ms @48k must be 576 frames")
        require(plan.steps[1].stemID == c, "second changed stem must be c")
        require(plan.steps[1].frameCount == 1_152, "12ms @96k must be 1152 frames")
        require(plan.committedTargetGains[b] == 0.5, "unchanged target must remain committed")

        let fortyFourOne = try PlaybackGainRampExecutionPlanner.plan(
            currentGains: [b: 0],
            targetGains: [b: 1],
            renderSampleRates: [b: 44_100]
        )
        require(fortyFourOne.steps.singleValue!.frameCount == 529, "12ms @44.1k rounds to 529 frames")

        let preserveMissingTarget = try PlaybackGainRampExecutionPlanner.plan(
            currentGains: [a: 0.25],
            targetGains: [:],
            renderSampleRates: [a: 48_000]
        )
        require(preserveMissingTarget.steps.isEmpty, "missing target must preserve current gain")
        require(preserveMissingTarget.committedTargetGains[a] == 0.25, "preserved current gain must commit")

        expectThrow(.unknownStem(unknown), {
            try PlaybackGainRampExecutionPlanner.plan(
                currentGains: [a: 1],
                targetGains: [unknown: 0],
                renderSampleRates: [a: 48_000]
            )
        }, "unknown target stem")

        expectThrow(.invalidGain(a, 1.5), {
            try PlaybackGainRampExecutionPlanner.plan(
                currentGains: [a: 1.5],
                targetGains: [a: 0],
                renderSampleRates: [a: 48_000]
            )
        }, "out-of-range current gain")

        do {
            _ = try PlaybackGainRampExecutionPlanner.plan(
                currentGains: [a: .nan],
                targetGains: [a: 0],
                renderSampleRates: [a: 48_000]
            )
            fputs("FAIL: expected NaN gain rejection\n", stderr)
            exit(1)
        } catch let error as PlaybackGainRampExecutionError {
            guard case .invalidGain(let id, let value) = error, id == a, value.isNaN else {
                fputs("FAIL: wrong NaN gain error \(error)\n", stderr)
                exit(1)
            }
        }

        expectThrow(.invalidSampleRate(a, 0), {
            try PlaybackGainRampExecutionPlanner.plan(
                currentGains: [a: 1],
                targetGains: [a: 0],
                renderSampleRates: [a: 0]
            )
        }, "zero sample rate")

        expectThrow(.invalidRampDuration(0), {
            try PlaybackGainRampExecutionPlanner.plan(
                currentGains: [a: 1],
                targetGains: [a: 0],
                renderSampleRates: [a: 48_000],
                policy: PlaybackGainRampPolicy(rampDurationSeconds: 0)
            )
        }, "zero ramp duration")

        var current: [StemID: Double] = [a: 1]
        for index in 0..<10_000 {
            let target = Double(index % 101) / 100.0
            let retarget = try PlaybackGainRampExecutionPlanner.plan(
                currentGains: current,
                targetGains: [a: target],
                renderSampleRates: [a: 48_000]
            )
            current = retarget.committedTargetGains
            require(current[a] == target, "rapid retarget committed state mismatch")
        }

        print("PASS L3-AW01 gain-ramp execution planner self-test")
    }
}

private extension Array {
    var singleValue: Element? { count == 1 ? self[0] : nil }
}
