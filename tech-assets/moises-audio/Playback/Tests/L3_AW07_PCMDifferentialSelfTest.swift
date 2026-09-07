import Foundation

@main
struct L3AW07PCMDifferentialSelfTest {
    static func main() throws {
        try shiftedSignalAndOnsetDetection()
        try injectedPopIsDetectedOutsideExpectedEvents()
        try malformedInputsFailClosed()
        try nonFiniteObservedSamplesAreReportedWithoutHang()
        try reportIsMachineEncodable()
        try localDriftIsVisible()
        try stress(iterations: 200)
        print("L3-AW07 PCM differential self-test PASS")
    }

    static func makeSignal(frames: Int, channels: Int = 2, shift: Int = 0, driftEvery: Int? = nil) -> [Float] {
        var mono: [Double] = []
        mono.reserveCapacity(frames)
        var rng: UInt64 = 0x9e3779b97f4a7c15
        for i in 0..<frames {
            let t = Double(i) / 48_000.0
            rng ^= rng << 13
            rng ^= rng >> 7
            rng ^= rng << 17
            let noise = (Double(rng & 0xffff) / 65_535.0 - 0.5) * 0.12
            var value = 0.18 * sin(2 * Double.pi * 220 * t)
                + 0.09 * sin(2 * Double.pi * 1_013 * t)
                + noise
            if i % 12_000 == 2_000 { value += 0.8 }
            mono.append(value)
        }
        if let driftEvery, driftEvery > 0 {
            var drifted: [Double] = []
            drifted.reserveCapacity(frames + frames / driftEvery + abs(shift))
            if shift > 0 { drifted.append(contentsOf: repeatElement(0.0, count: shift)) }
            for (index, value) in mono.enumerated() {
                drifted.append(value)
                if index > 0 && index % driftEvery == 0 { drifted.append(value) }
            }
            mono = Array(drifted.prefix(frames + max(0, shift) + frames / driftEvery))
        } else if shift > 0 {
            mono = Array(repeating: 0, count: shift) + mono
        }
        var interleaved: [Float] = []
        interleaved.reserveCapacity(mono.count * channels)
        for value in mono {
            for channel in 0..<channels {
                interleaved.append(Float(value * (channel == 0 ? 1.0 : 0.95)))
            }
        }
        return interleaved
    }

    static func shiftedSignalAndOnsetDetection() throws {
        let reference = Lane3PCMBufferDescriptor(interleavedSamples: makeSignal(frames: 96_000), channels: 2, sampleRate: 48_000)
        let observed = Lane3PCMBufferDescriptor(interleavedSamples: makeSignal(frames: 96_000, shift: 137), channels: 2, sampleRate: 48_000)
        let events: [Int64] = [2_000, 14_000, 26_000, 38_000, 50_000, 62_000, 74_000, 86_000]
        let report = try Lane3PCMDifferentialAnalyzer.analyze(reference: reference, observed: observed, expectedEventFrames: events)
        precondition(report.globalLagFrames == 137)
        precondition(report.globalNormalizedCorrelation > 0.999)
        precondition(report.maximumAbsoluteOnsetOffsetFrames == 137)
        precondition(report.maximumAbsoluteResidualOnsetErrorFrames == 0)
        precondition(report.unexpectedDiscontinuityCount == 0)
        precondition(report.parityPromotionAllowed == false)
    }

    static func injectedPopIsDetectedOutsideExpectedEvents() throws {
        let frames = 70_000
        let referenceSamples = makeSignal(frames: frames)
        var observedSamples = referenceSamples
        let popFrame = 33_333
        for channel in 0..<2 {
            observedSamples[popFrame * 2 + channel] = 0.99
            observedSamples[(popFrame + 1) * 2 + channel] = -0.99
        }
        let reference = Lane3PCMBufferDescriptor(interleavedSamples: referenceSamples, channels: 2, sampleRate: 48_000)
        let observed = Lane3PCMBufferDescriptor(interleavedSamples: observedSamples, channels: 2, sampleRate: 48_000)
        let report = try Lane3PCMDifferentialAnalyzer.analyze(reference: reference, observed: observed, expectedEventFrames: [2_000, 14_000, 26_000, 38_000, 50_000, 62_000])
        precondition(report.globalLagFrames == 0)
        precondition(report.unexpectedDiscontinuityCount >= 1)
        precondition(report.maximumUnexpectedDerivative > 1.5)
        precondition(report.residualRMS > 0)
    }

    static func malformedInputsFailClosed() throws {
        let valid = Lane3PCMBufferDescriptor(interleavedSamples: makeSignal(frames: 10_000), channels: 2, sampleRate: 48_000)
        let wrongRate = Lane3PCMBufferDescriptor(interleavedSamples: makeSignal(frames: 10_000), channels: 2, sampleRate: 44_100)
        do {
            _ = try Lane3PCMDifferentialAnalyzer.analyze(reference: valid, observed: wrongRate)
            preconditionFailure("sample-rate mismatch must fail")
        } catch Lane3PCMDifferentialError.sampleRateMismatch {
        }
        let malformed = Lane3PCMBufferDescriptor(interleavedSamples: [0, 1, 2], channels: 2, sampleRate: 48_000)
        do {
            _ = try Lane3PCMDifferentialAnalyzer.analyze(reference: valid, observed: malformed)
            preconditionFailure("malformed PCM must fail")
        } catch Lane3PCMDifferentialError.invalidFormat {
        }
        do {
            _ = try Lane3PCMDifferentialAnalyzer.analyze(reference: valid, observed: valid, expectedEventFrames: [20_000])
            preconditionFailure("out-of-range event must fail")
        } catch Lane3PCMDifferentialError.eventFrameOutOfBounds {
        }
    }

    static func nonFiniteObservedSamplesAreReportedWithoutHang() throws {
        let frames = 12_000
        let referenceSamples = makeSignal(frames: frames)
        var observedSamples = referenceSamples
        observedSamples[4_000] = .nan
        let reference = Lane3PCMBufferDescriptor(interleavedSamples: referenceSamples, channels: 2, sampleRate: 48_000)
        let observed = Lane3PCMBufferDescriptor(interleavedSamples: observedSamples, channels: 2, sampleRate: 48_000)
        let report = try Lane3PCMDifferentialAnalyzer.analyze(
            reference: reference,
            observed: observed,
            configuration: Lane3PCMDifferentialConfiguration(
                maximumAlignmentLagFrames: 32,
                alignmentWindowFrames: 8_192,
                localDriftSearchFrames: 8,
                localWindowFrames: 4_096,
                driftAnchorCount: 3,
                onsetSearchRadiusFrames: 64,
                expectedEventMaskRadiusFrames: 32,
                minimumComparableFrames: 1_024
            )
        )
        precondition(report.observedNonFiniteSampleCount == 1)
        precondition(report.parityPromotionAllowed == false)
    }

    static func reportIsMachineEncodable() throws {
        let reference = Lane3PCMBufferDescriptor(interleavedSamples: makeSignal(frames: 12_000), channels: 2, sampleRate: 48_000)
        let report = try Lane3PCMDifferentialAnalyzer.analyze(
            reference: reference,
            observed: reference,
            configuration: Lane3PCMDifferentialConfiguration(
                maximumAlignmentLagFrames: 16,
                alignmentWindowFrames: 8_192,
                localDriftSearchFrames: 4,
                localWindowFrames: 4_096,
                driftAnchorCount: 3,
                onsetSearchRadiusFrames: 64,
                expectedEventMaskRadiusFrames: 32,
                minimumComparableFrames: 1_024
            )
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(report)
        precondition(!data.isEmpty)
        let decoded = try JSONDecoder().decode(Lane3PCMDifferentialReport.self, from: data)
        precondition(decoded == report)
    }

    static func localDriftIsVisible() throws {
        let reference = Lane3PCMBufferDescriptor(interleavedSamples: makeSignal(frames: 160_000), channels: 2, sampleRate: 48_000)
        let observed = Lane3PCMBufferDescriptor(interleavedSamples: makeSignal(frames: 160_000, shift: 50, driftEvery: 40_000), channels: 2, sampleRate: 48_000)
        let report = try Lane3PCMDifferentialAnalyzer.analyze(
            reference: reference,
            observed: observed,
            configuration: Lane3PCMDifferentialConfiguration(
                maximumAlignmentLagFrames: 256,
                alignmentWindowFrames: 24_000,
                localDriftSearchFrames: 32,
                localWindowFrames: 12_000,
                driftAnchorCount: 7,
                onsetSearchRadiusFrames: 512,
                expectedEventMaskRadiusFrames: 128,
                minimumComparableFrames: 2_048
            )
        )
        precondition(report.driftObservations.count >= 3)
        precondition(report.driftSpanFrames >= 1)
    }

    static func stress(iterations: Int) throws {
        let frames = 16_384
        let reference = Lane3PCMBufferDescriptor(interleavedSamples: makeSignal(frames: frames), channels: 2, sampleRate: 48_000)
        for index in 0..<iterations {
            let shift = index % 17
            let observed = Lane3PCMBufferDescriptor(interleavedSamples: makeSignal(frames: frames, shift: shift), channels: 2, sampleRate: 48_000)
            let report = try Lane3PCMDifferentialAnalyzer.analyze(
                reference: reference,
                observed: observed,
                configuration: Lane3PCMDifferentialConfiguration(
                    maximumAlignmentLagFrames: 32,
                    alignmentWindowFrames: 8_192,
                    localDriftSearchFrames: 8,
                    localWindowFrames: 4_096,
                    driftAnchorCount: 3,
                    onsetSearchRadiusFrames: 64,
                    expectedEventMaskRadiusFrames: 32,
                    minimumComparableFrames: 1_024
                )
            )
            precondition(report.globalLagFrames == shift)
            precondition(report.globalNormalizedCorrelation > 0.99)
        }
    }
}
