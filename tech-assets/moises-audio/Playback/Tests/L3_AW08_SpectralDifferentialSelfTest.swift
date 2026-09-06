import Foundation

@main
struct L3AW08SpectralDifferentialSelfTest {
    static func main() throws {
        try identicalSignalBaseline()
        try knownOctaveShiftTracksExpectedRatio()
        try highFrequencyArtifactRaisesSpectralMetrics()
        try globalLagAndNonFiniteHandling()
        try invalidInputFailsClosed()
        try stressFrequencyRatios(iterations: 120)
        try jsonRoundTrip()
        print("L3-AW08 spectral/perceptual differential self-test PASS")
    }

    static func identicalSignalBaseline() throws {
        let sampleRate = 48_000.0
        let samples = signal(frames: 24_000, sampleRate: sampleRate, frequencies: [220, 440, 880, 1760])
        let input = Lane3PCMBufferDescriptor(interleavedSamples: stereo(samples), channels: 2, sampleRate: sampleRate)
        let report = try Lane3SpectralPerceptualDifferentialAnalyzer.analyze(
            reference: input,
            observed: input,
            configuration: config(expectedRatio: 1)
        )
        precondition(abs(report.frequencyRatioErrorCents) <= 0.001)
        precondition(report.meanLogSpectralDistanceDB < 1e-8)
        precondition(report.meanBandEnergyCosineDistance < 1e-10)
        precondition(report.meanAbsoluteCentroidRatioErrorCents < 1e-8)
        precondition(report.rmsEnvelopeCorrelation > 0.999999)
        precondition(!report.perceptualClaimAllowed && !report.parityPromotionAllowed)
    }

    static func knownOctaveShiftTracksExpectedRatio() throws {
        let sampleRate = 48_000.0
        let ref = signal(frames: 32_000, sampleRate: sampleRate, frequencies: [220, 330, 440, 660, 880])
        let obs = signal(frames: 32_000, sampleRate: sampleRate, frequencies: [440, 660, 880, 1320, 1760])
        let report = try Lane3SpectralPerceptualDifferentialAnalyzer.analyze(
            reference: descriptor(ref, sampleRate),
            observed: descriptor(obs, sampleRate),
            configuration: config(expectedRatio: 2, searchCents: 120, stepCents: 5)
        )
        precondition(abs(report.frequencyRatioErrorCents) <= 15)
        precondition(report.expectedScaleCorrelation > 0.85)
        precondition(report.bestScaleCorrelation >= report.expectedScaleCorrelation - 1e-9)
        precondition(abs(report.medianSpectralPeakRatioErrorCents ?? 999) < 15)
        precondition((report.p95AbsoluteSpectralPeakRatioErrorCents ?? 999) < 60)
        precondition(report.meanAbsoluteCentroidRatioErrorCents < 40)
    }

    static func highFrequencyArtifactRaisesSpectralMetrics() throws {
        let sampleRate = 48_000.0
        let ref = signal(frames: 24_000, sampleRate: sampleRate, frequencies: [180, 360, 720, 1440])
        let clean = ref
        var dirty = ref
        for frame in dirty.indices {
            let t = Double(frame) / sampleRate
            dirty[frame] += Float(0.08 * sin(2 * Double.pi * 10_500 * t))
            if frame % 4096 == 2048 { dirty[frame] += 0.7 }
        }
        let cleanReport = try Lane3SpectralPerceptualDifferentialAnalyzer.analyze(
            reference: descriptor(ref, sampleRate),
            observed: descriptor(clean, sampleRate),
            configuration: config(expectedRatio: 1)
        )
        let dirtyReport = try Lane3SpectralPerceptualDifferentialAnalyzer.analyze(
            reference: descriptor(ref, sampleRate),
            observed: descriptor(dirty, sampleRate),
            configuration: config(expectedRatio: 1)
        )
        precondition(dirtyReport.meanLogSpectralDistanceDB > cleanReport.meanLogSpectralDistanceDB + 2)
        precondition(dirtyReport.meanAbsoluteHighBandEnergyDeltaDB > cleanReport.meanAbsoluteHighBandEnergyDeltaDB + 3)
        precondition(dirtyReport.meanBandEnergyCosineDistance > cleanReport.meanBandEnergyCosineDistance + 0.001)
        precondition(dirtyReport.meanSpectralFluxDelta > cleanReport.meanSpectralFluxDelta)
    }

    static func globalLagAndNonFiniteHandling() throws {
        let sampleRate = 48_000.0
        let ref = signal(frames: 18_000, sampleRate: sampleRate, frequencies: [250, 500, 1000])
        let lag = 128
        var obs = [Float](repeating: 0, count: ref.count)
        for frame in 0..<(ref.count - lag) { obs[frame + lag] = ref[frame] }
        obs[7_777] = .nan
        let report = try Lane3SpectralPerceptualDifferentialAnalyzer.analyze(
            reference: descriptor(ref, sampleRate),
            observed: descriptor(obs, sampleRate),
            globalLagFrames: lag,
            configuration: config(expectedRatio: 1)
        )
        precondition(report.globalLagFramesApplied == lag)
        precondition(report.observedNonFiniteSampleCount == 2) // stereo descriptor duplicates NaN
        precondition(abs(report.frequencyRatioErrorCents) <= 10)
        precondition(report.meanLogSpectralDistanceDB < 3.5)
    }

    static func invalidInputFailsClosed() throws {
        let sr = 48_000.0
        let samples = signal(frames: 4096, sampleRate: sr, frequencies: [440])
        let input = descriptor(samples, sr)
        do {
            _ = try Lane3SpectralPerceptualDifferentialAnalyzer.analyze(
                reference: input,
                observed: input,
                configuration: Lane3SpectralDifferentialConfiguration(windowSize: 1000)
            )
            preconditionFailure("non-power-of-two FFT window must fail")
        } catch Lane3SpectralDifferentialError.invalidConfiguration {}

        do {
            _ = try Lane3SpectralPerceptualDifferentialAnalyzer.analyze(
                reference: input,
                observed: Lane3PCMBufferDescriptor(interleavedSamples: stereo(samples), channels: 2, sampleRate: 44_100),
                configuration: config(expectedRatio: 1)
            )
            preconditionFailure("sample-rate mismatch must fail")
        } catch Lane3SpectralDifferentialError.sampleRateMismatch {}

        do {
            _ = try Lane3SpectralPerceptualDifferentialAnalyzer.analyze(
                reference: input,
                observed: Lane3PCMBufferDescriptor(interleavedSamples: samples, channels: 1, sampleRate: sr),
                configuration: config(expectedRatio: 1)
            )
            preconditionFailure("channel mismatch must fail")
        } catch Lane3SpectralDifferentialError.channelMismatch {}
    }

    static func stressFrequencyRatios(iterations: Int) throws {
        let sampleRate = 48_000.0
        let baseFrequencies = [190.0, 285, 380, 570, 760]
        let ref = signal(frames: 8192, sampleRate: sampleRate, frequencies: baseFrequencies)
        for index in 0..<iterations {
            let cents = Double((index % 17) - 8) * 10
            let ratio = pow(2, cents / 1200)
            let obs = signal(frames: 8192, sampleRate: sampleRate, frequencies: baseFrequencies.map { $0 * ratio })
            let report = try Lane3SpectralPerceptualDifferentialAnalyzer.analyze(
                reference: descriptor(ref, sampleRate),
                observed: descriptor(obs, sampleRate),
                configuration: Lane3SpectralDifferentialConfiguration(
                    windowSize: 1024,
                    hopSize: 512,
                    minimumFrequencyHz: 50,
                    maximumFrequencyHz: 10_000,
                    expectedFrequencyRatio: ratio,
                    frequencyRatioSearchRadiusCents: 80,
                    frequencyRatioSearchStepCents: 5,
                    highBandStartHz: 4_000,
                    maximumWindows: 14
                )
            )
            precondition(abs(report.frequencyRatioErrorCents) <= 80)
            precondition(abs(report.medianSpectralPeakRatioErrorCents ?? 999) <= 30)
            precondition((report.p95AbsoluteSpectralPeakRatioErrorCents ?? 999) <= 80)
        }
    }

    static func jsonRoundTrip() throws {
        let sr = 48_000.0
        let samples = signal(frames: 8192, sampleRate: sr, frequencies: [440, 880])
        let report = try Lane3SpectralPerceptualDifferentialAnalyzer.analyze(
            reference: descriptor(samples, sr),
            observed: descriptor(samples, sr),
            configuration: Lane3SpectralDifferentialConfiguration(windowSize: 512, hopSize: 256, maximumFrequencyHz: 12_000, highBandStartHz: 5_000, maximumWindows: 16)
        )
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(Lane3SpectralDifferentialReport.self, from: data)
        precondition(decoded == report)
    }

    static func config(expectedRatio: Double, searchCents: Double = 160, stepCents: Double = 10) -> Lane3SpectralDifferentialConfiguration {
        Lane3SpectralDifferentialConfiguration(
            windowSize: 1024,
            hopSize: 512,
            minimumFrequencyHz: 50,
            maximumFrequencyHz: 16_000,
            expectedFrequencyRatio: expectedRatio,
            frequencyRatioSearchRadiusCents: searchCents,
            frequencyRatioSearchStepCents: stepCents,
            highBandStartHz: 6_000,
            maximumWindows: 48
        )
    }

    static func descriptor(_ mono: [Float], _ sampleRate: Double) -> Lane3PCMBufferDescriptor {
        Lane3PCMBufferDescriptor(interleavedSamples: stereo(mono), channels: 2, sampleRate: sampleRate)
    }

    static func stereo(_ mono: [Float]) -> [Float] {
        var output = [Float]()
        output.reserveCapacity(mono.count * 2)
        for value in mono { output.append(value); output.append(value) }
        return output
    }

    static func signal(frames: Int, sampleRate: Double, frequencies: [Double]) -> [Float] {
        var output = [Float](repeating: 0, count: frames)
        for frame in 0..<frames {
            let t = Double(frame) / sampleRate
            let envelope = 0.72 + 0.20 * sin(2 * Double.pi * 2.3 * t) + 0.08 * sin(2 * Double.pi * 7.1 * t)
            var value = 0.0
            for (index, frequency) in frequencies.enumerated() {
                value += sin(2 * Double.pi * frequency * t + Double(index) * 0.31) / Double(index + 1)
            }
            output[frame] = Float(0.18 * envelope * value)
        }
        return output
    }
}
