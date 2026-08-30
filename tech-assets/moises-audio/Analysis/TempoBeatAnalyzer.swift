import Foundation

public enum TempoBeatAnalyzer {
    private struct GridScore {
        let score: Double
        let beatStrength: Double
        let onsetCoverage: Double
        let phase: Int
    }

    private struct CandidateSeed {
        let lag: Int
        let bpm: Double
        let correlation: Double
        let grid: GridScore
    }

    private struct TempoCandidate {
        let lag: Int
        let bpm: Double
        let correlation: Double
        let grid: GridScore
        let weighted: Double
    }

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
        let signalRMS = sqrt(samples.reduce(0.0) { $0 + ($1 * $1) } / Double(samples.count))
        let transientContrast = maxOnset / max(log1p(signalRMS), 1e-9)
        guard transientContrast >= 0.01 else { return nil }
        if transientness < 2.5, transientContrast < 0.08 {
            return nil
        }

        let envelopeRate = signal.sampleRate / Double(tempoHopSize)
        let minLag = max(1, Int(floor((60.0 * envelopeRate) / configuration.tempoRange.upperBound)))
        let maxLag = min(onset.count - 2, Int(ceil((60.0 * envelopeRate) / configuration.tempoRange.lowerBound)))
        guard maxLag > minLag else { return nil }

        let candidates = tempoCandidates(onset: onset, minLag: minLag, maxLag: maxLag, envelopeRate: envelopeRate)
        guard let best = candidates.first else { return nil }

        // Weak but periodic percussion should remain analyzable, while sustained or noise-like
        // material must still fail closed instead of inventing a tempo.
        guard transientness >= 2.5 || best.correlation >= 0.22 || best.grid.score >= 0.35 else {
            return nil
        }

        let hopSeconds = Double(tempoHopSize) / signal.sampleRate
        let onsetOffsetSeconds = Double(tempoFrameSize) / signal.sampleRate
        let beatTimes = inferAdaptiveBeatTimes(
            onset: onset,
            hopSeconds: hopSeconds,
            onsetOffsetSeconds: onsetOffsetSeconds,
            initialPeriodSeconds: 60.0 / best.bpm,
            initialPhaseFrames: best.grid.phase,
            initialLagFrames: best.lag,
            durationSeconds: signal.durationSeconds
        )
        guard beatTimes.count >= 2 else { return nil }

        let trackedBPM = robustTrackedBPM(
            beatTimes: beatTimes,
            fallbackBPM: best.bpm,
            allowedRange: configuration.tempoRange
        )

        let peakValues = beatTimes.compactMap { time -> Double? in
            let index = Int(((time - onsetOffsetSeconds) / hopSeconds).rounded())
            guard onset.indices.contains(index) else { return nil }
            return onset[index] / maxOnset
        }
        let alignment = peakValues.isEmpty ? 0 : peakValues.reduce(0, +) / Double(peakValues.count)
        let ambiguityFactor = metricalAmbiguityFactor(best: best, candidates: candidates)
        let confidence = clamp01(
            ((best.correlation * 0.48) + (best.grid.score * 0.30) + (alignment * 0.22))
            * ambiguityFactor
        )
        guard confidence >= configuration.minimumTempoConfidence else { return nil }

        return TempoAnalysis(bpm: trackedBPM, confidence: confidence, beatTimesSeconds: beatTimes)
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

    private static func tempoCandidates(
        onset: [Double],
        minLag: Int,
        maxLag: Int,
        envelopeRate: Double
    ) -> [TempoCandidate] {
        var seeds: [Int: CandidateSeed] = [:]
        for lag in minLag...maxLag {
            let correlation = normalizedAutocorrelation(onset, lag: lag)
            guard correlation > 0.03 else { continue }
            let bpm = 60.0 * envelopeRate / Double(lag)
            let grid = metricalGridScore(onset: onset, lag: lag)
            seeds[lag] = CandidateSeed(lag: lag, bpm: bpm, correlation: correlation, grid: grid)
        }

        var candidates: [TempoCandidate] = []
        for seed in seeds.values {
            let baseScore = (seed.correlation * 0.45)
                + (seed.grid.score * 0.40)
                + (tempoPrior(seed.bpm) * 0.15)
            var metricalFactor = 1.0

            // Suppress a slower subharmonic when the faster beat grid is itself strongly
            // periodic and explains materially more onset mass. This prevents alternating
            // accents from collapsing 150 -> 75 BPM while preserving genuine 75 BPM with
            // weak subdivisions.
            let halfLagCandidates = Set([seed.lag / 2, (seed.lag + 1) / 2]).filter { $0 >= minLag }
            for fasterLag in halfLagCandidates {
                guard let faster = seeds[fasterLag] else { continue }
                if faster.correlation >= seed.correlation * 0.82,
                   faster.grid.onsetCoverage >= seed.grid.onsetCoverage + 0.08 {
                    metricalFactor = min(metricalFactor, 0.58)
                }
            }

            candidates.append(TempoCandidate(
                lag: seed.lag,
                bpm: seed.bpm,
                correlation: seed.correlation,
                grid: seed.grid,
                weighted: baseScore * metricalFactor
            ))
        }
        return candidates.sorted { lhs, rhs in
            if abs(lhs.weighted - rhs.weighted) <= 1e-12 {
                return abs(log2(lhs.bpm / 120.0)) < abs(log2(rhs.bpm / 120.0))
            }
            return lhs.weighted > rhs.weighted
        }
    }

    private static func metricalGridScore(onset: [Double], lag: Int) -> GridScore {
        guard lag > 0, let maxOnset = onset.max(), maxOnset > 0 else {
            return GridScore(score: 0, beatStrength: 0, onsetCoverage: 0, phase: 0)
        }
        let threshold = maxOnset * 0.05
        var peaks: [(index: Int, value: Double)] = []
        if onset.count >= 3 {
            for index in 1..<(onset.count - 1) where onset[index] >= threshold {
                if onset[index] >= onset[index - 1], onset[index] >= onset[index + 1] {
                    peaks.append((index, onset[index]))
                }
            }
        }
        guard !peaks.isEmpty else {
            return GridScore(score: 0, beatStrength: 0, onsetCoverage: 0, phase: 0)
        }

        let strongest = peaks.sorted { $0.value > $1.value }.prefix(24)
        var phases = Set(strongest.map { $0.index % lag })
        phases.insert(0)
        let tolerance = max(1, Int((Double(lag) * 0.12).rounded()))
        let totalPeakWeight = peaks.reduce(0.0) { $0 + $1.value }
        var best = GridScore(score: 0, beatStrength: 0, onsetCoverage: 0, phase: 0)

        for phase in phases {
            var sampledStrength = 0.0
            var beatCount = 0
            var position = phase
            while position < onset.count {
                let lower = max(0, position - tolerance)
                let upper = min(onset.count - 1, position + tolerance)
                var localMax = 0.0
                if lower <= upper {
                    for index in lower...upper {
                        localMax = max(localMax, onset[index])
                    }
                }
                sampledStrength += localMax / maxOnset
                beatCount += 1
                position += lag
            }
            let beatStrength = beatCount > 0 ? sampledStrength / Double(beatCount) : 0

            var matchedPeakWeight = 0.0
            for peak in peaks {
                let forward = (peak.index - phase) % lag
                let normalizedForward = forward >= 0 ? forward : forward + lag
                let circularDistance = min(normalizedForward, lag - normalizedForward)
                if circularDistance <= tolerance {
                    matchedPeakWeight += peak.value
                }
            }
            let onsetCoverage = totalPeakWeight > 0 ? matchedPeakWeight / totalPeakWeight : 0
            let score = beatStrength + onsetCoverage > 0
                ? 2 * beatStrength * onsetCoverage / (beatStrength + onsetCoverage)
                : 0
            if score > best.score {
                best = GridScore(
                    score: score,
                    beatStrength: beatStrength,
                    onsetCoverage: onsetCoverage,
                    phase: phase
                )
            }
        }
        return best
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
        return exp(-0.5 * pow(octaveDistance / 0.95, 2))
    }

    private static func metricalAmbiguityFactor(best: TempoCandidate, candidates: [TempoCandidate]) -> Double {
        let commonRatios = [0.5, 2.0, 2.0 / 3.0, 1.5]
        for alternative in candidates.dropFirst() {
            guard alternative.weighted >= best.weighted * 0.94 else { continue }
            let ratio = alternative.bpm / best.bpm
            if commonRatios.contains(where: { abs(ratio - $0) <= 0.04 }) {
                return 0.15
            }
        }
        return 1.0
    }

    private static func inferAdaptiveBeatTimes(
        onset: [Double],
        hopSeconds: Double,
        onsetOffsetSeconds: Double,
        initialPeriodSeconds: Double,
        initialPhaseFrames: Int,
        initialLagFrames: Int,
        durationSeconds: Double
    ) -> [Double] {
        guard !onset.isEmpty,
              hopSeconds > 0,
              initialPeriodSeconds > 0,
              durationSeconds > 0,
              let maxOnset = onset.max(),
              maxOnset > 0 else { return [] }

        let anchorTolerance = max(1, Int((Double(initialLagFrames) * 0.18).rounded()))
        var anchorIndex: Int?
        for cycle in 0..<4 {
            let center = initialPhaseFrames + cycle * initialLagFrames
            guard center < onset.count else { break }
            let lower = max(0, center - anchorTolerance)
            let upper = min(onset.count - 1, center + anchorTolerance)
            guard lower <= upper else { continue }
            var bestIndex = lower
            for index in lower...upper where onset[index] > onset[bestIndex] {
                bestIndex = index
            }
            if onset[bestIndex] >= maxOnset * 0.08 {
                anchorIndex = bestIndex
                break
            }
        }
        if anchorIndex == nil {
            let limit = min(onset.count, max(1, initialLagFrames * 4))
            anchorIndex = (0..<limit).max(by: { onset[$0] < onset[$1] })
        }
        guard let anchorIndex else { return [] }
        let anchorTime = Double(anchorIndex) * hopSeconds + onsetOffsetSeconds

        func track(direction: Double) -> [Double] {
            var result: [Double] = []
            var currentTime = anchorTime
            var currentPeriod = initialPeriodSeconds
            let minimumPeriod = initialPeriodSeconds * 0.70
            let maximumPeriod = initialPeriodSeconds * 1.30
            var safety = 0

            while safety < 100_000 {
                safety += 1
                let predicted = currentTime + direction * currentPeriod
                guard predicted >= 0, predicted <= durationSeconds else { break }

                let center = Int(((predicted - onsetOffsetSeconds) / hopSeconds).rounded())
                let searchSeconds = min(0.16, currentPeriod * 0.28)
                let searchFrames = max(1, Int((searchSeconds / hopSeconds).rounded()))
                let lower = max(0, center - searchFrames)
                let upper = min(onset.count - 1, center + searchFrames)

                var chosenTime = predicted
                var chosenStrength = 0.0
                var chosenScore = -Double.infinity
                if lower <= upper {
                    for index in lower...upper {
                        let time = Double(index) * hopSeconds + onsetOffsetSeconds
                        let deviation = abs(time - predicted) / max(searchSeconds, 1e-9)
                        let strength = onset[index] / maxOnset
                        let score = strength - (0.18 * deviation)
                        if score > chosenScore {
                            chosenScore = score
                            chosenStrength = strength
                            chosenTime = time
                        }
                    }
                }

                if chosenStrength >= 0.06, chosenScore > 0 {
                    let observedInterval = abs(chosenTime - currentTime)
                    if observedInterval >= initialPeriodSeconds * 0.65,
                       observedInterval <= initialPeriodSeconds * 1.35 {
                        currentPeriod = (currentPeriod * 0.80) + (observedInterval * 0.20)
                        currentPeriod = min(maximumPeriod, max(minimumPeriod, currentPeriod))
                        currentTime = chosenTime
                    } else {
                        currentTime = predicted
                    }
                } else {
                    currentTime = predicted
                }
                result.append(currentTime)
            }
            return result
        }

        let backward = track(direction: -1).reversed()
        let forward = track(direction: 1)
        var combined = Array(backward) + [anchorTime] + forward
        combined = combined.filter { $0 >= 0 && $0 <= durationSeconds }
        combined.sort()

        var deduplicated: [Double] = []
        for time in combined {
            if let last = deduplicated.last, time - last <= hopSeconds * 0.5 {
                continue
            }
            deduplicated.append(time)
        }
        return deduplicated
    }

    private static func robustTrackedBPM(
        beatTimes: [Double],
        fallbackBPM: Double,
        allowedRange: ClosedRange<Double>
    ) -> Double {
        guard beatTimes.count >= 3 else { return fallbackBPM }
        var intervals: [Double] = []
        for index in 1..<beatTimes.count {
            let interval = beatTimes[index] - beatTimes[index - 1]
            if interval.isFinite, interval > 0 {
                intervals.append(interval)
            }
        }
        guard let medianInterval = median(intervals), medianInterval > 0 else { return fallbackBPM }
        let tracked = 60.0 / medianInterval
        guard allowedRange.contains(tracked),
              tracked >= fallbackBPM * 0.70,
              tracked <= fallbackBPM * 1.30 else {
            return fallbackBPM
        }
        return tracked
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    private static func clamp01(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
