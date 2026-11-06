import Foundation

@main
enum L3AW52CandidatePhysicalResourceTraceStress {
    static func main() throws {
        let digest = String(repeating: "cd", count: 32)
        var validCells = 0
        var rejectedCells = 0

        for interval in [10.0, 12.0, 15.0, 20.0, 25.0, 30.0] {
            let sampleCount = Int(ceil(1_800 / interval)) + 1
            for repetition in 0..<50 {
                var accumulator = Lane3CandidatePhysicalResourceTraceAccumulator()
                for index in 0..<sampleCount {
                    let uptime = Double(index) * interval
                    try accumulator.append(sample(
                        index: index + repetition,
                        uptime: uptime,
                        powered: false
                    ))
                }
                let receipt = try accumulator.makeAW51CandidateReceipt(
                    sessionIdentifier: "valid-\(Int(interval))-\(repetition)",
                    traceArtifactSHA256: digest
                )
                precondition(receipt.sampleCount == sampleCount)
                precondition(receipt.maximumSampleIntervalSeconds <= 30)
                precondition(receipt.observedDurationSeconds >= 1_800)
                validCells += 1
            }
        }

        for poweredIndex in 0...120 {
            var accumulator = Lane3CandidatePhysicalResourceTraceAccumulator()
            for index in 0...120 {
                try accumulator.append(sample(
                    index: index,
                    uptime: Double(index) * 15,
                    powered: index == poweredIndex
                ))
            }
            do {
                _ = try accumulator.makeAW51CandidateReceipt(
                    sessionIdentifier: "power-\(poweredIndex)",
                    traceArtifactSHA256: digest
                )
                preconditionFailure("external-power cell escaped")
            } catch Lane3CandidatePhysicalResourceTraceError.externalPowerConnected {
                rejectedCells += 1
            }
        }

        for badIndex in 1...120 {
            var accumulator = Lane3CandidatePhysicalResourceTraceAccumulator()
            var rejected = false
            for index in 0...120 {
                var uptime = Double(index) * 15
                if index == badIndex { uptime = Double(index - 1) * 15 }
                do {
                    try accumulator.append(sample(index: index, uptime: uptime, powered: false))
                } catch Lane3CandidatePhysicalResourceTraceError.nonMonotonicUptime {
                    rejected = true
                    break
                }
            }
            precondition(rejected)
            rejectedCells += 1
        }

        for gapIndex in 1...120 {
            var accumulator = Lane3CandidatePhysicalResourceTraceAccumulator()
            for index in 0...120 {
                var uptime = Double(index) * 15
                if index >= gapIndex { uptime += 31 }
                try accumulator.append(sample(index: index, uptime: uptime, powered: false))
            }
            do {
                _ = try accumulator.makeAW51CandidateReceipt(
                    sessionIdentifier: "gap-\(gapIndex)",
                    traceArtifactSHA256: digest
                )
                preconditionFailure("sampling-gap cell escaped")
            } catch Lane3CandidatePhysicalResourceTraceError.samplingGapExceeded {
                rejectedCells += 1
            }
        }

        for index in 0...120 {
            var accumulator = Lane3CandidatePhysicalResourceTraceAccumulator()
            var rejected = false
            for sampleIndex in 0...120 {
                let battery = sampleIndex == index ? -1.0 : 0.8
                do {
                    try accumulator.append(.init(
                        uptimeSeconds: Double(sampleIndex) * 15,
                        residentSetBytes: 128_000_000 + UInt64(sampleIndex),
                        thermalState: .nominal,
                        batteryLevel: battery,
                        externalPowerConnected: false
                    ))
                } catch Lane3CandidatePhysicalResourceTraceError.invalidBatteryLevel {
                    rejected = true
                    break
                }
            }
            precondition(rejected)
            rejectedCells += 1
        }

        precondition(validCells == 300)
        precondition(rejectedCells == 482)
        print("L3_AW52_CandidatePhysicalResourceTraceStress PASS valid=\(validCells) rejected=\(rejectedCells)")
    }

    static func sample(
        index: Int,
        uptime: Double,
        powered: Bool
    ) -> Lane3CandidatePhysicalResourceSample {
        .init(
            uptimeSeconds: uptime,
            residentSetBytes: 160_000_000 + UInt64((index % 4096) * 8192),
            thermalState: Lane3CandidatePhysicalThermalState.allCases[index % 4],
            batteryLevel: max(0.2, 0.95 - Double(index % 400) * 0.001),
            externalPowerConnected: powered
        )
    }
}
