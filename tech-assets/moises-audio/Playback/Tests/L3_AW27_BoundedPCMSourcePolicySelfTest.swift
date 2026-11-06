import Foundation

@main
struct L3AW27BoundedPCMSourcePolicySelfTest {
    static func main() throws {
        let policy = try Lane3PCMChunkReadPolicy(maximumFramesPerRead: 65_536)
        let sampleCount = try policy.expectedInterleavedSampleCount(
            startFrame: 12_345,
            frameCount: 40_962,
            totalFrames: 86_400_000,
            channels: 2
        )
        precondition(sampleCount == 81_924)

        do {
            _ = try policy.expectedInterleavedSampleCount(
                startFrame: 0,
                frameCount: 65_537,
                totalFrames: 86_400_000,
                channels: 2
            )
            fatalError("oversized read must fail closed")
        } catch Lane3PCMChunkReadPolicyError.readExceedsLimit(let requested, let maximum) {
            precondition(requested == 65_537)
            precondition(maximum == 65_536)
        }

        do {
            _ = try policy.expectedInterleavedSampleCount(
                startFrame: 86_399_999,
                frameCount: 2,
                totalFrames: 86_400_000,
                channels: 2
            )
            fatalError("out-of-range read must fail closed")
        } catch Lane3PCMChunkReadPolicyError.invalidReadRange { }

        do {
            _ = try policy.expectedInterleavedSampleCount(
                startFrame: Int64.max,
                frameCount: 1,
                totalFrames: Int64.max,
                channels: 2
            )
            fatalError("overflowing range must fail closed")
        } catch Lane3PCMChunkReadPolicyError.invalidReadRange { }

        var audit = Lane3PCMChunkReadAudit()
        audit.recordSuccessfulRead(startFrame: 0, frameCount: 16_384)
        audit.recordSuccessfulRead(startFrame: 16_384, frameCount: 16_384)
        audit.recordSuccessfulRead(startFrame: 8_192, frameCount: 2_048)
        audit.recordSuccessfulRead(startFrame: 50_000, frameCount: 1_024)
        audit.recordSuccessfulRead(startFrame: 51_024, frameCount: 0)
        let snapshot = audit.snapshot()
        precondition(snapshot.schemaVersion == 1)
        precondition(snapshot.evidenceScope == "LANE3_BOUNDED_PCM_READ_AUDIT_NON_PARITY")
        precondition(snapshot.successfulReadCalls == 4)
        precondition(snapshot.zeroLengthReadCalls == 1)
        precondition(snapshot.totalFramesReturned == 35_840)
        precondition(snapshot.maximumRequestedFrames == 16_384)
        precondition(snapshot.initialReads == 1)
        precondition(snapshot.sequentialReads == 1)
        precondition(snapshot.backwardSeeks == 1)
        precondition(snapshot.forwardGapSeeks == 1)
        precondition(!snapshot.counterOverflowed)
        precondition(!snapshot.sourcePathIncluded)
        precondition(!snapshot.parityPromotionAllowed)

        print(
            "L3-AW27 bounded PCM policy PASS reads=\(snapshot.successfulReadCalls) max=\(snapshot.maximumRequestedFrames)"
        )
    }
}
