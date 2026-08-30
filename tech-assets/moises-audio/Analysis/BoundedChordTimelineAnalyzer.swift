import Foundation

public enum BoundedChordTimelineAnalyzer {
    private struct FrameDecision {
        var startSeconds: Double
        var endSeconds: Double
        var label: String
        var confidence: Double?
    }

    public static func analyze(
        signal: AnalysisSignal,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> [ChordEvent] {
        (try? analyzeInternal(
            signal: signal,
            configuration: configuration,
            cancellationChecksEnabled: false
        )) ?? []
    }

    public static func analyzeCancellable(
        signal: AnalysisSignal,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) throws -> [ChordEvent] {
        try analyzeInternal(
            signal: signal,
            configuration: configuration,
            cancellationChecksEnabled: true
        )
    }

    private static func analyzeInternal(
        signal: AnalysisSignal,
        configuration: MusicAnalysisConfiguration,
        cancellationChecksEnabled: Bool
    ) throws -> [ChordEvent] {
        try AnalysisCancellationPolicy.checkIfNeeded(enabled: cancellationChecksEnabled, iteration: 0, stride: 1)
        guard signal.durationSeconds > 0, !signal.monoSamples.isEmpty else { return [] }
        let samples = signal.monoSamples
        let sampleRate = signal.sampleRate
        let windowSamples = max(256, min(samples.count, Int((configuration.chordWindowSeconds * sampleRate).rounded())))
        let hopSamples = max(1, Int((configuration.chordHopSeconds * sampleRate).rounded()))
        let duration = signal.durationSeconds
        var decisions: [FrameDecision] = []
        decisions.reserveCapacity(max(1, Int(ceil(Double(samples.count) / Double(hopSamples)))))
        var segmentStart = 0
        var frameIndex = 0
        while segmentStart < samples.count {
            try AnalysisCancellationPolicy.checkIfNeeded(
                enabled: cancellationChecksEnabled,
                iteration: frameIndex,
                stride: AnalysisCancellationPolicy.chordFrameCheckStride
            )
            let segmentEnd = min(samples.count, segmentStart + hopSamples)
            let analysisCenter = segmentStart + (segmentEnd - segmentStart) / 2
            let halfWindow = windowSamples / 2
            var analysisStart = max(0, analysisCenter - halfWindow)
            var analysisEnd = min(samples.count, analysisStart + windowSamples)
            if analysisEnd - analysisStart < windowSamples {
                analysisStart = max(0, analysisEnd - windowSamples)
                analysisEnd = min(samples.count, analysisStart + windowSamples)
            }
            let decision: (label: String, confidence: Double?)
            if AnalysisWorkingSetPolicy.rms(samples, range: segmentStart..<segmentEnd) < configuration.noChordRMS {
                decision = ("N", 1)
            } else {
                let window = AnalysisWorkingSetPolicy.finiteWindow(samples, range: analysisStart..<analysisEnd)
                decision = ChordFrameClassifier.classify(
                    samples: window,
                    sampleRate: sampleRate,
                    configuration: configuration,
                    vocabulary: .conservativeMajorMinor
                )
            }
            decisions.append(
                FrameDecision(
                    startSeconds: Double(segmentStart) / sampleRate,
                    endSeconds: min(duration, Double(segmentEnd) / sampleRate),
                    label: decision.label,
                    confidence: decision.confidence
                )
            )
            segmentStart = segmentEnd
            frameIndex += 1
        }
        try bridgeSingleFrameFlickers(&decisions, cancellationChecksEnabled: cancellationChecksEnabled)
        var merged = try mergeAdjacent(decisions, cancellationChecksEnabled: cancellationChecksEnabled)
        try absorbShortUncertainSegments(
            &merged,
            minimumDuration: configuration.minimumChordSegmentSeconds,
            cancellationChecksEnabled: cancellationChecksEnabled
        )
        merged = try mergeAdjacent(merged, cancellationChecksEnabled: cancellationChecksEnabled)
        try normalizeTimeline(&merged, duration: duration, cancellationChecksEnabled: cancellationChecksEnabled)
        try AnalysisCancellationPolicy.checkIfNeeded(enabled: cancellationChecksEnabled, iteration: 0, stride: 1)
        return merged.compactMap { item in
            guard item.endSeconds > item.startSeconds else { return nil }
            return ChordEvent(
                startSeconds: item.startSeconds,
                endSeconds: item.endSeconds,
                normalizedLabel: item.label,
                confidence: item.confidence
            )
        }
    }

    private static func bridgeSingleFrameFlickers(
        _ decisions: inout [FrameDecision],
        cancellationChecksEnabled: Bool
    ) throws {
        guard decisions.count >= 3 else { return }
        let original = decisions
        for index in 1..<(decisions.count - 1) {
            try AnalysisCancellationPolicy.checkIfNeeded(
                enabled: cancellationChecksEnabled,
                iteration: index,
                stride: AnalysisCancellationPolicy.postProcessCheckStride
            )
            let previous = original[index - 1], current = original[index], next = original[index + 1]
            guard previous.label == next.label, current.label != previous.label, current.label != "N" else { continue }
            let currentConfidence = current.confidence ?? 0
            let neighborConfidence = min(previous.confidence ?? 1, next.confidence ?? 1)
            if current.label == "X" || currentConfidence <= neighborConfidence {
                decisions[index].label = previous.label
                decisions[index].confidence = min(previous.confidence ?? neighborConfidence, next.confidence ?? neighborConfidence)
            }
        }
    }

    private static func mergeAdjacent(
        _ input: [FrameDecision],
        cancellationChecksEnabled: Bool
    ) throws -> [FrameDecision] {
        guard var current = input.first else { return [] }
        var output: [FrameDecision] = []
        output.reserveCapacity(input.count)
        for (offset, next) in input.dropFirst().enumerated() {
            try AnalysisCancellationPolicy.checkIfNeeded(
                enabled: cancellationChecksEnabled,
                iteration: offset,
                stride: AnalysisCancellationPolicy.postProcessCheckStride
            )
            if next.label == current.label, abs(next.startSeconds - current.endSeconds) <= 1e-6 {
                current.confidence = mergeConfidence(
                    lhs: current.confidence,
                    lhsDuration: current.endSeconds - current.startSeconds,
                    rhs: next.confidence,
                    rhsDuration: next.endSeconds - next.startSeconds
                )
                current.endSeconds = next.endSeconds
            } else {
                output.append(current)
                current = next
            }
        }
        output.append(current)
        return output
    }

    private static func absorbShortUncertainSegments(
        _ segments: inout [FrameDecision],
        minimumDuration: Double,
        cancellationChecksEnabled: Bool
    ) throws {
        guard minimumDuration > 0, segments.count > 1 else { return }
        var changed = true
        var pass = 0
        while changed {
            try AnalysisCancellationPolicy.checkIfNeeded(
                enabled: cancellationChecksEnabled,
                iteration: pass,
                stride: 1
            )
            changed = false
            for index in segments.indices {
                try AnalysisCancellationPolicy.checkIfNeeded(
                    enabled: cancellationChecksEnabled,
                    iteration: index,
                    stride: AnalysisCancellationPolicy.postProcessCheckStride
                )
                let duration = segments[index].endSeconds - segments[index].startSeconds
                guard duration < minimumDuration, segments[index].label != "N" else { continue }
                let previousIndex = index > 0 ? index - 1 : nil
                let nextIndex = index + 1 < segments.count ? index + 1 : nil
                if let previousIndex, let nextIndex, segments[previousIndex].label == segments[nextIndex].label {
                    segments[index].label = segments[previousIndex].label
                    segments[index].confidence = min(segments[previousIndex].confidence ?? 1, segments[nextIndex].confidence ?? 1)
                    changed = true
                    break
                }
                let previousConfidence = previousIndex.map { segments[$0].confidence ?? 0 } ?? -1
                let nextConfidence = nextIndex.map { segments[$0].confidence ?? 0 } ?? -1
                if previousConfidence >= nextConfidence, let previousIndex {
                    segments[index].label = segments[previousIndex].label
                    segments[index].confidence = segments[previousIndex].confidence
                    changed = true
                    break
                } else if let nextIndex {
                    segments[index].label = segments[nextIndex].label
                    segments[index].confidence = segments[nextIndex].confidence
                    changed = true
                    break
                }
            }
            if changed {
                segments = try mergeAdjacent(
                    segments,
                    cancellationChecksEnabled: cancellationChecksEnabled
                )
            }
            pass += 1
        }
    }

    private static func normalizeTimeline(
        _ segments: inout [FrameDecision],
        duration: Double,
        cancellationChecksEnabled: Bool
    ) throws {
        guard !segments.isEmpty else { return }
        segments[0].startSeconds = 0
        for index in 1..<segments.count {
            try AnalysisCancellationPolicy.checkIfNeeded(
                enabled: cancellationChecksEnabled,
                iteration: index,
                stride: AnalysisCancellationPolicy.postProcessCheckStride
            )
            let boundary = max(segments[index - 1].startSeconds, min(duration, segments[index].startSeconds))
            segments[index - 1].endSeconds = boundary
            segments[index].startSeconds = boundary
        }
        segments[segments.count - 1].endSeconds = duration
    }

    private static func mergeConfidence(
        lhs: Double?,
        lhsDuration: Double,
        rhs: Double?,
        rhsDuration: Double
    ) -> Double? {
        switch (lhs, rhs) {
        case let (left?, right?):
            let total = max(1e-9, lhsDuration + rhsDuration)
            return (left * lhsDuration + right * rhsDuration) / total
        case let (left?, nil): return left
        case let (nil, right?): return right
        case (nil, nil): return nil
        }
    }
}
