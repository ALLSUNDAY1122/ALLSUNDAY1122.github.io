import Foundation

private struct Lane3AW47BitPatternSource: Lane3PCMChunkReadable, Sendable {
    let channels = 2
    let sampleRate = 48_000.0
    let frameCount: Int64 = 8

    private let bitPatterns: [UInt32] = [
        0x00000000, 0x80000000, 0x3f800000, 0xbf800000,
        0x00000001, 0x007fffff, 0x00800000, 0x7f7fffff,
        0x7f800000, 0xff800000, 0x7fc00000, 0x7fc01234,
        0x3eaaaaab, 0xbeaaaaab, 0x41200000, 0xc1200000
    ]

    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        let start = Int(startFrame) * channels
        let count = frameCount * channels
        return bitPatterns[start..<(start + count)].map { Float(bitPattern: $0) }
    }
}

@main
struct L3AW47StreamingPCMIdentitySelfTestMain {
    static func main() throws {
        let source = Lane3AW47BitPatternSource()
        let expected = "a44c84af8d97712aa378026410127ed758b73d0024b0aa8d053f3156291745cb"

        for chunkFrames in [1, 3, 8] {
            let digest = try Lane3LongTrackPCMIdentityHasher.digestWithChunkVisitor(
                source,
                chunkFrames: chunkFrames
            ) { _, _, _ in }
            precondition(digest == expected, "raw Float32 LE digest changed at chunkFrames=\(chunkFrames)")
        }

        let receipt = try Lane3LongTrackPCMIdentityHasher.makeReceipt(
            reference: source,
            observed: source,
            chunkFrames: 3
        )
        precondition(receipt.algorithm == "SHA256_FLOAT32_LE_V1")
        precondition(receipt.referenceDigestSHA256 == expected)
        precondition(receipt.observedDigestSHA256 == expected)
        precondition(receipt.channels == 2)
        precondition(receipt.sampleRate.bitPattern == 48_000.0.bitPattern)
        precondition(receipt.referenceFrameCount == 8)
        precondition(receipt.observedFrameCount == 8)

        print("L3-AW47 raw-byte compatibility PASS digest=\(expected.prefix(16)) specialBitPatterns=16")
    }
}
