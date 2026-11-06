import Foundation

public enum Lane3CepstralEnvelopeError: Error, Equatable, Sendable {
    case invalidFormat
    case sampleRateMismatch(expected: Double, actual: Double)
    case channelMismatch(expected: Int, actual: Int)
    case invalidConfiguration
    case insufficientComparableFrames
}

public struct Lane3CepstralEnvelopeConfiguration: Equatable, Codable, Sendable {
    public let windowSize: Int
    public let hopSize: Int
    public let minimumFrequencyHz: Double
    public let maximumFrequencyHz: Double
    public let cepstralCoefficientCount: Int
    public let minimumWindowRMS: Double
    public let maximumWindows: Int
    public let formantPeakLimit: Int

    public init(
        windowSize: Int = 2_048,
        hopSize: Int = 512,
        minimumFrequencyHz: Double = 100,
        maximumFrequencyHz: Double = 5_000,
        cepstralCoefficientCount: Int = 8,
        minimumWindowRMS: Double = 1e-7,
        maximumWindows: Int = 256,
        formantPeakLimit: Int = 8
    ) {
        self.windowSize = windowSize
        self.hopSize = hopSize
        self.minimumFrequencyHz = minimumFrequencyHz
        self.maximumFrequencyHz = maximumFrequencyHz
        self.cepstralCoefficientCount = cepstralCoefficientCount
        self.minimumWindowRMS = minimumWindowRMS
        self.maximumWindows = maximumWindows
        self.formantPeakLimit = formantPeakLimit
    }
}

public struct Lane3FormantPeakObservation: Equatable, Codable, Sendable {
    public let referenceFrequencyHz: Double
    public let observedFrequencyHz: Double
    public let frequencyErrorCents: Double
}

public struct Lane3CepstralEnvelopeWindowObservation: Equatable, Codable, Sendable {
    public let referenceStartFrame: Int64
    public let observedStartFrame: Int64
    public let envelopeRMSEDB: Double
    public let envelopeCorrelation: Double
    public let spectralTiltDeltaDBPerOctave: Double
}

public struct Lane3CepstralEnvelopeDifferentialReport: Equatable, Codable, Sendable {
    public let evidenceScope: String
    public let globalLagFramesApplied: Int
    public let windowsAnalyzed: Int
    public let cepstralCoefficientCount: Int
    public let meanEnvelopeRMSEDB: Double
    public let p95EnvelopeRMSEDB: Double
    public let meanEnvelopeCorrelation: Double
    public let meanAbsoluteSpectralTiltDeltaDBPerOctave: Double
    public let formantPeakMatches: [Lane3FormantPeakObservation]
    public let medianAbsoluteFormantPeakErrorCents: Double?
    public let p95AbsoluteFormantPeakErrorCents: Double?
    public let referenceNonFiniteSampleCount: Int64
    public let observedNonFiniteSampleCount: Int64
    public let windowObservations: [Lane3CepstralEnvelopeWindowObservation]
    public let standardizedPerceptualClaimAllowed: Bool
    public let formantPreservationClaimAllowed: Bool
    public let parityPromotionAllowed: Bool
}

public enum Lane3CepstralEnvelopeDifferentialAnalyzer {
    public static func analyze(
        reference: Lane3PCMBufferDescriptor,
        observed: Lane3PCMBufferDescriptor,
        globalLagFrames: Int = 0,
        configuration: Lane3CepstralEnvelopeConfiguration = Lane3CepstralEnvelopeConfiguration()
    ) throws -> Lane3CepstralEnvelopeDifferentialReport {
        try validate(reference, observed, configuration)
        let ref = collapse(reference)
        let obs = collapse(observed)
        let aligned = alignedRanges(
            referenceCount: ref.samples.count,
            observedCount: obs.samples.count,
            lag: globalLagFrames
        )
        guard aligned.count >= configuration.windowSize else {
            throw Lane3CepstralEnvelopeError.insufficientComparableFrames
        }

        let starts = selectedStarts(comparableFrames: aligned.count, configuration: configuration)
        let window = hann(configuration.windowSize)
        var observations: [Lane3CepstralEnvelopeWindowObservation] = []
        var referenceEnvelopeAggregate: [Double]?
        var observedEnvelopeAggregate: [Double]?

        for localStart in starts {
            let referenceStart = aligned.referenceStart + localStart
            let observedStart = aligned.observedStart + localStart
            let referenceFrame = Array(ref.samples[referenceStart..<(referenceStart + configuration.windowSize)])
            let observedFrame = Array(obs.samples[observedStart..<(observedStart + configuration.windowSize)])
            if rms(referenceFrame) < configuration.minimumWindowRMS,
               rms(observedFrame) < configuration.minimumWindowRMS {
                continue
            }

            let referencePower = powerSpectrum(referenceFrame, window: window)
            let observedPower = powerSpectrum(observedFrame, window: window)
            let range = analysisRange(
                sampleRate: reference.sampleRate,
                configuration: configuration,
                binCount: min(referencePower.count, observedPower.count)
            )
            guard range.count >= configuration.cepstralCoefficientCount + 2 else { continue }

            let referenceLog = range.map { 10 * log10(max(referencePower[$0], 1e-20)) }
            let observedLog = range.map { 10 * log10(max(observedPower[$0], 1e-20)) }
            let referenceEnvelope = lowOrderEnvelope(referenceLog, coefficientCount: configuration.cepstralCoefficientCount)
            let observedEnvelope = lowOrderEnvelope(observedLog, coefficientCount: configuration.cepstralCoefficientCount)
            let normalizedReference = removeMean(referenceEnvelope)
            let normalizedObserved = removeMean(observedEnvelope)
            let referenceTilt = spectralTilt(
                envelopeDB: referenceEnvelope,
                binRange: range,
                sampleRate: reference.sampleRate,
                windowSize: configuration.windowSize
            )
            let observedTilt = spectralTilt(
                envelopeDB: observedEnvelope,
                binRange: range,
                sampleRate: reference.sampleRate,
                windowSize: configuration.windowSize
            )

            observations.append(
                Lane3CepstralEnvelopeWindowObservation(
                    referenceStartFrame: Int64(referenceStart),
                    observedStartFrame: Int64(observedStart),
                    envelopeRMSEDB: rmsDifference(normalizedReference, normalizedObserved),
                    envelopeCorrelation: correlation(normalizedReference, normalizedObserved),
                    spectralTiltDeltaDBPerOctave: observedTilt - referenceTilt
                )
            )

            if referenceEnvelopeAggregate == nil {
                referenceEnvelopeAggregate = referenceEnvelope
                observedEnvelopeAggregate = observedEnvelope
            } else {
                for index in referenceEnvelope.indices {
                    referenceEnvelopeAggregate![index] += referenceEnvelope[index]
                    observedEnvelopeAggregate![index] += observedEnvelope[index]
                }
            }
        }

        guard !observations.isEmpty,
              var referenceAggregate = referenceEnvelopeAggregate,
              var observedAggregate = observedEnvelopeAggregate else {
            throw Lane3CepstralEnvelopeError.insufficientComparableFrames
        }

        let divisor = Double(observations.count)
        referenceAggregate = referenceAggregate.map { $0 / divisor }
        observedAggregate = observedAggregate.map { $0 / divisor }
        let range = analysisRange(
            sampleRate: reference.sampleRate,
            configuration: configuration,
            binCount: configuration.windowSize / 2 + 1
        )
        let peakMatches = matchEnvelopePeaks(
            referenceEnvelope: referenceAggregate,
            observedEnvelope: observedAggregate,
            binRange: range,
            sampleRate: reference.sampleRate,
            windowSize: configuration.windowSize,
            limit: configuration.formantPeakLimit
        )
        let peakErrors = peakMatches.map { abs($0.frequencyErrorCents) }
        let rmsErrors = observations.map(\.envelopeRMSEDB)

        return Lane3CepstralEnvelopeDifferentialReport(
            evidenceScope: "LANE3_CEPSTRAL_ENVELOPE_FORMANT_PROXY_NON_PARITY",
            globalLagFramesApplied: globalLagFrames,
            windowsAnalyzed: observations.count,
            cepstralCoefficientCount: configuration.cepstralCoefficientCount,
            meanEnvelopeRMSEDB: mean(rmsErrors),
            p95EnvelopeRMSEDB: percentile95(rmsErrors),
            meanEnvelopeCorrelation: mean(observations.map(\.envelopeCorrelation)),
            meanAbsoluteSpectralTiltDeltaDBPerOctave: mean(observations.map { abs($0.spectralTiltDeltaDBPerOctave) }),
            formantPeakMatches: peakMatches,
            medianAbsoluteFormantPeakErrorCents: median(peakErrors),
            p95AbsoluteFormantPeakErrorCents: peakErrors.isEmpty ? nil : percentile95(peakErrors),
            referenceNonFiniteSampleCount: ref.nonFinite,
            observedNonFiniteSampleCount: obs.nonFinite,
            windowObservations: observations,
            standardizedPerceptualClaimAllowed: false,
            formantPreservationClaimAllowed: false,
            parityPromotionAllowed: false
        )
    }

    private static func validate(
        _ reference: Lane3PCMBufferDescriptor,
        _ observed: Lane3PCMBufferDescriptor,
        _ configuration: Lane3CepstralEnvelopeConfiguration
    ) throws {
        for input in [reference, observed] {
            guard input.channels > 0,
                  input.sampleRate.isFinite, input.sampleRate > 0,
                  !input.interleavedSamples.isEmpty,
                  input.interleavedSamples.count % input.channels == 0 else {
                throw Lane3CepstralEnvelopeError.invalidFormat
            }
        }
        guard abs(reference.sampleRate - observed.sampleRate) <= 0.5 else {
            throw Lane3CepstralEnvelopeError.sampleRateMismatch(expected: reference.sampleRate, actual: observed.sampleRate)
        }
        guard reference.channels == observed.channels else {
            throw Lane3CepstralEnvelopeError.channelMismatch(expected: reference.channels, actual: observed.channels)
        }
        guard isPowerOfTwo(configuration.windowSize),
              configuration.windowSize >= 256,
              configuration.windowSize <= 16_384,
              configuration.hopSize > 0,
              configuration.hopSize <= configuration.windowSize,
              configuration.minimumFrequencyHz.isFinite,
              configuration.minimumFrequencyHz > 0,
              configuration.maximumFrequencyHz.isFinite,
              configuration.maximumFrequencyHz > configuration.minimumFrequencyHz,
              configuration.maximumFrequencyHz <= reference.sampleRate / 2,
              configuration.cepstralCoefficientCount >= 4,
              configuration.cepstralCoefficientCount < configuration.windowSize / 4,
              configuration.minimumWindowRMS.isFinite,
              configuration.minimumWindowRMS >= 0,
              configuration.maximumWindows > 0,
              configuration.formantPeakLimit > 0 else {
            throw Lane3CepstralEnvelopeError.invalidConfiguration
        }
    }

    private static func isPowerOfTwo(_ value: Int) -> Bool {
        value > 0 && (value & (value - 1)) == 0
    }

    private static func collapse(_ input: Lane3PCMBufferDescriptor) -> (samples: [Double], nonFinite: Int64) {
        let frameCount = Int(input.frameCount)
        var mono = [Double](repeating: 0, count: frameCount)
        var nonFinite: Int64 = 0
        for frame in 0..<frameCount {
            var sum = 0.0
            var finiteCount = 0
            for channel in 0..<input.channels {
                let value = Double(input.interleavedSamples[frame * input.channels + channel])
                if value.isFinite {
                    sum += value
                    finiteCount += 1
                } else {
                    nonFinite += 1
                }
            }
            mono[frame] = finiteCount > 0 ? sum / Double(finiteCount) : 0
        }
        return (mono, nonFinite)
    }

    private struct AlignedRange {
        let referenceStart: Int
        let observedStart: Int
        let count: Int
    }

    private static func alignedRanges(referenceCount: Int, observedCount: Int, lag: Int) -> AlignedRange {
        let referenceStart = max(0, -lag)
        let observedStart = max(0, lag)
        return AlignedRange(
            referenceStart: referenceStart,
            observedStart: observedStart,
            count: max(0, min(referenceCount - referenceStart, observedCount - observedStart))
        )
    }

    private static func selectedStarts(
        comparableFrames: Int,
        configuration: Lane3CepstralEnvelopeConfiguration
    ) -> [Int] {
        var starts: [Int] = []
        var start = 0
        while start + configuration.windowSize <= comparableFrames {
            starts.append(start)
            start += configuration.hopSize
        }
        guard starts.count > configuration.maximumWindows else { return starts }
        if configuration.maximumWindows == 1 { return [starts[starts.count / 2]] }
        return (0..<configuration.maximumWindows).map { index in
            let position = Double(index) * Double(starts.count - 1) / Double(configuration.maximumWindows - 1)
            return starts[Int(position.rounded())]
        }
    }

    private static func hann(_ size: Int) -> [Double] {
        (0..<size).map { 0.5 - 0.5 * cos(2 * Double.pi * Double($0) / Double(size - 1)) }
    }

    private struct Complex {
        var real: Double
        var imaginary: Double
    }

    private static func powerSpectrum(_ samples: [Double], window: [Double]) -> [Double] {
        var values = samples.indices.map { Complex(real: samples[$0] * window[$0], imaginary: 0) }
        fft(&values)
        return (0...samples.count / 2).map {
            max(0, values[$0].real * values[$0].real + values[$0].imaginary * values[$0].imaginary)
        }
    }

    private static func fft(_ values: inout [Complex]) {
        let count = values.count
        var j = 0
        if count > 1 {
            for i in 1..<(count - 1) {
                var bit = count >> 1
                while j & bit != 0 { j ^= bit; bit >>= 1 }
                j ^= bit
                if i < j { values.swapAt(i, j) }
            }
        }
        var length = 2
        while length <= count {
            let angle = -2 * Double.pi / Double(length)
            let wLength = Complex(real: cos(angle), imaginary: sin(angle))
            var start = 0
            while start < count {
                var w = Complex(real: 1, imaginary: 0)
                for offset in 0..<(length / 2) {
                    let evenIndex = start + offset
                    let oddIndex = evenIndex + length / 2
                    let odd = multiply(values[oddIndex], w)
                    let even = values[evenIndex]
                    values[evenIndex] = Complex(real: even.real + odd.real, imaginary: even.imaginary + odd.imaginary)
                    values[oddIndex] = Complex(real: even.real - odd.real, imaginary: even.imaginary - odd.imaginary)
                    w = multiply(w, wLength)
                }
                start += length
            }
            length <<= 1
        }
    }

    private static func multiply(_ lhs: Complex, _ rhs: Complex) -> Complex {
        Complex(
            real: lhs.real * rhs.real - lhs.imaginary * rhs.imaginary,
            imaginary: lhs.real * rhs.imaginary + lhs.imaginary * rhs.real
        )
    }

    private static func analysisRange(
        sampleRate: Double,
        configuration: Lane3CepstralEnvelopeConfiguration,
        binCount: Int
    ) -> Range<Int> {
        let hzPerBin = sampleRate / Double(configuration.windowSize)
        let lower = max(1, Int(ceil(configuration.minimumFrequencyHz / hzPerBin)))
        let upper = min(binCount - 1, Int(floor(configuration.maximumFrequencyHz / hzPerBin)))
        return lower..<max(lower, upper + 1)
    }

    /// Low-order DCT-II reconstruction of the log spectrum. This is a deterministic
    /// cepstral-style spectral-envelope proxy; it is not a standardized formant estimator.
    private static func lowOrderEnvelope(_ input: [Double], coefficientCount: Int) -> [Double] {
        let count = input.count
        let retained = min(coefficientCount, count)
        var coefficients = [Double](repeating: 0, count: retained)
        for k in 0..<retained {
            var sum = 0.0
            for index in 0..<count {
                sum += input[index] * cos(Double.pi * (Double(index) + 0.5) * Double(k) / Double(count))
            }
            coefficients[k] = sum
        }
        var output = [Double](repeating: 0, count: count)
        for index in 0..<count {
            var sum = coefficients[0] / Double(count)
            if retained > 1 {
                for k in 1..<retained {
                    sum += (2 / Double(count)) * coefficients[k] * cos(Double.pi * (Double(index) + 0.5) * Double(k) / Double(count))
                }
            }
            output[index] = sum
        }
        return output
    }

    private static func removeMean(_ values: [Double]) -> [Double] {
        let average = mean(values)
        return values.map { $0 - average }
    }

    private static func rms(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : sqrt(values.reduce(0) { $0 + $1 * $1 } / Double(values.count))
    }

    private static func rmsDifference(_ lhs: [Double], _ rhs: [Double]) -> Double {
        let count = min(lhs.count, rhs.count)
        guard count > 0 else { return 0 }
        var sum = 0.0
        for index in 0..<count { sum += pow(lhs[index] - rhs[index], 2) }
        return sqrt(sum / Double(count))
    }

    private static func correlation(_ lhs: [Double], _ rhs: [Double]) -> Double {
        let count = min(lhs.count, rhs.count)
        guard count >= 2 else { return 0 }
        let lhsMean = lhs.prefix(count).reduce(0, +) / Double(count)
        let rhsMean = rhs.prefix(count).reduce(0, +) / Double(count)
        var numerator = 0.0
        var lhsPower = 0.0
        var rhsPower = 0.0
        for index in 0..<count {
            let a = lhs[index] - lhsMean
            let b = rhs[index] - rhsMean
            numerator += a * b
            lhsPower += a * a
            rhsPower += b * b
        }
        let denominator = sqrt(lhsPower * rhsPower)
        return denominator > 1e-20 ? max(-1, min(1, numerator / denominator)) : 1
    }

    private static func spectralTilt(
        envelopeDB: [Double],
        binRange: Range<Int>,
        sampleRate: Double,
        windowSize: Int
    ) -> Double {
        guard envelopeDB.count >= 2 else { return 0 }
        let hzPerBin = sampleRate / Double(windowSize)
        var x: [Double] = []
        var y: [Double] = []
        for index in envelopeDB.indices {
            let frequency = Double(binRange.lowerBound + index) * hzPerBin
            if frequency > 0 { x.append(log2(frequency)); y.append(envelopeDB[index]) }
        }
        let xMean = mean(x)
        let yMean = mean(y)
        var numerator = 0.0
        var denominator = 0.0
        for index in x.indices {
            numerator += (x[index] - xMean) * (y[index] - yMean)
            denominator += pow(x[index] - xMean, 2)
        }
        return denominator > 1e-20 ? numerator / denominator : 0
    }

    private static func matchEnvelopePeaks(
        referenceEnvelope: [Double],
        observedEnvelope: [Double],
        binRange: Range<Int>,
        sampleRate: Double,
        windowSize: Int,
        limit: Int
    ) -> [Lane3FormantPeakObservation] {
        let referencePeaks = peaks(referenceEnvelope, binRange: binRange, sampleRate: sampleRate, windowSize: windowSize, limit: limit)
        let observedPeaks = peaks(observedEnvelope, binRange: binRange, sampleRate: sampleRate, windowSize: windowSize, limit: limit)
        var used = Set<Int>()
        var output: [Lane3FormantPeakObservation] = []
        for reference in referencePeaks {
            var bestIndex: Int?
            var bestError = Double.infinity
            for (index, observed) in observedPeaks.enumerated() where !used.contains(index) {
                let error = abs(1_200 * log2(observed / reference))
                if error < bestError { bestError = error; bestIndex = index }
            }
            if let bestIndex, bestError <= 600 {
                used.insert(bestIndex)
                let observed = observedPeaks[bestIndex]
                output.append(
                    Lane3FormantPeakObservation(
                        referenceFrequencyHz: reference,
                        observedFrequencyHz: observed,
                        frequencyErrorCents: 1_200 * log2(observed / reference)
                    )
                )
            }
        }
        return output
    }

    private static func peaks(
        _ envelope: [Double],
        binRange: Range<Int>,
        sampleRate: Double,
        windowSize: Int,
        limit: Int
    ) -> [Double] {
        guard envelope.count >= 3 else { return [] }
        let hzPerBin = sampleRate / Double(windowSize)
        var found: [(frequency: Double, value: Double)] = []
        for index in 1..<(envelope.count - 1)
        where envelope[index] > envelope[index - 1] && envelope[index] >= envelope[index + 1] {
            found.append((Double(binRange.lowerBound + index) * hzPerBin, envelope[index]))
        }
        return found.sorted { $0.value > $1.value }.prefix(limit).map(\.frequency).sorted()
    }

    private static func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    private static func percentile95(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = min(sorted.count - 1, Int((0.95 * Double(sorted.count - 1)).rounded(.up)))
        return sorted[index]
    }
}
