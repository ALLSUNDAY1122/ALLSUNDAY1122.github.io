import Foundation

private final class Lane3AW50BenchmarkSource: Lane3PCMChunkReadable, @unchecked Sendable {
    private let lock = NSLock()
    private var channelGets = 0
    private var sampleRateGets = 0
    private var frameCountGets = 0
    private var pcmReads = 0

    var channels: Int {
        lock.lock()
        defer { lock.unlock() }
        channelGets += 1
        return 2
    }

    var sampleRate: Double {
        lock.lock()
        defer { lock.unlock() }
        sampleRateGets += 1
        return 48_000.0
    }

    var frameCount: Int64 {
        lock.lock()
        defer { lock.unlock() }
        frameCountGets += 1
        return 1_024
    }

    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        lock.lock()
        pcmReads += 1
        lock.unlock()
        return [Float](repeating: 0.25, count: frameCount * 2)
    }

    func counters() -> (channels: Int, sampleRate: Int, frameCount: Int, pcmReads: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (channelGets, sampleRateGets, frameCountGets, pcmReads)
    }
}

@main
struct L3AW50RepresentativeCodecMetadataStabilityBenchmarkMain {
    static func main() throws {
        let iterations = 2_000
        let source = Lane3AW50BenchmarkSource()
        let descriptor = try Lane3RepresentativeCodecFixtureDescriptor(
            fixtureID: "aw50-benchmark",
            declaredCodecLabel: "pcm-test",
            faultExpectation: .clean,
            expectedChannels: 2,
            expectedSampleRate: 48_000,
            baselineFrameCount: 1_024,
            rightsCleared: true
        )

        let start = Date().timeIntervalSinceReferenceDate
        for _ in 0..<iterations {
            let report = try Lane3RepresentativeCodecExecutionProbe.sweep(
                source: source,
                descriptor: descriptor,
                environment: .portableStructural,
                chunkFrames: 256
            )
            precondition(report.failureCode == nil)
            precondition(report.completeSequentialSweep)
            precondition(report.readCalls == 4)
        }
        let elapsed = Date().timeIntervalSinceReferenceDate - start
        let counts = source.counters()

        // Two preflight snapshots + pre/post each of four reads + one final check = 11 getter reads
        // per metadata field per sweep. PCM read count remains exactly four per sweep.
        precondition(counts.channels == iterations * 11)
        precondition(counts.sampleRate == iterations * 11)
        precondition(counts.frameCount == iterations * 11)
        precondition(counts.pcmReads == iterations * 4)

        print(
            "L3-AW50 metadata fence benchmark PASS iterations=\(iterations) "
                + "elapsedSeconds=\(elapsed) metadataGetsPerField=\(counts.channels) pcmReads=\(counts.pcmReads)"
        )
    }
}
