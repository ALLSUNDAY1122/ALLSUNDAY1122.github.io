import Foundation

enum AnalysisLongAudioCPUDutyPolicy {
    /// CPU-resource switch only; not a quality or PARITY threshold. Ordinary
    /// songs remain on the exact historical frame-rescan summation order.
    static let rollingTempoMinimumDurationSeconds = 1_800.0
    static let rollingTempoRebaseFrameInterval = 2_048
}

enum AnalysisTempoFrameEnergyMode: Sendable {
    case referenceRescan
    case rollingReuse
}

struct AnalysisTempoFrameEnergyTracker {
    let frameSize: Int
    let hopSize: Int
    let mode: AnalysisTempoFrameEnergyMode

    private var ring: [Float]
    private var rollingSumSquares = 0.0
    private var emittedFrameCount = 0
    private(set) var referenceSquareTerms = 0
    private(set) var rollingSquareUpdates = 0

    init(frameSize: Int, hopSize: Int, mode: AnalysisTempoFrameEnergyMode) {
        precondition(frameSize > 0)
        precondition(hopSize > 0)
        self.frameSize = frameSize
        self.hopSize = hopSize
        self.mode = mode
        ring = Array(repeating: 0, count: frameSize)
    }

    var ringSampleCount: Int { ring.count }

    mutating func consume(
        _ value: Float,
        precomputedSquare square: Double,
        at sampleIndex: Int
    ) -> Double? {
        precondition(sampleIndex >= 0)
        let slot = sampleIndex % ring.count

        switch mode {
        case .referenceRescan:
            ring[slot] = value
        case .rollingReuse:
            if sampleIndex >= frameSize {
                let outgoing = Double(ring[slot])
                rollingSumSquares -= outgoing * outgoing
                rollingSquareUpdates += 1
            }
            ring[slot] = value
            rollingSumSquares += square
            rollingSquareUpdates += 1
        }

        guard sampleIndex + 1 >= frameSize,
              (sampleIndex + 1 - frameSize) % hopSize == 0 else {
            return nil
        }

        let frameStart = sampleIndex + 1 - frameSize
        let sumSquares: Double
        switch mode {
        case .referenceRescan:
            sumSquares = exactWindowSum(frameStart: frameStart, frameEnd: sampleIndex)
            referenceSquareTerms += frameSize
        case .rollingReuse:
            if emittedFrameCount % AnalysisLongAudioCPUDutyPolicy.rollingTempoRebaseFrameInterval == 0 {
                rollingSumSquares = exactWindowSum(frameStart: frameStart, frameEnd: sampleIndex)
                referenceSquareTerms += frameSize
            }
            sumSquares = max(0, rollingSumSquares)
        }
        emittedFrameCount += 1
        return log1p(sqrt(sumSquares / Double(frameSize)))
    }

    private func exactWindowSum(frameStart: Int, frameEnd: Int) -> Double {
        var sumSquares = 0.0
        for absoluteIndex in frameStart...frameEnd {
            let frameValue = Double(ring[absoluteIndex % ring.count])
            sumSquares += frameValue * frameValue
        }
        return sumSquares
    }
}

/// Incremental W29/W30 feature accumulator. The caller feeds exactly one
/// prepared mono sample for every logical prepared sample index, in strictly
/// increasing order starting at zero. W31 bounds extreme retained cardinality.
/// W32 preserves ordinary-song Tempo summation exactly, uses rolling Tempo
/// energy only for long audio, and reuses Chord spectral setup/scratch without
/// changing Chord cadence, vocabulary, candidate scoring or Goertzel recurrence.
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
    private let retentionPlan: AnalysisExtremeDurationRetentionPlan

    private let tempoFrameSize: Int
    private let tempoHopSize: Int
    private var tempoEnergyTracker: AnalysisTempoFrameEnergyTracker
    private var tempoFlux: [Double] = []
    private var previousTempoEnergy: Double?
    private var tempoPoolMaximum = 0.0
    private var tempoPoolCount = 0

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
    private var chordSpectralWorkspace: AnalysisReusableChordSpectralWorkspace
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

        let plan = AnalysisExtremeDurationRetentionPolicy.plan(
            sampleRate: sampleRate,
            sampleCount: sampleCount,
            durationSeconds: durationSeconds,
            configuration: configuration
        )
        retentionPlan = plan

        let computedTempoFrameSize = min(
            configuration.analysisWindowSize,
            max(256, Int((sampleRate * 0.046).rounded()))
        )
        let baseTempoHopSize = min(
            configuration.analysisHopSize,
            max(32, Int((sampleRate * 0.010).rounded()))
        )
        tempoFrameSize = computedTempoFrameSize
        tempoHopSize = max(1, plan.tempoHopSamples)
        let tempoMode: AnalysisTempoFrameEnergyMode = durationSeconds >= AnalysisLongAudioCPUDutyPolicy.rollingTempoMinimumDurationSeconds
            ? .rollingReuse
            : .referenceRescan
        tempoEnergyTracker = .init(
            frameSize: computedTempoFrameSize,
            hopSize: baseTempoHopSize,
            mode: tempoMode
        )
        tempoFlux.reserveCapacity(plan.retainedTempoFrameUpperBound)

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

        let computedChordWindowSamples = max(
            256,
            min(max(1, sampleCount), Int((configuration.chordWindowSeconds * sampleRate).rounded()))
        )
        chordWindowSamples = computedChordWindowSamples
        chordHopSamples = max(1, plan.chordHopSamples)
        chordRing = Array(repeating: 0, count: computedChordWindowSamples)
        chordSpectralWorkspace = .init(
            sampleRate: sampleRate,
            windowSampleCount: computedChordWindowSamples
        )
        chordFrameDecisions.reserveCapacity(plan.retainedChordFrameUpperBound)
        pendingChordFrames.reserveCapacity(4)
        currentChordSegmentEnd = min(sampleCount, chordHopSamples)

        sectionFrameCount = sampleCount > 0 && durationSeconds > 0
            ? plan.retainedSectionEnergyFrameCount
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

        if retentionPlan.tempoResolutionSafe,
           let energy = tempoEnergyTracker.consume(
               value,
               precomputedSquare: square,
               at: sampleIndex
           ) {
            let onset = previousTempoEnergy.map { max(0, energy - $0) } ?? 0
            previousTempoEnergy = energy
            tempoPoolMaximum = max(tempoPoolMaximum, onset)
            tempoPoolCount += 1
            if tempoPoolCount >= retentionPlan.tempoFrameStride {
                tempoFlux.append(tempoPoolMaximum)
                tempoPoolMaximum = 0
                tempoPoolCount = 0
            }
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

        if retentionPlan.chordWindowRetentionSafe {
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
                let nextEnd = currentChordSegmentStart.addingReportingOverflow(chordHopSamples)
                currentChordSegmentEnd = nextEnd.overflow
                    ? sampleCount
                    : min(sampleCount, nextEnd.partialValue)
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
                    decision = AnalysisReusableChordFrameClassifier.classify(
                        samples: window,
                        workspace: &chordSpectralWorkspace,
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
        if retentionPlan.tempoResolutionSafe {
            if tempoPoolCount > 0 {
                tempoFlux.append(tempoPoolMaximum)
                tempoPoolMaximum = 0
                tempoPoolCount = 0
            }
            try Self.normalizeTempoFlux(&tempoFlux)
        } else {
            tempoFlux.removeAll(keepingCapacity: false)
        }
        if !retentionPlan.chordWindowRetentionSafe, duration > 0 {
            chordFrameDecisions = [
                .init(startSeconds: 0, endSeconds: duration, label: "X", confidence: nil)
            ]
        }

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
            + Int64(tempoEnergyTracker.ringSampleCount + chordRing.count) * Int64(MemoryLayout<Float>.stride)
            + Int64(chordSpectralWorkspace.windowedScratch.count) * Int64(MemoryLayout<Double>.stride)

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
                maximumTempoRingSamples: tempoEnergyTracker.ringSampleCount,
                maximumChordRingSamples: chordRing.count,
                estimatedRetainedFeatureBytes: retainedBytes,
                exactSinglePreparedTraversal: consumedSampleCount == sampleCount
                    && preparedSampleComputations == sampleCount,
                extremeDurationCompressionApplied: retentionPlan.compressionApplied,
                tempoFrameStride: retentionPlan.tempoFrameStride,
                chordFrameStride: retentionPlan.chordFrameStride,
                naturalSectionEnergyFrameCount: retentionPlan.naturalSectionEnergyFrameCount,
                sectionEnergyFrameStrideEquivalent: retentionPlan.sectionFrameStrideEquivalent,
                tempoResolutionSafe: retentionPlan.tempoResolutionSafe,
                chordWindowRetentionSafe: retentionPlan.chordWindowRetentionSafe,
                sectionResolutionSafe: retentionPlan.sectionResolutionSafe
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
