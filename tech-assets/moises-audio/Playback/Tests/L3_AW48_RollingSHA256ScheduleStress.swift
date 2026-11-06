import Foundation

private struct Lane3AW48StressSource: Lane3PCMChunkReadable, Sendable {
    let channels: Int
    let sampleRate: Double
    let frameCount: Int64
    let samples: [Float]

    static func make(caseIndex: Int) -> Self {
        let channels = 1 + (caseIndex % 4)
        let rates = [8_000.0, 44_100.0, 48_000.0, 96_000.0]
        let sampleRate = rates[caseIndex % rates.count]
        let frameCount = Int64(17 + caseIndex * 13)
        let totalSamples = Int(frameCount) * channels
        var seed = UInt64(0x9e3779b97f4a7c15) ^ (UInt64(caseIndex) &* 0x100000001b3)
        var samples: [Float] = []
        samples.reserveCapacity(totalSamples)
        for _ in 0..<totalSamples {
            seed ^= seed << 13
            seed ^= seed >> 7
            seed ^= seed << 17
            samples.append(Float(bitPattern: UInt32(truncatingIfNeeded: seed)))
        }
        return Self(
            channels: channels,
            sampleRate: sampleRate,
            frameCount: frameCount,
            samples: samples
        )
    }

    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        let start = Int(startFrame) * channels
        let count = frameCount * channels
        return Array(samples[start..<(start + count)])
    }
}

private func lane3AW48FNV1A(_ value: String, seed: UInt64) -> UInt64 {
    var hash = seed
    for byte in value.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x100000001b3
    }
    return hash
}

@main
struct L3AW48RollingSHA256ScheduleStressMain {
    static func main() throws {
        let chunkFrames = [1, 3, 7, 64, 257]
        let expectedAggregate: UInt64 = 18_370_574_486_077_463_754
        var aggregate: UInt64 = 0xcbf29ce484222325
        var cells = 0

        for caseIndex in 0..<40 {
            let source = Lane3AW48StressSource.make(caseIndex: caseIndex)
            var canonical: String?
            for chunk in chunkFrames {
                let digest = try Lane3LongTrackPCMIdentityHasher.digestWithChunkVisitor(
                    source,
                    chunkFrames: chunk
                ) { _, _, _ in }
                if let canonical {
                    precondition(digest == canonical, "chunk-boundary digest drift case=\(caseIndex) chunk=\(chunk)")
                } else {
                    canonical = digest
                }
                aggregate = lane3AW48FNV1A(digest, seed: aggregate)
                cells += 1
            }
        }

        precondition(cells == 200)
        precondition(
            aggregate == expectedAggregate,
            "independent Python aggregate mismatch expected=\(expectedAggregate) actual=\(aggregate)"
        )
        print("L3-AW48 rolling SHA schedule stress PASS cells=\(cells) aggregate=\(aggregate)")
    }
}
