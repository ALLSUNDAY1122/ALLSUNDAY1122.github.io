import Foundation

public enum StreamingBoundedChordTimelineAnalyzer {
    public static func analyzeCancellable(
        reader: AnalysisPreparedSampleReader,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) throws -> [ChordEvent] {
        try AnalysisCancellationPolicy.check()
        guard reader.durationSeconds > 0, reader.sampleCount > 0 else { return [] }
        let sampleRate = reader.sampleRate
        let windowSamples = max(256, min(reader.sampleCount, Int((configuration.chordWindowSeconds * sampleRate).rounded())))
        let hopSamples = max(1, Int((configuration.chordHopSeconds * sampleRate).rounded()))
        let duration = reader.durationSeconds
        var decisions: [AnalysisPreparedChordFrameDecision] = []
        decisions.reserveCapacity(max(1, Int(ceil(Double(reader.sampleCount) / Double(hopSamples)))))
        var segmentStart = 0, frameIndex = 0
        while segmentStart < reader.sampleCount {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: frameIndex, stride: AnalysisCancellationPolicy.chordFrameCheckStride)
            let segmentEnd = min(reader.sampleCount, segmentStart + hopSamples)
            let center = segmentStart + (segmentEnd - segmentStart) / 2
            let half = windowSamples / 2
            var analysisStart = max(0, center - half)
            var analysisEnd = min(reader.sampleCount, analysisStart + windowSamples)
            if analysisEnd - analysisStart < windowSamples {
                analysisStart = max(0, analysisEnd - windowSamples)
                analysisEnd = min(reader.sampleCount, analysisStart + windowSamples)
            }
            let decision: (label: String, confidence: Double?)
            if try reader.rms(range: segmentStart..<segmentEnd) < configuration.noChordRMS {
                decision = ("N", 1)
            } else {
                decision = ChordFrameClassifier.classify(
                    samples: try reader.finiteWindow(range: analysisStart..<analysisEnd),
                    sampleRate: sampleRate,
                    configuration: configuration,
                    vocabulary: .conservativeMajorMinor
                )
            }
            decisions.append(.init(
                startSeconds: Double(segmentStart) / sampleRate,
                endSeconds: min(duration, Double(segmentEnd) / sampleRate),
                label: decision.label,
                confidence: decision.confidence
            ))
            segmentStart = segmentEnd
            frameIndex += 1
        }
        return try finalizePreclassifiedFramesCancellable(
            decisions,
            duration: duration,
            configuration: configuration
        )
    }

    public static func finalizePreclassifiedFramesCancellable(
        _ input: [AnalysisPreparedChordFrameDecision],
        duration: Double,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) throws -> [ChordEvent] {
        try AnalysisCancellationPolicy.check()
        guard duration.isFinite, duration > 0 else { return [] }
        var decisions = input
        try bridgeSingleFrameFlickers(&decisions)
        var merged = try mergeAdjacent(decisions)
        try absorbShortUncertainSegments(&merged, minimumDuration: configuration.minimumChordSegmentSeconds)
        merged = try mergeAdjacent(merged)
        try normalizeTimeline(&merged, duration: duration)
        try AnalysisCancellationPolicy.check()
        return merged.compactMap {
            $0.endSeconds > $0.startSeconds
                ? ChordEvent(startSeconds: $0.startSeconds, endSeconds: $0.endSeconds, normalizedLabel: $0.label, confidence: $0.confidence)
                : nil
        }
    }

    private static func bridgeSingleFrameFlickers(_ decisions: inout [AnalysisPreparedChordFrameDecision]) throws {
        guard decisions.count >= 3 else { return }
        let original = decisions
        for index in 1..<(decisions.count - 1) {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: index, stride: AnalysisCancellationPolicy.postProcessCheckStride)
            let previous = original[index - 1], current = original[index], next = original[index + 1]
            guard previous.label == next.label, current.label != previous.label, current.label != "N" else { continue }
            let currentConfidence = current.confidence ?? 0
            let neighborConfidence = min(previous.confidence ?? 1, next.confidence ?? 1)
            if current.label == "X" || currentConfidence <= neighborConfidence {
                decisions[index] = .init(
                    startSeconds: current.startSeconds,
                    endSeconds: current.endSeconds,
                    label: previous.label,
                    confidence: min(previous.confidence ?? neighborConfidence, next.confidence ?? neighborConfidence)
                )
            }
        }
    }

    private static func mergeAdjacent(_ input: [AnalysisPreparedChordFrameDecision]) throws -> [AnalysisPreparedChordFrameDecision] {
        guard var current = input.first else { return [] }
        var output: [AnalysisPreparedChordFrameDecision] = []
        output.reserveCapacity(input.count)
        for (offset, next) in input.dropFirst().enumerated() {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: offset, stride: AnalysisCancellationPolicy.postProcessCheckStride)
            if next.label == current.label, abs(next.startSeconds - current.endSeconds) <= 1e-6 {
                current = .init(
                    startSeconds: current.startSeconds,
                    endSeconds: next.endSeconds,
                    label: current.label,
                    confidence: mergeConfidence(
                        lhs: current.confidence,
                        lhsDuration: current.endSeconds - current.startSeconds,
                        rhs: next.confidence,
                        rhsDuration: next.endSeconds - next.startSeconds
                    )
                )
            } else {
                output.append(current)
                current = next
            }
        }
        output.append(current)
        return output
    }

    private static func absorbShortUncertainSegments(
        _ segments: inout [AnalysisPreparedChordFrameDecision],
        minimumDuration: Double
    ) throws {
        guard minimumDuration > 0, segments.count > 1 else { return }
        var changed = true, pass = 0
        while changed {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: pass, stride: 1)
            changed = false
            for index in segments.indices {
                try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: index, stride: AnalysisCancellationPolicy.postProcessCheckStride)
                let duration = segments[index].endSeconds - segments[index].startSeconds
                guard duration < minimumDuration, segments[index].label != "N" else { continue }
                let previousIndex = index > 0 ? index - 1 : nil
                let nextIndex = index + 1 < segments.count ? index + 1 : nil
                if let previousIndex, let nextIndex, segments[previousIndex].label == segments[nextIndex].label {
                    segments[index] = .init(
                        startSeconds: segments[index].startSeconds,
                        endSeconds: segments[index].endSeconds,
                        label: segments[previousIndex].label,
                        confidence: min(segments[previousIndex].confidence ?? 1, segments[nextIndex].confidence ?? 1)
                    )
                    changed = true
                    break
                }
                let previousConfidence = previousIndex.map { segments[$0].confidence ?? 0 } ?? -1
                let nextConfidence = nextIndex.map { segments[$0].confidence ?? 0 } ?? -1
                if previousConfidence >= nextConfidence, let previousIndex {
                    segments[index] = .init(
                        startSeconds: segments[index].startSeconds,
                        endSeconds: segments[index].endSeconds,
                        label: segments[previousIndex].label,
                        confidence: segments[previousIndex].confidence
                    )
                    changed = true
                    break
                } else if let nextIndex {
                    segments[index] = .init(
                        startSeconds: segments[index].startSeconds,
                        endSeconds: segments[index].endSeconds,
                        label: segments[nextIndex].label,
                        confidence: segments[nextIndex].confidence
                    )
                    changed = true
                    break
                }
            }
            if changed { segments = try mergeAdjacent(segments) }
            pass += 1
        }
    }

    private static func normalizeTimeline(_ segments: inout [AnalysisPreparedChordFrameDecision], duration: Double) throws {
        guard !segments.isEmpty else { return }
        segments[0] = .init(startSeconds: 0, endSeconds: segments[0].endSeconds, label: segments[0].label, confidence: segments[0].confidence)
        for index in 1..<segments.count {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: index, stride: AnalysisCancellationPolicy.postProcessCheckStride)
            let boundary = max(segments[index - 1].startSeconds, min(duration, segments[index].startSeconds))
            let previous = segments[index - 1]
            let current = segments[index]
            segments[index - 1] = .init(startSeconds: previous.startSeconds, endSeconds: boundary, label: previous.label, confidence: previous.confidence)
            segments[index] = .init(startSeconds: boundary, endSeconds: current.endSeconds, label: current.label, confidence: current.confidence)
        }
        let last = segments[segments.count - 1]
        segments[segments.count - 1] = .init(startSeconds: last.startSeconds, endSeconds: duration, label: last.label, confidence: last.confidence)
    }

    private static func mergeConfidence(lhs: Double?, lhsDuration: Double, rhs: Double?, rhsDuration: Double) -> Double? {
        switch (lhs, rhs) {
        case let (left?, right?):
            let total = max(1e-9, lhsDuration + rhsDuration)
            return (left * lhsDuration + right * rhsDuration) / total
        case let (left?, nil): return left
        case let (nil, right?): return right
        default: return nil
        }
    }
}
