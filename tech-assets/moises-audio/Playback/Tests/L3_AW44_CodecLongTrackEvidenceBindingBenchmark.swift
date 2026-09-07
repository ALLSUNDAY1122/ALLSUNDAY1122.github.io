import Foundation

@main
struct L3AW44CodecLongTrackEvidenceBindingBenchmarkMain {
    static func main() throws {
        let descriptor = try Lane3RepresentativeCodecFixtureDescriptor(
            fixtureID: "aw44-benchmark-truncated",
            declaredCodecLabel: "aac-lc",
            faultExpectation: .truncated,
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
        let runs = 20
        let operationsPerRun = 10_000
        var durations: [UInt64] = []
        var checksum: UInt64 = 0
        durations.reserveCapacity(runs)
        for _ in 0..<runs {
            let start = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<operationsPerRun {
                let digest = Lane3CodecLongTrackEvidenceBinder.reportBindingSHA256(report)
                guard let prefix = UInt64(digest.prefix(16), radix: 16) else {
                    preconditionFailure("invalid SHA-256 digest")
                }
                checksum &+= prefix
            }
            durations.append(DispatchTime.now().uptimeNanoseconds - start)
        }
        durations.sort()
        let median = durations[durations.count / 2]
        let p95 = durations[Int(Double(durations.count - 1) * 0.95)]
        print("L3-AW44 content binding benchmark PASS runs=\(runs) operations=\(operationsPerRun) median_ns=\(median) p95_ns=\(p95) max_ns=\(durations.last!) checksum=\(checksum)")
    }
}
