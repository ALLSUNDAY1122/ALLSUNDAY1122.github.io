import Foundation

private struct Lane3AW46StablePCMSource: Lane3PCMChunkReadable, Sendable {
    let channels: Int
    let sampleRate: Double
    let frameCount: Int64

    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        var output = [Float](repeating: 0, count: frameCount * channels)
        for frame in 0..<frameCount {
            let absolute = startFrame + Int64(frame)
            for channel in 0..<channels {
                output[frame * channels + channel] = Float((absolute * 17 + Int64(channel) * 31) % 997) / 997
            }
        }
        return output
    }
}

private final class Lane3AW46MutatingPCMSource: Lane3PCMChunkReadable, @unchecked Sendable {
    enum Mutation {
        case channels
        case sampleRate
        case frameCount
    }

    private let mutation: Mutation
    private let mutateAfterRead: Int
    private var reads: Int = 0
    private let baseChannels = 2
    private let baseSampleRate = 100.0
    private let baseFrameCount: Int64 = 180_000

    init(mutation: Mutation, mutateAfterRead: Int = 1) {
        self.mutation = mutation
        self.mutateAfterRead = mutateAfterRead
    }

    var channels: Int {
        mutation == .channels && reads >= mutateAfterRead ? 1 : baseChannels
    }

    var sampleRate: Double {
        mutation == .sampleRate && reads >= mutateAfterRead ? 101 : baseSampleRate
    }

    var frameCount: Int64 {
        mutation == .frameCount && reads >= mutateAfterRead ? baseFrameCount - 1 : baseFrameCount
    }

    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        var output = [Float](repeating: 0, count: frameCount * baseChannels)
        for frame in 0..<frameCount {
            let absolute = startFrame + Int64(frame)
            for channel in 0..<baseChannels {
                output[frame * baseChannels + channel] = Float((absolute * 17 + Int64(channel) * 31) % 997) / 997
            }
        }
        reads += 1
        return output
    }
}

private enum Lane3AW46SelfTest {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }

    static func requireMetadataMutationRejected(
        _ mutation: Lane3AW46MutatingPCMSource.Mutation
    ) throws {
        let source = Lane3AW46MutatingPCMSource(mutation: mutation)
        do {
            _ = try Lane3LongTrackPCMIdentityHasher.digestWithChunkVisitor(
                source,
                chunkFrames: 4_096
            ) { _, _, _ in }
            preconditionFailure("dynamic metadata was accepted: \(mutation)")
        } catch Lane3PCMIdentityStabilityError.sourceMetadataChanged {
            return
        }
    }
}

@main
struct L3AW46PCMIdentityMetadataStabilitySelfTestMain {
    static func main() throws {
        let stable = Lane3AW46StablePCMSource(
            channels: 2,
            sampleRate: 100,
            frameCount: 180_000
        )
        let digest = try Lane3LongTrackPCMIdentityHasher.digestWithChunkVisitor(
            stable,
            chunkFrames: 4_096
        ) { _, _, _ in }
        Lane3AW46SelfTest.require(
            digest == "fed6505b0fcb3b01a65fccc8e3b913772cb50e90e2835f9a0e51e74f6719bab2",
            "AW45 stable digest changed"
        )

        try Lane3AW46SelfTest.requireMetadataMutationRejected(.channels)
        try Lane3AW46SelfTest.requireMetadataMutationRejected(.sampleRate)
        try Lane3AW46SelfTest.requireMetadataMutationRejected(.frameCount)

        let mutatingReceiptSource = Lane3AW46MutatingPCMSource(mutation: .sampleRate)
        do {
            _ = try Lane3LongTrackPCMIdentityHasher.makeReceipt(
                reference: mutatingReceiptSource,
                observed: mutatingReceiptSource,
                chunkFrames: 4_096
            )
            preconditionFailure("makeReceipt accepted source metadata mutation")
        } catch Lane3PCMIdentityStabilityError.sourceMetadataChanged {}

        print("L3-AW46 metadata stability PASS digest=\(digest.prefix(16)) mutations=3 receiptFence=PASS")
    }
}
