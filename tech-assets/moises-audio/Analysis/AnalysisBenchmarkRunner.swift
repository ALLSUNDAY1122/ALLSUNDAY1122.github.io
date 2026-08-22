import Foundation

public enum AnalysisRightsClass: String, Codable, Sendable {
    case projectOwned = "PROJECT_OWNED"
    case licensedTest = "LICENSED_TEST"
    case publicReference = "PUBLIC_REFERENCE"
}

public struct TempoBeatKeyReference: Equatable, Sendable {
    public let bpm: Double?
    public let beatTimesSeconds: [Double]
    public let key: MusicalKey?
    public let chords: [ChordEvent]

    public init(
        bpm: Double?,
        beatTimesSeconds: [Double] = [],
        key: MusicalKey? = nil,
        chords: [ChordEvent] = []
    ) {
        self.bpm = bpm
        self.beatTimesSeconds = beatTimesSeconds.sorted()
        self.key = key
        self.chords = chords.sorted {
            if $0.startSeconds == $1.startSeconds { return $0.endSeconds < $1.endSeconds }
            return $0.startSeconds < $1.startSeconds
        }
    }
}

public struct AnalysisBenchmarkFixture: Equatable, Sendable {
    public let fixtureID: String
    public let rightsClass: AnalysisRightsClass
    public let genre: String
    public let syntheticOnly: Bool
    public let signal: AnalysisSignal
    public let reference: TempoBeatKeyReference

    public init(fixtureID: String, rightsClass: AnalysisRightsClass, genre: String, syntheticOnly: Bool, signal: AnalysisSignal, reference: TempoBeatKeyReference) {
        self.fixtureID = fixtureID
        self.rightsClass = rightsClass
        self.genre = genre
        self.syntheticOnly = syntheticOnly
        self.signal = signal
        self.reference = reference
    }
}

public struct AnalysisBenchmarkRow: Codable, Equatable, Sendable {
    public let fixtureID: String
    public let rightsClass: AnalysisRightsClass
    public let genre: String
    public let durationSeconds: Double
    public let syntheticOnly: Bool
    public let parityEligible: Bool
    public let engine: String
    public let engineVersion: String
    public let domain: String
    public let metrics: [String: Double]
    public let wallSeconds: Double
    public let rtf: Double?
    public let peakRSSMB: Double?
    public let thermal: String?
    public let knownLimitations: [String]

    enum CodingKeys: String, CodingKey {
        case fixtureID = "fixture_id"
        case rightsClass = "rights_class"
        case genre
        case durationSeconds = "duration_seconds"
        case syntheticOnly = "synthetic_only"
        case parityEligible = "parity_eligible"
        case engine
        case engineVersion = "engine_version"
        case domain
        case metrics
        case wallSeconds = "wall_seconds"
        case rtf
        case peakRSSMB = "peak_rss_mb"
        case thermal
        case knownLimitations = "known_limitations"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fixtureID, forKey: .fixtureID)
        try container.encode(rightsClass, forKey: .rightsClass)
        try container.encode(genre, forKey: .genre)
        try container.encode(durationSeconds, forKey: .durationSeconds)
        try container.encode(syntheticOnly, forKey: .syntheticOnly)
        try container.encode(parityEligible, forKey: .parityEligible)
        try container.encode(engine, forKey: .engine)
        try container.encode(engineVersion, forKey: .engineVersion)
        try container.encode(domain, forKey: .domain)
        try container.encode(metrics, forKey: .metrics)
        try container.encode(wallSeconds, forKey: .wallSeconds)
        if let rtf { try container.encode(rtf, forKey: .rtf) } else { try container.encodeNil(forKey: .rtf) }
        if let peakRSSMB { try container.encode(peakRSSMB, forKey: .peakRSSMB) } else { try container.encodeNil(forKey: .peakRSSMB) }
        if let thermal { try container.encode(thermal, forKey: .thermal) } else { try container.encodeNil(forKey: .thermal) }
        try container.encode(knownLimitations, forKey: .knownLimitations)
    }
}

public enum AnalysisBenchmarkRunner {
    public static func evaluate(
        fixture: AnalysisBenchmarkFixture,
        snapshot: AnalysisSnapshot,
        wallSeconds: Double,
        engine: String = "project-owned-dsp",
        engineVersion: String = "l4-m03-v1"
    ) -> [AnalysisBenchmarkRow] {
        var rows: [AnalysisBenchmarkRow] = []
        let duration = fixture.signal.durationSeconds
        let rtf = duration > 0 ? wallSeconds / duration : nil
        let parityEligible = !fixture.syntheticOnly
        let limitations = fixture.syntheticOnly ? ["SYNTHETIC_UNIT_ONLY_NOT_PARITY_EVIDENCE"] : []

        if let referenceBPM = fixture.reference.bpm {
            var metrics: [String: Double] = [:]
            if let predicted = snapshot.tempo?.bpm {
                let relativeError = abs(predicted - referenceBPM) / referenceBPM
                metrics["tempo_rel_error"] = relativeError
                metrics["exact_within_4pct"] = relativeError <= 0.04 ? 1 : 0
                let ratios = [predicted / referenceBPM, predicted / (referenceBPM * 0.5), predicted / (referenceBPM * 2)]
                let octaveAware = ratios.contains { abs($0 - 1) <= 0.04 }
                metrics["octave_aware_within_4pct"] = octaveAware ? 1 : 0
                metrics["predicted_bpm"] = predicted
                if let confidence = snapshot.tempo?.confidence { metrics["confidence"] = confidence }
            } else {
                metrics["decision_emitted"] = 0
            }
            rows.append(row(fixture, parityEligible, engine, engineVersion, "tempo", metrics, wallSeconds, rtf, limitations))
        }

        if !fixture.reference.beatTimesSeconds.isEmpty {
            var metrics: [String: Double] = [:]
            let estimated = snapshot.tempo?.beatTimesSeconds ?? []
            metrics["beat_f_70ms"] = beatFMeasure(reference: fixture.reference.beatTimesSeconds, estimated: estimated, tolerance: 0.070)
            metrics["reference_beats"] = Double(fixture.reference.beatTimesSeconds.count)
            metrics["estimated_beats"] = Double(estimated.count)
            if let medianError = medianAbsoluteBeatError(reference: fixture.reference.beatTimesSeconds, estimated: estimated) {
                metrics["median_abs_error_seconds"] = medianError
            }
            rows.append(row(fixture, parityEligible, engine, engineVersion, "beat", metrics, wallSeconds, rtf, limitations))
        }

        if let referenceKey = fixture.reference.key {
            var metrics: [String: Double] = [:]
            if let predicted = snapshot.key {
                metrics["exact_key_accuracy"] = (predicted.tonicPitchClass == referenceKey.tonicPitchClass && predicted.mode == referenceKey.mode) ? 1 : 0
                metrics["tonic_accuracy"] = predicted.tonicPitchClass == referenceKey.tonicPitchClass ? 1 : 0
                metrics["mode_accuracy"] = predicted.mode == referenceKey.mode ? 1 : 0
                metrics["weighted_key_score"] = weightedKeyScore(reference: referenceKey, estimated: predicted)
                if let confidence = predicted.confidence { metrics["confidence"] = confidence }
            } else {
                metrics["decision_emitted"] = 0
            }
            rows.append(row(fixture, parityEligible, engine, engineVersion, "key", metrics, wallSeconds, rtf, limitations))
        }

        if !fixture.reference.chords.isEmpty {
            let metrics = chordMetrics(
                reference: fixture.reference.chords,
                estimated: snapshot.chords,
                duration: duration
            )
            rows.append(row(fixture, parityEligible, engine, engineVersion, "chord", metrics, wallSeconds, rtf, limitations))
        }

        return rows
    }

    public static func beatFMeasure(reference: [Double], estimated: [Double], tolerance: Double = 0.070) -> Double {
        guard tolerance >= 0 else { return 0 }
        let reference = reference.sorted()
        let estimated = estimated.sorted()
        guard !reference.isEmpty || !estimated.isEmpty else { return 1 }
        var used = Array(repeating: false, count: reference.count)
        var matches = 0
        for estimate in estimated {
            var bestIndex: Int?
            var bestError = Double.greatestFiniteMagnitude
            for index in reference.indices where !used[index] {
                let error = abs(reference[index] - estimate)
                if error <= tolerance, error < bestError {
                    bestError = error
                    bestIndex = index
                }
            }
            if let bestIndex {
                used[bestIndex] = true
                matches += 1
            }
        }
        let precision = estimated.isEmpty ? 0 : Double(matches) / Double(estimated.count)
        let recall = reference.isEmpty ? 0 : Double(matches) / Double(reference.count)
        guard precision + recall > 0 else { return 0 }
        return 2 * precision * recall / (precision + recall)
    }

    public static func weightedKeyScore(reference: MusicalKey, estimated: MusicalKey) -> Double {
        if reference.tonicPitchClass == estimated.tonicPitchClass, reference.mode == estimated.mode { return 1 }
        if reference.mode == estimated.mode,
           (estimated.tonicPitchClass - reference.tonicPitchClass + 12) % 12 == 7 { return 0.5 }
        if reference.mode != estimated.mode {
            let isRelative = (reference.mode == "major" && estimated.mode == "minor" && estimated.tonicPitchClass == (reference.tonicPitchClass + 9) % 12)
                || (reference.mode == "minor" && estimated.mode == "major" && estimated.tonicPitchClass == (reference.tonicPitchClass + 3) % 12)
            if isRelative { return 0.3 }
            if reference.tonicPitchClass == estimated.tonicPitchClass { return 0.2 }
        }
        return 0
    }

    public static func chordMetrics(reference: [ChordEvent], estimated: [ChordEvent], duration: Double) -> [String: Double] {
        guard duration > 0 else {
            return [
                "root_weighted_accuracy": 0,
                "majmin_weighted_accuracy": 0,
                "no_chord_precision": 0,
                "no_chord_recall": 0,
                "coverage": 0
            ]
        }

        let clippedReference = normalizeChordEvents(reference, duration: duration)
        let clippedEstimated = normalizeChordEvents(estimated, duration: duration)
        var boundaries: [Double] = [0, duration]
        boundaries.append(contentsOf: clippedReference.flatMap { [$0.startSeconds, $0.endSeconds] })
        boundaries.append(contentsOf: clippedEstimated.flatMap { [$0.startSeconds, $0.endSeconds] })
        boundaries = Array(Set(boundaries.map { min(duration, max(0, $0)) })).sorted()

        var comparableDuration = 0.0
        var rootCorrect = 0.0
        var majMinCorrect = 0.0
        var estimatedNoChord = 0.0
        var referenceNoChord = 0.0
        var noChordIntersection = 0.0
        var decidedDuration = 0.0

        for index in 0..<(max(0, boundaries.count - 1)) {
            let start = boundaries[index]
            let end = boundaries[index + 1]
            let span = end - start
            guard span > 0 else { continue }
            let midpoint = (start + end) / 2
            let refLabel = chordLabel(at: midpoint, events: clippedReference) ?? "X"
            let estLabel = chordLabel(at: midpoint, events: clippedEstimated) ?? "X"

            if estLabel != "X" { decidedDuration += span }
            if refLabel == "N" { referenceNoChord += span }
            if estLabel == "N" { estimatedNoChord += span }
            if refLabel == "N", estLabel == "N" { noChordIntersection += span }

            guard refLabel != "N", refLabel != "X", estLabel != "N", estLabel != "X" else { continue }
            comparableDuration += span
            if chordRoot(refLabel) == chordRoot(estLabel) { rootCorrect += span }
            if normalizeMajMinLabel(refLabel) == normalizeMajMinLabel(estLabel) { majMinCorrect += span }
        }

        var metrics: [String: Double] = [:]
        metrics["root_weighted_accuracy"] = comparableDuration > 0 ? rootCorrect / comparableDuration : 0
        metrics["majmin_weighted_accuracy"] = comparableDuration > 0 ? majMinCorrect / comparableDuration : 0
        metrics["no_chord_precision"] = estimatedNoChord > 0 ? noChordIntersection / estimatedNoChord : (referenceNoChord == 0 ? 1 : 0)
        metrics["no_chord_recall"] = referenceNoChord > 0 ? noChordIntersection / referenceNoChord : 1
        metrics["coverage"] = decidedDuration / duration
        metrics["reference_events"] = Double(clippedReference.count)
        metrics["estimated_events"] = Double(clippedEstimated.count)
        if let error = medianChordBoundaryError(reference: clippedReference, estimated: clippedEstimated, duration: duration) {
            metrics["boundary_median_abs_error_seconds"] = error
        }
        return metrics
    }

    private static func medianAbsoluteBeatError(reference: [Double], estimated: [Double]) -> Double? {
        guard !reference.isEmpty, !estimated.isEmpty else { return nil }
        let errors = reference.map { ref in estimated.map { abs($0 - ref) }.min() ?? Double.greatestFiniteMagnitude }.sorted()
        return median(errors)
    }

    private static func medianChordBoundaryError(reference: [ChordEvent], estimated: [ChordEvent], duration: Double) -> Double? {
        let referenceBoundaries = reference.map(\.endSeconds).filter { $0 > 1e-9 && $0 < duration - 1e-9 }
        let estimatedBoundaries = estimated.map(\.endSeconds).filter { $0 > 1e-9 && $0 < duration - 1e-9 }
        guard !referenceBoundaries.isEmpty, !estimatedBoundaries.isEmpty else {
            return referenceBoundaries.isEmpty && estimatedBoundaries.isEmpty ? 0 : nil
        }
        let errors = referenceBoundaries.map { ref in
            estimatedBoundaries.map { abs($0 - ref) }.min() ?? duration
        }.sorted()
        return median(errors)
    }

    private static func normalizeChordEvents(_ events: [ChordEvent], duration: Double) -> [ChordEvent] {
        events.compactMap { event in
            let start = min(duration, max(0, event.startSeconds))
            let end = min(duration, max(start, event.endSeconds))
            guard end > start else { return nil }
            return ChordEvent(startSeconds: start, endSeconds: end, normalizedLabel: event.normalizedLabel, confidence: event.confidence)
        }.sorted {
            if $0.startSeconds == $1.startSeconds { return $0.endSeconds < $1.endSeconds }
            return $0.startSeconds < $1.startSeconds
        }
    }

    private static func chordLabel(at time: Double, events: [ChordEvent]) -> String? {
        events.first { time >= $0.startSeconds && time < $0.endSeconds }?.normalizedLabel
    }

    private static func chordRoot(_ label: String) -> String? {
        guard label != "N", label != "X" else { return nil }
        return label.split(separator: ":", maxSplits: 1).first.map(String.init)
    }

    private static func normalizeMajMinLabel(_ label: String) -> String? {
        guard let root = chordRoot(label) else { return nil }
        let quality = label.contains(":min") ? "min" : "maj"
        return "\(root):\(quality)"
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let mid = values.count / 2
        if values.count % 2 == 0 { return (values[mid - 1] + values[mid]) / 2 }
        return values[mid]
    }

    private static func row(_ fixture: AnalysisBenchmarkFixture, _ parityEligible: Bool, _ engine: String, _ engineVersion: String, _ domain: String, _ metrics: [String: Double], _ wallSeconds: Double, _ rtf: Double?, _ limitations: [String]) -> AnalysisBenchmarkRow {
        AnalysisBenchmarkRow(
            fixtureID: fixture.fixtureID,
            rightsClass: fixture.rightsClass,
            genre: fixture.genre,
            durationSeconds: fixture.signal.durationSeconds,
            syntheticOnly: fixture.syntheticOnly,
            parityEligible: parityEligible,
            engine: engine,
            engineVersion: engineVersion,
            domain: domain,
            metrics: metrics,
            wallSeconds: wallSeconds,
            rtf: rtf,
            peakRSSMB: nil,
            thermal: nil,
            knownLimitations: limitations
        )
    }
}
