import Foundation

@main
enum L3AW52CandidatePhysicalResourceTraceBenchmark {
    static func main() throws {
        let iterations = 5_000
        let digest = String(repeating: "ef", count: 32)
        let started = ProcessInfo.processInfo.systemUptime
        var totalArtifactBytes = 0
        var peakReceiptRSS: UInt64 = 0

        for iteration in 0..<iterations {
            var accumulator = Lane3CandidatePhysicalResourceTraceAccumulator()
            for index in 0...120 {
                try accumulator.append(.init(
                    uptimeSeconds: Double(index) * 15,
                    residentSetBytes: 180_000_000 + UInt64((iteration + index) % 2048) * 4096,
                    thermalState: Lane3CandidatePhysicalThermalState.allCases[(iteration + index) % 4],
                    batteryLevel: 0.9 - Double(index) * 0.001,
                    externalPowerConnected: false
                ))
            }
            let artifact = try accumulator.canonicalArtifactData(
                sessionIdentifier: "benchmark-\(iteration)"
            )
            let receipt = try accumulator.makeAW51CandidateReceipt(
                sessionIdentifier: "benchmark-\(iteration)",
                traceArtifactSHA256: digest
            )
            totalArtifactBytes += artifact.count
            peakReceiptRSS = max(peakReceiptRSS, receipt.peakRSSBytes)
        }

        let elapsed = ProcessInfo.processInfo.systemUptime - started
        let tracesPerSecond = Double(iterations) / elapsed
        print("L3_AW52_CandidatePhysicalResourceTraceBenchmark iterations=\(iterations) elapsed=\(elapsed) tracesPerSecond=\(tracesPerSecond) totalArtifactBytes=\(totalArtifactBytes) peakReceiptRSS=\(peakReceiptRSS)")
    }
}
