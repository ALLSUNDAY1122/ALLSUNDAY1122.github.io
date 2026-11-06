import Foundation

private final class Lane3AW46StressMutatingSource: Lane3PCMChunkReadable, @unchecked Sendable {
    enum Mutation: CaseIterable {
        case channels
        case sampleRate
        case frameCount
    }

    private let mutation: Mutation
    private let mutateAfterRead: Int
    private var reads = 0
    private let baseChannels = 2
    private let baseSampleRate = 100.0
    private let baseFrameCount: Int64 = 180_000

    init(mutation: Mutation, mutateAfterRead: Int) {
        self.mutation = mutation
        self.mutateAfterRead = mutateAfterRead
    }

    var channels: Int {
        mutation == .channels && reads >= mutateAfterRead ? 1 : baseChannels
    }

    var sampleRate: Double {
        mutation == .sampleRate && reads >= mutateAfterRead ? 100.5 : baseSampleRate
    }

    var frameCount: Int64 {
        mutation == .frameCount && reads >= mutateAfterRead ? baseFrameCount - 1 : baseFrameCount
    }

    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        let samples = [Float](repeating: 0.25, count: frameCount * baseChannels)
        reads += 1
        return samples
    }
}

@main
struct L3AW46PCMIdentityMetadataStabilityStressMain {
    static func main() throws {
        let chunkFrames = 4_096
        let expectedReadCalls = Int((180_000 + Int64(chunkFrames) - 1) / Int64(chunkFrames))
        var rejected = 0

        for mutation in Lane3AW46StressMutatingSource.Mutation.allCases {
            for mutationRead in 1...expectedReadCalls {
                let source = Lane3AW46StressMutatingSource(
                    mutation: mutation,
                    mutateAfterRead: mutationRead
                )
                do {
                    _ = try Lane3LongTrackPCMIdentityHasher.digestWithChunkVisitor(
                        source,
                        chunkFrames: chunkFrames
                    ) { _, _, _ in }
                    preconditionFailure("metadata mutation escaped fence mutation=\(mutation) read=\(mutationRead)")
                } catch Lane3PCMIdentityStabilityError.sourceMetadataChanged {
                    rejected += 1
                }
            }
        }

        let expected = Lane3AW46StressMutatingSource.Mutation.allCases.count * expectedReadCalls
        precondition(rejected == expected)
        print("L3-AW46 metadata stability stress PASS rejected=\(rejected) expected=\(expected)")
    }
}
