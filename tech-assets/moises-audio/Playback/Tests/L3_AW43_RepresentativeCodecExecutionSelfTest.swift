import Foundation

enum AW43InjectedError: Error { case damaged }

@main
struct L3AW43RepresentativeCodecExecutionSelfTest {
    static func main() throws {
        let sampleRate = 10.0
        let baselineFrames: Int64 = 18_000 // 30 min at synthetic 10 Hz
        let cleanDescriptor = try Lane3RepresentativeCodecFixtureDescriptor(
            fixtureID: "aw43-aac-clean",
            declaredCodecLabel: "aac-m4a",
            faultExpectation: .clean,
            expectedChannels: 2,
            expectedSampleRate: sampleRate,
            baselineFrameCount: baselineFrames,
            rightsCleared: true
        )
        let truncatedDescriptor = try Lane3RepresentativeCodecFixtureDescriptor(
            fixtureID: "aw43-aac-truncated",
            declaredCodecLabel: "aac-m4a",
            faultExpectation: .truncated,
            expectedChannels: 2,
            expectedSampleRate: sampleRate,
            baselineFrameCount: baselineFrames,
            rightsCleared: true
        )
        let corruptDescriptor = try Lane3RepresentativeCodecFixtureDescriptor(
            fixtureID: "aw43-aac-corrupted",
            declaredCodecLabel: "aac-m4a",
            faultExpectation: .corrupted,
            expectedChannels: 2,
            expectedSampleRate: sampleRate,
            baselineFrameCount: baselineFrames,
            rightsCleared: true
        )

        let clean = Lane3ClosurePCMChunkSource(channels: 2, sampleRate: sampleRate, frameCount: baselineFrames) { _, count in
            [Float](repeating: 0.25, count: count * 2)
        }
        let cleanReport = try Lane3RepresentativeCodecExecutionProbe.sweep(
            source: clean,
            descriptor: cleanDescriptor,
            environment: .portableStructural,
            chunkFrames: 1024
        )
        precondition(cleanReport.cleanDecodeContractSatisfied)
        precondition(cleanReport.completeSequentialSweep)
        precondition(cleanReport.framesRead == UInt64(baselineFrames))
        precondition(!cleanReport.authoritativePhysicalEvidenceAllowed)

        let truncatedFrames = baselineFrames / 2
        let truncated = Lane3ClosurePCMChunkSource(channels: 2, sampleRate: sampleRate, frameCount: truncatedFrames) { _, count in
            [Float](repeating: -0.125, count: count * 2)
        }
        let truncatedReport = try Lane3RepresentativeCodecExecutionProbe.sweep(
            source: truncated,
            descriptor: truncatedDescriptor,
            environment: .portableStructural,
            chunkFrames: 777
        )
        precondition(truncatedReport.metadataTruncationObserved)
        precondition(truncatedReport.expectedFaultObserved)
        precondition(truncatedReport.completeSequentialSweep)

        let corrupt = Lane3ClosurePCMChunkSource(channels: 2, sampleRate: sampleRate, frameCount: baselineFrames) { start, count in
            if start >= 4096 { throw AW43InjectedError.damaged }
            return [Float](repeating: 0.5, count: count * 2)
        }
        let corruptReport = try Lane3RepresentativeCodecExecutionProbe.sweep(
            source: corrupt,
            descriptor: corruptDescriptor,
            environment: .portableStructural,
            chunkFrames: 2048
        )
        precondition(corruptReport.expectedFaultObserved)
        precondition(corruptReport.failureCode == .unexpectedReadFailure)
        precondition(!corruptReport.completeSequentialSweep)

        let classifiedCorrupt = Lane3ClosurePCMChunkSource(channels: 2, sampleRate: sampleRate, frameCount: baselineFrames) { start, count in
            if start >= 2048 { throw Lane3RepresentativeCodecReadFailure(.shortRead) }
            return [Float](repeating: 0.375, count: count * 2)
        }
        let classifiedReport = try Lane3RepresentativeCodecExecutionProbe.sweep(
            source: classifiedCorrupt,
            descriptor: corruptDescriptor,
            environment: .portableStructural,
            chunkFrames: 1024
        )
        precondition(classifiedReport.expectedFaultObserved)
        precondition(classifiedReport.failureCode == .shortRead)

        let silentlyAcceptedCorrupt = try Lane3RepresentativeCodecExecutionProbe.sweep(
            source: clean,
            descriptor: corruptDescriptor,
            environment: .portableStructural,
            chunkFrames: 1024
        )
        precondition(!silentlyAcceptedCorrupt.expectedFaultObserved)
        let incomplete = Lane3RepresentativeCodecEvidenceMatrixEvaluator.evaluate(
            reports: [cleanReport, truncatedReport, silentlyAcceptedCorrupt],
            requiredCodecLabels: ["aac-m4a"]
        )
        precondition(!incomplete.contractCoverageComplete)
        precondition(incomplete.missingContractCells == ["aac-m4a:corrupted"])

        let completePortable = Lane3RepresentativeCodecEvidenceMatrixEvaluator.evaluate(
            reports: [cleanReport, truncatedReport, corruptReport],
            requiredCodecLabels: ["aac-m4a"]
        )
        precondition(completePortable.contractCoverageComplete)
        precondition(!completePortable.physicalEvidenceComplete)
        precondition(completePortable.missingContractCells.isEmpty)

        let shortDescriptor = try Lane3RepresentativeCodecFixtureDescriptor(
            fixtureID: "aw43-short-clean",
            declaredCodecLabel: "short-pcm",
            faultExpectation: .clean,
            expectedChannels: 2,
            expectedSampleRate: 10,
            baselineFrameCount: 17_999,
            rightsCleared: true
        )
        let shortSource = Lane3ClosurePCMChunkSource(channels: 2, sampleRate: 10, frameCount: 17_999) { _, count in
            [Float](repeating: 0, count: count * 2)
        }
        let shortReport = try Lane3RepresentativeCodecExecutionProbe.sweep(
            source: shortSource,
            descriptor: shortDescriptor,
            environment: .portableStructural,
            chunkFrames: 1024
        )
        precondition(shortReport.cleanDecodeContractSatisfied)
        precondition(!shortReport.representativeLongTrack)
        let shortMatrix = Lane3RepresentativeCodecEvidenceMatrixEvaluator.evaluate(
            reports: [shortReport],
            requiredCodecLabels: ["short-pcm"]
        )
        precondition(!shortMatrix.contractCoverageComplete)
        precondition(shortMatrix.rightsOrDurationFailures == 1)

        let unclearedDescriptor = try Lane3RepresentativeCodecFixtureDescriptor(
            fixtureID: "aw43-uncleared-clean",
            declaredCodecLabel: "uncleared-pcm",
            faultExpectation: .clean,
            expectedChannels: 2,
            expectedSampleRate: sampleRate,
            baselineFrameCount: baselineFrames,
            rightsCleared: false
        )
        let unclearedReport = try Lane3RepresentativeCodecExecutionProbe.sweep(
            source: clean,
            descriptor: unclearedDescriptor,
            environment: .portableStructural,
            chunkFrames: 1024
        )
        precondition(unclearedReport.cleanDecodeContractSatisfied)
        precondition(!unclearedReport.authoritativePhysicalEvidenceAllowed)
        let unclearedMatrix = Lane3RepresentativeCodecEvidenceMatrixEvaluator.evaluate(
            reports: [unclearedReport],
            requiredCodecLabels: ["uncleared-pcm"]
        )
        precondition(!unclearedMatrix.contractCoverageComplete)
        precondition(unclearedMatrix.rightsOrDurationFailures == 1)

        let openRejected = Lane3RepresentativeCodecExecutionProbe.openRejected(
            descriptor: corruptDescriptor,
            environment: .selectedAppleAVFAudio,
            failureCode: .openRejected
        )
        precondition(openRejected.expectedFaultObserved)
        precondition(!openRejected.authoritativePhysicalEvidenceAllowed)

        print("L3-AW43 self-test PASS clean=\(cleanReport.framesRead) truncated=\(truncatedReport.framesRead) corruptFailure=\(corruptReport.failureCode!.rawValue) physicalComplete=\(completePortable.physicalEvidenceComplete)")
    }
}
