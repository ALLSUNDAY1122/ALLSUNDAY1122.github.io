import Foundation

private final class AW26TrackingSource: Lane3PCMChunkReadable, @unchecked Sendable {
    let channels: Int
    let sampleRate: Double
    let frameCount: Int64
    private let generator: @Sendable (Int64, Int) -> Float
    private let lock = NSLock()
    private(set) var maximumRequestedFrames = 0
    private(set) var readCalls = 0

    init(channels: Int = 2, sampleRate: Double = 48_000, frameCount: Int64, generator: @escaping @Sendable (Int64, Int) -> Float) {
        self.channels = channels
        self.sampleRate = sampleRate
        self.frameCount = frameCount
        self.generator = generator
    }

    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        lock.lock()
        maximumRequestedFrames = max(maximumRequestedFrames, frameCount)
        readCalls += 1
        lock.unlock()
        var output: [Float] = []
        output.reserveCapacity(frameCount * channels)
        for local in 0..<frameCount {
            let frame = startFrame + Int64(local)
            for channel in 0..<channels { output.append(generator(frame, channel)) }
        }
        return output
    }
}

private struct AW26ShortReadSource: Lane3PCMChunkReadable {
    let channels = 2
    let sampleRate = 48_000.0
    let frameCount: Int64 = 16_384
    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        [Float](repeating: 0, count: max(0, frameCount * channels - 1))
    }
}

private func aw26Fixture(frameCount: Int = 65_536, observedLag: Int = 7) -> (Lane3PCMBufferDescriptor, Lane3PCMBufferDescriptor) {
    var reference: [Float] = []
    var observed: [Float] = []
    reference.reserveCapacity(frameCount * 2)
    observed.reserveCapacity(frameCount * 2)
    func sample(_ frame: Int, _ channel: Int) -> Float {
        let x = sin(Double(frame) * 0.0031) * 0.18
            + cos(Double(frame) * 0.0107 + Double(channel) * 0.37) * 0.07
            + sin(Double(frame) * 0.00031) * 0.03
        return Float(x)
    }
    for frame in 0..<frameCount {
        for channel in 0..<2 {
            reference.append(sample(frame, channel))
            observed.append(frame >= observedLag ? sample(frame - observedLag, channel) : 0)
        }
    }
    return (
        Lane3PCMBufferDescriptor(interleavedSamples: reference, channels: 2, sampleRate: 48_000),
        Lane3PCMBufferDescriptor(interleavedSamples: observed, channels: 2, sampleRate: 48_000)
    )
}

@main
struct L3AW26LongTrackEvidenceSelfTest {
    static func main() throws {
        let fixture = aw26Fixture()
        let referenceSource = Lane3ArrayPCMChunkSource(fixture.0)
        let observedSource = Lane3ArrayPCMChunkSource(fixture.1)

        let legacyIdentity = try Lane3PCMIdentityHasher.makeReceipt(reference: fixture.0, observed: fixture.1)
        for chunkFrames in [1, 31, 257, 4_096, 16_384] {
            let streaming = try Lane3LongTrackPCMIdentityHasher.makeReceipt(
                reference: referenceSource,
                observed: observedSource,
                chunkFrames: chunkFrames
            )
            precondition(streaming == legacyIdentity, "AW13 PCM identity must be byte-for-byte compatible across chunk boundaries")
        }

        let timeConfiguration = Lane3PCMDifferentialConfiguration(
            maximumAlignmentLagFrames: 64,
            alignmentWindowFrames: 8_192,
            localDriftSearchFrames: 16,
            localWindowFrames: 2_048,
            driftAnchorCount: 5,
            onsetSearchRadiusFrames: 64,
            expectedEventMaskRadiusFrames: 16,
            minimumComparableFrames: 512
        )
        let legacyTime = try Lane3PCMDifferentialAnalyzer.analyze(
            reference: fixture.0,
            observed: fixture.1,
            configuration: timeConfiguration
        )
        let streamingTime = try Lane3LongTrackPCMDifferentialAnalyzer.analyze(
            reference: referenceSource,
            observed: observedSource,
            configuration: timeConfiguration,
            chunkFrames: 4_096
        )
        precondition(streamingTime == legacyTime, "AW07 report changed under long-track reader")

        let spectralConfiguration = Lane3SpectralDifferentialConfiguration(
            windowSize: 1_024,
            hopSize: 256,
            minimumFrequencyHz: 40,
            maximumFrequencyHz: 12_000,
            expectedFrequencyRatio: 1,
            frequencyRatioSearchRadiusCents: 100,
            frequencyRatioSearchStepCents: 10,
            highBandStartHz: 5_000,
            spectralFloorDB: -120,
            minimumWindowRMS: 1e-7,
            maximumWindows: 32
        )
        let legacySpectral = try Lane3SpectralPerceptualDifferentialAnalyzer.analyze(
            reference: fixture.0,
            observed: fixture.1,
            globalLagFrames: legacyTime.globalLagFrames,
            configuration: spectralConfiguration
        )
        let streamingSpectral = try Lane3LongTrackSpectralPerceptualDifferentialAnalyzer.analyze(
            reference: referenceSource,
            observed: observedSource,
            globalLagFrames: streamingTime.globalLagFrames,
            configuration: spectralConfiguration,
            chunkFrames: 4_096
        )
        precondition(streamingSpectral == legacySpectral, "AW08 report changed under bounded selected-window reads")

        let envelopeConfiguration = Lane3CepstralEnvelopeConfiguration(
            windowSize: 1_024,
            hopSize: 256,
            minimumFrequencyHz: 100,
            maximumFrequencyHz: 5_000,
            cepstralCoefficientCount: 8,
            minimumWindowRMS: 1e-7,
            maximumWindows: 32,
            formantPeakLimit: 8
        )
        let legacyEnvelope = try Lane3CepstralEnvelopeDifferentialAnalyzer.analyze(
            reference: fixture.0,
            observed: fixture.1,
            globalLagFrames: legacyTime.globalLagFrames,
            configuration: envelopeConfiguration
        )
        let streamingEnvelope = try Lane3LongTrackCepstralEnvelopeDifferentialAnalyzer.analyze(
            reference: referenceSource,
            observed: observedSource,
            globalLagFrames: streamingTime.globalLagFrames,
            configuration: envelopeConfiguration,
            chunkFrames: 4_096
        )
        precondition(streamingEnvelope == legacyEnvelope, "AW10 report changed under bounded selected-window reads")

        do {
            _ = try Lane3LongTrackPCMIdentityHasher.makeReceipt(
                reference: AW26ShortReadSource(),
                observed: AW26ShortReadSource(),
                chunkFrames: 4_096
            )
            preconditionFailure("short reads must fail closed")
        } catch Lane3LongTrackEvidenceError.shortRead { }

        let thirtyMinuteFrames: Int64 = 48_000 * 60 * 30
        let profile = try Lane3LongTrackEvidenceResourcePlanner.profile(channels: 2)
        precondition(profile.maximumSingleReadFrames == 40_962)
        precondition(profile.approximateMaximumSingleReadBytes == 327_696)
        precondition(profile.estimatedMajorAnalysisBufferBytesUpperBound < 10_000_000)
        precondition(!profile.fullTrackPCMRetainedByPipeline)
        precondition(!profile.actualProcessRSSMeasured)
        precondition(thirtyMinuteFrames == 86_400_000)

        let tracking = AW26TrackingSource(frameCount: 1_000_000) { frame, channel in
            Float((frame + Int64(channel * 17)) & 1_023) / 2_048
        }
        _ = try Lane3LongTrackPCMIdentityHasher.makeReceipt(reference: tracking, observed: tracking, chunkFrames: 16_384)
        precondition(tracking.maximumRequestedFrames <= 16_384)

        print(
            "L3-AW26 long-track evidence self-test PASS "
            + "lag=\(streamingTime.globalLagFrames) "
            + "spectralWindows=\(streamingSpectral.windowsAnalyzed) "
            + "envelopeWindows=\(streamingEnvelope.windowsAnalyzed) "
            + "maxSingleRead=\(profile.maximumSingleReadFrames) "
            + "majorBufferBound=\(profile.estimatedMajorAnalysisBufferBytesUpperBound)"
        )
    }
}
