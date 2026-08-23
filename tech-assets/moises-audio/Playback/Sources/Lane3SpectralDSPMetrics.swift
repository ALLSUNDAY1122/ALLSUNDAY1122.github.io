import Foundation

extension Lane3SpectralPerceptualDifferentialAnalyzer {
    static func warpedReferencePower(referencePower: [Double], ratio: Double, outputBinCount: Int) -> [Double] {
        var output = [Double](repeating: 0, count: outputBinCount)
        guard ratio > 0 else { return output }
        for outputBin in 0..<outputBinCount {
            let sourcePosition = Double(outputBin) / ratio
            let lower = Int(floor(sourcePosition))
            let upper = lower + 1
            guard lower >= 0, lower < referencePower.count else { continue }
            if upper < referencePower.count {
                let fraction = sourcePosition - Double(lower)
                output[outputBin] = referencePower[lower] * (1 - fraction) + referencePower[upper] * fraction
            } else {
                output[outputBin] = referencePower[lower]
            }
        }
        return output
    }

    static func normalizeSpectrum(_ power: [Double]) -> [Double] {
        let total = power.reduce(0) { $0 + max(0, $1) }
        guard total > 1e-30 else { return [Double](repeating: 0, count: power.count) }
        return power.map { max(0, $0) / total }
    }

    static func analysisBinRange(
        sampleRate: Double,
        windowSize: Int,
        configuration: Lane3SpectralDifferentialConfiguration,
        binCount: Int
    ) -> Range<Int> {
        let hzPerBin = sampleRate / Double(windowSize)
        let lower = max(1, Int(ceil(configuration.minimumFrequencyHz / hzPerBin)))
        let upperInclusive = min(binCount - 1, Int(floor(configuration.maximumFrequencyHz / hzPerBin)))
        return lower..<max(lower, upperInclusive + 1)
    }

    static func logSpectralDistanceDB(
        expectedReference: [Double],
        observed: [Double],
        sampleRate: Double,
        windowSize: Int,
        configuration: Lane3SpectralDifferentialConfiguration
    ) -> Double {
        let range = analysisBinRange(sampleRate: sampleRate, windowSize: windowSize, configuration: configuration, binCount: min(expectedReference.count, observed.count))
        guard !range.isEmpty else { return 0 }
        let floorPower = pow(10, configuration.spectralFloorDB / 10)
        var sumSquares = 0.0
        for bin in range {
            let refDB = 10 * log10(max(expectedReference[bin], floorPower))
            let obsDB = 10 * log10(max(observed[bin], floorPower))
            let delta = obsDB - refDB
            sumSquares += delta * delta
        }
        return sqrt(sumSquares / Double(range.count))
    }

    static func spectralCentroidHz(
        power: [Double],
        sampleRate: Double,
        windowSize: Int,
        configuration: Lane3SpectralDifferentialConfiguration
    ) -> Double {
        let range = analysisBinRange(sampleRate: sampleRate, windowSize: windowSize, configuration: configuration, binCount: power.count)
        let hzPerBin = sampleRate / Double(windowSize)
        var weighted = 0.0
        var total = 0.0
        for bin in range {
            let value = max(0, power[bin])
            weighted += Double(bin) * hzPerBin * value
            total += value
        }
        return total > 1e-30 ? weighted / total : configuration.minimumFrequencyHz
    }

    static func spectralFlatness(
        power: [Double],
        sampleRate: Double,
        windowSize: Int,
        configuration: Lane3SpectralDifferentialConfiguration
    ) -> Double {
        let range = analysisBinRange(sampleRate: sampleRate, windowSize: windowSize, configuration: configuration, binCount: power.count)
        guard !range.isEmpty else { return 0 }
        let floorValue = 1e-30
        var logSum = 0.0
        var arithmetic = 0.0
        for bin in range {
            let value = max(power[bin], floorValue)
            logSum += log(value)
            arithmetic += value
        }
        let geometric = exp(logSum / Double(range.count))
        arithmetic /= Double(range.count)
        return arithmetic > 0 ? geometric / arithmetic : 0
    }

    static func highBandEnergyFraction(
        power: [Double],
        sampleRate: Double,
        windowSize: Int,
        configuration: Lane3SpectralDifferentialConfiguration
    ) -> Double {
        let range = analysisBinRange(sampleRate: sampleRate, windowSize: windowSize, configuration: configuration, binCount: power.count)
        let hzPerBin = sampleRate / Double(windowSize)
        var high = 0.0
        var total = 0.0
        for bin in range {
            let value = max(0, power[bin])
            total += value
            if Double(bin) * hzPerBin >= configuration.highBandStartHz { high += value }
        }
        return total > 1e-30 ? high / total : 0
    }

    static func bandEnergyCosineDistance(
        referencePower: [Double],
        observedPower: [Double],
        sampleRate: Double,
        windowSize: Int,
        configuration: Lane3SpectralDifferentialConfiguration
    ) -> Double {
        let edges = logarithmicBandEdges(minHz: max(configuration.minimumFrequencyHz, 20), maxHz: configuration.maximumFrequencyHz, bands: 8)
        let ref = bandEnergies(power: referencePower, sampleRate: sampleRate, windowSize: windowSize, edges: edges)
        let obs = bandEnergies(power: observedPower, sampleRate: sampleRate, windowSize: windowSize, edges: edges)
        var dot = 0.0
        var rr = 0.0
        var oo = 0.0
        for index in ref.indices {
            dot += ref[index] * obs[index]
            rr += ref[index] * ref[index]
            oo += obs[index] * obs[index]
        }
        let denominator = sqrt(rr * oo)
        let cosine = denominator > 1e-30 ? max(0, min(1, dot / denominator)) : 1
        return 1 - cosine
    }

    static func logarithmicBandEdges(minHz: Double, maxHz: Double, bands: Int) -> [Double] {
        let logMin = log(max(minHz, 1))
        let logMax = log(max(maxHz, minHz + 1))
        return (0...bands).map { index in
            exp(logMin + (logMax - logMin) * Double(index) / Double(bands))
        }
    }

    static func bandEnergies(power: [Double], sampleRate: Double, windowSize: Int, edges: [Double]) -> [Double] {
        guard edges.count >= 2 else { return [] }
        let hzPerBin = sampleRate / Double(windowSize)
        var output = [Double](repeating: 0, count: edges.count - 1)
        for bin in 1..<power.count {
            let frequency = Double(bin) * hzPerBin
            if let index = (0..<(edges.count - 1)).first(where: { frequency >= edges[$0] && frequency < edges[$0 + 1] }) {
                output[index] += max(0, power[bin])
            }
        }
        let total = output.reduce(0, +)
        return total > 1e-30 ? output.map { $0 / total } : output
    }

    static func spectralFlux(previous: [Double], current: [Double]) -> Double {
        let count = min(previous.count, current.count)
        guard count > 0 else { return 0 }
        var sum = 0.0
        for index in 0..<count {
            let delta = max(0, current[index] - previous[index])
            sum += delta * delta
        }
        return sqrt(sum / Double(count))
    }

    static func rms(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        var sum = 0.0
        var count = 0
        for value in values where value.isFinite {
            sum += value * value
            count += 1
        }
        return count > 0 ? sqrt(sum / Double(count)) : 0
    }

    static func correlation(_ lhs: [Double], _ rhs: [Double]) -> Double {
        let count = min(lhs.count, rhs.count)
        guard count >= 2 else { return count == 1 ? 1 : 0 }
        let meanL = lhs.prefix(count).reduce(0, +) / Double(count)
        let meanR = rhs.prefix(count).reduce(0, +) / Double(count)
        var numerator = 0.0
        var ll = 0.0
        var rr = 0.0
        for index in 0..<count {
            let a = lhs[index] - meanL
            let b = rhs[index] - meanR
            numerator += a * b
            ll += a * a
            rr += b * b
        }
        let denominator = sqrt(ll * rr)
        if denominator <= 1e-30 {
            return zip(lhs.prefix(count), rhs.prefix(count)).allSatisfy { abs($0 - $1) <= 1e-12 } ? 1 : 0
        }
        return max(-1, min(1, numerator / denominator))
    }

    static func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count % 2 == 0 { return (sorted[middle - 1] + sorted[middle]) / 2 }
        return sorted[middle]
    }

    static func percentile95(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = min(sorted.count - 1, Int((0.95 * Double(sorted.count - 1)).rounded(.up)))
        return sorted[index]
    }

    static func centsError(actualRatio: Double, expectedRatio: Double) -> Double {
        guard actualRatio > 0, expectedRatio > 0 else { return 0 }
        return 1_200 * log2(actualRatio / expectedRatio)
    }

    static func powerLikeDBDelta(observed: Double, reference: Double) -> Double {
        10 * log10(max(observed, 1e-12)) - 10 * log10(max(reference, 1e-12))
    }
}
