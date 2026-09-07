import Foundation

public struct AnalysisSnapshotCardinalityDiagnostics: Codable, Equatable, Sendable {
    public let beatInputCount: Int
    public let beatInputLimit: Int
    public let chordInputCount: Int
    public let chordInputLimit: Int
    public let sectionInputCount: Int
    public let sectionInputLimit: Int
    public let tempoCardinalityAccepted: Bool
    public let chordCardinalityAccepted: Bool
    public let sectionCardinalityAccepted: Bool

    enum CodingKeys: String, CodingKey {
        case beatInputCount = "beat_input_count"
        case beatInputLimit = "beat_input_limit"
        case chordInputCount = "chord_input_count"
        case chordInputLimit = "chord_input_limit"
        case sectionInputCount = "section_input_count"
        case sectionInputLimit = "section_input_limit"
        case tempoCardinalityAccepted = "tempo_cardinality_accepted"
        case chordCardinalityAccepted = "chord_cardinality_accepted"
        case sectionCardinalityAccepted = "section_cardinality_accepted"
    }
}

public enum AnalysisSnapshotCardinalityPolicy {
    public static func beatInputLimit(
        duration: Double,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> Int {
        let expected = max(0, duration) * max(1, configuration.tempoRange.upperBound) / 60
        return safeCeiling(expected * 2 + 64, minimum: 2_048)
    }

    public static func chordInputLimit(
        duration: Double,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> Int {
        let hop = max(0.05, configuration.chordHopSeconds)
        let expected = max(0, duration) / hop
        return safeCeiling(expected * 2 + 64, minimum: 4_096)
    }

    public static func sectionInputLimit(
        duration: Double,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> Int {
        let minimum = max(0.25, configuration.minimumSectionSeconds)
        let expected = max(0, duration) / minimum
        return min(
            SongSectionComplexityBudget.maximumBoundaryCandidates + 1,
            safeCeiling(expected * 4 + 64, minimum: 512)
        )
    }

    public static func diagnostics(
        snapshot: AnalysisSnapshot,
        duration: Double,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> AnalysisSnapshotCardinalityDiagnostics {
        let beatCount = snapshot.tempo?.beatTimesSeconds.count ?? 0
        let beatLimit = beatInputLimit(duration: duration, configuration: configuration)
        let chordLimit = chordInputLimit(duration: duration, configuration: configuration)
        let sectionLimit = sectionInputLimit(duration: duration, configuration: configuration)
        return AnalysisSnapshotCardinalityDiagnostics(
            beatInputCount: beatCount,
            beatInputLimit: beatLimit,
            chordInputCount: snapshot.chords.count,
            chordInputLimit: chordLimit,
            sectionInputCount: snapshot.sections.count,
            sectionInputLimit: sectionLimit,
            tempoCardinalityAccepted: beatCount <= beatLimit,
            chordCardinalityAccepted: snapshot.chords.count <= chordLimit,
            sectionCardinalityAccepted: snapshot.sections.count <= sectionLimit
        )
    }

    private static func safeCeiling(_ value: Double, minimum: Int) -> Int {
        guard value.isFinite, value > 0 else { return minimum }
        let capped = min(value, Double(Int.max / 4))
        return max(minimum, Int(ceil(capped)))
    }
}

public extension AnalysisSnapshotRobustness {
    /// Cooperative, cardinality-safe publication guard for the product path.
    /// The legacy non-throwing `harden` remains available for compatibility and
    /// evidence tooling; product publication uses this throwing variant so
    /// cancellation never waits for large normalization/sort passes to finish.
    static func hardenCancellable(
        snapshot: AnalysisSnapshot,
        duration: Double,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) throws -> AnalysisSnapshot {
        try AnalysisCancellationPolicy.check()
        guard duration.isFinite, duration > 0 else {
            return AnalysisSnapshot(tempo: nil, key: nil, chords: [], sections: [])
        }

        let cardinality = AnalysisSnapshotCardinalityPolicy.diagnostics(
            snapshot: snapshot,
            duration: duration,
            configuration: configuration
        )

        let tempo = cardinality.tempoCardinalityAccepted
            ? try snapshotHardenTempoCancellable(snapshot.tempo, duration: duration, configuration: configuration)
            : nil
        try AnalysisCancellationPolicy.check()
        let key = snapshotHardenKeyCancellable(snapshot.key, configuration: configuration)
        let chords = try snapshotNormalizeChordsCancellable(
            snapshot.chords,
            duration: duration,
            cardinalityAccepted: cardinality.chordCardinalityAccepted
        )
        try AnalysisCancellationPolicy.check()
        let decidedChordCoverage = try snapshotDecidedChordCoverageCancellable(
            chords,
            duration: duration
        )
        let sections = try snapshotNormalizeSectionsCancellable(
            snapshot.sections,
            duration: duration,
            decidedChordCoverage: decidedChordCoverage,
            configuration: configuration,
            cardinalityAccepted: cardinality.sectionCardinalityAccepted
        )
        try AnalysisCancellationPolicy.check()
        return AnalysisSnapshot(tempo: tempo, key: key, chords: chords, sections: sections)
    }

    private static func snapshotHardenTempoCancellable(
        _ tempo: TempoAnalysis?,
        duration: Double,
        configuration: MusicAnalysisConfiguration
    ) throws -> TempoAnalysis? {
        guard let tempo,
              tempo.bpm.isFinite,
              configuration.tempoRange.contains(tempo.bpm),
              let confidence = snapshotNormalizedConfidence(tempo.confidence),
              confidence >= configuration.minimumTempoConfidence else {
            return nil
        }

        var finiteBeats: [Double] = []
        finiteBeats.reserveCapacity(tempo.beatTimesSeconds.count)
        for (iteration, rawBeat) in tempo.beatTimesSeconds.enumerated() {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: iteration, stride: 256)
            guard rawBeat.isFinite, rawBeat >= 0, rawBeat <= duration + 1e-6 else { continue }
            finiteBeats.append(min(duration, max(0, rawBeat)))
        }
        finiteBeats = try snapshotStableSort(finiteBeats, by: <)

        var beats: [Double] = []
        beats.reserveCapacity(finiteBeats.count)
        for (iteration, beat) in finiteBeats.enumerated() {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: iteration, stride: 256)
            if let last = beats.last, beat - last <= 1e-6 { continue }
            beats.append(beat)
        }
        guard beats.count >= 2 else { return nil }

        var intervals: [Double] = []
        intervals.reserveCapacity(max(0, beats.count - 1))
        for index in 1..<beats.count {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: index, stride: 256)
            let interval = beats[index] - beats[index - 1]
            if interval > 1e-6 { intervals.append(interval) }
        }
        guard !intervals.isEmpty else { return nil }
        intervals = try snapshotStableSort(intervals, by: <)

        let middle = intervals.count / 2
        let medianInterval = intervals.count.isMultiple(of: 2)
            ? (intervals[middle - 1] + intervals[middle]) / 2
            : intervals[middle]
        guard medianInterval.isFinite, medianInterval > 1e-6 else { return nil }
        let beatDerivedBPM = 60 / medianInterval
        let relativeMismatch = abs(beatDerivedBPM - tempo.bpm) / max(tempo.bpm, 1e-9)
        guard relativeMismatch <= 0.12 else { return nil }
        return TempoAnalysis(bpm: tempo.bpm, confidence: confidence, beatTimesSeconds: beats)
    }

    private static func snapshotHardenKeyCancellable(
        _ key: MusicalKey?,
        configuration: MusicAnalysisConfiguration
    ) -> MusicalKey? {
        guard let key,
              key.mode == "major" || key.mode == "minor",
              let confidence = snapshotNormalizedConfidence(key.confidence),
              confidence >= configuration.minimumKeyConfidence else {
            return nil
        }
        return MusicalKey(
            tonicPitchClass: key.tonicPitchClass,
            mode: key.mode,
            confidence: confidence
        )
    }

    private static func snapshotNormalizeChordsCancellable(
        _ input: [ChordEvent],
        duration: Double,
        cardinalityAccepted: Bool
    ) throws -> [ChordEvent] {
        guard cardinalityAccepted else {
            if input.isEmpty { return [] }
            return [ChordEvent(startSeconds: 0, endSeconds: duration, normalizedLabel: "X", confidence: nil)]
        }

        var candidates: [ChordEvent] = []
        candidates.reserveCapacity(input.count)
        for (iteration, event) in input.enumerated() {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: iteration, stride: 128)
            guard event.startSeconds.isFinite, event.endSeconds.isFinite else { continue }
            let start = min(duration, max(0, event.startSeconds))
            let end = min(duration, max(start, event.endSeconds))
            guard end - start > 1e-6 else { continue }
            candidates.append(
                ChordEvent(
                    startSeconds: start,
                    endSeconds: end,
                    normalizedLabel: snapshotNormalizedProductChordLabel(event.normalizedLabel),
                    confidence: snapshotNormalizedConfidence(event.confidence)
                )
            )
        }
        candidates = try snapshotStableSort(candidates) { lhs, rhs in
            if lhs.startSeconds == rhs.startSeconds { return lhs.endSeconds < rhs.endSeconds }
            return lhs.startSeconds < rhs.startSeconds
        }

        guard !candidates.isEmpty else {
            if input.isEmpty { return [] }
            return [ChordEvent(startSeconds: 0, endSeconds: duration, normalizedLabel: "X", confidence: nil)]
        }

        var output: [ChordEvent] = []
        output.reserveCapacity(candidates.count + 1)
        var cursor = 0.0
        for (iteration, event) in candidates.enumerated() {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: iteration, stride: 128)
            if event.startSeconds > cursor + 1e-6 {
                snapshotAppendChord(
                    ChordEvent(startSeconds: cursor, endSeconds: event.startSeconds, normalizedLabel: "X", confidence: nil),
                    to: &output
                )
                cursor = event.startSeconds
            }
            let start = max(cursor, event.startSeconds)
            let end = min(duration, event.endSeconds)
            guard end - start > 1e-6 else { continue }
            snapshotAppendChord(
                ChordEvent(
                    startSeconds: start,
                    endSeconds: end,
                    normalizedLabel: event.normalizedLabel,
                    confidence: event.confidence
                ),
                to: &output
            )
            cursor = end
            if cursor >= duration - 1e-6 { break }
        }
        if cursor < duration - 1e-6 {
            snapshotAppendChord(
                ChordEvent(startSeconds: cursor, endSeconds: duration, normalizedLabel: "X", confidence: nil),
                to: &output
            )
        }
        return output
    }

    private static func snapshotNormalizeSectionsCancellable(
        _ input: [SongSection],
        duration: Double,
        decidedChordCoverage: Double,
        configuration: MusicAnalysisConfiguration,
        cardinalityAccepted: Bool
    ) throws -> [SongSection] {
        guard !input.isEmpty else { return [] }
        guard cardinalityAccepted,
              decidedChordCoverage >= configuration.minimumSectionChordCoverage else {
            return [snapshotUnknownSection(duration)]
        }

        var candidates: [SongSection] = []
        candidates.reserveCapacity(input.count)
        for (iteration, section) in input.enumerated() {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: iteration, stride: 128)
            guard section.startSeconds.isFinite, section.endSeconds.isFinite else { continue }
            let start = min(duration, max(0, section.startSeconds))
            let end = min(duration, max(start, section.endSeconds))
            guard end - start > 1e-6 else { continue }
            let confidence = snapshotNormalizedConfidence(section.confidence)
            let structural = section.structuralLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            let safeStructural = structural.isEmpty ? "X" : structural
            let functional: String?
            if let proposed = section.functionalLabel?.lowercased(),
               snapshotProductFunctionalLabels.contains(proposed),
               let confidence,
               confidence >= configuration.minimumFunctionalSectionConfidence {
                functional = proposed
            } else {
                functional = nil
            }
            candidates.append(
                SongSection(
                    startSeconds: start,
                    endSeconds: end,
                    structuralLabel: safeStructural,
                    functionalLabel: functional,
                    confidence: confidence
                )
            )
        }
        candidates = try snapshotStableSort(candidates) { lhs, rhs in
            if lhs.startSeconds == rhs.startSeconds { return lhs.endSeconds < rhs.endSeconds }
            return lhs.startSeconds < rhs.startSeconds
        }
        guard !candidates.isEmpty else { return [snapshotUnknownSection(duration)] }

        var output: [SongSection] = []
        output.reserveCapacity(candidates.count + 1)
        var cursor = 0.0
        for (iteration, section) in candidates.enumerated() {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: iteration, stride: 128)
            if section.startSeconds > cursor + 1e-6 {
                snapshotAppendSection(
                    SongSection(startSeconds: cursor, endSeconds: section.startSeconds, structuralLabel: "X", functionalLabel: nil, confidence: nil),
                    to: &output
                )
                cursor = section.startSeconds
            }
            let start = max(cursor, section.startSeconds)
            let end = min(duration, section.endSeconds)
            guard end - start > 1e-6 else { continue }
            snapshotAppendSection(
                SongSection(
                    startSeconds: start,
                    endSeconds: end,
                    structuralLabel: section.structuralLabel,
                    functionalLabel: section.functionalLabel,
                    confidence: section.confidence
                ),
                to: &output
            )
            cursor = end
            if cursor >= duration - 1e-6 { break }
        }
        if cursor < duration - 1e-6 {
            snapshotAppendSection(
                SongSection(startSeconds: cursor, endSeconds: duration, structuralLabel: "X", functionalLabel: nil, confidence: nil),
                to: &output
            )
        }
        return output
    }

    private static func snapshotDecidedChordCoverageCancellable(
        _ chords: [ChordEvent],
        duration: Double
    ) throws -> Double {
        guard duration > 0 else { return 0 }
        var covered = 0.0
        var currentStart: Double?
        var currentEnd = 0.0
        for (iteration, chord) in chords.enumerated() {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: iteration, stride: 128)
            guard chord.normalizedLabel != "X" else {
                if let start = currentStart {
                    covered += currentEnd - start
                    currentStart = nil
                }
                continue
            }
            let start = min(duration, max(0, chord.startSeconds))
            let end = min(duration, max(start, chord.endSeconds))
            guard end > start else { continue }
            if currentStart == nil {
                currentStart = start
                currentEnd = end
            } else if start <= currentEnd + 1e-6 {
                currentEnd = max(currentEnd, end)
            } else {
                covered += currentEnd - currentStart!
                currentStart = start
                currentEnd = end
            }
        }
        if let start = currentStart { covered += currentEnd - start }
        return min(1, max(0, covered / duration))
    }

    private static let snapshotProductChordRoots: Set<String> = [
        "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
    ]
    private static let snapshotProductFunctionalLabels: Set<String> = [
        "intro", "verse", "pre-chorus", "chorus", "bridge", "outro"
    ]

    private static func snapshotNormalizedProductChordLabel(_ label: String) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "N" || trimmed == "X" { return trimmed }
        if trimmed.hasSuffix(":min") {
            let root = String(trimmed.dropLast(4))
            return snapshotProductChordRoots.contains(root) ? "\(root):min" : "X"
        }
        return snapshotProductChordRoots.contains(trimmed) ? trimmed : "X"
    }

    private static func snapshotNormalizedConfidence(_ value: Double?) -> Double? {
        guard let value, value.isFinite, (0...1).contains(value) else { return nil }
        return value
    }

    private static func snapshotMergedConfidence(_ lhs: Double?, _ rhs: Double?) -> Double? {
        switch (lhs, rhs) {
        case let (left?, right?): return min(left, right)
        case let (left?, nil): return left
        case let (nil, right?): return right
        case (nil, nil): return nil
        }
    }

    private static func snapshotAppendChord(_ event: ChordEvent, to output: inout [ChordEvent]) {
        guard let last = output.last,
              last.normalizedLabel == event.normalizedLabel,
              abs(last.endSeconds - event.startSeconds) <= 1e-6 else {
            output.append(event)
            return
        }
        output[output.count - 1] = ChordEvent(
            startSeconds: last.startSeconds,
            endSeconds: event.endSeconds,
            normalizedLabel: last.normalizedLabel,
            confidence: snapshotMergedConfidence(last.confidence, event.confidence)
        )
    }

    private static func snapshotAppendSection(_ section: SongSection, to output: inout [SongSection]) {
        guard let last = output.last,
              last.structuralLabel == section.structuralLabel,
              last.functionalLabel == section.functionalLabel,
              abs(last.endSeconds - section.startSeconds) <= 1e-6 else {
            output.append(section)
            return
        }
        output[output.count - 1] = SongSection(
            startSeconds: last.startSeconds,
            endSeconds: section.endSeconds,
            structuralLabel: last.structuralLabel,
            functionalLabel: last.functionalLabel,
            confidence: snapshotMergedConfidence(last.confidence, section.confidence)
        )
    }

    private static func snapshotUnknownSection(_ duration: Double) -> SongSection {
        SongSection(startSeconds: 0, endSeconds: duration, structuralLabel: "X", functionalLabel: nil, confidence: nil)
    }

    private static func snapshotStableSort<T>(
        _ values: [T],
        by areInIncreasingOrder: (T, T) -> Bool
    ) throws -> [T] {
        guard values.count > 1 else { return values }
        var source = values
        var destination = values
        var width = 1
        var mergePass = 0
        while width < source.count {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: mergePass, stride: 1)
            var start = 0
            var mergeIndex = 0
            while start < source.count {
                try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: mergeIndex, stride: 16)
                let middle = min(start + width, source.count)
                let end = min(start + width * 2, source.count)
                var left = start
                var right = middle
                var output = start
                var itemIteration = 0
                while output < end {
                    try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: itemIteration, stride: 2_048)
                    if left < middle && (right >= end || !areInIncreasingOrder(source[right], source[left])) {
                        destination[output] = source[left]
                        left += 1
                    } else {
                        destination[output] = source[right]
                        right += 1
                    }
                    output += 1
                    itemIteration += 1
                }
                start = end
                mergeIndex += 1
            }
            swap(&source, &destination)
            if width > source.count / 2 { width = source.count } else { width *= 2 }
            mergePass += 1
        }
        return source
    }
}
