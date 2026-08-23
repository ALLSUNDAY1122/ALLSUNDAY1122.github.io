import Foundation

extension Lane3SpectralPerceptualDifferentialAnalyzer {
    static func validate(
        reference: Lane3PCMBufferDescriptor,
        observed: Lane3PCMBufferDescriptor,
        configuration: Lane3SpectralDifferentialConfiguration
    ) throws {
        for item in [reference, observed] {
            guard item.channels > 0,
                  item.sampleRate.isFinite, item.sampleRate > 0,
                  !item.interleavedSamples.isEmpty,
                  item.interleavedSamples.count % item.channels == 0 else {
                throw Lane3SpectralDifferentialError.invalidFormat
            }
        }
        guard abs(reference.sampleRate - observed.sampleRate) <= 0.5 else {
            throw Lane3SpectralDifferentialError.sampleRateMismatch(expected: reference.sampleRate, actual: observed.sampleRate)
        }
        guard reference.channels == observed.channels else {
            throw Lane3SpectralDifferentialError.channelMismatch(expected: reference.channels, actual: observed.channels)
        }
        guard isPowerOfTwo(configuration.windowSize),
              configuration.windowSize >= 128,
              configuration.windowSize <= 16_384,
              configuration.hopSize > 0,
              configuration.hopSize <= configuration.windowSize,
              configuration.minimumFrequencyHz.isFinite,
              configuration.minimumFrequencyHz >= 0,
              configuration.maximumFrequencyHz.isFinite,
              configuration.maximumFrequencyHz > configuration.minimumFrequencyHz,
              configuration.maximumFrequencyHz <= reference.sampleRate / 2,
              configuration.expectedFrequencyRatio.isFinite,
              configuration.expectedFrequencyRatio > 0,
              configuration.expectedFrequencyRatio <= 8,
              configuration.frequencyRatioSearchRadiusCents.isFinite,
              configuration.frequencyRatioSearchRadiusCents >= 0,
              configuration.frequencyRatioSearchRadiusCents <= 2_400,
              configuration.frequencyRatioSearchStepCents.isFinite,
              configuration.frequencyRatioSearchStepCents > 0,
              (configuration.frequencyRatioSearchRadiusCents == 0 || configuration.frequencyRatioSearchStepCents <= configuration.frequencyRatioSearchRadiusCents),
              configuration.highBandStartHz.isFinite,
              configuration.highBandStartHz >= configuration.minimumFrequencyHz,
              configuration.highBandStartHz < configuration.maximumFrequencyHz,
              configuration.spectralFloorDB.isFinite,
              configuration.spectralFloorDB <= 0,
              configuration.minimumWindowRMS.isFinite,
              configuration.minimumWindowRMS >= 0,
              configuration.maximumWindows > 0 else {
            throw Lane3SpectralDifferentialError.invalidConfiguration
        }
    }

    static func isPowerOfTwo(_ value: Int) -> Bool {
        value > 0 && (value & (value - 1)) == 0
    }

    static func collapseToMono(_ input: Lane3PCMBufferDescriptor) -> (samples: [Double], nonFinite: Int64) {
        let frames = Int(input.frameCount)
        var mono = [Double](repeating: 0, count: frames)
        var nonFinite: Int64 = 0
        for frame in 0..<frames {
            var sum = 0.0
            var count = 0
            for channel in 0..<input.channels {
                let value = Double(input.interleavedSamples[frame * input.channels + channel])
                if value.isFinite {
                    sum += value
                    count += 1
                } else {
                    nonFinite += 1
                }
            }
            mono[frame] = count > 0 ? sum / Double(count) : 0
        }
        return (mono, nonFinite)
    }

    struct AlignedRange {
        let referenceStart: Int
        let observedStart: Int
        let count: Int
    }

    static func alignedRanges(referenceCount: Int, observedCount: Int, lag: Int) -> AlignedRange {
        let referenceStart = max(0, -lag)
        let observedStart = max(0, lag)
        let count = max(0, min(referenceCount - referenceStart, observedCount - observedStart))
        return AlignedRange(referenceStart: referenceStart, observedStart: observedStart, count: count)
    }

    static func selectedWindowStarts(comparableFrames: Int, windowSize: Int, hopSize: Int, maximumWindows: Int) -> [Int] {
        guard comparableFrames >= windowSize else { return [] }
        var starts: [Int] = []
        var start = 0
        while start + windowSize <= comparableFrames {
            starts.append(start)
            start += hopSize
        }
        guard starts.count > maximumWindows else { return starts }
        if maximumWindows == 1 { return [starts[starts.count / 2]] }
        return (0..<maximumWindows).map { index in
            let position = Double(index) * Double(starts.count - 1) / Double(maximumWindows - 1)
            return starts[Int(position.rounded())]
        }
    }

    static func hannWindow(_ size: Int) -> [Double] {
        guard size > 1 else { return [1] }
        return (0..<size).map { index in
            0.5 - 0.5 * cos(2 * Double.pi * Double(index) / Double(size - 1))
        }
    }

    struct Complex {
        var real: Double
        var imag: Double
    }

    static func powerSpectrum(_ samples: [Double], window: [Double]) -> [Double] {
        let n = samples.count
        var values = [Complex](repeating: Complex(real: 0, imag: 0), count: n)
        for index in 0..<n {
            values[index].real = samples[index] * window[index]
        }
        fft(&values)
        var output = [Double](repeating: 0, count: n / 2 + 1)
        for bin in 0..<output.count {
            let real = values[bin].real
            let imag = values[bin].imag
            output[bin] = max(0, real * real + imag * imag)
        }
        return output
    }

    static func fft(_ values: inout [Complex]) {
        let n = values.count
        var j = 0
        if n > 1 {
            for i in 1..<(n - 1) {
                var bit = n >> 1
                while j & bit != 0 {
                    j ^= bit
                    bit >>= 1
                }
                j ^= bit
                if i < j { values.swapAt(i, j) }
            }
        }
        var length = 2
        while length <= n {
            let angle = -2 * Double.pi / Double(length)
            let wLength = Complex(real: cos(angle), imag: sin(angle))
            var start = 0
            while start < n {
                var w = Complex(real: 1, imag: 0)
                for offset in 0..<(length / 2) {
                    let evenIndex = start + offset
                    let oddIndex = evenIndex + length / 2
                    let odd = multiply(values[oddIndex], w)
                    let even = values[evenIndex]
                    values[evenIndex] = Complex(real: even.real + odd.real, imag: even.imag + odd.imag)
                    values[oddIndex] = Complex(real: even.real - odd.real, imag: even.imag - odd.imag)
                    w = multiply(w, wLength)
                }
                start += length
            }
            length <<= 1
        }
    }

    static func multiply(_ lhs: Complex, _ rhs: Complex) -> Complex {
        Complex(
            real: lhs.real * rhs.real - lhs.imag * rhs.imag,
            imag: lhs.real * rhs.imag + lhs.imag * rhs.real
        )
    }

    static func estimateFrequencyRatio(
        referencePower: [Double],
        observedPower: [Double],
        sampleRate: Double,
        configuration: Lane3SpectralDifferentialConfiguration
    ) -> (ratio: Double, correlation: Double) {
        if configuration.frequencyRatioSearchRadiusCents == 0 {
            let ratio = configuration.expectedFrequencyRatio
            return (ratio, scaleCorrelation(referencePower: referencePower, observedPower: observedPower, ratio: ratio, sampleRate: sampleRate, configuration: configuration))
        }
        let steps = Int((configuration.frequencyRatioSearchRadiusCents / configuration.frequencyRatioSearchStepCents).rounded(.down))
        var bestRatio = configuration.expectedFrequencyRatio
        var bestCorrelation = -Double.infinity
        for step in (-steps)...steps {
            let cents = Double(step) * configuration.frequencyRatioSearchStepCents
            let ratio = configuration.expectedFrequencyRatio * pow(2, cents / 1_200)
            let score = scaleCorrelation(
                referencePower: referencePower,
                observedPower: observedPower,
                ratio: ratio,
                sampleRate: sampleRate,
                configuration: configuration
            )
            if score > bestCorrelation || (score == bestCorrelation && abs(cents) < abs(centsError(actualRatio: bestRatio, expectedRatio: configuration.expectedFrequencyRatio))) {
                bestCorrelation = score
                bestRatio = ratio
            }
        }
        return (bestRatio, bestCorrelation)
    }

    static func scaleCorrelation(
        referencePower: [Double],
        observedPower: [Double],
        ratio: Double,
        sampleRate: Double,
        configuration: Lane3SpectralDifferentialConfiguration
    ) -> Double {
        let warped = normalizeSpectrum(warpedReferencePower(referencePower: referencePower, ratio: ratio, outputBinCount: observedPower.count))
        let observedNormalized = normalizeSpectrum(observedPower)
        let range = analysisBinRange(sampleRate: sampleRate, windowSize: (referencePower.count - 1) * 2, configuration: configuration, binCount: observedPower.count)
        var dot = 0.0
        var rr = 0.0
        var oo = 0.0
        for bin in range {
            let r = log1p(max(0, warped[bin]) * 1e9)
            let o = log1p(max(0, observedNormalized[bin]) * 1e9)
            dot += r * o
            rr += r * r
            oo += o * o
        }
        let denominator = sqrt(rr * oo)
        return denominator > 1e-20 ? max(-1, min(1, dot / denominator)) : 0
    }

    struct SpectralPeak {
        let frequencyHz: Double
        let power: Double
    }

    static func spectralPeakMatches(
        referencePower: [Double],
        observedPower: [Double],
        sampleRate: Double,
        configuration: Lane3SpectralDifferentialConfiguration
    ) -> [Lane3SpectralPeakMatchObservation] {
        let referencePeaks = spectralPeaks(power: referencePower, sampleRate: sampleRate, configuration: configuration)
        let observedPeaks = spectralPeaks(power: observedPower, sampleRate: sampleRate, configuration: configuration)
        guard !referencePeaks.isEmpty, !observedPeaks.isEmpty else { return [] }
        var usedObserved = Set<Int>()
        var matches: [Lane3SpectralPeakMatchObservation] = []
        let tolerance = max(50, min(100, configuration.frequencyRatioSearchRadiusCents / 2 + configuration.frequencyRatioSearchStepCents * 2))
        for referencePeak in referencePeaks {
            let expected = referencePeak.frequencyHz * configuration.expectedFrequencyRatio
            guard expected >= configuration.minimumFrequencyHz, expected <= configuration.maximumFrequencyHz else { continue }
            var bestIndex: Int?
            var bestAbsoluteCents = Double.infinity
            var bestSignedCents = 0.0
            for (index, observedPeak) in observedPeaks.enumerated() where !usedObserved.contains(index) {
                let signed = centsError(actualRatio: observedPeak.frequencyHz / max(referencePeak.frequencyHz, 1e-12), expectedRatio: configuration.expectedFrequencyRatio)
                let absolute = abs(signed)
                if absolute < bestAbsoluteCents {
                    bestAbsoluteCents = absolute
                    bestSignedCents = signed
                    bestIndex = index
                }
            }
            if let bestIndex, bestAbsoluteCents <= tolerance {
                usedObserved.insert(bestIndex)
                matches.append(
                    Lane3SpectralPeakMatchObservation(
                        referenceFrequencyHz: referencePeak.frequencyHz,
                        expectedObservedFrequencyHz: expected,
                        observedFrequencyHz: observedPeaks[bestIndex].frequencyHz,
                        ratioErrorCents: bestSignedCents
                    )
                )
            }
        }
        return matches.sorted { abs($0.ratioErrorCents) < abs($1.ratioErrorCents) }
    }

    static func spectralPeaks(
        power: [Double],
        sampleRate: Double,
        configuration: Lane3SpectralDifferentialConfiguration
    ) -> [SpectralPeak] {
        let windowSize = max(2, (power.count - 1) * 2)
        let range = analysisBinRange(sampleRate: sampleRate, windowSize: windowSize, configuration: configuration, binCount: power.count)
        guard range.count >= 3 else { return [] }
        let maximum = range.map { max(0, power[$0]) }.max() ?? 0
        guard maximum > 1e-30 else { return [] }
        let threshold = maximum * 1e-5
        let hzPerBin = sampleRate / Double(windowSize)
        var peaks: [SpectralPeak] = []
        let lower = max(range.lowerBound + 1, 1)
        let upper = min(range.upperBound - 1, power.count - 1)
        guard lower < upper else { return [] }
        for bin in lower..<upper {
            let center = max(power[bin], 1e-30)
            guard center >= threshold, center > power[bin - 1], center >= power[bin + 1] else { continue }
            let leftLog = log(max(power[bin - 1], 1e-30))
            let centerLog = log(center)
            let rightLog = log(max(power[bin + 1], 1e-30))
            let denominator = leftLog - 2 * centerLog + rightLog
            var delta = 0.0
            if abs(denominator) > 1e-12 {
                delta = 0.5 * (leftLog - rightLog) / denominator
                delta = max(-0.5, min(0.5, delta))
            }
            peaks.append(SpectralPeak(frequencyHz: (Double(bin) + delta) * hzPerBin, power: center))
        }
        return Array(peaks.sorted { $0.power > $1.power }.prefix(32))
    }

}
