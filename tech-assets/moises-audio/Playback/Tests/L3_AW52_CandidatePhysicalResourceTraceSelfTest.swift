import Foundation

@main
enum L3AW52CandidatePhysicalResourceTraceSelfTest {
    static func main() throws {
        let digest = String(repeating: "ab", count: 32)
        var stable = Lane3CandidatePhysicalResourceTraceAccumulator()
        for index in 0...120 {
            try stable.append(makeSample(index: index, interval: 15))
        }
        let artifactA = try stable.canonicalArtifactData(sessionIdentifier: "aw52-selftest")
        let artifactB = try stable.canonicalArtifactData(sessionIdentifier: "aw52-selftest")
        precondition(artifactA == artifactB)
        precondition(!artifactA.isEmpty)

        let receipt = try stable.makeAW51CandidateReceipt(
            sessionIdentifier: "aw52-selftest",
            traceArtifactSHA256: digest
        )
        precondition(receipt.subject == .candidate)
        precondition(receipt.scenario == .longTrackStability)
        precondition(receipt.observedDurationSeconds == 1_800)
        precondition(receipt.sampleCount == 121)
        precondition(receipt.maximumSampleIntervalSeconds == 15)
        precondition(receipt.peakRSSBytes == 200_000_000 + UInt64(120 * 4096))
        precondition(receipt.thermalNominalSamples == 31)
        precondition(receipt.thermalFairSamples == 30)
        precondition(receipt.thermalSeriousSamples == 30)
        precondition(receipt.thermalCriticalSamples == 30)
        precondition(abs(receipt.batteryStartLevel - 0.90) < 1e-12)
        precondition(abs(receipt.batteryEndLevel - 0.78) < 1e-12)
        precondition(!receipt.externalPowerConnectedDuringBatteryWindow)
        precondition(receipt.traceArtifactSHA256 == digest)
        precondition(!receipt.parityPromotionAllowed)

        try expect(.invalidUptime) {
            var accumulator = Lane3CandidatePhysicalResourceTraceAccumulator()
            try accumulator.append(.init(
                uptimeSeconds: .nan,
                residentSetBytes: 1,
                thermalState: .nominal,
                batteryLevel: 0.5,
                externalPowerConnected: false
            ))
        }
        try expect(.invalidResidentSetBytes) {
            var accumulator = Lane3CandidatePhysicalResourceTraceAccumulator()
            try accumulator.append(.init(
                uptimeSeconds: 1,
                residentSetBytes: 0,
                thermalState: .nominal,
                batteryLevel: 0.5,
                externalPowerConnected: false
            ))
        }
        try expect(.invalidBatteryLevel) {
            var accumulator = Lane3CandidatePhysicalResourceTraceAccumulator()
            try accumulator.append(.init(
                uptimeSeconds: 1,
                residentSetBytes: 1,
                thermalState: .nominal,
                batteryLevel: -1,
                externalPowerConnected: false
            ))
        }
        try expectNonMonotonic {
            var accumulator = Lane3CandidatePhysicalResourceTraceAccumulator()
            try accumulator.append(makeSample(index: 0, interval: 15))
            try accumulator.append(makeSample(index: 0, interval: 15))
        }
        try expectInsufficientDuration {
            var accumulator = Lane3CandidatePhysicalResourceTraceAccumulator()
            for index in 0...120 { try accumulator.append(makeSample(index: index, interval: 14)) }
            _ = try accumulator.makeAW51CandidateReceipt(
                sessionIdentifier: "short",
                traceArtifactSHA256: digest
            )
        }
        try expectSamplingGap {
            var accumulator = Lane3CandidatePhysicalResourceTraceAccumulator()
            for index in 0...120 {
                var uptime = Double(index) * 15
                if index >= 60 { uptime += 31 }
                try accumulator.append(makeSample(index: index, uptime: uptime))
            }
            _ = try accumulator.makeAW51CandidateReceipt(
                sessionIdentifier: "gap",
                traceArtifactSHA256: digest
            )
        }
        try expect(.externalPowerConnected) {
            var accumulator = Lane3CandidatePhysicalResourceTraceAccumulator()
            for index in 0...120 {
                try accumulator.append(makeSample(index: index, interval: 15, powered: index == 60))
            }
            _ = try accumulator.makeAW51CandidateReceipt(
                sessionIdentifier: "power",
                traceArtifactSHA256: digest
            )
        }
        try expect(.invalidArtifactDigest) {
            _ = try stable.makeAW51CandidateReceipt(
                sessionIdentifier: "aw52-selftest",
                traceArtifactSHA256: "NOT-A-DIGEST"
            )
        }

        var changed = stable
        try changed.append(makeSample(index: 121, interval: 15))
        let artifactChanged = try changed.canonicalArtifactData(sessionIdentifier: "aw52-selftest")
        precondition(artifactChanged != artifactA)

        print("L3_AW52_CandidatePhysicalResourceTraceSelfTest PASS samples=\(receipt.sampleCount) duration=\(receipt.observedDurationSeconds) peakRSS=\(receipt.peakRSSBytes)")
    }

    static func makeSample(
        index: Int,
        interval: Double = 15,
        uptime: Double? = nil,
        powered: Bool = false
    ) -> Lane3CandidatePhysicalResourceSample {
        let thermal = Lane3CandidatePhysicalThermalState.allCases[index % 4]
        return .init(
            uptimeSeconds: uptime ?? Double(index) * interval,
            residentSetBytes: 200_000_000 + UInt64(index * 4096),
            thermalState: thermal,
            batteryLevel: 0.90 - Double(index) * 0.001,
            externalPowerConnected: powered
        )
    }

    static func expect(
        _ expected: Lane3CandidatePhysicalResourceTraceError,
        _ body: () throws -> Void
    ) throws {
        do {
            try body()
            preconditionFailure("expected \(expected)")
        } catch let error as Lane3CandidatePhysicalResourceTraceError {
            precondition(error == expected, "expected \(expected), got \(error)")
        }
    }

    static func expectNonMonotonic(_ body: () throws -> Void) throws {
        do {
            try body()
            preconditionFailure("expected nonMonotonicUptime")
        } catch Lane3CandidatePhysicalResourceTraceError.nonMonotonicUptime {
            return
        }
    }

    static func expectInsufficientDuration(_ body: () throws -> Void) throws {
        do {
            try body()
            preconditionFailure("expected insufficientDuration")
        } catch Lane3CandidatePhysicalResourceTraceError.insufficientDuration {
            return
        }
    }

    static func expectSamplingGap(_ body: () throws -> Void) throws {
        do {
            try body()
            preconditionFailure("expected samplingGapExceeded")
        } catch Lane3CandidatePhysicalResourceTraceError.samplingGapExceeded {
            return
        }
    }
}
