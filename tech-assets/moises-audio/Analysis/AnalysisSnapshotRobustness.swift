import Foundation

/// Final Lane-4 guard between independent MIR analyzers and the product-facing
/// `AnalysisSnapshot`. The individual analyzers remain responsible for musical
/// inference; this layer is deliberately conservative and only enforces data
/// integrity, confidence validity, timeline consistency and cross-feature
/// fail-closed behavior.
public enum AnalysisSnapshotRobustness {
    private static let maximumAbsoluteSample: Float = 16
    private static let epsilon = 1e-6
    private static let productChordRoots: Set<String> = [
        "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
    ]
    private static let productFunctionalLabels: Set<String> = [
        "intro", "verse", "pre-chorus", "chorus", "bridge", "outro"
    ]

    /// Replaces non-finite samples and bounds pathological finite amplitudes.
    /// Clean production audio returns the original value without allocating a
    /// second sample buffer, which matters for long-track analysis.
    public static func sanitize(signal: AnalysisSignal) -> AnalysisSignal {
        var requiresCopy = false
        for sample in signal.monoSamples {
            if !sample.isFinite || abs(sample) > maximumAbsoluteSample {
                requiresCopy = true
                break
            }
        }
        guard requiresCopy else { return signal }

        let sanitized = signal.monoSamples.map { sample -> Float in
            guard sample.isFinite else { return 0 }
            return min(maximumAbsoluteSample, max(-maximumAbsoluteSample, sample))
        }
        return AnalysisSignal(sampleRate: signal.sampleRate, monoSamples: sanitized)
    }

    public static func harden(
        snapshot: AnalysisSnapshot,
        duration: Double,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> AnalysisSnapshot {
        guard duration.isFinite, duration > 0 else {
            return AnalysisSnapshot(tempo: nil, key: nil, chords: [], sections: [])
        }

        let tempo = hardenTempo(snapshot.tempo, duration: duration, configuration: configuration)
        let key = hardenKey(snapshot.key, configuration: configuration)
        let chords = normalizeChords(snapshot.chords, duration: duration)
        let decidedChordCoverage = coverage(
            chords.filter { $0.normalizedLabel != "X" },
            duration: duration,
            interval: { ($0.startSeconds, $0.endSeconds) }
        )
        let sections = normalizeSections(
            snapshot.sections,
            duration: duration,
            decidedChordCoverage: decidedChordCoverage,
            configuration: configuration
        )

        return AnalysisSnapshot(tempo: tempo, key: key, chords: chords, sections: sections)
    }

    /// Stable transport form for snapshot caching/evidence. `sortedKeys` makes
    /// repeated encodes byte-identical for an identical value.
    public static func canonicalJSON(_ snapshot: AnalysisSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(snapshot)
    }

    /// Machine-readable health metrics appended to Analysis benchmark rows.
    /// These metrics describe integrity/coverage only; they are not MIR accuracy
    /// metrics and never constitute PARITY evidence by themselves.
    public static func diagnostics(snapshot: AnalysisSnapshot, duration: Double) -> [String: Double] {
        guard duration.isFinite, duration > 0 else {
            return [
                "snapshot_duration_valid": 0,
                "tempo_decision": snapshot.tempo == nil ? 0 : 1,
                "key_decision": snapshot.key == nil ? 0 : 1,
                "chord_timeline_coverage": 0,
                "section_timeline_coverage": 0,
                "invalid_confidence_count": Double(invalidConfidenceCount(snapshot))
            ]
        }

        let chordCoverage = coverage(snapshot.chords, duration: duration) { ($0.startSeconds, $0.endSeconds) }
        let chordUnknown = coverage(
            snapshot.chords.filter { $0.normalizedLabel == "X" },
            duration: duration
        ) { ($0.startSeconds, $0.endSeconds) }
        let noChord = coverage(
            snapshot.chords.filter { $0.normalizedLabel == "N" },
            duration: duration
        ) { ($0.startSeconds, $0.endSeconds) }
        let sectionCoverage = coverage(snapshot.sections, duration: duration) { ($0.startSeconds, $0.endSeconds) }
        let sectionUnknown = coverage(
            snapshot.sections.filter { $0.structuralLabel == "X" },
            duration: duration
        ) { ($0.startSeconds, $0.endSeconds) }
        let functionalCoverage = coverage(
            snapshot.sections.filter { $0.functionalLabel != nil },
            duration: duration
        ) { ($0.startSeconds, $0.endSeconds) }

        let beats = snapshot.tempo?.beatTimesSeconds ?? []
        let beatMonotonic = zip(beats, beats.dropFirst()).allSatisfy { pair in pair.0 < pair.1 }
        let chordGapOverlap = gapAndOverlap(
            snapshot.chords.map { ($0.startSeconds, $0.endSeconds) },
            duration: duration
        )
        let sectionGapOverlap = gapAndOverlap(
            snapshot.sections.map { ($0.startSeconds, $0.endSeconds) },
            duration: duration
        )

        return [
            "snapshot_duration_valid": 1,
            "tempo_decision": snapshot.tempo == nil ? 0 : 1,
            "key_decision": snapshot.key == nil ? 0 : 1,
            "beat_count": Double(beats.count),
            "beat_times_strictly_monotonic": beatMonotonic ? 1 : 0,
            "chord_timeline_coverage": chordCoverage,
            "chord_unknown_fraction": chordUnknown,
            "chord_no_chord_fraction": noChord,
            "chord_gap_seconds": chordGapOverlap.gap,
            "chord_overlap_seconds": chordGapOverlap.overlap,
            "section_timeline_coverage": sectionCoverage,
            "section_unknown_fraction": sectionUnknown,
            "section_functional_coverage": functionalCoverage,
            "section_gap_seconds": sectionGapOverlap.gap,
            "section_overlap_seconds": sectionGapOverlap.overlap,
            "invalid_confidence_count": Double(invalidConfidenceCount(snapshot))
        ]
    }

    private static func hardenTempo(
        _ tempo: TempoAnalysis?,
        duration: Double,
        configuration: MusicAnalysisConfiguration
    ) -> TempoAnalysis? {
        guard let tempo,
              tempo.bpm.isFinite,
              configuration.tempoRange.contains(tempo.bpm),
              let confidence = normalizedConfidence(tempo.confidence),
              confidence >= configuration.minimumTempoConfidence else {
            return nil
        }

        let finiteBeats = tempo.beatTimesSeconds
            .filter { $0.isFinite && $0 >= 0 && $0 <= duration + epsilon }
            .map { min(duration, max(0, $0)) }
            .sorted()
        var beats: [Double] = []
        beats.reserveCapacity(finiteBeats.count)
        for beat in finiteBeats {
            if let last = beats.last, beat - last <= epsilon { continue }
            beats.append(beat)
        }
        guard beats.count >= 2 else { return nil }

        let intervals = zip(beats, beats.dropFirst())
            .map { pair in pair.1 - pair.0 }
            .filter { $0 > epsilon }
        guard !intervals.isEmpty else { return nil }
        let ordered = intervals.sorted()
        let medianInterval: Double
        let middle = ordered.count / 2
        if ordered.count % 2 == 0 {
            medianInterval = (ordered[middle - 1] + ordered[middle]) / 2
        } else {
            medianInterval = ordered[middle]
        }
        guard medianInterval.isFinite, medianInterval > epsilon else { return nil }
        let beatDerivedBPM = 60 / medianInterval
        let relativeMismatch = abs(beatDerivedBPM - tempo.bpm) / max(tempo.bpm, 1e-9)
        guard relativeMismatch <= 0.12 else { return nil }

        return TempoAnalysis(bpm: tempo.bpm, confidence: confidence, beatTimesSeconds: beats)
    }

    private static func hardenKey(
        _ key: MusicalKey?,
        configuration: MusicAnalysisConfiguration
    ) -> MusicalKey? {
        guard let key,
              key.mode == "major" || key.mode == "minor",
              let confidence = normalizedConfidence(key.confidence),
              confidence >= configuration.minimumKeyConfidence else {
            return nil
        }
        return MusicalKey(
            tonicPitchClass: key.tonicPitchClass,
            mode: key.mode,
            confidence: confidence
        )
    }

    private static func normalizeChords(_ input: [ChordEvent], duration: Double) -> [ChordEvent] {
        let candidates = input.compactMap { event -> ChordEvent? in
            guard event.startSeconds.isFinite, event.endSeconds.isFinite else { return nil }
            let start = min(duration, max(0, event.startSeconds))
            let end = min(duration, max(start, event.endSeconds))
            guard end - start > epsilon else { return nil }
            return ChordEvent(
                startSeconds: start,
                endSeconds: end,
                normalizedLabel: normalizedProductChordLabel(event.normalizedLabel),
                confidence: normalizedConfidence(event.confidence)
            )
        }.sorted {
            if $0.startSeconds == $1.startSeconds { return $0.endSeconds < $1.endSeconds }
            return $0.startSeconds < $1.startSeconds
        }

        guard !candidates.isEmpty else {
            if input.isEmpty { return [] }
            return [ChordEvent(startSeconds: 0, endSeconds: duration, normalizedLabel: "X", confidence: nil)]
        }

        var output: [ChordEvent] = []
        var cursor = 0.0
        for event in candidates {
            if event.startSeconds > cursor + epsilon {
                appendChord(
                    ChordEvent(startSeconds: cursor, endSeconds: event.startSeconds, normalizedLabel: "X", confidence: nil),
                    to: &output
                )
                cursor = event.startSeconds
            }
            let start = max(cursor, event.startSeconds)
            let end = min(duration, event.endSeconds)
            guard end - start > epsilon else { continue }
            appendChord(
                ChordEvent(
                    startSeconds: start,
                    endSeconds: end,
                    normalizedLabel: event.normalizedLabel,
                    confidence: event.confidence
                ),
                to: &output
            )
            cursor = end
            if cursor >= duration - epsilon { break }
        }
        if cursor < duration - epsilon {
            appendChord(
                ChordEvent(startSeconds: cursor, endSeconds: duration, normalizedLabel: "X", confidence: nil),
                to: &output
            )
        }
        return output
    }

    private static func normalizeSections(
        _ input: [SongSection],
        duration: Double,
        decidedChordCoverage: Double,
        configuration: MusicAnalysisConfiguration
    ) -> [SongSection] {
        guard !input.isEmpty else { return [] }
        guard decidedChordCoverage >= configuration.minimumSectionChordCoverage else {
            return [SongSection(
                startSeconds: 0,
                endSeconds: duration,
                structuralLabel: "X",
                functionalLabel: nil,
                confidence: nil
            )]
        }

        let candidates = input.compactMap { section -> SongSection? in
            guard section.startSeconds.isFinite, section.endSeconds.isFinite else { return nil }
            let start = min(duration, max(0, section.startSeconds))
            let end = min(duration, max(start, section.endSeconds))
            guard end - start > epsilon else { return nil }
            let confidence = normalizedConfidence(section.confidence)
            let structural = section.structuralLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            let safeStructural = structural.isEmpty ? "X" : structural
            let functional: String?
            if let proposed = section.functionalLabel?.lowercased(),
               productFunctionalLabels.contains(proposed),
               let confidence,
               confidence >= configuration.minimumFunctionalSectionConfidence {
                functional = proposed
            } else {
                functional = nil
            }
            return SongSection(
                startSeconds: start,
                endSeconds: end,
                structuralLabel: safeStructural,
                functionalLabel: functional,
                confidence: confidence
            )
        }.sorted {
            if $0.startSeconds == $1.startSeconds { return $0.endSeconds < $1.endSeconds }
            return $0.startSeconds < $1.startSeconds
        }

        guard !candidates.isEmpty else {
            return [SongSection(
                startSeconds: 0,
                endSeconds: duration,
                structuralLabel: "X",
                functionalLabel: nil,
                confidence: nil
            )]
        }

        var output: [SongSection] = []
        var cursor = 0.0
        for section in candidates {
            if section.startSeconds > cursor + epsilon {
                appendSection(
                    SongSection(
                        startSeconds: cursor,
                        endSeconds: section.startSeconds,
                        structuralLabel: "X",
                        functionalLabel: nil,
                        confidence: nil
                    ),
                    to: &output
                )
                cursor = section.startSeconds
            }
            let start = max(cursor, section.startSeconds)
            let end = min(duration, section.endSeconds)
            guard end - start > epsilon else { continue }
            appendSection(
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
            if cursor >= duration - epsilon { break }
        }
        if cursor < duration - epsilon {
            appendSection(
                SongSection(
                    startSeconds: cursor,
                    endSeconds: duration,
                    structuralLabel: "X",
                    functionalLabel: nil,
                    confidence: nil
                ),
                to: &output
            )
        }
        return output
    }

    private static func appendChord(_ event: ChordEvent, to output: inout [ChordEvent]) {
        guard let last = output.last,
              last.normalizedLabel == event.normalizedLabel,
              abs(last.endSeconds - event.startSeconds) <= epsilon else {
            output.append(event)
            return
        }
        output[output.count - 1] = ChordEvent(
            startSeconds: last.startSeconds,
            endSeconds: event.endSeconds,
            normalizedLabel: last.normalizedLabel,
            confidence: mergedConfidence(last.confidence, event.confidence)
        )
    }

    private static func appendSection(_ section: SongSection, to output: inout [SongSection]) {
        guard let last = output.last,
              last.structuralLabel == section.structuralLabel,
              last.functionalLabel == section.functionalLabel,
              abs(last.endSeconds - section.startSeconds) <= epsilon else {
            output.append(section)
            return
        }
        output[output.count - 1] = SongSection(
            startSeconds: last.startSeconds,
            endSeconds: section.endSeconds,
            structuralLabel: last.structuralLabel,
            functionalLabel: last.functionalLabel,
            confidence: mergedConfidence(last.confidence, section.confidence)
        )
    }

    private static func normalizedProductChordLabel(_ label: String) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "N" || trimmed == "X" { return trimmed }
        if trimmed.hasSuffix(":min") {
            let root = String(trimmed.dropLast(4))
            return productChordRoots.contains(root) ? "\(root):min" : "X"
        }
        return productChordRoots.contains(trimmed) ? trimmed : "X"
    }

    private static func normalizedConfidence(_ value: Double?) -> Double? {
        guard let value, value.isFinite, (0...1).contains(value) else { return nil }
        return value
    }

    private static func mergedConfidence(_ lhs: Double?, _ rhs: Double?) -> Double? {
        switch (lhs, rhs) {
        case let (left?, right?): return min(left, right)
        case let (left?, nil): return left
        case let (nil, right?): return right
        case (nil, nil): return nil
        }
    }

    private static func coverage<T>(
        _ values: [T],
        duration: Double,
        interval: (T) -> (Double, Double)
    ) -> Double {
        guard duration > 0 else { return 0 }
        let intervals = values.compactMap { value -> (Double, Double)? in
            let raw = interval(value)
            guard raw.0.isFinite, raw.1.isFinite else { return nil }
            let start = min(duration, max(0, raw.0))
            let end = min(duration, max(start, raw.1))
            return end > start ? (start, end) : nil
        }.sorted { $0.0 < $1.0 }
        guard !intervals.isEmpty else { return 0 }

        var covered = 0.0
        var currentStart = intervals[0].0
        var currentEnd = intervals[0].1
        for item in intervals.dropFirst() {
            if item.0 <= currentEnd + epsilon {
                currentEnd = max(currentEnd, item.1)
            } else {
                covered += currentEnd - currentStart
                currentStart = item.0
                currentEnd = item.1
            }
        }
        covered += currentEnd - currentStart
        return min(1, max(0, covered / duration))
    }

    private static func gapAndOverlap(_ intervals: [(Double, Double)], duration: Double) -> (gap: Double, overlap: Double) {
        let valid = intervals.compactMap { raw -> (Double, Double)? in
            guard raw.0.isFinite, raw.1.isFinite else { return nil }
            let start = min(duration, max(0, raw.0))
            let end = min(duration, max(start, raw.1))
            return end > start ? (start, end) : nil
        }.sorted { lhs, rhs in
            if lhs.0 == rhs.0 { return lhs.1 < rhs.1 }
            return lhs.0 < rhs.0
        }
        guard let first = valid.first else { return (duration, 0) }

        var gap = max(0, first.0)
        var overlap = 0.0
        var cursor = first.1
        for item in valid.dropFirst() {
            if item.0 > cursor {
                gap += item.0 - cursor
            } else if item.0 < cursor {
                overlap += min(cursor, item.1) - item.0
            }
            cursor = max(cursor, item.1)
        }
        if cursor < duration { gap += duration - cursor }
        return (max(0, gap), max(0, overlap))
    }

    private static func invalidConfidenceCount(_ snapshot: AnalysisSnapshot) -> Int {
        var count = 0
        let all: [Double?] = [snapshot.tempo?.confidence, snapshot.key?.confidence]
            + snapshot.chords.map(\.confidence)
            + snapshot.sections.map(\.confidence)
        for value in all {
            if let value, !value.isFinite || !(0...1).contains(value) { count += 1 }
        }
        return count
    }
}
