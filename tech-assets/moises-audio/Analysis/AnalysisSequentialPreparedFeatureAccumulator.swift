import Foundation

/// Incremental W29 feature accumulator. The caller must feed exactly one
/// prepared mono sample for every logical prepared sample index, in strictly
/// increasing order starting at zero. It intentionally owns only bounded
/// rings plus retained feature vectors; it never owns whole-track PCM.
final class AnalysisSequentialPreparedFeatureAccumulator {
    private struct PendingChordFrame {
        let startSeconds: Double
        let endSeconds: Double
        let analysisStart: Int
        let analysisEnd: Int
        let segmentRMS: Double
    }

    private let sampleRate: Double
    private let sampleCount: Int
    private let duration: Double
    private let configuration: MusicAnalysisConfiguration

    private let tempoFrameSize: Int
    private let tempoHopSize: Int
    private var tempoRing: [Float]
    private var tempoFlux: [Double] = []
    private var previousTempoEnergy: Double?

    private let keyWindowSize: Int
    private let keyStarts: [Int]
    private var keyWindows: [[Double]]
    private var nextKeyWindowIndex = 0
    private var activeKeyWindows: [Int] = []
    private let rmsProbeStride: Int
    private var keyProbeSquares = 0.0
    private var keyProbeCount = 0

    private let chordWindowSamples: Int
    private let chordHopSamples: Int
    private var chordRing: [Float]
    private var chordFrameDecisions: [AnalysisPreparedChordFrameDecision] = []
    private var pendingChordFrames: [PendingChordFrame] = []
    private var currentChordSegmentStart = 0
    private var currentChordSegmentEnd: Int
    private var currentChordSegmentSquares = 0.0
    private var currentChordSegmentCount = 0

    private let sectionFrameCount: Int
    private let sectionEffectiveRate: Double
    private var sectionEnergy: [Float]
    private var currentSectionFrame = 0
    private var currentSectionStart: Int
    private var currentSectionEnd: Int
    private var currentSectionSquares = 0.0
    private var currentSectionCount = 0

    private var consumedSampleCount = 0

    init(
        sampleRate: Double,
        sampleCount: Int,
        durationSeconds: Double,
        configuration: MusicAnalysisConfiguration
    ) {
        precondition(sampleRate.isFinite && sampleRate > 0)
        precondition(sampleCount >= 0)
        precondition(durationSeconds.isFinite && durationSeconds >= 0)
        self.sampleRate = sampleRate
        self.sampleCount = sampleCount
        self.duration = durationSeconds
        self.configuration = configuration

        tempoFrameSize = min(
            configuration.analysisWindowSize,
            max(256, Int((sampleRate * 0.046).rounded()))
        )
        tempoHopSize = min(
            configuration.analysisHopSize,
            max(32, Int((sampleRate * 0.010).rounded()))
        )
        tempoRing = Array(repeating: 0, count: max(1, tempoFrameSize))
        let expectedTempoFrames = sampleCount >= tempoFrameSize
            ? 1 + (sampleCount - tempoFrameSize) / max(1, tempoHopSize)
            : 0
        tempoFlux.reserveCapacity(expectedTempoFrames)

        keyWindowSize = configuration.analysisWindowSize
        let availableKeyWindows = sampleCount >= keyWindowSize
            ? max(1, (sampleCount - keyWindowSize) / max(1, configuration.analysisHopSize) + 1)
            : 0
        let selectedKeyWindowCount = min(configuration.maximumKeyWindows, availableKeyWindows)
        keyStarts = Self.uniformlySpacedWindowStarts(
            sampleCount: sampleCount,
            windowSize: keyWindowSize,
            count: selectedKeyWindowCount
        )
        keyWindows = Array(repeating: [Double](), count: keyStarts.count)
        for index in keyWindows.indices { keyWindows[index].reserveCapacity(keyWindowSize) }
        activeKeyWindows.reserveCapacity(min(configuration.maximumKeyWindows, 4))
        rmsProbeStride = max(
            1,
            Int(ceil(Double(max(1, sampleCount)) / Double(AnalysisWorkingSetPolicy.maximumRMSProbeSamples)))
        )

        chordWindowSamples = max(
            256,
            min(max(1, sampleCount), Int((configuration.chordWindowSeconds * sampleRate).rounded()))
        )
        chordHopSamples = max(1, Int((configuration.chordHopSeconds * sampleRate).rounded()))
        chordRing = Array(repeating: 0, count: max(1, chordWindowSamples))
        chordFrameDecisions.reserveCapacity(max(1, Int(ceil(Double(max(1, sampleCount)) / Double(chordHopSamples)))))
        pendingChordFrames.reserveCapacity(4)
        currentChordSegmentEnd = min(sampleCount, chordHopSamples)

        sectionFrameCount = sampleCount > 0 && durationSeconds > 0
            ? max(1, Int((durationSeconds * AnalysisSectionEnergyFeatureExtractor.targetFramesPerSecond).rounded()))
            : 0
        sectionEffectiveRate = sectionFrameCount > 0 && durationSeconds > 0
            ? Double(sectionFrameCount) / durationSeconds
            : 1
        sectionEnergy = Array(repeating: 0, count: sectionFrameCount)
        currentSectionStart = sectionFrameCount > 0
            ? Self.sectionFrameStart(frame: 0, frameCount: sectionFrameCount, sampleCount: sampleCount)
            : 0
        currentSectionEnd = sectionFrameCount > 0
            ? Self.sectionFrameEnd(frame: 0, frameCount: sectionFrameCount, sampleCount: sampleCount)
            : 0
    }

    func consume(_ value: Float, at sampleIndex: Int) throws {
        guard sampleIndex == consumedSampleCount, sampleIndex >= 0, sampleIndex < sampleCount else {
            throw AnalysisChunkedInputError.nonSequentialPreparedSample(
                expected: consumedSampleCount,
                actual: sampleIndex
            )
        }
        try AnalysisCancellationPolicy.checkIfNeeded(
            enabled: true,
            iteration: sampleIndex,
            stride: AnalysisCancellationPolicy.preparationCheckStride
        )
        consumedSampleCount += 1

        let valueDouble = Double(value)
        let square = valueDouble * valueDouble

        if sampleIndex % rmsProbeStride == 0 {
            keyProbeSquares += square
            keyProbeCount += 1
        }

        tempoRing[sampleIndex % tempoRing.count] = value
        if sampleIndex + 1 >= tempoFrameSize,
           (sampleIndex + 1 - tempoFrameSize) % tempoHopSize == 0 {
            let frameStart = sampleIndex + 1 - tempoFrameSize
            var sumSquares = 0.0
            for absoluteIndex in frameStart...sampleIndex {
                let frameValue = Double(tempoRing[absoluteIndex % tempoRing.count])
                sumSquares += frameValue * frameValue
            }
            let energy = log1p(sqrt(sumSquares / Double(tempoFrameSize)))
            tempoFlux.append(previousTempoEnergy.map { max(0, energy - $0) } ?? 0)
            previousTempoEnergy = energy
        }

        while nextKeyWindowIndex < keyStarts.count,
              keyStarts[nextKeyWindowIndex] == sampleIndex {
            activeKeyWindows.append(nextKeyWindowIndex)
            nextKeyWindowIndex += 1
        }
        if !activeKeyWindows.isEmpty {
            var activeIndex = activeKeyWindows.count - 1
            while true {
                let keyIndex = activeKeyWindows[activeIndex]
                let start = keyStarts[keyIndex]
                if sampleIndex >= start, sampleIndex < start + keyWindowSize {
                    keyWindows[keyIndex].append(valueDouble)
                }
                if sampleIndex + 1 >= start + keyWindowSize {
                    activeKeyWindows.remove(at: activeIndex)
                }
                if activeIndex == 0 { break }
                activeIndex -= 1
            }
        }

        chordRing[sampleIndex % chordRing.count] = value
        if sampleIndex >= currentChordSegmentStart, sampleIndex < currentChordSegmentEnd {
            currentChordSegmentSquares += square
            currentChordSegmentCount += 1
        }
        if sampleIndex + 1 == currentChordSegmentEnd {
            let center = currentChordSegmentStart + (currentChordSegmentEnd - currentChordSegmentStart) / 2
            let halfWindow = chordWindowSamples / 2
            var analysisStart = max(0, center - halfWindow)
            var analysisEnd = min(sampleCount, analysisStart + chordWindowSamples)
            if analysisEnd - analysisStart < chordWindowSamples {
                analysisStart = max(0, analysisEnd - chordWindowSamples)
                analysisEnd = min(sampleCount, analysisStart + chordWindowSamples)
            }
            let segmentRMS = currentChordSegmentCount > 0
                ? sqrt(currentChordSegmentSquares / Double(currentChordSegmentCount))
                : 0
            pendingChordFrames.append(
                .init(
                    startSeconds: Double(currentChordSegmentStart) / sampleRate,
                    endSeconds: min(duration, Double(currentChordSegmentEnd) / sampleRate),
                    analysisStart: analysisStart,
                    analysisEnd: analysisEnd,
                    segmentRMS: segmentRMS
                )
            )
            currentChordSegmentStart = currentChordSegmentEnd
            currentChordSegmentEnd = min(sampleCount, currentChordSegmentStart + chordHopSamples)
            currentChordSegmentSquares = 0
            currentChordSegmentCount = 0
        }

        while let pending = pendingChordFrames.first,
              pending.analysisEnd <= sampleIndex + 1 {
            let decision: (label: String, confidence: Double?)
            if pending.segmentRMS < configuration.noChordRMS {
                decision = ("N", 1)
            } else {
                var window: [Double] = []
                window.reserveCapacity(pending.analysisEnd - pending.analysisStart)
                for absoluteIndex in pending.analysisStart..<pending.analysisEnd {
                    window.append(Double(chordRing[absoluteIndex % chordRing.count]))
                }
                decision = ChordFrameClassifier.classify(
                    samples: window,
                    sampleRate: sampleRate,
                    configuration: configuration,
                    vocabulary: .conservativeMajorMinor
                )
            }
            chordFrameDecisions.append(
                .init(
                    startSeconds: pending.startSeconds,
                    endSeconds: pending.endSeconds,
                    label: decision.label,
                    confidence: decision.confidence
                )
            )
            pendingChordFrames.removeFirst()
        }

        while currentSectionFrame < sectionFrameCount,
              sampleIndex >= currentSectionEnd {
            if currentSectionCount > 0 {
                sectionEnergy[currentSectionFrame] = Float(
                    sqrt(currentSectionSquares / Double(currentSectionCount))
                )
            }
            currentSectionFrame += 1
            currentSectionSquares = 0
            currentSectionCount = 0
            if currentSectionFrame < sectionFrameCount {
                currentSectionStart = Self.sectionFrameStart(
                    frame: currentSectionFrame,
                    frameCount: sectionFrameCount,
                    sampleCount: sampleCount
                )
                currentSectionEnd = Self.sectionFrameEnd(
                    frame: currentSectionFrame,
                    frameCount: sectionFrameCount,
                    sampleCount: sampleCount
                )
            }
        }
        if currentSectionFrame < sectionFrameCount,
           sampleIndex >= currentSectionStart,
           sampleIndex < currentSectionEnd {
            currentSectionSquares += square
            currentSectionCount += 1
        }
    }

    func finish(
        preparedSampleComputations: Int,
        preparedBlockLoads: Int
    ) throws -> AnalysisSinglePassPreparedFeatures {
        try AnalysisCancellationPolicy.check()
        guard consumedSampleCount == sampleCount else {
            throw AnalysisChunkedInputError.preparedSampleCountMismatch(
                expected: sampleCount,
                actual: consumedSampleCount
            )
        }
        if currentSectionFrame < sectionFrameCount, currentSectionCount > 0 {
            sectionEnergy[currentSectionFrame] = Float(
                sqrt(currentSectionSquares / Double(currentSectionCount))
            )
        }
        try Self.normalizeTempoFlux(&tempoFlux)
        let keyGlobalRMS = keyProbeCount > 0
            ? sqrt(keyProbeSquares / Double(keyProbeCount))
            : 0
        let sectionSignal = sectionFrameCount > 0
            ? AnalysisSignal(sampleRate: sectionEffectiveRate, monoSamples: sectionEnergy)
            : AnalysisSignal(sampleRate: 1, monoSamples: [])
        let keySampleCount = keyWindows.reduce(0) { $0 + $1.count }
        let retainedBytes = Int64(tempoFlux.count) * Int64(MemoryLayout<Double>.stride)
            + Int64(keySampleCount) * Int64(MemoryLayout<Double>.stride)
            + Int64(chordFrameDecisions.count) * 64
            + Int64(sectionEnergy.count) * Int64(MemoryLayout<Float>.stride)
            + Int64(tempoRing.count + chordRing.count) * Int64(MemoryLayout<Float>.stride)

        return .init(
            tempoOnset: tempoFlux,
            tempoFrameSize: tempoFrameSize,
            tempoHopSize: tempoHopSize,
            keyWindows: keyWindows,
            keyGlobalRMS: keyGlobalRMS,
            chordFrameDecisions: chordFrameDecisions,
            sectionEnergySignal: sectionSignal,
            sampleRate: sampleRate,
            durationSeconds: duration,
            diagnostics: .init(
                preparedSampleCount: sampleCount,
                preparedSampleRequests: consumedSampleCount,
                preparedSampleComputations: preparedSampleComputations,
                preparedBlockLoads: preparedBlockLoads,
                tempoOnsetCount: tempoFlux.count,
                keyWindowCount: keyWindows.count,
                keyWindowSampleCount: keySampleCount,
                chordFrameDecisionCount: chordFrameDecisions.count,
                sectionEnergyFrameCount: sectionEnergy.count,
                maximumTempoRingSamples: tempoRing.count,
                maximumChordRingSamples: chordRing.count,
                estimatedRetainedFeatureBytes: retainedBytes,
                exactSinglePreparedTraversal: consumedSampleCount == sampleCount
                    && preparedSampleComputations == sampleCount
            )
        )
    }

    private static func normalizeTempoFlux(_ flux: inout [Double]) throws {
        try AnalysisCancellationPolicy.check()
        let positive = flux.filter { $0 > 0 }.sorted()
        guard !positive.isEmpty else { return }
        let floorValue = positive[positive.count / 2] * 0.25
        guard floorValue > 0 else { return }
        for index in flux.indices {
            try AnalysisCancellationPolicy.checkIfNeeded(
                enabled: true,
                iteration: index,
                stride: AnalysisCancellationPolicy.tempoFrameCheckStride * 4
            )
            flux[index] = max(0, flux[index] - floorValue)
        }
    }

    private static func uniformlySpacedWindowStarts(
        sampleCount: Int,
        windowSize: Int,
        count: Int
    ) -> [Int] {
        guard count > 0 else { return [] }
        let lastStart = max(0, sampleCount - windowSize)
        guard count > 1, lastStart > 0 else { return [0] }
        return (0..<count).map {
            Int((Double($0) * Double(lastStart) / Double(count - 1)).rounded())
        }
    }

    private static func sectionFrameStart(frame: Int, frameCount: Int, sampleCount: Int) -> Int {
        Int((Double(frame) * Double(sampleCount) / Double(frameCount)).rounded(.down))
    }

    private static func sectionFrameEnd(frame: Int, frameCount: Int, sampleCount: Int) -> Int {
        let start = sectionFrameStart(frame: frame, frameCount: frameCount, sampleCount: sampleCount)
        let rawEnd = Int((Double(frame + 1) * Double(sampleCount) / Double(frameCount)).rounded(.down))
        return min(sampleCount, max(start + 1, rawEnd))
    }
}
