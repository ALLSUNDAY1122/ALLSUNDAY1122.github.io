import Foundation

private func makeHarmonicFixture(
    frames: Int,
    sampleRate: Double,
    fundamentalHz: Double,
    formants: [(frequency: Double, width: Double)],
    leadingFrames: Int = 0,
    gain: Double = 1
) -> Lane3PCMBufferDescriptor {
    var mono = [Float](repeating: 0, count: frames + max(0, leadingFrames))
    for frame in 0..<frames {
        let t = Double(frame) / sampleRate
        var value = 0.0
        for harmonic in 1...24 {
            let frequency = fundamentalHz * Double(harmonic)
            if frequency >= sampleRate / 2 { break }
            var amplitude = 1.0 / Double(harmonic)
            for formant in formants {
                amplitude *= 0.15 + exp(-0.5 * pow((frequency - formant.frequency) / formant.width, 2))
            }
            value += amplitude * sin(2 * Double.pi * frequency * t)
        }
        mono[frame + leadingFrames] = Float(value * 0.18 * gain)
    }
    var stereo: [Float] = []
    stereo.reserveCapacity(mono.count * 2)
    for sample in mono { stereo.append(sample); stereo.append(sample) }
    return Lane3PCMBufferDescriptor(interleavedSamples: stereo, channels: 2, sampleRate: sampleRate)
}

private func requireAW10(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}

@main
enum L3AW10SelfTest {
    static func main() throws {
        let sampleRate = 48_000.0
        let formants = [(700.0, 180.0), (1_300.0, 220.0), (2_500.0, 300.0)]
        let reference = makeHarmonicFixture(frames: 48_000, sampleRate: sampleRate, fundamentalHz: 200, formants: formants)

        let identical = try Lane3CepstralEnvelopeDifferentialAnalyzer.analyze(reference: reference, observed: reference)
        requireAW10(identical.meanEnvelopeRMSEDB < 1e-8, "identical envelope RMSE")
        requireAW10(identical.meanEnvelopeCorrelation > 0.999_999, "identical envelope correlation")
        requireAW10(identical.medianAbsoluteFormantPeakErrorCents == 0, "identical peak error")
        requireAW10(!identical.standardizedPerceptualClaimAllowed && !identical.formantPreservationClaimAllowed && !identical.parityPromotionAllowed, "claim boundaries")

        let gainOnly = Lane3PCMBufferDescriptor(
            interleavedSamples: reference.interleavedSamples.map { $0 * 0.5 },
            channels: 2,
            sampleRate: sampleRate
        )
        let gainReport = try Lane3CepstralEnvelopeDifferentialAnalyzer.analyze(reference: reference, observed: gainOnly)
        requireAW10(gainReport.meanEnvelopeRMSEDB < 1e-5, "gain-only should not damage normalized envelope")

        let pitchChangedSameEnvelope = makeHarmonicFixture(frames: 48_000, sampleRate: sampleRate, fundamentalHz: 300, formants: formants)
        let pitchReport = try Lane3CepstralEnvelopeDifferentialAnalyzer.analyze(reference: reference, observed: pitchChangedSameEnvelope)
        requireAW10((pitchReport.medianAbsoluteFormantPeakErrorCents ?? .infinity) < 250, "same broad envelope under F0 change should retain bounded peak proxy")

        let shiftedFormants = [(850.0, 180.0), (1_560.0, 220.0), (3_000.0, 300.0)]
        let damaged = makeHarmonicFixture(frames: 48_000, sampleRate: sampleRate, fundamentalHz: 200, formants: shiftedFormants)
        let damagedReport = try Lane3CepstralEnvelopeDifferentialAnalyzer.analyze(reference: reference, observed: damaged)
        let pitchError = pitchReport.medianAbsoluteFormantPeakErrorCents ?? 0
        let damagedError = damagedReport.medianAbsoluteFormantPeakErrorCents ?? 0
        requireAW10(damagedError > 300 && damagedError > pitchError * 2, "shifted broad envelope should raise peak error")

        let lagged = makeHarmonicFixture(frames: 48_000, sampleRate: sampleRate, fundamentalHz: 200, formants: formants, leadingFrames: 137)
        let lagReport = try Lane3CepstralEnvelopeDifferentialAnalyzer.analyze(reference: reference, observed: lagged, globalLagFrames: 137)
        requireAW10(lagReport.meanEnvelopeRMSEDB < 1e-8, "AW07-style global lag application")

        var nonFinite = reference.interleavedSamples
        nonFinite[1_000] = .nan
        let nonFiniteReport = try Lane3CepstralEnvelopeDifferentialAnalyzer.analyze(
            reference: reference,
            observed: Lane3PCMBufferDescriptor(interleavedSamples: nonFinite, channels: 2, sampleRate: sampleRate)
        )
        requireAW10(nonFiniteReport.observedNonFiniteSampleCount == 1, "non-finite count")

        var rejectedInvalidFFT = false
        do {
            _ = try Lane3CepstralEnvelopeDifferentialAnalyzer.analyze(reference: reference, observed: reference, configuration: .init(windowSize: 1_000))
        } catch Lane3CepstralEnvelopeError.invalidConfiguration { rejectedInvalidFFT = true }
        requireAW10(rejectedInvalidFFT, "non-power-of-two FFT must reject")

        var rejectedRate = false
        do {
            _ = try Lane3CepstralEnvelopeDifferentialAnalyzer.analyze(
                reference: reference,
                observed: Lane3PCMBufferDescriptor(interleavedSamples: reference.interleavedSamples, channels: 2, sampleRate: 44_100)
            )
        } catch Lane3CepstralEnvelopeError.sampleRateMismatch { rejectedRate = true }
        requireAW10(rejectedRate, "sample rate mismatch")

        var rejectedSilence = false
        do {
            let silence = Lane3PCMBufferDescriptor(interleavedSamples: [Float](repeating: 0, count: 16_384), channels: 2, sampleRate: sampleRate)
            _ = try Lane3CepstralEnvelopeDifferentialAnalyzer.analyze(reference: silence, observed: silence)
        } catch Lane3CepstralEnvelopeError.insufficientComparableFrames { rejectedSilence = true }
        requireAW10(rejectedSilence, "all-silent evidence must not yield a quality report")

        let encoded = try JSONEncoder().encode(pitchReport)
        _ = try JSONDecoder().decode(Lane3CepstralEnvelopeDifferentialReport.self, from: encoded)

        let stressConfig = Lane3CepstralEnvelopeConfiguration(windowSize: 1_024, hopSize: 512, maximumWindows: 12)
        for index in 0..<120 {
            let fundamental = 170.0 + Double(index % 23) * 5
            let fixture = makeHarmonicFixture(frames: 8_192, sampleRate: sampleRate, fundamentalHz: fundamental, formants: formants)
            let report = try Lane3CepstralEnvelopeDifferentialAnalyzer.analyze(reference: fixture, observed: fixture, configuration: stressConfig)
            requireAW10(report.meanEnvelopeRMSEDB < 1e-8, "stress identical envelope")
        }

        print("L3-AW10 cepstral-envelope self-test PASS")
        print(String(format: "pitch_same_envelope_peak_median_cents=%.3f shifted_formant_peak_median_cents=%.3f", pitchError, damagedError))
    }
}
