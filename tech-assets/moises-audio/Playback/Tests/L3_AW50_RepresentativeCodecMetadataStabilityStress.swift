import Foundation

private enum Lane3AW50StressMutation: Equatable, Sendable {
    case channels
    case sampleRate
    case frameCount
}

private final class Lane3AW50StressSource: Lane3PCMChunkReadable, @unchecked Sendable {
    private let lock = NSLock()
    private var mutated = false
    private var reads = 0
    private let mutation: Lane3AW50StressMutation?
    private let mutationRead: Int

    init(mutation: Lane3AW50StressMutation?, mutationRead: Int = .max) {
        self.mutation = mutation
        self.mutationRead = mutationRead
    }

    var channels: Int {
        lock.lock()
        defer { lock.unlock() }
        return mutated && mutation == .channels ? 4 : 2
    }

    var sampleRate: Double {
        lock.lock()
        defer { lock.unlock() }
        return mutated && mutation == .sampleRate ? 47_999.0 : 48_000.0
    }

    var frameCount: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return mutated && mutation == .frameCount ? 3_085 : 3_084
    }

    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        lock.lock()
        reads += 1
        let shouldMutate = reads == mutationRead
        lock.unlock()

        let output = [Float](repeating: 0.25, count: frameCount * 2)
        if shouldMutate {
            lock.lock()
            mutated = true
            lock.unlock()
        }
        return output
    }
}

@main
struct L3AW50RepresentativeCodecMetadataStabilityStressMain {
    static func main() throws {
        let descriptor = try Lane3RepresentativeCodecFixtureDescriptor(
            fixtureID: "aw50-stress",
            declaredCodecLabel: "pcm-test",
            faultExpectation: .clean,
            expectedChannels: 2,
            expectedSampleRate: 48_000,
            baselineFrameCount: 3_084,
            rightsCleared: true
        )

        var mutationCells = 0
        var stableCells = 0
        for _ in 0..<20 {
            let stable = try Lane3RepresentativeCodecExecutionProbe.sweep(
                source: Lane3AW50StressSource(mutation: nil),
                descriptor: descriptor,
                environment: .portableStructural,
                chunkFrames: 257
            )
            precondition(stable.failureCode == nil)
            precondition(stable.completeSequentialSweep)
            precondition(stable.rollingPCMChecksumFNV1A64 == 8_284_563_594_282_402_565)
            stableCells += 1

            for mutation in [Lane3AW50StressMutation.channels, .sampleRate, .frameCount] {
                for mutationRead in 1...12 {
                    let report = try Lane3RepresentativeCodecExecutionProbe.sweep(
                        source: Lane3AW50StressSource(
                            mutation: mutation,
                            mutationRead: mutationRead
                        ),
                        descriptor: descriptor,
                        environment: .portableStructural,
                        chunkFrames: 257
                    )
                    precondition(report.failureCode == .sourceMetadataChanged)
                    precondition(!report.completeSequentialSweep)
                    precondition(!report.cleanDecodeContractSatisfied)
                    precondition(report.actualChannels == 2)
                    precondition(report.actualSampleRate?.bitPattern == 48_000.0.bitPattern)
                    precondition(report.actualFrameCount == 3_084)
                    precondition(report.readCalls == UInt64(mutationRead - 1))
                    precondition(report.framesRead == UInt64((mutationRead - 1) * 257))
                    mutationCells += 1
                }
            }
        }

        precondition(stableCells == 20)
        precondition(mutationCells == 720)
        print("L3-AW50 metadata stability stress PASS stableCells=20 mutationCells=720 positionsPerField=12")
    }
}
