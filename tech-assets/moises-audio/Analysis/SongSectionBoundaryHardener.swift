import Foundation

public struct SongSectionBoundaryDiagnostics: Codable, Equatable, Sendable {
    public let inputSectionCount: Int
    public let outputSectionCount: Int
    public let removedBoundaryCount: Int
    public let preferredStructuralSpacingSeconds: Double
    public let inputShortFragmentCount: Int
    public let outputShortFragmentCount: Int
    public let inputBoundaryDensityPerMinute: Double
    public let outputBoundaryDensityPerMinute: Double
    public let inputMedianSectionSeconds: Double
    public let outputMedianSectionSeconds: Double

    enum CodingKeys: String, CodingKey {
        case inputSectionCount = "input_section_count"
        case outputSectionCount = "output_section_count"
        case removedBoundaryCount = "removed_boundary_count"
        case preferredStructuralSpacingSeconds = "preferred_structural_spacing_seconds"
        case inputShortFragmentCount = "input_short_fragment_count"
        case outputShortFragmentCount = "output_short_fragment_count"
        case inputBoundaryDensityPerMinute = "input_boundary_density_per_minute"
        case outputBoundaryDensityPerMinute = "output_boundary_density_per_minute"
        case inputMedianSectionSeconds = "input_median_section_seconds"
        case outputMedianSectionSeconds = "output_median_section_seconds"
    }
}

/// Final section-boundary gate for the product analysis path.
///
/// The W13 section detector is intentionally sensitive enough to discover
/// structural candidates, but chord-subphrase changes can still create a
/// candidate every few seconds. This gate re-evaluates those candidate
/// boundaries using evidence independent of a single chord change:
///
/// - local energy discontinuity,
/// - broad harmonic-distribution change,
/// - decided/unknown chord-coverage change.
///
/// A short section is retained only when both of its bounding candidates have
/// corroborating evidence. Otherwise the normal preferred structural spacing
/// is twice the configured minimum section duration (bounded to 12 seconds).
/// The resulting neutral seeds are passed back through the existing W13
/// cancellable hardener so structural-family and functional-label semantics are
/// not duplicated here.
public enum SongSectionBoundaryHardener {
    private struct Histogram {
        var bins = Array(repeating: 0.0, count: 26)
        var coverage = 0.0
    }

    private struct BoundaryEvidence {
        let time: Double
        let chordDistance: Double
        let energyJump: Double
        let coverageJump: Double
        let supportsShortSection: Bool
        let priority: Double
    }

    public static func harden(
        sections: [SongSection],
        signal: AnalysisSignal,
        chords: [ChordEvent],
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) throws -> [SongSection] {
        try AnalysisCancellationPolicy.check()

        let duration = signal.durationSeconds
        guard duration > 0, !signal.monoSamples.isEmpty else { return [] }

        let internalBoundaries = normalizedInternalBoundaries(
            sections: sections,
            duration: duration
        )
        guard !internalBoundaries.isEmpty else {
            return try CancellableSongSectionPipeline.hardenCancellable(
                sections: [unknownSection(duration: duration)],
                signal: signal,
                chords: chords,
                configuration: configuration
            )
        }

        let chordIndex = SectionChordTimelineIndex(chords)
        var evidence: [BoundaryEvidence] = []
        evidence.reserveCapacity(internalBoundaries.count)

        for (iteration, time) in internalBoundaries.enumerated() {
            try AnalysisCancellationPolicy.checkIfNeeded(
                enabled: true,
                iteration: iteration,
                stride: 16
            )
            evidence.append(
                try boundaryEvidence(
                    at: time,
                    signal: signal,
                    chordIndex: chordIndex,
                    configuration: configuration
                )
            )
        }

        let preferredSpacing = preferredStructuralSpacing(configuration)
        var kept: [BoundaryEvidence] = []
        kept.reserveCapacity(evidence.count)

        for (iteration, candidate) in evidence.enumerated() {
            try AnalysisCancellationPolicy.checkIfNeeded(
                enabled: true,
                iteration: iteration,
                stride: 32
            )

            let edgeSpacing = candidate.supportsShortSection
                ? configuration.minimumSectionSeconds
                : preferredSpacing
            guard candidate.time + 1e-9 >= edgeSpacing,
                  duration - candidate.time + 1e-9 >= edgeSpacing else {
                continue
            }

            guard let previous = kept.last else {
                kept.append(candidate)
                continue
            }

            let requiredSpacing = candidate.supportsShortSection && previous.supportsShortSection
                ? configuration.minimumSectionSeconds
                : preferredSpacing

            if candidate.time - previous.time + 1e-9 < requiredSpacing {
                if wins(candidate, over: previous) {
                    kept[kept.count - 1] = candidate
                }
            } else {
                kept.append(candidate)
            }
        }

        let boundaryTimes = [0.0] + kept.map(\.time) + [duration]
        var seeds: [SongSection] = []
        seeds.reserveCapacity(max(1, boundaryTimes.count - 1))

        for index in 0..<(boundaryTimes.count - 1)
        where boundaryTimes[index + 1] - boundaryTimes[index] > 1e-6 {
            let leftEvidence = index == 0
                ? 0.65
                : min(1, kept[index - 1].priority)
            let rightEvidence = index == kept.count
                ? 0.65
                : min(1, kept[index].priority)

            seeds.append(
                SongSection(
                    startSeconds: boundaryTimes[index],
                    endSeconds: boundaryTimes[index + 1],
                    structuralLabel: "seed-\(index)",
                    functionalLabel: nil,
                    confidence: clamp01((leftEvidence + rightEvidence) / 2)
                )
            )
        }

        guard !seeds.isEmpty else {
            return [unknownSection(duration: duration)]
        }

        try AnalysisCancellationPolicy.check()
        return try CancellableSongSectionPipeline.hardenCancellable(
            sections: seeds,
            signal: signal,
            chords: chords,
            configuration: configuration
        )
    }

    public static func diagnostics(
        before: [SongSection],
        after: [SongSection],
        duration: Double,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> SongSectionBoundaryDiagnostics {
        let preferredSpacing = preferredStructuralSpacing(configuration)
        let inputDurations = validDurations(before, duration: duration)
        let outputDurations = validDurations(after, duration: duration)

        return SongSectionBoundaryDiagnostics(
            inputSectionCount: inputDurations.count,
            outputSectionCount: outputDurations.count,
            removedBoundaryCount: max(0, inputDurations.count - outputDurations.count),
            preferredStructuralSpacingSeconds: preferredSpacing,
            inputShortFragmentCount: inputDurations.filter { $0 + 1e-9 < preferredSpacing }.count,
            outputShortFragmentCount: outputDurations.filter { $0 + 1e-9 < preferredSpacing }.count,
            inputBoundaryDensityPerMinute: boundaryDensity(
                sectionCount: inputDurations.count,
                duration: duration
            ),
            outputBoundaryDensityPerMinute: boundaryDensity(
                sectionCount: outputDurations.count,
                duration: duration
            ),
            inputMedianSectionSeconds: median(inputDurations),
            outputMedianSectionSeconds: median(outputDurations)
        )
    }

    private static func boundaryEvidence(
        at time: Double,
        signal: AnalysisSignal,
        chordIndex: SectionChordTimelineIndex,
        configuration: MusicAnalysisConfiguration
    ) throws -> BoundaryEvidence {
        let localSpan = min(
            1.5,
            max(0.5, configuration.sectionContextSeconds / 2)
        )
        let structuralSpan = min(
            max(localSpan, configuration.minimumSectionSeconds * 2),
            max(localSpan, signal.durationSeconds / 2)
        )

        let leftLocalRMS = try localRMS(
            signal,
            start: time - localSpan,
            end: time
        )
        let rightLocalRMS = try localRMS(
            signal,
            start: time,
            end: time + localSpan
        )
        let energyJump = min(
            1,
            abs(log10(leftLocalRMS + 1e-6) - log10(rightLocalRMS + 1e-6)) * 1.5
        )

        let leftBroad = try harmonicHistogram(
            chordIndex,
            start: max(0, time - structuralSpan),
            end: time
        )
        let rightBroad = try harmonicHistogram(
            chordIndex,
            start: time,
            end: min(signal.durationSeconds, time + structuralSpan)
        )
        let chordDistance = clamp01(
            1 - cosine(leftBroad.bins, rightBroad.bins)
        )
        let coverageJump = min(
            1,
            abs(leftBroad.coverage - rightBroad.coverage)
        )

        let relaxedEnergyThreshold = max(
            0.08,
            configuration.sectionEnergyJumpThreshold * 0.70
        )
        let harmonicWithDynamics = chordDistance >= max(
            0.70,
            configuration.sectionNoveltyThreshold + 0.25
        ) && energyJump >= relaxedEnergyThreshold * 0.50
        let supportsShortSection = energyJump >= relaxedEnergyThreshold
            || coverageJump >= 0.45
            || harmonicWithDynamics

        let basePriority = clamp01(
            0.60 * chordDistance
                + 0.30 * energyJump
                + 0.10 * coverageJump
        )
        let priority = clamp01(
            basePriority + (supportsShortSection ? 0.25 : 0)
        )

        return BoundaryEvidence(
            time: time,
            chordDistance: chordDistance,
            energyJump: energyJump,
            coverageJump: coverageJump,
            supportsShortSection: supportsShortSection,
            priority: priority
        )
    }

    private static func harmonicHistogram(
        _ index: SectionChordTimelineIndex,
        start: Double,
        end: Double
    ) throws -> Histogram {
        let lower = max(0, start)
        let upper = max(lower, end)
        let duration = max(1e-9, upper - lower)
        var result = Histogram()
        var decidedDuration = 0.0
        var iteration = 0

        for chordIndex in index.overlappingIndices(start: lower, end: upper) {
            try AnalysisCancellationPolicy.checkIfNeeded(
                enabled: true,
                iteration: iteration,
                stride: 64
            )
            let chord = index.entries[chordIndex]
            let overlap = max(
                0,
                min(upper, chord.endSeconds) - max(lower, chord.startSeconds)
            )
            if overlap > 0 {
                result.bins[chordBin(chord.normalizedLabel)] += overlap
                if chord.normalizedLabel != "X", chord.normalizedLabel != "N" {
                    decidedDuration += overlap
                }
            }
            iteration += 1
        }

        let total = result.bins.reduce(0, +)
        if total > 0 {
            result.bins = result.bins.map { $0 / total }
        }
        result.coverage = min(1, decidedDuration / duration)
        return result
    }

    private static func localRMS(
        _ signal: AnalysisSignal,
        start: Double,
        end: Double
    ) throws -> Double {
        let lower = max(
            0,
            Int((max(0, start) * signal.sampleRate).rounded(.down))
        )
        let upper = min(
            signal.monoSamples.count,
            Int((min(signal.durationSeconds, max(start, end)) * signal.sampleRate).rounded(.up))
        )
        guard upper > lower else { return 0 }

        let sampleCap = 2_048
        let step = max(
            1,
            Int(ceil(Double(upper - lower) / Double(sampleCap)))
        )
        var sumSquares = 0.0
        var count = 0
        var sampleIndex = lower

        while sampleIndex < upper {
            try AnalysisCancellationPolicy.checkIfNeeded(
                enabled: true,
                iteration: count,
                stride: 256
            )
            let raw = Double(signal.monoSamples[sampleIndex])
            let value = raw.isFinite ? min(16, max(-16, raw)) : 0
            sumSquares += value * value
            count += 1
            sampleIndex += step
        }

        return count > 0 ? sqrt(sumSquares / Double(count)) : 0
    }

    private static func normalizedInternalBoundaries(
        sections: [SongSection],
        duration: Double
    ) -> [Double] {
        let values = sections
            .map(\.endSeconds)
            .filter { value in
                value.isFinite
                    && value > 1e-6
                    && value < duration - 1e-6
            }
            .sorted()

        var output: [Double] = []
        output.reserveCapacity(values.count)
        for value in values {
            if let last = output.last, abs(last - value) <= 1e-6 {
                continue
            }
            output.append(value)
        }
        return output
    }

    private static func preferredStructuralSpacing(
        _ configuration: MusicAnalysisConfiguration
    ) -> Double {
        max(
            configuration.minimumSectionSeconds,
            min(
                12,
                max(
                    configuration.minimumSectionSeconds * 2,
                    configuration.minimumSectionSeconds + configuration.sectionContextSeconds
                )
            )
        )
    }

    private static func wins(
        _ candidate: BoundaryEvidence,
        over previous: BoundaryEvidence
    ) -> Bool {
        if abs(candidate.priority - previous.priority) > 1e-12 {
            return candidate.priority > previous.priority
        }
        if candidate.supportsShortSection != previous.supportsShortSection {
            return candidate.supportsShortSection
        }
        return candidate.energyJump > previous.energyJump
    }

    private static func validDurations(
        _ sections: [SongSection],
        duration: Double
    ) -> [Double] {
        sections.compactMap { section in
            let start = min(duration, max(0, section.startSeconds))
            let end = min(duration, max(start, section.endSeconds))
            let sectionDuration = end - start
            return sectionDuration > 1e-6 ? sectionDuration : nil
        }
    }

    private static func boundaryDensity(
        sectionCount: Int,
        duration: Double
    ) -> Double {
        guard duration > 0 else { return 0 }
        return Double(max(0, sectionCount - 1)) / (duration / 60)
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    private static func chordBin(_ label: String) -> Int {
        if label == "N" { return 24 }
        if label == "X" { return 25 }

        let names: [String: Int] = [
            "C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
            "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11
        ]
        let root = String(
            label.split(separator: ":", maxSplits: 1).first ?? "C"
        )
        let pitchClass = names[root] ?? 0
        return label.contains(":min") ? 12 + pitchClass : pitchClass
    }

    private static func unknownSection(duration: Double) -> SongSection {
        SongSection(
            startSeconds: 0,
            endSeconds: duration,
            structuralLabel: "X",
            functionalLabel: nil,
            confidence: nil
        )
    }

    private static func cosine(_ lhs: [Double], _ rhs: [Double]) -> Double {
        let dot = zip(lhs, rhs).reduce(0.0) { partial, pair in
            partial + pair.0 * pair.1
        }
        let left = sqrt(lhs.reduce(0.0) { $0 + $1 * $1 })
        let right = sqrt(rhs.reduce(0.0) { $0 + $1 * $1 })
        guard left > 1e-12, right > 1e-12 else { return 0 }
        return dot / (left * right)
    }

    private static func clamp01(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
