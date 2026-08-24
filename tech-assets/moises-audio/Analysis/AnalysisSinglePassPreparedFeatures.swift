import Foundation

public struct AnalysisPreparedChordFrameDecision: Equatable, Sendable {
    public let startSeconds: Double
    public let endSeconds: Double
    public let label: String
    public let confidence: Double?

    public init(startSeconds: Double, endSeconds: Double, label: String, confidence: Double?) {
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.label = label
        self.confidence = confidence
    }
}

public struct AnalysisSinglePassPreparedFeatureDiagnostics: Codable, Equatable, Sendable {
    public let preparedSampleCount: Int
    public let preparedSampleRequests: Int
    public let preparedSampleComputations: Int
    public let preparedBlockLoads: Int
    public let tempoOnsetCount: Int
    public let keyWindowCount: Int
    public let keyWindowSampleCount: Int
    public let chordFrameDecisionCount: Int
    public let sectionEnergyFrameCount: Int
    public let maximumTempoRingSamples: Int
    public let maximumChordRingSamples: Int
    public let estimatedRetainedFeatureBytes: Int64
    public let exactSinglePreparedTraversal: Bool
}

public struct AnalysisSinglePassPreparedFeatures: Equatable, Sendable {
    public let tempoOnset: [Double]
    public let tempoFrameSize: Int
    public let tempoHopSize: Int
    public let keyWindows: [[Double]]
    public let keyGlobalRMS: Double
    public let chordFrameDecisions: [AnalysisPreparedChordFrameDecision]
    public let sectionEnergySignal: AnalysisSignal
    public let sampleRate: Double
    public let durationSeconds: Double
    public let diagnostics: AnalysisSinglePassPreparedFeatureDiagnostics
}

public enum AnalysisSinglePassPreparedFeatureExtractor {
    private struct PendingChordFrame {
        let startSeconds: Double
        let endSeconds: Double
        let analysisStart: Int
        let analysisEnd: Int
        let segmentRMS: Double
    }

    public static func extract(
        reader: AnalysisPreparedSampleReader,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) throws -> AnalysisSinglePassPreparedFeatures {
        try AnalysisCancellationPolicy.check()
        guard reader.sampleCount > 0, reader.durationSeconds > 0 else {
            let emptySignal = AnalysisSignal(sampleRate: 1, monoSamples: [])
            return .init(
                tempoOnset: [], tempoFrameSize: 0, tempoHopSize: 0,
                keyWindows: [], keyGlobalRMS: 0, chordFrameDecisions: [],
                sectionEnergySignal: emptySignal, sampleRate: reader.sampleRate,
                durationSeconds: reader.durationSeconds,
                diagnostics: .init(
                    preparedSampleCount: reader.sampleCount,
                    preparedSampleRequests: 0,
                    preparedSampleComputations: 0,
                    preparedBlockLoads: 0,
                    tempoOnsetCount: 0,
                    keyWindowCount: 0,
                    keyWindowSampleCount: 0,
                    chordFrameDecisionCount: 0,
                    sectionEnergyFrameCount: 0,
                    maximumTempoRingSamples: 0,
                    maximumChordRingSamples: 0,
                    estimatedRetainedFeatureBytes: 0,
                    exactSinglePreparedTraversal: true
                )
            )
        }

        let computationStart = reader.preparedSampleComputationCount
        let blockLoadStart = reader.preparedBlockLoadCount
        let sampleRate = reader.sampleRate
        let sampleCount = reader.sampleCount
        let duration = reader.durationSeconds

        let tempoFrameSize = min(
            configuration.analysisWindowSize,
            max(256, Int((sampleRate * 0.046).rounded()))
        )
        let tempoHopSize = min(
            configuration.analysisHopSize,
            max(32, Int((sampleRate * 0.010).rounded()))
        )
        var tempoRing = Array(repeating: Float(0), count: max(1, tempoFrameSize))
        let expectedTempoFrames = sampleCount >= tempoFrameSize
            ? 1 + (sampleCount - tempoFrameSize) / max(1, tempoHopSize)
            : 0
        var tempoFlux: [Double] = []
        tempoFlux.reserveCapacity(expectedTempoFrames)
        var previousTempoEnergy: Double?

        let keyWindowSize = configuration.analysisWindowSize
        let availableKeyWindows = sampleCount >= keyWindowSize
            ? max(1, (sampleCount - keyWindowSize) / max(1, configuration.analysisHopSize) + 1)
            : 0
        let selectedKeyWindowCount = min(configuration.maximumKeyWindows, availableKeyWindows)
        let keyStarts = uniformlySpacedWindowStarts(
            sampleCount: sampleCount,
            windowSize: keyWindowSize,
            count: selectedKeyWindowCount
        )
        var keyWindows = Array(repeating: [Double](), count: keyStarts.count)
        for index in keyWindows.indices { keyWindows[index].reserveCapacity(keyWindowSize) }
        var nextKeyWindowIndex = 0
        var activeKeyWindows: [Int] = []
        activeKeyWindows.reserveCapacity(min(configuration.maximumKeyWindows, 4))
        let rmsProbeStride = max(
            1,
            Int(ceil(Double(sampleCount) / Double(AnalysisWorkingSetPolicy.maximumRMSProbeSamples)))
        )
        var keyProbeSquares = 0.0
        var keyProbeCount = 0

        let chordWindowSamples = max(
            256,
            min(sampleCount, Int((configuration.chordWindowSeconds * sampleRate).rounded()))
        )
        let chordHopSamples = max(1, Int((configuration.chordHopSeconds * sampleRate).rounded()))
        var chordRing = Array(repeating: Float(0), count: max(1, chordWindowSamples))
        var chordFrameDecisions: [AnalysisPreparedChordFrameDecision] = []
        chordFrameDecisions.reserveCapacity(max(1, Int(ceil(Double(sampleCount) / Double(chordHopSamples)))))
        var pendingChordFrames: [PendingChordFrame] = []
        pendingChordFrames.reserveCapacity(4)
        var currentChordSegmentStart = 0
        var currentChordSegmentEnd = min(sampleCount, chordHopSamples)
        var currentChordSegmentSquares = 0.0
        var currentChordSegmentCount = 0

        let sectionFrameCount = max(
            1,
            Int((duration * AnalysisSectionEnergyFeatureExtractor.targetFramesPerSecond).rounded())
        )
        let sectionEffectiveRate = Double(sectionFrameCount) / duration
        var sectionEnergy = Array(repeating: Float(0), count: sectionFrameCount)
        var currentSectionFrame = 0
        var currentSectionStart = sectionFrameStart(
            frame: 0,
            frameCount: sectionFrameCount,
            sampleCount: sampleCount
        )
        var currentSectionEnd = sectionFrameEnd(
            frame: 0,
            frameCount: sectionFrameCount,
            sampleCount: sampleCount
        )
        var currentSectionSquares = 0.0
        var currentSectionCount = 0

        var sampleRequests = 0
        for sampleIndex in 0..<sampleCount {
            try AnalysisCancellationPolicy.checkIfNeeded(
                enabled: true,
                iteration: sampleIndex,
                stride: 2_048
            )
            let value = try reader.sample(at: sampleIndex)
            sampleRequests += 1
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
                    currentSectionStart = sectionFrameStart(
                        frame: currentSectionFrame,
                        frameCount: sectionFrameCount,
                        sampleCount: sampleCount
                    )
                    currentSectionEnd = sectionFrameEnd(
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

        if currentSectionFrame < sectionFrameCount, currentSectionCount > 0 {
            sectionEnergy[currentSectionFrame] = Float(
                sqrt(currentSectionSquares / Double(currentSectionCount))
            )
        }

        try normalizeTempoFlux(&tempoFlux)
        let keyGlobalRMS = keyProbeCount > 0
            ? sqrt(keyProbeSquares / Double(keyProbeCount))
            : 0
        let sectionSignal = AnalysisSignal(
            sampleRate: sectionEffectiveRate,
            monoSamples: sectionEnergy
        )
        let computationDelta = reader.preparedSampleComputationCount - computationStart
        let blockLoadDelta = reader.preparedBlockLoadCount - blockLoadStart
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
                preparedSampleRequests: sampleRequests,
                preparedSampleComputations: computationDelta,
                preparedBlockLoads: blockLoadDelta,
                tempoOnsetCount: tempoFlux.count,
                keyWindowCount: keyWindows.count,
                keyWindowSampleCount: keySampleCount,
                chordFrameDecisionCount: chordFrameDecisions.count,
                sectionEnergyFrameCount: sectionEnergy.count,
                maximumTempoRingSamples: tempoRing.count,
                maximumChordRingSamples: chordRing.count,
                estimatedRetainedFeatureBytes: retainedBytes,
                exactSinglePreparedTraversal: sampleRequests == sampleCount && computationDelta == sampleCount
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
