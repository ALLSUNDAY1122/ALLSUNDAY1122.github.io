import Foundation

public enum BoundedTempoBeatAnalyzer {
    private struct Candidate {
        let lag: Int
        let bpm: Double
        let correlation: Double
        let phase: Int
        let gridAlignment: Double
        let weightedScore: Double
    }

    public static func analyze(
        signal: AnalysisSignal,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> TempoAnalysis? {
        let samples = signal.monoSamples
        let frameSize = min(
            configuration.analysisWindowSize,
            max(256, Int((signal.sampleRate * 0.046).rounded()))
        )
        let hopSize = min(
            configuration.analysisHopSize,
            max(32, Int((signal.sampleRate * 0.010).rounded()))
        )
        guard samples.count >= frameSize,
              signal.durationSeconds >= configuration.minimumDurationSeconds else {
            return nil
        }

        let onset = onsetEnvelope(samples: samples, frameSize: frameSize, hopSize: hopSize)
        guard onset.count >= 8 else { return nil }
        let maxOnset = onset.max() ?? 0
        let meanOnset = onset.reduce(0, +) / Double(onset.count)
        guard maxOnset > 1e-7, meanOnset > 1e-9 else { return nil }

        // Keep the bounded-memory path aligned with the canonical tempo analyzer's
        // fail-closed transient gate. A sustained sinusoid can produce tiny periodic
        // RMS-window leakage when frame and carrier periods are incommensurate; high
        // autocorrelation alone must not turn that leakage into a confident tempo.
        let peakiness = maxOnset / meanOnset
        let strongFraction = Double(onset.filter { $0 >= maxOnset * 0.5 }.count) / Double(onset.count)
        let transientness = peakiness * max(0, 1 - min(1, strongFraction * 4))
        let signalRMS = AnalysisWorkingSetPolicy.rms(
            samples,
            maximumSamples: AnalysisWorkingSetPolicy.maximumRMSProbeSamples
        )
        let transientContrast = maxOnset / max(log1p(signalRMS), 1e-9)
        guard transientContrast >= 0.01 else { return nil }
        if transientness < 2.5, transientContrast < 0.08 {
            return nil
        }

        let envelopeRate = signal.sampleRate / Double(hopSize)
        let minLag = max(1, Int(floor(60 * envelopeRate / configuration.tempoRange.upperBound)))
        let maxLag = min(onset.count - 2, Int(ceil(60 * envelopeRate / configuration.tempoRange.lowerBound)))
        guard maxLag > minLag else { return nil }

        var candidates: [Candidate] = []
        candidates.reserveCapacity(maxLag - minLag + 1)
        for lag in minLag...maxLag {
            let correlation = normalizedAutocorrelation(onset, lag: lag)
            guard correlation > 0.025 else { continue }
            let phaseAndAlignment = bestPhase(onset: onset, lag: lag, maxOnset: maxOnset)
            let bpm = 60 * envelopeRate / Double(lag)
            let prior = tempoPrior(bpm)
            let score = correlation * 0.62 + phaseAndAlignment.alignment * 0.30 + prior * 0.08
            candidates.append(
                Candidate(
                    lag: lag,
                    bpm: bpm,
                    correlation: correlation,
                    phase: phaseAndAlignment.phase,
                    gridAlignment: phaseAndAlignment.alignment,
                    weightedScore: score
                )
            )
        }
        guard !candidates.isEmpty else { return nil }
        candidates.sort {
            if abs($0.weightedScore - $1.weightedScore) <= 1e-12 {
                return abs(log2($0.bpm / 120)) < abs(log2($1.bpm / 120))
            }
            return $0.weightedScore > $1.weightedScore
        }

        guard let best = resolveMetricalCandidate(candidates) else { return nil }
        guard transientness >= 2.5 || best.correlation >= 0.22 || best.gridAlignment >= 0.35 else {
            return nil
        }

        let hopSeconds = Double(hopSize) / signal.sampleRate
        let onsetOffsetSeconds = Double(frameSize) / signal.sampleRate
        let beatTimes = trackedBeatTimes(
            onset: onset,
            lag: best.lag,
            phase: best.phase,
            hopSeconds: hopSeconds,
            onsetOffsetSeconds: onsetOffsetSeconds,
            durationSeconds: signal.durationSeconds
        )
        guard beatTimes.count >= 2 else { return nil }

        let intervals = zip(beatTimes, beatTimes.dropFirst()).map { $1 - $0 }.filter { $0 > 1e-6 }
        guard let medianInterval = median(intervals), medianInterval > 1e-6 else { return nil }
        let trackedBPM = 60 / medianInterval
        guard configuration.tempoRange.contains(trackedBPM) else { return nil }

        let ambiguity = metricalAmbiguity(best: best, candidates: candidates)
        let confidence = clamp01(
            (best.correlation * 0.54 + best.gridAlignment * 0.36 + tempoPrior(trackedBPM) * 0.10)
                * ambiguity
        )
        guard confidence >= configuration.minimumTempoConfidence else { return nil }

        return TempoAnalysis(
            bpm: trackedBPM,
            confidence: confidence,
            beatTimesSeconds: beatTimes
        )
    }

    private static func onsetEnvelope(samples: [Float], frameSize: Int, hopSize: Int) -> [Double] {
        guard samples.count >= frameSize else { return [] }
        let frameCount = 1 + (samples.count - frameSize) / hopSize
        var flux: [Double] = []
        flux.reserveCapacity(frameCount)
        var previousEnergy: Double?
        var start = 0
        while start + frameSize <= samples.count {
            var sumSquares = 0.0
            for index in start..<(start + frameSize) {
                let value = Double(AnalysisWorkingSetPolicy.boundedFinite(samples[index]))
                sumSquares += value * value
            }
            let energy = log1p(sqrt(sumSquares / Double(frameSize)))
            if let previousEnergy {
                flux.append(max(0, energy - previousEnergy))
            } else {
                flux.append(0)
            }
            previousEnergy = energy
            start += hopSize
        }

        let positive = flux.filter { $0 > 0 }.sorted()
        guard !positive.isEmpty else { return flux }
        let floorValue = positive[positive.count / 2] * 0.25
        if floorValue > 0 {
            for index in flux.indices {
                flux[index] = max(0, flux[index] - floorValue)
            }
        }
        return flux
    }

    private static func normalizedAutocorrelation(_ values: [Double], lag: Int) -> Double {
        guard lag > 0, lag < values.count else { return 0 }
        let pairCount = values.count - lag
        let stride = max(1, Int(ceil(Double(pairCount) / 120_000.0)))
        var dot = 0.0
        var leftEnergy = 0.0
        var rightEnergy = 0.0
        var index = 0
        while index < pairCount {
            let left = values[index]
            let right = values[index + lag]
            dot += left * right
            leftEnergy += left * left
            rightEnergy += right * right
            index += stride
        }
        let denominator = sqrt(leftEnergy * rightEnergy)
        guard denominator > 1e-12 else { return 0 }
        return max(0, min(1, dot / denominator))
    }

    private static func bestPhase(onset: [Double], lag: Int, maxOnset: Double) -> (phase: Int, alignment: Double) {
        guard lag > 0, maxOnset > 0 else { return (0, 0) }
        let strongest = onset.enumerated().sorted { $0.element > $1.element }.prefix(32)
        var phases = Set(strongest.map { $0.offset % lag })
        phases.insert(0)
        let tolerance = max(1, Int((Double(lag) * 0.10).rounded()))
        var bestPhase = 0
        var bestAlignment = 0.0

        for phase in phases {
            var score = 0.0
            var count = 0
            var position = phase
            while position < onset.count {
                let lower = max(0, position - tolerance)
                let upper = min(onset.count - 1, position + tolerance)
                var localMaximum = 0.0
                if lower <= upper {
                    for index in lower...upper {
                        localMaximum = max(localMaximum, onset[index])
                    }
                }
                score += localMaximum / maxOnset
                count += 1
                position += lag
            }
            let alignment = count > 0 ? score / Double(count) : 0
            if alignment > bestAlignment {
                bestAlignment = alignment
                bestPhase = phase
            }
        }
        return (bestPhase, bestAlignment)
    }

    private static func resolveMetricalCandidate(_ candidates: [Candidate]) -> Candidate? {
        guard var selected = candidates.first else { return nil }
        for candidate in candidates.dropFirst().prefix(12) {
            let ratio = candidate.bpm / selected.bpm
            let isOctaveRelated = abs(ratio - 2) <= 0.08 || abs(ratio - 0.5) <= 0.04
            guard isOctaveRelated else { continue }
            if candidate.correlation >= selected.correlation * 0.88,
               candidate.gridAlignment >= selected.gridAlignment + 0.08,
               candidate.weightedScore >= selected.weightedScore * 0.94 {
                selected = candidate
            }
        }
        return selected
    }

    private static func trackedBeatTimes(
        onset: [Double],
        lag: Int,
        phase: Int,
        hopSeconds: Double,
        onsetOffsetSeconds: Double,
        durationSeconds: Double
    ) -> [Double] {
        guard lag > 0, hopSeconds > 0 else { return [] }
        let tolerance = max(1, Int((Double(lag) * 0.18).rounded()))
        var indices: [Int] = []
        var predicted = phase
        while predicted < onset.count {
            let lower = max(0, predicted - tolerance)
            let upper = min(onset.count - 1, predicted + tolerance)
            var bestIndex = predicted
            var bestValue = -Double.infinity
            if lower <= upper {
                for index in lower...upper where onset[index] > bestValue {
                    bestValue = onset[index]
                    bestIndex = index
                }
            }
            if let last = indices.last, bestIndex <= last {
                bestIndex = max(last + 1, predicted)
            }
            if bestIndex < onset.count { indices.append(bestIndex) }
            predicted += lag
        }

        var times: [Double] = []
        times.reserveCapacity(indices.count)
        for index in indices {
            let time = min(durationSeconds, max(0, onsetOffsetSeconds + Double(index) * hopSeconds))
            if let last = times.last, time - last <= 1e-6 { continue }
            if time <= durationSeconds + 1e-6 { times.append(time) }
        }
        return times
    }

    private static func metricalAmbiguity(best: Candidate, candidates: [Candidate]) -> Double {
        let related = candidates.filter { candidate in
            guard candidate.lag != best.lag else { return false }
            let ratio = candidate.bpm / best.bpm
            return abs(ratio - 2) <= 0.08 || abs(ratio - 0.5) <= 0.04
        }
        guard let rival = related.max(by: { $0.weightedScore < $1.weightedScore }) else { return 1 }
        let margin = max(0, best.weightedScore - rival.weightedScore)
        return clamp01(0.72 + min(0.28, margin * 2.2))
    }

    private static func tempoPrior(_ bpm: Double) -> Double {
        guard bpm > 0 else { return 0 }
        return exp(-pow(log2(bpm / 120), 2) / 1.4)
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    private static func clamp01(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
