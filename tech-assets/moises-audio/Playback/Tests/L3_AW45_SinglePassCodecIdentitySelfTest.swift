import Foundation

private final class Lane3AW45ReadCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }

    func reset() {
        lock.lock()
        value = 0
        lock.unlock()
    }

    func snapshot() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

private struct Lane3AW45SyntheticPCMSource: Lane3PCMChunkReadable, Sendable {
    let channels: Int
    let sampleRate: Double
    let frameCount: Int64
    let counter: Lane3AW45ReadCounter
    let shortReadAtFrame: Int64?

    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        counter.increment()
        let actualFrames = startFrame == shortReadAtFrame ? max(0, frameCount - 1) : frameCount
        var output = [Float](repeating: 0, count: actualFrames * channels)
        for frame in 0..<actualFrames {
            let absolute = startFrame + Int64(frame)
            for channel in 0..<channels {
                output[frame * channels + channel] = Float((absolute * 17 + Int64(channel) * 31) % 997) / 997
            }
        }
        return output
    }
}

@main
struct L3AW45SinglePassCodecIdentitySelfTestMain {
    static func main() throws {
        let counter = Lane3AW45ReadCounter()
        let source = Lane3AW45SyntheticPCMSource(
            channels: 2,
            sampleRate: 100,
            frameCount: 180_000,
            counter: counter,
            shortReadAtFrame: nil
        )
        let descriptor = try Lane3RepresentativeCodecFixtureDescriptor(
            fixtureID: "aw45-aac-clean",
            declaredCodecLabel: "aac-lc",
            faultExpectation: .clean,
            expectedChannels: 2,
            expectedSampleRate: 100,
            baselineFrameCount: 180_000,
            rightsCleared: true
        )

        counter.reset()
        let legacyReport = try Lane3RepresentativeCodecExecutionProbe.sweep(
            source: source,
            descriptor: descriptor,
            environment: .portableStructural,
            chunkFrames: 4_096
        )
        let identity = try Lane3LongTrackPCMIdentityHasher.makeReceipt(
            reference: source,
            observed: source,
            chunkFrames: 4_096
        )
        let legacyEquivalentReads = counter.snapshot()
        precondition(legacyEquivalentReads == Int(legacyReport.readCalls) * 3)

        counter.reset()
        var readCalls: UInt64 = 0
        var framesRead: UInt64 = 0
        var nonFinite: UInt64 = 0
        var fnv: UInt64 = 0xcbf29ce484222325
        let singlePassDigest = try Lane3LongTrackPCMIdentityHasher.digestWithChunkVisitor(
            source,
            chunkFrames: legacyReport.maximumChunkFrames
        ) { _, count, samples in
            readCalls += 1
            framesRead += UInt64(count)
            for sample in samples {
                if !sample.isFinite { nonFinite += 1 }
                fnv ^= UInt64(sample.bitPattern)
                fnv = fnv &* 0x100000001b3
            }
        }
        let singlePassReads = counter.snapshot()

        precondition(singlePassReads == Int(legacyReport.readCalls))
        precondition(singlePassReads * 3 == legacyEquivalentReads)
        precondition(singlePassDigest == identity.referenceDigestSHA256)
        precondition(singlePassDigest == identity.observedDigestSHA256)
        precondition(readCalls == legacyReport.readCalls)
        precondition(framesRead == legacyReport.framesRead)
        precondition(nonFinite == legacyReport.nonFiniteSampleCount)
        precondition(fnv == legacyReport.rollingPCMChecksumFNV1A64)

        counter.reset()
        let alternateChunkDigest = try Lane3LongTrackPCMIdentityHasher.digestWithChunkVisitor(
            source,
            chunkFrames: 1_000
        ) { _, _, _ in }
        precondition(alternateChunkDigest == singlePassDigest)

        let shortCounter = Lane3AW45ReadCounter()
        let shortSource = Lane3AW45SyntheticPCMSource(
            channels: 2,
            sampleRate: 100,
            frameCount: 180_000,
            counter: shortCounter,
            shortReadAtFrame: 4_096
        )
        do {
            _ = try Lane3LongTrackPCMIdentityHasher.digestWithChunkVisitor(
                shortSource,
                chunkFrames: 4_096
            ) { _, _, _ in }
            preconditionFailure("short read was accepted")
        } catch Lane3LongTrackEvidenceError.shortRead {}

        do {
            _ = try Lane3LongTrackPCMIdentityHasher.digestWithChunkVisitor(
                source,
                chunkFrames: 0
            ) { _, _, _ in }
            preconditionFailure("zero chunk size was accepted")
        } catch Lane3LongTrackEvidenceError.invalidChunkFrames(0) {}

        print(
            "L3-AW45 single-pass PASS digest=\(singlePassDigest.prefix(16)) " +
            "legacyReads=\(legacyEquivalentReads) singlePassReads=\(singlePassReads) " +
            "reduction=\(legacyEquivalentReads / singlePassReads)x"
        )
    }
}