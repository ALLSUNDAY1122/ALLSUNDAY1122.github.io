import Foundation

private struct Lane3AW46FingerprintStableSource: Lane3PCMChunkReadable, Sendable {
    let channels = 2
    let sampleRate = 100.0
    let frameCount: Int64 = 180_000

    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        var output = [Float](repeating: 0, count: frameCount * channels)
        for frame in 0..<frameCount {
            let absolute = startFrame + Int64(frame)
            output[frame * channels] = Float((absolute * 17) % 997) / 997
            output[frame * channels + 1] = Float((absolute * 17 + 31) % 997) / 997
        }
        return output
    }
}

private final class Lane3AW46FingerprintMutatingSource: Lane3PCMChunkReadable, @unchecked Sendable {
    private var reads = 0
    var channels: Int { 2 }
    var sampleRate: Double { reads > 0 ? 100.25 : 100 }
    var frameCount: Int64 { 180_000 }

    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        reads += 1
        return [Float](repeating: 0.25, count: frameCount * 2)
    }
}

@main
struct L3AW46FrozenFingerprintBridgeSelfTestMain {
    static func main() throws {
        let stable = Lane3AW46FingerprintStableSource()
        let fingerprint = try Lane3LongTrackPCMIdentityHasher.fingerprintWithChunkVisitor(
            stable,
            chunkFrames: 4_096
        ) { _, _, _ in }
        precondition(fingerprint.algorithm == "SHA256_FLOAT32_LE_V1")
        precondition(fingerprint.channels == 2)
        precondition(fingerprint.sampleRate.bitPattern == 100.0.bitPattern)
        precondition(fingerprint.frameCount == 180_000)
        precondition(
            fingerprint.digestSHA256 == "fed6505b0fcb3b01a65fccc8e3b913772cb50e90e2835f9a0e51e74f6719bab2"
        )

        do {
            _ = try Lane3LongTrackPCMIdentityHasher.fingerprintWithChunkVisitor(
                Lane3AW46FingerprintMutatingSource(),
                chunkFrames: 4_096
            ) { _, _, _ in }
            preconditionFailure("fingerprint bridge accepted post-read metadata mutation")
        } catch Lane3PCMIdentityStabilityError.sourceMetadataChanged {}

        print("L3-AW46 frozen fingerprint PASS digest=\(fingerprint.digestSHA256.prefix(16)) mutation=REJECTED")
    }
}
