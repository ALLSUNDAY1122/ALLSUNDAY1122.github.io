import Foundation

struct SectionChordTimelineIndex: Sendable {
    let entries: [ChordEvent]
    private let starts: [Double]
    private let prefixMaxEnd: [Double]
    private let boundaries: [Double]

    init(_ chords: [ChordEvent]) {
        self.entries = chords
            .filter { $0.startSeconds.isFinite && $0.endSeconds.isFinite && $0.endSeconds > $0.startSeconds }
            .sorted {
                if $0.startSeconds == $1.startSeconds { return $0.endSeconds < $1.endSeconds }
                return $0.startSeconds < $1.startSeconds
            }
        self.starts = entries.map(\.startSeconds)
        var running = -Double.infinity
        var maxEnds: [Double] = []
        maxEnds.reserveCapacity(entries.count)
        var rawBoundaries: [Double] = []
        rawBoundaries.reserveCapacity(entries.count * 2)
        for chord in entries {
            running = max(running, chord.endSeconds)
            maxEnds.append(running)
            if chord.startSeconds > 0 { rawBoundaries.append(chord.startSeconds) }
            if chord.endSeconds > 0 { rawBoundaries.append(chord.endSeconds) }
        }
        self.prefixMaxEnd = maxEnds
        rawBoundaries.sort()
        var deduplicated: [Double] = []
        deduplicated.reserveCapacity(rawBoundaries.count)
        for value in rawBoundaries {
            if let last = deduplicated.last, abs(last - value) <= 1e-9 { continue }
            deduplicated.append(value)
        }
        self.boundaries = deduplicated
    }

    func overlappingIndices(start: Double, end: Double) -> Range<Int> {
        guard end > start, !entries.isEmpty else { return 0..<0 }
        let first = firstPrefixEnd(after: start)
        let upper = firstStart(notBefore: end)
        guard first < upper else { return 0..<0 }
        return first..<upper
    }

    func nearestBoundary(to time: Double, maximumDistance: Double) -> Double? {
        guard !boundaries.isEmpty, maximumDistance >= 0 else { return nil }
        var low = 0
        var high = boundaries.count
        while low < high {
            let middle = (low + high) / 2
            if boundaries[middle] < time { low = middle + 1 } else { high = middle }
        }
        var best: Double?
        if low < boundaries.count { best = boundaries[low] }
        if low > 0 {
            let previous = boundaries[low - 1]
            if best == nil || abs(previous - time) <= abs(best! - time) { best = previous }
        }
        guard let best, abs(best - time) <= maximumDistance else { return nil }
        return best
    }

    private func firstPrefixEnd(after value: Double) -> Int {
        var low = 0
        var high = prefixMaxEnd.count
        while low < high {
            let middle = (low + high) / 2
            if prefixMaxEnd[middle] <= value { low = middle + 1 } else { high = middle }
        }
        return low
    }

    private func firstStart(notBefore value: Double) -> Int {
        var low = 0
        var high = starts.count
        while low < high {
            let middle = (low + high) / 2
            if starts[middle] < value { low = middle + 1 } else { high = middle }
        }
        return low
    }
}

public struct SongSectionComplexityDiagnostics: Codable, Equatable, Sendable {
    public let durationSeconds: Double
    public let chordCount: Int
    public let estimatedBoundaryCandidates: Int
    public let effectiveSectionHopSeconds: Double
    public let maximumBoundaryCandidates: Int
    public let maximumPrototypeClusters: Int
    public let descriptorSampleCap: Int
    public let legacyNaiveChordVisitsUpperBound: Int64
    public let indexedChordVisitsNominalUpperBound: Int64

    enum CodingKeys: String, CodingKey {
        case durationSeconds = "duration_seconds"
        case chordCount = "chord_count"
        case estimatedBoundaryCandidates = "estimated_boundary_candidates"
        case effectiveSectionHopSeconds = "effective_section_hop_seconds"
        case maximumBoundaryCandidates = "maximum_boundary_candidates"
        case maximumPrototypeClusters = "maximum_prototype_clusters"
        case descriptorSampleCap = "descriptor_sample_cap"
        case legacyNaiveChordVisitsUpperBound = "legacy_naive_chord_visits_upper_bound"
        case indexedChordVisitsNominalUpperBound = "indexed_chord_visits_nominal_upper_bound"
    }
}

public enum SongSectionComplexityBudget {
    public static let maximumBoundaryCandidates = 16_384
    public static let maximumPrototypeClusters = 64
    public static let descriptorSampleCap = 8_000

    public static func effectiveHop(durationSeconds: Double, configuredHop: Double) -> Double {
        guard durationSeconds.isFinite, durationSeconds > 0 else { return max(0.001, configuredHop) }
        let safeHop = max(0.001, configuredHop)
        return max(safeHop, durationSeconds / Double(maximumBoundaryCandidates))
    }

    public static func estimate(
        durationSeconds: Double,
        chordCount: Int,
        configuredHop: Double
    ) -> SongSectionComplexityDiagnostics {
        let duration = max(0, durationSeconds.isFinite ? durationSeconds : 0)
        let chords = max(0, chordCount)
        let hop = effectiveHop(durationSeconds: duration, configuredHop: configuredHop)
        let candidates = duration > 0 ? min(maximumBoundaryCandidates, Int(ceil(duration / hop))) : 0
        let descriptorQueries = Int64(candidates) * 4 + 1
        let legacy = descriptorQueries * Int64(chords) + Int64(candidates) * Int64(chords * 2)
        let indexed = Int64(candidates) * 32 + Int64(chords)
        return SongSectionComplexityDiagnostics(
            durationSeconds: duration,
            chordCount: chords,
            estimatedBoundaryCandidates: candidates,
            effectiveSectionHopSeconds: hop,
            maximumBoundaryCandidates: maximumBoundaryCandidates,
            maximumPrototypeClusters: maximumPrototypeClusters,
            descriptorSampleCap: descriptorSampleCap,
            legacyNaiveChordVisitsUpperBound: legacy,
            indexedChordVisitsNominalUpperBound: indexed
        )
    }
}
