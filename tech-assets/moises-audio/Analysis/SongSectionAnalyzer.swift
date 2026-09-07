import Foundation

public enum SongSectionAnalyzer {
    private struct Descriptor {
        var chordHistogram: [Double]
        var rms: Double
        var zeroCrossingRate: Double
        var decidedCoverage: Double
    }

    private struct BoundaryCandidate {
        var time: Double
        var strength: Double
        var isEnergyCue: Bool
    }

    private struct SegmentWork {
        var start: Double
        var end: Double
        var descriptor: Descriptor
        var cluster: Int = -1
        var structuralLabel: String = "X"
        var functionalLabel: String?
        var confidence: Double = 0
    }

    public static func analyze(
        signal: AnalysisSignal,
        chords: [ChordEvent],
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> [SongSection] {
        let duration = signal.durationSeconds
        guard duration > 0, !signal.monoSamples.isEmpty else { return [] }

        let global = descriptor(signal: signal, chords: chords, start: 0, end: duration)
        guard global.rms >= configuration.sectionSilenceRMS,
              global.decidedCoverage >= configuration.minimumSectionChordCoverage else {
            return [unknownSection(duration: duration)]
        }

        let context = min(configuration.sectionContextSeconds, max(1, duration / 4))
        let hop = configuration.sectionHopSeconds
        var candidates: [BoundaryCandidate] = []

        if duration >= context * 2 + configuration.minimumSectionSeconds {
            var time = context
            while time <= duration - context + 1e-9 {
                let left = descriptor(signal: signal, chords: chords, start: time - context, end: time)
                let right = descriptor(signal: signal, chords: chords, start: time, end: time + context)
                let contextScore = descriptorDistance(left, right)

                let localSpan = min(0.75, context / 2)
                let localLeft = descriptor(signal: signal, chords: chords, start: max(0, time - localSpan), end: time)
                let localRight = descriptor(signal: signal, chords: chords, start: time, end: min(duration, time + localSpan))
                let energyJump = min(1, abs(log10(localLeft.rms + 1e-6) - log10(localRight.rms + 1e-6)) * 1.5)
                let isEnergyCue = energyJump >= configuration.sectionEnergyJumpThreshold
                let energyScore = isEnergyCue ? min(1, 0.55 + 0.6 * energyJump) : 0
                candidates.append(BoundaryCandidate(time: time, strength: max(contextScore, energyScore), isEnergyCue: isEnergyCue))
                time += hop
            }
        }

        var selected: [BoundaryCandidate] = []
        for index in candidates.indices {
            let candidate = candidates[index]
            let previous = index > 0 ? candidates[index - 1].strength : -1
            let next = index + 1 < candidates.count ? candidates[index + 1].strength : -1
            let localMaximum = candidate.strength >= previous && candidate.strength >= next
            guard candidate.strength >= configuration.sectionNoveltyThreshold,
                  localMaximum || candidate.isEnergyCue else { continue }

            let snapped = snapToChordBoundary(candidate.time, chords: chords, maximumDistance: min(1, hop))
            let edgeMinimum = candidate.isEnergyCue
                ? min(configuration.minimumSectionSeconds, configuration.minimumEdgeSectionSeconds)
                : configuration.minimumSectionSeconds
            guard snapped >= edgeMinimum, duration - snapped >= edgeMinimum else { continue }
            selected.append(BoundaryCandidate(time: snapped, strength: candidate.strength, isEnergyCue: candidate.isEnergyCue))
        }

        selected.sort { $0.time < $1.time }
        var filtered: [BoundaryCandidate] = []
        for candidate in selected {
            guard let last = filtered.last else {
                filtered.append(candidate)
                continue
            }
            let separation = (candidate.isEnergyCue || last.isEnergyCue)
                ? min(configuration.minimumSectionSeconds, configuration.minimumEdgeSectionSeconds)
                : configuration.minimumSectionSeconds
            if candidate.time - last.time < separation {
                let candidatePriority = candidate.strength + (candidate.isEnergyCue ? 0.08 : 0)
                let lastPriority = last.strength + (last.isEnergyCue ? 0.08 : 0)
                if candidatePriority > lastPriority { filtered[filtered.count - 1] = candidate }
            } else {
                filtered.append(candidate)
            }
        }

        let boundaries = deduplicated([0.0] + filtered.map(\.time) + [duration])
        var segments: [SegmentWork] = []
        for index in 0..<(max(0, boundaries.count - 1)) where boundaries[index + 1] > boundaries[index] {
            segments.append(
                SegmentWork(
                    start: boundaries[index],
                    end: boundaries[index + 1],
                    descriptor: descriptor(signal: signal, chords: chords, start: boundaries[index], end: boundaries[index + 1])
                )
            )
        }
        guard !segments.isEmpty else { return [unknownSection(duration: duration)] }

        var prototypes: [Descriptor] = []
        var counts: [Int] = []
        for index in segments.indices {
            let matches = prototypes.indices.map { ($0, descriptorSimilarity(segments[index].descriptor, prototypes[$0])) }
            if let best = matches.max(by: { $0.1 < $1.1 }), best.1 >= configuration.sectionClusterSimilarity {
                segments[index].cluster = best.0
                counts[best.0] += 1
                prototypes[best.0] = blend(prototypes[best.0], segments[index].descriptor, previousCount: counts[best.0] - 1)
            } else {
                segments[index].cluster = prototypes.count
                prototypes.append(segments[index].descriptor)
                counts.append(1)
            }
        }

        for index in segments.indices {
            segments[index].structuralLabel = structuralName(for: segments[index].cluster)
            let leftStrength = index == 0 ? 0.65 : strengthNear(segments[index].start, boundaries: filtered)
            let rightStrength = index == segments.count - 1 ? 0.65 : strengthNear(segments[index].end, boundaries: filtered)
            let clusterSimilarity = descriptorSimilarity(segments[index].descriptor, prototypes[segments[index].cluster])
            segments[index].confidence = clamp01(
                0.45 * ((leftStrength + rightStrength) / 2)
                    + 0.35 * clusterSimilarity
                    + 0.20 * segments[index].descriptor.decidedCoverage
            )
        }

        assignFunctionalLabels(
            segments: &segments,
            clusterCounts: counts,
            minimumConfidence: configuration.minimumFunctionalSectionConfidence
        )

        return segments.map {
            SongSection(
                startSeconds: $0.start,
                endSeconds: $0.end,
                structuralLabel: $0.structuralLabel,
                functionalLabel: $0.functionalLabel,
                confidence: $0.confidence
            )
        }
    }

    private static func unknownSection(duration: Double) -> SongSection {
        SongSection(startSeconds: 0, endSeconds: duration, structuralLabel: "X", functionalLabel: nil, confidence: nil)
    }

    private static func assignFunctionalLabels(
        segments: inout [SegmentWork],
        clusterCounts: [Int],
        minimumConfidence: Double
    ) {
        guard !segments.isEmpty else { return }
        let medianEnergy = segments.map { $0.descriptor.rms }.sorted()[segments.count / 2]

        if segments[0].end - segments[0].start <= 12,
           segments[0].descriptor.rms < medianEnergy * 0.75,
           segments[0].confidence >= minimumConfidence {
            segments[0].functionalLabel = "intro"
        }
        let last = segments.count - 1
        if segments[last].end - segments[last].start <= 12,
           segments[last].descriptor.rms < medianEnergy * 0.75,
           segments[last].confidence >= minimumConfidence {
            segments[last].functionalLabel = "outro"
        }

        // Edge sections already explained as intro/outro do not count as an independent
        // repeated family for verse/chorus inference. Require two repeated interior families.
        let repeatedInteriorClusters = clusterCounts.indices.filter { cluster in
            segments.filter { $0.cluster == cluster && $0.functionalLabel == nil }.count >= 2
        }
        guard repeatedInteriorClusters.count >= 2 else { return }

        let averageEnergy = Dictionary(uniqueKeysWithValues: repeatedInteriorClusters.map { cluster in
            let values = segments.filter { $0.cluster == cluster && $0.functionalLabel == nil }.map { $0.descriptor.rms }
            return (cluster, values.reduce(0, +) / Double(values.count))
        })
        let ordered = repeatedInteriorClusters.sorted { averageEnergy[$0, default: 0] > averageEnergy[$1, default: 0] }
        let chorusCluster = ordered[0]
        let verseCluster = ordered[1]

        for index in segments.indices where segments[index].functionalLabel == nil && segments[index].confidence >= minimumConfidence {
            if segments[index].cluster == chorusCluster { segments[index].functionalLabel = "chorus" }
            else if segments[index].cluster == verseCluster { segments[index].functionalLabel = "verse" }
        }

        if segments.count >= 3 {
            for index in 1..<(segments.count - 1) {
                guard segments[index].functionalLabel == nil,
                      segments[index].confidence >= minimumConfidence,
                      clusterCounts[segments[index].cluster] == 1,
                      segments[index].end - segments[index].start <= 16 else { continue }
                let previous = segments[index - 1].cluster
                let next = segments[index + 1].cluster
                if previous == next, clusterCounts[previous] >= 2 {
                    segments[index].functionalLabel = "bridge"
                }
            }
        }
    }

    private static func descriptor(
        signal: AnalysisSignal,
        chords: [ChordEvent],
        start: Double,
        end: Double
    ) -> Descriptor {
        let lower = max(0, start)
        let upper = min(signal.durationSeconds, max(start, end))
        let duration = max(1e-9, upper - lower)
        var histogram = Array(repeating: 0.0, count: 26)
        var decidedDuration = 0.0

        for chord in chords {
            let overlap = max(0, min(upper, chord.endSeconds) - max(lower, chord.startSeconds))
            guard overlap > 0 else { continue }
            histogram[chordIndex(chord.normalizedLabel)] += overlap
            if chord.normalizedLabel != "X" { decidedDuration += overlap }
        }
        let total = histogram.reduce(0, +)
        if total > 0 { histogram = histogram.map { $0 / total } }

        let lowerSample = max(0, Int((lower * signal.sampleRate).rounded(.down)))
        let upperSample = min(signal.monoSamples.count, Int((upper * signal.sampleRate).rounded(.up)))
        var sumSquares = 0.0
        var count = 0
        var crossings = 0
        var previous: Double?
        if upperSample > lowerSample {
            let step = max(1, (upperSample - lowerSample) / 8_000)
            var index = lowerSample
            while index < upperSample {
                let raw = Double(signal.monoSamples[index])
                let sample = raw.isFinite ? raw : 0
                sumSquares += sample * sample
                count += 1
                if let previous, (previous >= 0) != (sample >= 0) { crossings += 1 }
                previous = sample
                index += step
            }
        }

        return Descriptor(
            chordHistogram: histogram,
            rms: count > 0 ? sqrt(sumSquares / Double(count)) : 0,
            zeroCrossingRate: count > 1 ? Double(crossings) / Double(count - 1) : 0,
            decidedCoverage: min(1, decidedDuration / duration)
        )
    }

    private static func chordIndex(_ label: String) -> Int {
        if label == "N" { return 24 }
        if label == "X" { return 25 }
        let pitchClass: [String: Int] = [
            "C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
            "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11
        ]
        let root = String(label.split(separator: ":", maxSplits: 1).first ?? "C")
        return label.contains(":min") ? 12 + (pitchClass[root] ?? 0) : (pitchClass[root] ?? 0)
    }

    private static func descriptorDistance(_ lhs: Descriptor, _ rhs: Descriptor) -> Double {
        let chordDistance = 1 - cosine(lhs.chordHistogram, rhs.chordHistogram)
        let energyDistance = min(1, abs(log10(lhs.rms + 1e-6) - log10(rhs.rms + 1e-6)) / 3)
        let zeroCrossingDistance = min(1, abs(lhs.zeroCrossingRate - rhs.zeroCrossingRate) * 8)
        return clamp01(0.72 * chordDistance + 0.20 * energyDistance + 0.08 * zeroCrossingDistance)
    }

    private static func descriptorSimilarity(_ lhs: Descriptor, _ rhs: Descriptor) -> Double {
        let chordSimilarity = cosine(lhs.chordHistogram, rhs.chordHistogram)
        let energySimilarity = 1 - min(1, abs(log10(lhs.rms + 1e-6) - log10(rhs.rms + 1e-6)) / 2)
        let zeroCrossingSimilarity = 1 - min(1, abs(lhs.zeroCrossingRate - rhs.zeroCrossingRate) * 6)
        return clamp01(0.75 * chordSimilarity + 0.18 * energySimilarity + 0.07 * zeroCrossingSimilarity)
    }

    private static func blend(_ lhs: Descriptor, _ rhs: Descriptor, previousCount: Int) -> Descriptor {
        let weight = Double(max(1, previousCount))
        let denominator = weight + 1
        return Descriptor(
            chordHistogram: zip(lhs.chordHistogram, rhs.chordHistogram).map { ($0.0 * weight + $0.1) / denominator },
            rms: (lhs.rms * weight + rhs.rms) / denominator,
            zeroCrossingRate: (lhs.zeroCrossingRate * weight + rhs.zeroCrossingRate) / denominator,
            decidedCoverage: (lhs.decidedCoverage * weight + rhs.decidedCoverage) / denominator
        )
    }

    private static func snapToChordBoundary(_ time: Double, chords: [ChordEvent], maximumDistance: Double) -> Double {
        let boundaries = chords.flatMap { [$0.startSeconds, $0.endSeconds] }.filter { $0 > 0 }
        guard let nearest = boundaries.min(by: { abs($0 - time) < abs($1 - time) }),
              abs(nearest - time) <= maximumDistance else { return time }
        return nearest
    }

    private static func strengthNear(_ time: Double, boundaries: [BoundaryCandidate]) -> Double {
        boundaries.min(by: { abs($0.time - time) < abs($1.time - time) })?.strength ?? 0.5
    }

    private static func deduplicated(_ values: [Double]) -> [Double] {
        var result: [Double] = []
        for value in values.sorted() {
            if let last = result.last, abs(last - value) <= 1e-6 { continue }
            result.append(value)
        }
        return result
    }

    private static func structuralName(for index: Int) -> String {
        if index < 26, let scalar = UnicodeScalar(65 + index) { return String(scalar) }
        return "S\(index + 1)"
    }

    private static func cosine(_ lhs: [Double], _ rhs: [Double]) -> Double {
        let dot = zip(lhs, rhs).reduce(0.0) { $0 + $1.0 * $1.1 }
        let left = sqrt(lhs.reduce(0.0) { $0 + $1 * $1 })
        let right = sqrt(rhs.reduce(0.0) { $0 + $1 * $1 })
        guard left > 1e-12, right > 1e-12 else { return 0 }
        return dot / (left * right)
    }

    private static func clamp01(_ value: Double) -> Double { min(1, max(0, value)) }
}
