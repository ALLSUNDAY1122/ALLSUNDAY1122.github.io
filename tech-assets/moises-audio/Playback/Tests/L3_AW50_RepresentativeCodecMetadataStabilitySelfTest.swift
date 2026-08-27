import Foundation

private enum Lane3AW50MetadataMutation: Sendable {
    case channels
    case sampleRate
    case frameCount
}

private final class Lane3AW50MutableCodecSource: Lane3PCMChunkReadable, @unchecked Sendable {
    private let lock = NSLock()
    private var mutated = false
    private var readCount = 0
    private let mutation: Lane3AW50MetadataMutation?
    private let mutationRead: Int

    init(mutation: Lane3AW50MetadataMutation? = nil, mutationRead: Int = .max) {
        self.mutation = mutation
        self.mutationRead = mutationRead
    }

    var channels: Int {
        lock.lock()
        defer { lock.unlock() }
        return mutated && mutation == .channels ? 1 : 2
    }

    var sampleRate: Double {
        lock.lock()
        defer { lock.unlock() }
        return mutated && mutation == .sampleRate ? 48_001.0 : 48_000.0
    }

    var frameCount: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return mutated && mutation == .frameCount ? 3_083 : 3_084
    }

    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        lock.lock()
        readCount += 1
        let shouldMutate = readCount == mutationRead
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

private final class Lane3AW50PreflightFlappingSource: Lane3PCMChunkReadable, @unchecked Sendable {
    private let lock = NSLock()
    private var channelReads = 0

    var channels: Int {
        lock.lock()
        defer { lock.unlock() }
        channelReads += 1
        return channelReads >= 2 ? 1 : 2
    }

    var sampleRate: Double { 48_000.0 }
    var frameCount: Int64 { 3_084 }

    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        preconditionFailure("preflight metadata instability must be rejected before PCM read")
    }
}

@main
struct L3AW50RepresentativeCodecMetadataStabilitySelfTestMain {
    static func main() throws {
        let descriptor = try Lane3RepresentativeCodecFixtureDescriptor(
            fixtureID: "aw50-clean",
            declaredCodecLabel: "pcm-test",
            faultExpectation: .clean,
            expectedChannels: 2,
            expectedSampleRate: 48_000,
            baselineFrameCount: 3_084,
            rightsCleared: true
        )

        let stable = try Lane3RepresentativeCodecExecutionProbe.sweep(
            source: Lane3AW50MutableCodecSource(),
            descriptor: descriptor,
            environment: .portableStructural,
            chunkFrames: 257
        )
        precondition(stable.failureCode == nil)
        precondition(stable.completeSequentialSweep)
        precondition(stable.cleanDecodeContractSatisfied)
        precondition(stable.readCalls == 12)
        precondition(stable.framesRead == 3_084)
        precondition(stable.actualChannels == 2)
        precondition(stable.actualSampleRate?.bitPattern == 48_000.0.bitPattern)
        precondition(stable.actualFrameCount == 3_084)
        precondition(stable.rollingPCMChecksumFNV1A64 == 8_284_563_594_282_402_565)

        let mutated = try Lane3RepresentativeCodecExecutionProbe.sweep(
            source: Lane3AW50MutableCodecSource(mutation: .channels, mutationRead: 4),
            descriptor: descriptor,
            environment: .portableStructural,
            chunkFrames: 257
        )
        precondition(mutated.failureCode == .sourceMetadataChanged)
        precondition(!mutated.completeSequentialSweep)
        precondition(!mutated.cleanDecodeContractSatisfied)
        precondition(mutated.actualChannels == 2)
        precondition(mutated.actualSampleRate?.bitPattern == 48_000.0.bitPattern)
        precondition(mutated.actualFrameCount == 3_084)

        let flapping = try Lane3RepresentativeCodecExecutionProbe.sweep(
            source: Lane3AW50PreflightFlappingSource(),
            descriptor: descriptor,
            environment: .portableStructural,
            chunkFrames: 257
        )
        precondition(flapping.failureCode == .sourceMetadataChanged)
        precondition(flapping.readCalls == 0)
        precondition(!flapping.completeSequentialSweep)

        print("L3-AW50 representative codec metadata stability self-test PASS stableFNV=8284563594282402565")
    }
}
