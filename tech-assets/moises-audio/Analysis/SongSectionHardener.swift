import Foundation

public enum SongSectionHardener {
    private struct Descriptor {
        var chordHistogram: [Double]
        var rms: Double
        var decidedCoverage: Double
    }

    private struct WorkSection {
        var start: Double
        var end: Double
        var descriptor: Descriptor
        var sourceConfidence: Double?
        var cluster: Int = -1
        var structuralLabel: String = "X"
        var functionalLabel: String?
        var confidence: Double?

        var duration: Double { end - start }
    }

    public static func analyze(
        signal: AnalysisSignal,
        chords: [ChordEvent],
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> [SongSection] {
        let base = SongSectionAnalyzer.analyze(signal: signal, chords: chords, configuration: configuration)
        return harden(sections: base, signal: signal, chords: chords, configuration: configuration)
    }

    public static func harden(
        sections: [SongSection],
        signal: AnalysisSignal,
        chords: [ChordEvent],
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> [SongSection] {
        let duration = signal.durationSeconds
        guard duration > 0, !signal.monoSamples.isEmpty else { return [] }
        guard !sections.isEmpty else {
            return [SongSection(startSeconds: 0, endSeconds: duration, structuralLabel: "X", functionalLabel: nil, confidence: nil)]
        }

        var work = sections
            .compactMap { section -> WorkSection? in
                let start = min(duration, max(0, section.startSeconds))
                let end = min(duration, max(start, section.endSeconds))
                guard end - start > 1e-6 else { return nil }
                return WorkSection(
                    start: start,
                    end: end,
                    descriptor: descriptor(signal: signal, chords: chords, start: start, end: end),
                    sourceConfidence: section.confidence
                )
            }
            .sorted { lhs, rhs in
                if lhs.start == rhs.start { return lhs.end < rhs.end }
                return lhs.start < rhs.start
            }

        guard !work.isEmpty else {
            return [SongSection(startSeconds: 0, endSeconds: duration, structuralLabel: "X", functionalLabel: nil, confidence: nil)]
        }

        work = suppressFalseBoundaries(work, configuration: configuration)
        clusterAndScore(&work, configuration: configuration)
        assignFunctionalLabels(&work, configuration: configuration)

        return work.map { item in
            SongSection(
                startSeconds: item.start,
                endSeconds: item.end,
                structuralLabel: item.structuralLabel,
                functionalLabel: item.functionalLabel,
                confidence: item.confidence
            )
        }
    }

    public static func diagnostics(sections: [SongSection], duration: Double) -> [String: Double] {
        guard duration > 0 else {
            return [
                "section_count": Double(sections.count),
                "unknown_duration_ratio": 1,
                "functional_decision_ratio": 0,
                "mean_section_confidence": 0
            ]
        }

        var unknownDuration = 0.0
        var functionalDuration = 0.0
        var confidenceWeighted = 0.0
        var confidenceDuration = 0.0
        for section in sections {
            let clampedStart = min(duration, max(0, section.startSeconds))
            let clampedEnd = min(duration, max(clampedStart, section.endSeconds))
            let sectionDuration = clampedEnd - clampedStart
            guard sectionDuration > 0 else { continue }
            if section.structuralLabel == "X" { unknownDuration += sectionDuration }
            if section.functionalLabel != nil { functionalDuration += sectionDuration }
            if let confidence = section.confidence, confidence.isFinite {
                confidenceWeighted += min(1, max(0, confidence)) * sectionDuration
                confidenceDuration += sectionDuration
            }
        }

        return [
            "section_count": Double(sections.count),
            "unknown_duration_ratio": min(1, unknownDuration / duration),
            "functional_decision_ratio": min(1, functionalDuration / duration),
            "mean_section_confidence": confidenceDuration > 0 ? confidenceWeighted / confidenceDuration : 0
        ]
    }

    private static func suppressFalseBoundaries(
        _ input: [WorkSection],
        configuration: MusicAnalysisConfiguration
    ) -> [WorkSection] {
        guard input.count >= 2 else { return input }
        var output: [WorkSection] = []
        let mergeSimilarity = min(0.98, max(0.90, configuration.sectionClusterSimilarity + 0.06))
        let maximumNovelty = min(0.58, configuration.sectionNoveltyThreshold + 0.10)

        for current in input {
            guard var previous = output.last else {
                output.append(current)
                continue
            }
            let similarity = descriptorSimilarity(previous.descriptor, current.descriptor)
            let novelty = descriptorDistance(previous.descriptor, current.descriptor)
            let hasDecidedEvidence = previous.descriptor.decidedCoverage >= configuration.minimumSectionChordCoverage
                && current.descriptor.decidedCoverage >= configuration.minimumSectionChordCoverage
            let shouldMerge = hasDecidedEvidence && similarity >= mergeSimilarity && novelty <= maximumNovelty

            if shouldMerge {
                output.removeLast()
                let previousDuration = previous.duration
                let currentDuration = current.duration
                let totalDuration = max(1e-9, previousDuration + currentDuration)
                previous.end = current.end
                previous.descriptor = blend(
                    previous.descriptor,
                    current.descriptor,
                    leftWeight: previousDuration / totalDuration,
                    rightWeight: currentDuration / totalDuration
                )
                previous.sourceConfidence = weightedConfidence(
                    previous.sourceConfidence,
                    current.sourceConfidence,
                    leftWeight: previousDuration / totalDuration,
                    rightWeight: currentDuration / totalDuration
                )
                output.append(previous)
            } else {
                output.append(current)
            }
        }
        return output
    }

    private static func clusterAndScore(
        _ work: inout [WorkSection],
        configuration: MusicAnalysisConfiguration
    ) {
        var prototypes: [Descriptor] = []
        var prototypeWeights: [Double] = []

        for index in work.indices {
            let descriptor = work[index].descriptor
            guard descriptor.decidedCoverage >= configuration.minimumSectionChordCoverage,
                  descriptor.rms >= configuration.sectionSilenceRMS else {
                work[index].cluster = -1
                work[index].structuralLabel = "X"
                work[index].functionalLabel = nil
                work[index].confidence = nil
                continue
            }

            let matches = prototypes.indices.map { prototypeIndex in
                (prototypeIndex, descriptorSimilarity(descriptor, prototypes[prototypeIndex]))
            }
            if let best = matches.max(by: { $0.1 < $1.1 }), best.1 >= configuration.sectionClusterSimilarity {
                work[index].cluster = best.0
                let oldWeight = prototypeWeights[best.0]
                let newWeight = max(1e-9, work[index].duration)
                let denominator = oldWeight + newWeight
                prototypes[best.0] = blend(
                    prototypes[best.0],
                    descriptor,
                    leftWeight: oldWeight / denominator,
                    rightWeight: newWeight / denominator
                )
                prototypeWeights[best.0] = denominator
            } else {
                work[index].cluster = prototypes.count
                prototypes.append(descriptor)
                prototypeWeights.append(max(1e-9, work[index].duration))
            }
        }

        for index in work.indices where work[index].cluster >= 0 {
            let cluster = work[index].cluster
            let similarity = descriptorSimilarity(work[index].descriptor, prototypes[cluster])
            let source = work[index].sourceConfidence.map { min(1, max(0, $0)) } ?? 0.55
            let evidence = clamp01(
                0.48 * source
                    + 0.30 * work[index].descriptor.decidedCoverage
                    + 0.22 * similarity
            )
            work[index].structuralLabel = structuralName(for: cluster)
            work[index].confidence = evidence
            work[index].functionalLabel = nil
        }
    }

    private static func assignFunctionalLabels(
        _ work: inout [WorkSection],
        configuration: MusicAnalysisConfiguration
    ) {
        let eligibleIndices = work.indices.filter {
            work[$0].cluster >= 0
                && (work[$0].confidence ?? 0) >= configuration.minimumFunctionalSectionConfidence
        }
        guard !eligibleIndices.isEmpty else { return }

        let sortedEnergy = eligibleIndices.map { work[$0].descriptor.rms }.sorted()
        let medianEnergy = sortedEnergy[sortedEnergy.count / 2]

        if let first = eligibleIndices.first,
           first == work.startIndex,
           work[first].duration <= 14,
           work[first].descriptor.rms < medianEnergy * 0.82 {
            work[first].functionalLabel = "intro"
        }
        if let last = eligibleIndices.last,
           last == work.index(before: work.endIndex),
           work[last].duration <= 14,
           work[last].descriptor.rms < medianEnergy * 0.82 {
            work[last].functionalLabel = "outro"
        }

        var occurrences: [Int: [Int]] = [:]
        for index in eligibleIndices where work[index].functionalLabel == nil {
            occurrences[work[index].cluster, default: []].append(index)
        }
        let repeatedClusters = occurrences.keys.filter { occurrences[$0, default: []].count >= 2 }
        guard repeatedClusters.count >= 2 else {
            assignConservativeBridgeOnly(&work, eligibleIndices: eligibleIndices)
            return
        }

        let averageEnergy: [Int: Double] = Dictionary(uniqueKeysWithValues: repeatedClusters.map { cluster in
            let indices = occurrences[cluster, default: []]
            let average = indices.map { work[$0].descriptor.rms }.reduce(0, +) / Double(indices.count)
            return (cluster, average)
        })
        let averageDuration: [Int: Double] = Dictionary(uniqueKeysWithValues: repeatedClusters.map { cluster in
            let indices = occurrences[cluster, default: []]
            let average = indices.map { work[$0].duration }.reduce(0, +) / Double(indices.count)
            return (cluster, average)
        })

        let chorusCluster = repeatedClusters.max { lhs, rhs in
            let lhsScore = averageEnergy[lhs, default: 0] * (1 + min(0.20, averageDuration[lhs, default: 0] / 80))
            let rhsScore = averageEnergy[rhs, default: 0] * (1 + min(0.20, averageDuration[rhs, default: 0] / 80))
            return lhsScore < rhsScore
        }

        guard let chorusCluster else { return }

        var preChorusClusters = Set<Int>()
        for cluster in repeatedClusters where cluster != chorusCluster {
            let indices = occurrences[cluster, default: []]
            let qualifying = indices.filter { index in
                let next = index + 1
                guard next < work.count else { return false }
                return work[next].cluster == chorusCluster
                    && work[index].duration <= 18
            }
            if qualifying.count >= 2,
               Double(qualifying.count) / Double(indices.count) >= 0.75 {
                preChorusClusters.insert(cluster)
            }
        }

        let verseCandidates = repeatedClusters.filter {
            $0 != chorusCluster && !preChorusClusters.contains($0)
        }
        guard let verseCluster = verseCandidates.max(by: {
            occurrences[$0, default: []].count < occurrences[$1, default: []].count
        }) else {
            assignConservativeBridgeOnly(&work, eligibleIndices: eligibleIndices)
            return
        }

        let chorusEnergy = averageEnergy[chorusCluster, default: 0]
        let verseEnergy = averageEnergy[verseCluster, default: 0]
        let denominator = max(1e-9, max(chorusEnergy, verseEnergy))
        let energySeparation = abs(chorusEnergy - verseEnergy) / denominator
        guard energySeparation >= 0.08 else {
            assignConservativeBridgeOnly(&work, eligibleIndices: eligibleIndices)
            return
        }

        for index in eligibleIndices where work[index].functionalLabel == nil {
            let cluster = work[index].cluster
            if cluster == chorusCluster {
                work[index].functionalLabel = "chorus"
            } else if cluster == verseCluster {
                work[index].functionalLabel = "verse"
            } else if preChorusClusters.contains(cluster) {
                work[index].functionalLabel = "pre-chorus"
            }
        }

        let chorusIndices = work.indices.filter { work[$0].functionalLabel == "chorus" }
        for index in eligibleIndices where work[index].functionalLabel == nil {
            guard work[index].duration <= 24,
                  occurrences[work[index].cluster, default: []].count == 1 else { continue }
            let hasPriorChorus = chorusIndices.contains { $0 < index }
            let hasLaterChorus = chorusIndices.contains { $0 > index }
            if hasPriorChorus && hasLaterChorus {
                work[index].functionalLabel = "bridge"
            }
        }
    }

    private static func assignConservativeBridgeOnly(
        _ work: inout [WorkSection],
        eligibleIndices: [Int]
    ) {
        let clusterCounts = Dictionary(grouping: eligibleIndices, by: { work[$0].cluster }).mapValues(\.count)
        for index in eligibleIndices {
            guard work[index].functionalLabel == nil,
                  work[index].duration <= 24,
                  clusterCounts[work[index].cluster, default: 0] == 1,
                  index > 0,
                  index + 1 < work.count,
                  work[index - 1].cluster == work[index + 1].cluster,
                  clusterCounts[work[index - 1].cluster, default: 0] >= 2 else { continue }
            work[index].functionalLabel = "bridge"
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
            if chord.normalizedLabel != "X" && chord.normalizedLabel != "N" {
                decidedDuration += overlap
            }
        }
        let total = histogram.reduce(0, +)
        if total > 0 { histogram = histogram.map { $0 / total } }

        let lowerSample = max(0, Int((lower * signal.sampleRate).rounded(.down)))
        let upperSample = min(signal.monoSamples.count, Int((upper * signal.sampleRate).rounded(.up)))
        var sumSquares = 0.0
        var count = 0
        if upperSample > lowerSample {
            let step = max(1, (upperSample - lowerSample) / 8_000)
            var index = lowerSample
            while index < upperSample {
                let raw = Double(signal.monoSamples[index])
                let sample = raw.isFinite ? raw : 0
                sumSquares += sample * sample
                count += 1
                index += step
            }
        }

        return Descriptor(
            chordHistogram: histogram,
            rms: count > 0 ? sqrt(sumSquares / Double(count)) : 0,
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

    private static func descriptorSimilarity(_ lhs: Descriptor, _ rhs: Descriptor) -> Double {
        let chordSimilarity = cosine(lhs.chordHistogram, rhs.chordHistogram)
        let energySimilarity = 1 - min(1, abs(log10(lhs.rms + 1e-6) - log10(rhs.rms + 1e-6)) / 2)
        return clamp01(0.82 * chordSimilarity + 0.18 * energySimilarity)
    }

    private static func descriptorDistance(_ lhs: Descriptor, _ rhs: Descriptor) -> Double {
        1 - descriptorSimilarity(lhs, rhs)
    }

    private static func blend(
        _ lhs: Descriptor,
        _ rhs: Descriptor,
        leftWeight: Double,
        rightWeight: Double
    ) -> Descriptor {
        Descriptor(
            chordHistogram: zip(lhs.chordHistogram, rhs.chordHistogram).map {
                $0.0 * leftWeight + $0.1 * rightWeight
            },
            rms: lhs.rms * leftWeight + rhs.rms * rightWeight,
            decidedCoverage: lhs.decidedCoverage * leftWeight + rhs.decidedCoverage * rightWeight
        )
    }

    private static func weightedConfidence(
        _ lhs: Double?,
        _ rhs: Double?,
        leftWeight: Double,
        rightWeight: Double
    ) -> Double? {
        switch (lhs, rhs) {
        case let (left?, right?):
            return clamp01(left * leftWeight + right * rightWeight)
        case let (left?, nil):
            return clamp01(left)
        case let (nil, right?):
            return clamp01(right)
        case (nil, nil):
            return nil
        }
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
