import Foundation

public enum StreamingBoundedTempoBeatAnalyzer {
    private struct Candidate {
        let lag: Int
        let bpm: Double
        let correlation: Double
        let phase: Int
        let gridAlignment: Double
        let weightedScore: Double
    }

    public static func analyzeCancellable(
        reader: AnalysisPreparedSampleReader,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) throws -> TempoAnalysis? {
        try AnalysisCancellationPolicy.check()
        let frameSize = min(configuration.analysisWindowSize, max(256, Int((reader.sampleRate * 0.046).rounded())))
        let hopSize = min(configuration.analysisHopSize, max(32, Int((reader.sampleRate * 0.010).rounded())))
        guard reader.sampleCount >= frameSize, reader.durationSeconds >= configuration.minimumDurationSeconds else { return nil }
        let onset = try onsetEnvelope(reader: reader, frameSize: frameSize, hopSize: hopSize)
        return try analyzePreparedOnsetCancellable(
            onset: onset,
            sampleRate: reader.sampleRate,
            durationSeconds: reader.durationSeconds,
            frameSize: frameSize,
            hopSize: hopSize,
            configuration: configuration
        )
    }

    public static func analyzePreparedOnsetCancellable(
        onset: [Double],
        sampleRate: Double,
        durationSeconds: Double,
        frameSize: Int,
        hopSize: Int,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) throws -> TempoAnalysis? {
        try AnalysisCancellationPolicy.check()
        guard sampleRate.isFinite, sampleRate > 0,
              durationSeconds.isFinite, durationSeconds >= configuration.minimumDurationSeconds,
              frameSize > 0, hopSize > 0, onset.count >= 8 else { return nil }
        let maxOnset = onset.max() ?? 0
        let meanOnset = onset.reduce(0, +) / Double(onset.count)
        guard maxOnset > 1e-7, meanOnset > 1e-9 else { return nil }
        let envelopeRate = sampleRate / Double(hopSize)
        let minLag = max(1, Int(floor(60 * envelopeRate / configuration.tempoRange.upperBound)))
        let maxLag = min(onset.count - 2, Int(ceil(60 * envelopeRate / configuration.tempoRange.lowerBound)))
        guard maxLag > minLag else { return nil }
        var candidates: [Candidate] = []
        candidates.reserveCapacity(maxLag - minLag + 1)
        for lag in minLag...maxLag {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: lag - minLag, stride: 1)
            let correlation = try normalizedAutocorrelation(onset, lag: lag)
            guard correlation > 0.025 else { continue }
            let phaseAndAlignment = try bestPhase(onset: onset, lag: lag, maxOnset: maxOnset)
            let bpm = 60 * envelopeRate / Double(lag)
            let prior = tempoPrior(bpm)
            let score = correlation * 0.62 + phaseAndAlignment.alignment * 0.30 + prior * 0.08
            candidates.append(.init(lag: lag, bpm: bpm, correlation: correlation, phase: phaseAndAlignment.phase, gridAlignment: phaseAndAlignment.alignment, weightedScore: score))
        }
        guard !candidates.isEmpty else { return nil }
        try AnalysisCancellationPolicy.check()
        candidates.sort {
            if abs($0.weightedScore - $1.weightedScore) <= 1e-12 { return abs(log2($0.bpm / 120)) < abs(log2($1.bpm / 120)) }
            return $0.weightedScore > $1.weightedScore
        }
        guard let best = resolveMetricalCandidate(candidates) else { return nil }
        let hopSeconds = Double(hopSize) / sampleRate
        let onsetOffsetSeconds = Double(frameSize) / sampleRate
        let beatTimes = try trackedBeatTimes(
            onset: onset, lag: best.lag, phase: best.phase,
            hopSeconds: hopSeconds, onsetOffsetSeconds: onsetOffsetSeconds,
            durationSeconds: durationSeconds
        )
        guard beatTimes.count >= 2 else { return nil }
        let intervals = zip(beatTimes, beatTimes.dropFirst()).map { $1 - $0 }.filter { $0 > 1e-6 }
        guard let medianInterval = median(intervals), medianInterval > 1e-6 else { return nil }
        let trackedBPM = 60 / medianInterval
        guard configuration.tempoRange.contains(trackedBPM) else { return nil }
        let ambiguity = metricalAmbiguity(best: best, candidates: candidates)
        let confidence = clamp01((best.correlation * 0.54 + best.gridAlignment * 0.36 + tempoPrior(trackedBPM) * 0.10) * ambiguity)
        guard confidence >= configuration.minimumTempoConfidence else { return nil }
        try AnalysisCancellationPolicy.check()
        return TempoAnalysis(bpm: trackedBPM, confidence: confidence, beatTimesSeconds: beatTimes)
    }

    private static func onsetEnvelope(
        reader: AnalysisPreparedSampleReader,
        frameSize: Int,
        hopSize: Int
    ) throws -> [Double] {
        guard reader.sampleCount >= frameSize else { return [] }
        let frameCount = 1 + (reader.sampleCount - frameSize) / hopSize
        var flux: [Double] = []
        flux.reserveCapacity(frameCount)
        var previousEnergy: Double?
        var start = 0
        var frameIndex = 0
        while start + frameSize <= reader.sampleCount {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: frameIndex, stride: AnalysisCancellationPolicy.tempoFrameCheckStride)
            var sumSquares = 0.0
            for index in start..<(start + frameSize) {
                let value = Double(try reader.sample(at: index))
                sumSquares += value * value
            }
            let energy = log1p(sqrt(sumSquares / Double(frameSize)))
            flux.append(previousEnergy.map { max(0, energy - $0) } ?? 0)
            previousEnergy = energy
            start += hopSize
            frameIndex += 1
        }
        return try normalizedFlux(flux)
    }

    public static func normalizedPreparedOnsetFluxCancellable(_ flux: [Double]) throws -> [Double] {
        try normalizedFlux(flux)
    }

    private static func normalizedFlux(_ input: [Double]) throws -> [Double] {
        var flux = input
        try AnalysisCancellationPolicy.check()
        let positive = flux.filter { $0 > 0 }.sorted()
        try AnalysisCancellationPolicy.check()
        guard !positive.isEmpty else { return flux }
        let floorValue = positive[positive.count / 2] * 0.25
        if floorValue > 0 {
            for index in flux.indices {
                try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: index, stride: AnalysisCancellationPolicy.tempoFrameCheckStride * 4)
                flux[index] = max(0, flux[index] - floorValue)
            }
        }
        return flux
    }

    private static func normalizedAutocorrelation(_ values: [Double], lag: Int) throws -> Double {
        guard lag > 0, lag < values.count else { return 0 }
        let pairCount = values.count - lag
        let stride = max(1, Int(ceil(Double(pairCount) / 120_000.0)))
        var dot = 0.0, leftEnergy = 0.0, rightEnergy = 0.0
        var index = 0, iteration = 0
        while index < pairCount {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: iteration, stride: AnalysisCancellationPolicy.tempoCorrelationCheckStride)
            let left = values[index], right = values[index + lag]
            dot += left * right; leftEnergy += left * left; rightEnergy += right * right
            index += stride; iteration += 1
        }
        let denominator = sqrt(leftEnergy * rightEnergy)
        guard denominator > 1e-12 else { return 0 }
        return max(0, min(1, dot / denominator))
    }

    private static func bestPhase(onset: [Double], lag: Int, maxOnset: Double) throws -> (phase: Int, alignment: Double) {
        guard lag > 0, maxOnset > 0 else { return (0, 0) }
        let strongest = onset.enumerated().sorted { $0.element > $1.element }.prefix(32)
        var phases = Set(strongest.map { $0.offset % lag }); phases.insert(0)
        let tolerance = max(1, Int((Double(lag) * 0.10).rounded()))
        var bestPhase = 0, bestAlignment = 0.0
        for (phaseIndex, phase) in phases.enumerated() {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: phaseIndex, stride: 1)
            var score = 0.0, count = 0, position = phase
            while position < onset.count {
                try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: count, stride: AnalysisCancellationPolicy.tempoPhaseCheckStride)
                let lower = max(0, position - tolerance), upper = min(onset.count - 1, position + tolerance)
                var localMaximum = 0.0
                if lower <= upper { for index in lower...upper { localMaximum = max(localMaximum, onset[index]) } }
                score += localMaximum / maxOnset; count += 1; position += lag
            }
            let alignment = count > 0 ? score / Double(count) : 0
            if alignment > bestAlignment { bestAlignment = alignment; bestPhase = phase }
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
               candidate.weightedScore >= selected.weightedScore * 0.94 { selected = candidate }
        }
        return selected
    }

    private static func trackedBeatTimes(
        onset: [Double], lag: Int, phase: Int, hopSeconds: Double,
        onsetOffsetSeconds: Double, durationSeconds: Double
    ) throws -> [Double] {
        guard lag > 0, hopSeconds > 0 else { return [] }
        let tolerance = max(1, Int((Double(lag) * 0.18).rounded()))
        var indices: [Int] = [], predicted = phase, beatIndex = 0
        while predicted < onset.count {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: beatIndex, stride: AnalysisCancellationPolicy.tempoPhaseCheckStride)
            let lower = max(0, predicted - tolerance), upper = min(onset.count - 1, predicted + tolerance)
            var bestIndex = predicted, bestValue = -Double.infinity
            if lower <= upper { for index in lower...upper where onset[index] > bestValue { bestValue = onset[index]; bestIndex = index } }
            if let last = indices.last, bestIndex <= last { bestIndex = max(last + 1, predicted) }
            if bestIndex < onset.count { indices.append(bestIndex) }
            predicted += lag; beatIndex += 1
        }
        var times: [Double] = []; times.reserveCapacity(indices.count)
        for (offset, index) in indices.enumerated() {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: offset, stride: AnalysisCancellationPolicy.tempoPhaseCheckStride)
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

    private static func tempoPrior(_ bpm: Double) -> Double { bpm > 0 ? exp(-pow(log2(bpm / 120), 2) / 1.4) : 0 }
    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted(), middle = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
    private static func clamp01(_ value: Double) -> Double { min(1, max(0, value)) }
}
