import Foundation

@main
struct L3AW44CodecLongTrackEvidenceBindingStressMain {
    static func main() throws {
        let descriptor = try Lane3RepresentativeCodecFixtureDescriptor(
            fixtureID: "aw44-stress-corrupted",
            declaredCodecLabel: "aac-lc",
            faultExpectation: .corrupted,
            expectedChannels: 2,
            expectedSampleRate: 44_100,
            baselineFrameCount: 79_380_000,
            rightsCleared: true
        )
        let report = Lane3RepresentativeCodecExecutionProbe.openRejected(
            descriptor: descriptor,
            environment: .portableStructural,
            failureCode: .openRejected
        )
        let iterations = 100_000
        var checksum: UInt64 = 0
        for index in 0..<iterations {
            let digest = Lane3CodecLongTrackEvidenceBinder.reportBindingSHA256(report)
            guard digest.count == 64, let prefix = UInt64(digest.prefix(16), radix: 16) else {
                preconditionFailure("invalid SHA-256 digest")
            }
            checksum &+= prefix ^ UInt64(index)
        }
        print("L3-AW44 content binding stress PASS iterations=\(iterations) checksum=\(checksum)")
    }
}
