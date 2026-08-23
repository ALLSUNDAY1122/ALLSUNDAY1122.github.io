import Foundation

public enum TempoBeatAnalyzer {
    public static func analyze(signal: AnalysisSignal, configuration: MusicAnalysisConfiguration = .productBaseline) -> TempoAnalysis? {
        let samples = finiteSamples(signal.monoSamples)
        let tempoFrameSize = min(configuration.analysisWindowSize, max(256, Int((signal.sampleRate * 0.046).rounded())))
        let tempoHopSize = min(configuration.analysisHopSize, max(32, Int((signal.sampleRate * 0.010).rounded())))
        guard samples.count >= tempoFrameSize,
              signal.durationSeconds >= configuration.minimumDurationSeconds else {
            return nil
        }

        let onset = onsetEnvelope(samples: samples, frameSize: tempoFrameSize, hopSize: tempoHopSize)
        guard onset.count >= 8 else { return nil }

        let maxOnset = onset.max() ?? 0
        let onsetMean = onset.reduce(0, +) / Double(onset.count)
        guard maxOnset > 1e-7, onsetMean > 1e-9 else { return nil }
        let peakiness = maxOnset / onsetMean
        let strongFraction = Double(onset.filter { $0 >= maxOnset * 0.5 }.count) / Double(onset.count)
        let transientness = peakiness * max(0, 1 - min(1, strongFraction * 4))
        guard transientness >= 5 else { return nil }

        let envelopeRate = signal.sampleRate / Double(tempoHopSize)
        let minLag = max(1, Int(floor((60.0 * envelopeRate) / configuration.tempoRange.upperBound)))
        let maxLag = min(onset.count - 2, Int(ceil((60.0 * envelopeRate) / configuration.tempoRange.lowerBound)))
        guard maxLag > minLag else { return nil }

        var candidates: [(lag: Int, bpm: Double, correlation: Double, weighted: Double)] = []
        for lag in minLag...maxLag {
            let correlation = normalizedAutocorrelation(onset, lag: lag)
            guard correlation > 0 else { continue }
            let bpm = 60.0 * envelopeRate / Double(lag)
            let prior = tempoPrior(bpm)
            var metricalFactor = 1.0
            let halfLagFloor = lag / 2
            let halfLagCeil = (lag + 1) / 2
            let halfLagCandidates = [halfLagFloor, halfLagCeil].filter { $0 >= minLag }
            if !halfLagCandidates.isEmpty {
                let subdivisionCorrelation = halfLagCandidates
                    .map { normalizedAutocorrelation(onset, lag: $0) }
                    .max() ?? 0
                if subdivisionCorrelation >= correlation * 0.82 {
                    metricalFactor = 0.35
                }
            }
            candidates.append((lag, bpm, correlation, correlation * prior * metricalFactor))
        }
        guard let best = candidates.max(by: { $0.weighted < $1.weighted }) else { return nil }

        let beatTimes = inferBeatTimes(
            onset: onset,
            hopSeconds: Double(tempoHopSize) / signal.sampleRate,
            onsetOffsetSeconds: Double(tempoFrameSize) / signal.sampleRate,
            periodSeconds: 60.0 / best.bpm,
            durationSeconds: signal.durationSeconds
        )
        guard beatTimes.count >= 2 else { return nil }

        let peakValues = beatTimes.compactMap { time -> Double? in
            let index = Int((time * envelopeRate).rounded())
            guard onset.indices.contains(index) else { return nil }
            return onset[index] / maxOnset
        }
        let alignment = peakValues.isEmpty ? 0 : peakValues.reduce(0, +) / Double(peakValues.count)
        let confidence = clamp01((best.correlation * 0.72) + (alignment * 0.28))
        guard confidence >= configuration.minimumTempoConfidence else { return nil }

        return TempoAnalysis(bpm: best.bpm, confidence: confidence, beatTimesSeconds: beatTimes)
    }

    private static func finiteSamples(_ samples: [Float]) -> [Double] {
        samples.map { sample in
            let value = Double(sample)
            return value.isFinite ? value : 0
        }
    }

    private static func onsetEnvelope(samples: [Double], frameSize: Int, hopSize: Int) -> [Double] {
        guard samples.count >= frameSize else { return [] }
        var energies: [Double] = []
        var start = 0
        while start + frameSize <= samples.count {
            var sumSquares = 0.0
            for index in start..<(start + frameSize) {
                let value = samples[index]
                sumSquares += value * value
            }
            energies.append(log1p(sqrt(sumSquares / Double(frameSize))))
            start += hopSize
        }
        guard energies.count > 1 else { return [] }

        var flux = Array(repeating: 0.0, count: energies.count)
        for index in 1..<energies.count {
            flux[index] = max(0, energies[index] - energies[index - 1])
        }

        let positive = flux.filter { $0 > 0 }.sorted()
        let floorValue: Double
        if positive.isEmpty {
            floorValue = 0
        } else {
            floorValue = positive[positive.count / 2] * 0.25
        }
        if floorValue > 0 {
            for index in flux.indices {
                flux[index] = max(0, flux[index] - floorValue)
            }
        }
        return flux
    }

    private static func normalizedAutocorrelation(_ values: [Double], lag: Int) -> Double {
        guard lag > 0, lag < values.count else { return 0 }
        var dot = 0.0
        var leftEnergy = 0.0
        var rightEnergy = 0.0
        for index in lag..<values.count {
            let left = values[index]
            let right = values[index - lag]
            dot += left * right
            leftEnergy += left * left
            rightEnergy += right * right
        }
        let denominator = sqrt(leftEnergy * rightEnergy)
        guard denominator > 1e-12 else { return 0 }
        return max(0, min(1, dot / denominator))
    }

    private static func tempoPrior(_ bpm: Double) -> Double {
        let octaveDistance = log2(bpm / 120.0)
        return exp(-0.5 * pow(octaveDistance / 0.72, 2))
    }

    private static func inferBeatTimes(onset: [Double], hopSeconds: Double, onsetOffsetSeconds: Double, periodSeconds: Double, durationSeconds: Double) -> [Double] {
        guard !onset.isEmpty, hopSeconds > 0, periodSeconds > 0 else { return [] }
        let searchFrames = max(1, Int((periodSeconds / hopSeconds * 0.20).rounded()))
        let anchorLimit = min(onset.count, max(1, Int((periodSeconds * 2 / hopSeconds).rounded())))
        let anchorIndex = (0..<anchorLimit).max(by: { onset[$0] < onset[$1] }) ?? 0
        let anchorTime = Double(anchorIndex) * hopSeconds + onsetOffsetSeconds

        var idealTimes: [Double] = []
        var time = anchorTime
        while time - periodSeconds >= 0 { time -= periodSeconds }
        while time <= durationSeconds + 1e-9 {
            idealTimes.append(time)
            time += periodSeconds
        }

        var aligned: [Double] = []
        for ideal in idealTimes {
            let center = Int(((ideal - onsetOffsetSeconds) / hopSeconds).rounded())
            let lower = max(0, center - searchFrames)
            let upper = min(onset.count - 1, center + searchFrames)
            guard lower <= upper else { continue }
            let bestIndex = (lower...upper).max(by: { onset[$0] < onset[$1] }) ?? center
            let candidate = Double(bestIndex) * hopSeconds + onsetOffsetSeconds
            if candidate >= 0, candidate <= durationSeconds,
               aligned.last.map({ candidate - $0 > hopSeconds * 0.5 }) ?? true {
                aligned.append(candidate)
            }
        }
        return aligned
    }

    private static func clamp01(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
