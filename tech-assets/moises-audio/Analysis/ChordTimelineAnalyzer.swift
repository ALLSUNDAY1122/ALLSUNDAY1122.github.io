import Foundation

public enum ChordTimelineAnalyzer {
    private struct FrameDecision {
        var startSeconds: Double
        var endSeconds: Double
        var label: String
        var confidence: Double?
    }

    private struct Candidate {
        let root: Int
        let quality: String
        let score: Double
    }

    private static let pitchNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    public static func analyze(
        signal: AnalysisSignal,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> [ChordEvent] {
        guard signal.durationSeconds > 0, !signal.monoSamples.isEmpty else { return [] }

        let prepared = resampleForAnalysis(signal: signal, targetSampleRate: configuration.chordAnalysisSampleRate)
        let samples = prepared.monoSamples.map { value -> Double in
            let sample = Double(value)
            return sample.isFinite ? sample : 0
        }
        guard !samples.isEmpty else { return [] }

        let sampleRate = prepared.sampleRate
        let windowSamples = max(256, min(samples.count, Int((configuration.chordWindowSeconds * sampleRate).rounded())))
        let hopSamples = max(1, Int((configuration.chordHopSeconds * sampleRate).rounded()))
        let duration = prepared.durationSeconds

        var decisions: [FrameDecision] = []
        var segmentStart = 0
        while segmentStart < samples.count {
            let segmentEnd = min(samples.count, segmentStart + hopSamples)
            let analysisCenter = segmentStart + (segmentEnd - segmentStart) / 2
            let halfWindow = windowSamples / 2
            var analysisStart = max(0, analysisCenter - halfWindow)
            var analysisEnd = min(samples.count, analysisStart + windowSamples)
            if analysisEnd - analysisStart < windowSamples {
                analysisStart = max(0, analysisEnd - windowSamples)
                analysisEnd = min(samples.count, analysisStart + windowSamples)
            }

            let localHop = Array(samples[segmentStart..<segmentEnd])
            let decision: (label: String, confidence: Double?)
            if rms(localHop) < configuration.noChordRMS {
                decision = ("N", 1)
            } else {
                let slice = Array(samples[analysisStart..<analysisEnd])
                decision = classify(
                    samples: slice,
                    sampleRate: sampleRate,
                    configuration: configuration
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
        }

        bridgeSingleFrameFlickers(&decisions)
        var merged = mergeAdjacent(decisions)
        absorbShortUncertainSegments(&merged, minimumDuration: configuration.minimumChordSegmentSeconds)
        merged = mergeAdjacent(merged)
        normalizeTimeline(&merged, duration: duration)

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

    private static func classify(
        samples: [Double],
        sampleRate: Double,
        configuration: MusicAnalysisConfiguration
    ) -> (label: String, confidence: Double?) {
        guard !samples.isEmpty else { return ("N", 1) }
        let localRMS = rms(samples)
        guard localRMS >= configuration.noChordRMS else { return ("N", 1) }

        let chroma = chromaForWindow(samples, sampleRate: sampleRate)
        let total = chroma.reduce(0, +)
        guard total > 1e-12 else { return ("X", nil) }
        let normalized = chroma.map { $0 / total }
        let maximum = normalized.max() ?? 0
        let activePitchClasses = normalized.filter { $0 >= maximum * 0.18 }.count
        guard activePitchClasses >= 2 else { return ("X", nil) }

        var candidates: [Candidate] = []
        for root in 0..<12 {
            candidates.append(Candidate(root: root, quality: "major", score: templateScore(chroma: normalized, root: root, intervals: [0, 4, 7])))
            candidates.append(Candidate(root: root, quality: "minor", score: templateScore(chroma: normalized, root: root, intervals: [0, 3, 7])))
        }
        candidates.sort {
            if $0.score == $1.score {
                if $0.root == $1.root { return $0.quality < $1.quality }
                return $0.root < $1.root
            }
            return $0.score > $1.score
        }
        guard let best = candidates.first else { return ("X", nil) }
        let second = candidates.dropFirst().first?.score ?? 0
        let margin = max(0, best.score - second)
        let relativeMargin = margin / max(best.score, 1e-9)
        let scoreStrength = max(0, min(1, (best.score - 0.45) / 0.55))
        let confidence = min(1, 0.65 * relativeMargin + 0.35 * scoreStrength)

        guard best.score >= configuration.minimumChordTemplateScore,
              confidence >= configuration.minimumChordConfidence else {
            return ("X", confidence)
        }

        let root = pitchNames[best.root]
        let label = best.quality == "minor" ? "\(root):min" : root
        return (label, confidence)
    }

    private static func chromaForWindow(_ samples: [Double], sampleRate: Double) -> [Double] {
        guard samples.count > 1 else { return Array(repeating: 0, count: 12) }
        var windowed = Array(repeating: 0.0, count: samples.count)
        for index in samples.indices {
            let hann = 0.5 - 0.5 * cos((2 * Double.pi * Double(index)) / Double(samples.count - 1))
            windowed[index] = samples[index] * hann
        }

        var chroma = Array(repeating: 0.0, count: 12)
        for midi in 36...83 {
            let frequency = 440.0 * pow(2.0, Double(midi - 69) / 12.0)
            guard frequency < sampleRate * 0.45 else { continue }
            let power = goertzelPower(windowed, sampleRate: sampleRate, frequency: frequency)
            chroma[(midi % 12 + 12) % 12] += sqrt(max(0, power))
        }
        return chroma
    }

    private static func templateScore(chroma: [Double], root: Int, intervals: [Int]) -> Double {
        var template = Array(repeating: 0.0, count: 12)
        let weights = [1.0, 0.82, 0.68]
        for (offset, interval) in intervals.enumerated() {
            template[(root + interval) % 12] = weights[min(offset, weights.count - 1)]
        }
        let dot = zip(chroma, template).reduce(0.0) { $0 + $1.0 * $1.1 }
        let chromaNorm = sqrt(chroma.reduce(0.0) { $0 + $1 * $1 })
        let templateNorm = sqrt(template.reduce(0.0) { $0 + $1 * $1 })
        guard chromaNorm > 1e-12, templateNorm > 1e-12 else { return 0 }
        let cosineScore = dot / (chromaNorm * templateNorm)
        let templateCoverage = intervals.reduce(0.0) { $0 + chroma[(root + $1) % 12] }
        return 0.7 * cosineScore + 0.3 * templateCoverage
    }

    private static func goertzelPower(_ samples: [Double], sampleRate: Double, frequency: Double) -> Double {
        let omega = 2 * Double.pi * frequency / sampleRate
        let coefficient = 2 * cos(omega)
        var s0 = 0.0
        var s1 = 0.0
        var s2 = 0.0
        for sample in samples {
            s0 = sample + coefficient * s1 - s2
            s2 = s1
            s1 = s0
        }
        return max(0, s1 * s1 + s2 * s2 - coefficient * s1 * s2)
    }

    private static func resampleForAnalysis(signal: AnalysisSignal, targetSampleRate: Double) -> AnalysisSignal {
        let target = min(signal.sampleRate, targetSampleRate)
        guard signal.sampleRate > target * 1.05 else { return signal }
        let ratio = signal.sampleRate / target
        let outputCount = max(1, Int(Double(signal.monoSamples.count) / ratio))
        var output: [Float] = []
        output.reserveCapacity(outputCount)
        for outputIndex in 0..<outputCount {
            let sourceStart = Int(Double(outputIndex) * ratio)
            let sourceEnd = min(signal.monoSamples.count, max(sourceStart + 1, Int(Double(outputIndex + 1) * ratio)))
            guard sourceStart < sourceEnd else { continue }
            var sum = 0.0
            var count = 0
            for index in sourceStart..<sourceEnd {
                let value = Double(signal.monoSamples[index])
                if value.isFinite {
                    sum += value
                    count += 1
                }
            }
            output.append(count > 0 ? Float(sum / Double(count)) : 0)
        }
        return AnalysisSignal(sampleRate: target, monoSamples: output)
    }

    private static func bridgeSingleFrameFlickers(_ decisions: inout [FrameDecision]) {
        guard decisions.count >= 3 else { return }
        let original = decisions
        for index in 1..<(decisions.count - 1) {
            let previous = original[index - 1]
            let current = original[index]
            let next = original[index + 1]
            guard previous.label == next.label,
                  current.label != previous.label,
                  current.label != "N" else { continue }
            let currentConfidence = current.confidence ?? 0
            let neighborConfidence = min(previous.confidence ?? 1, next.confidence ?? 1)
            if current.label == "X" || currentConfidence <= neighborConfidence {
                decisions[index].label = previous.label
                decisions[index].confidence = min(previous.confidence ?? neighborConfidence, next.confidence ?? neighborConfidence)
            }
        }
    }

    private static func mergeAdjacent(_ input: [FrameDecision]) -> [FrameDecision] {
        guard var current = input.first else { return [] }
        var output: [FrameDecision] = []
        for next in input.dropFirst() {
            if next.label == current.label, abs(next.startSeconds - current.endSeconds) <= 1e-6 {
                let weightedConfidence = mergeConfidence(
                    lhs: current.confidence,
                    lhsDuration: current.endSeconds - current.startSeconds,
                    rhs: next.confidence,
                    rhsDuration: next.endSeconds - next.startSeconds
                )
                current.endSeconds = next.endSeconds
                current.confidence = weightedConfidence
            } else {
                output.append(current)
                current = next
            }
        }
        output.append(current)
        return output
    }

    private static func absorbShortUncertainSegments(_ segments: inout [FrameDecision], minimumDuration: Double) {
        guard minimumDuration > 0, segments.count > 1 else { return }
        var changed = true
        while changed {
            changed = false
            for index in segments.indices {
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
            if changed { segments = mergeAdjacent(segments) }
        }
    }

    private static func normalizeTimeline(_ segments: inout [FrameDecision], duration: Double) {
        guard !segments.isEmpty else { return }
        segments[0].startSeconds = 0
        for index in 1..<segments.count {
            let boundary = max(segments[index - 1].startSeconds, min(duration, segments[index].startSeconds))
            segments[index - 1].endSeconds = boundary
            segments[index].startSeconds = boundary
        }
        segments[segments.count - 1].endSeconds = duration
    }

    private static func mergeConfidence(lhs: Double?, lhsDuration: Double, rhs: Double?, rhsDuration: Double) -> Double? {
        switch (lhs, rhs) {
        case let (left?, right?):
            let total = max(1e-9, lhsDuration + rhsDuration)
            return (left * lhsDuration + right * rhsDuration) / total
        case let (left?, nil): return left
        case let (nil, right?): return right
        case (nil, nil): return nil
        }
    }

    private static func rms(_ samples: [Double]) -> Double {
        guard !samples.isEmpty else { return 0 }
        return sqrt(samples.reduce(0.0) { $0 + $1 * $1 } / Double(samples.count))
    }
}
