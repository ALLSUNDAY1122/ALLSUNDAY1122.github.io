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

    public init(
        fixtureID: String,
        rightsClass: AnalysisRightsClass,
        genre: String,
        syntheticOnly: Bool,
        signal: AnalysisSignal,
        reference: TempoBeatKeyReference
    ) {
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
        engineVersion: String = "l4-m03-v1",
        configuration: MusicAnalysisConfiguration = .productBaseline,
        supplementalMetrics: [String: Double] = [:]
    ) -> [AnalysisBenchmarkRow] {
        try! evaluateInternal(
            fixture: fixture,
            snapshot: snapshot,
            wallSeconds: wallSeconds,
            engine: engine,
            engineVersion: engineVersion,
            configuration: configuration,
            supplementalMetrics: supplementalMetrics,
            cancellationEnabled: false
        )
    }

    public static func evaluateCancellable(
        fixture: AnalysisBenchmarkFixture,
        snapshot: AnalysisSnapshot,
        wallSeconds: Double,
        engine: String = "project-owned-dsp",
        engineVersion: String = "lane4-autonomous-w16",
        configuration: MusicAnalysisConfiguration = .productBaseline,
        supplementalMetrics: [String: Double] = [:]
    ) throws -> [AnalysisBenchmarkRow] {
        try evaluateInternal(
            fixture: fixture,
            snapshot: snapshot,
            wallSeconds: wallSeconds,
            engine: engine,
            engineVersion: engineVersion,
            configuration: configuration,
            supplementalMetrics: supplementalMetrics,
            cancellationEnabled: true
        )
    }

    public static func beatFMeasure(
        reference: [Double],
        estimated: [Double],
        tolerance: Double = 0.070
    ) -> Double {
        guard tolerance >= 0 else { return 0 }
        if reference.isEmpty, estimated.isEmpty { return 1 }
        let matching = BenchmarkTimelineMatcher.greedyNearestOneToOne(
            reference: reference,
            estimated: estimated,
            tolerance: tolerance
        )
        return fMeasure(matches: matching.matches, referenceCount: reference.count, estimatedCount: estimated.count)
    }

    public static func beatFMeasureCancellable(
        reference: [Double],
        estimated: [Double],
        tolerance: Double = 0.070
    ) throws -> Double {
        guard tolerance >= 0 else { return 0 }
        if reference.isEmpty, estimated.isEmpty { return 1 }
        let matching = try BenchmarkTimelineMatcher.greedyNearestOneToOneCancellable(
            reference: reference,
            estimated: estimated,
            tolerance: tolerance
        )
        return fMeasure(matches: matching.matches, referenceCount: reference.count, estimatedCount: estimated.count)
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

    public static func chordMetrics(
        reference: [ChordEvent],
        estimated: [ChordEvent],
        duration: Double
    ) -> [String: Double] {
        try! chordMetricsInternal(
            reference: reference,
            estimated: estimated,
            duration: duration,
            cancellationEnabled: false
        )
    }

    public static func chordMetricsCancellable(
        reference: [ChordEvent],
        estimated: [ChordEvent],
        duration: Double
    ) throws -> [String: Double] {
        try chordMetricsInternal(
            reference: reference,
            estimated: estimated,
            duration: duration,
            cancellationEnabled: true
        )
    }

    private static func evaluateInternal(
        fixture: AnalysisBenchmarkFixture,
        snapshot: AnalysisSnapshot,
        wallSeconds: Double,
        engine: String,
        engineVersion: String,
        configuration: MusicAnalysisConfiguration,
        supplementalMetrics: [String: Double],
        cancellationEnabled: Bool
    ) throws -> [AnalysisBenchmarkRow] {
        if cancellationEnabled { try AnalysisCancellationPolicy.check() }
        var rows: [AnalysisBenchmarkRow] = []
        let duration = fixture.signal.durationSeconds
        let rtf = duration > 0 ? wallSeconds / duration : nil
        let baseParityEligible = !fixture.syntheticOnly
        let baseLimitations = fixture.syntheticOnly ? ["SYNTHETIC_UNIT_ONLY_NOT_PARITY_EVIDENCE"] : []
        let estimatedBeats = snapshot.tempo?.beatTimesSeconds ?? []
        let evaluator = AnalysisBenchmarkEvaluatorPolicy.diagnostics(
            referenceBeatCount: fixture.reference.beatTimesSeconds.count,
            estimatedBeatCount: estimatedBeats.count,
            referenceChordCount: fixture.reference.chords.count,
            estimatedChordCount: snapshot.chords.count,
            referenceSectionCount: 0,
            estimatedSectionCount: snapshot.sections.count,
            duration: duration,
            configuration: configuration
        )

        if let referenceBPM = fixture.reference.bpm {
            var metrics = supplementalMetrics
            if let predicted = snapshot.tempo?.bpm {
                let relativeError = abs(predicted - referenceBPM) / referenceBPM
                metrics["tempo_rel_error"] = relativeError
                metrics["exact_within_4pct"] = relativeError <= 0.04 ? 1 : 0
                let ratios = [predicted / referenceBPM, predicted / (referenceBPM * 0.5), predicted / (referenceBPM * 2)]
                metrics["octave_aware_within_4pct"] = ratios.contains { abs($0 - 1) <= 0.04 } ? 1 : 0
                metrics["predicted_bpm"] = predicted
                if let confidence = snapshot.tempo?.confidence { metrics["confidence"] = confidence }
            } else {
                metrics["decision_emitted"] = 0
            }
            rows.append(row(
                fixture, baseParityEligible, engine, engineVersion, "tempo", metrics,
                wallSeconds, rtf, baseLimitations
            ))
        }

        if !fixture.reference.beatTimesSeconds.isEmpty {
            var metrics = supplementalMetrics
            metrics["reference_beats"] = Double(fixture.reference.beatTimesSeconds.count)
            metrics["estimated_beats"] = Double(estimatedBeats.count)
            metrics["evaluator_beat_input_limit"] = Double(evaluator.beatInputLimit)
            metrics["evaluator_input_accepted"] = evaluator.beatInputsAccepted ? 1 : 0
            var limitations = baseLimitations
            var parityEligible = baseParityEligible
            if evaluator.beatInputsAccepted {
                metrics["beat_f_70ms"] = cancellationEnabled
                    ? try beatFMeasureCancellable(reference: fixture.reference.beatTimesSeconds, estimated: estimatedBeats, tolerance: 0.070)
                    : beatFMeasure(reference: fixture.reference.beatTimesSeconds, estimated: estimatedBeats, tolerance: 0.070)
                let errors = cancellationEnabled
                    ? try BenchmarkTimelineMatcher.nearestAbsoluteErrorsCancellable(source: fixture.reference.beatTimesSeconds, target: estimatedBeats)
                    : BenchmarkTimelineMatcher.nearestAbsoluteErrors(source: fixture.reference.beatTimesSeconds, target: estimatedBeats)
                if let errors, let value = median(errors.sorted()) { metrics["median_abs_error_seconds"] = value }
            } else {
                parityEligible = false
                limitations.append("EVALUATOR_BEAT_CARDINALITY_REJECTED_NOT_PARITY_EVIDENCE")
            }
            rows.append(row(
                fixture, parityEligible, engine, engineVersion, "beat", metrics,
                wallSeconds, rtf, limitations
            ))
        }

        if let referenceKey = fixture.reference.key {
            var metrics = supplementalMetrics
            if let predicted = snapshot.key {
                metrics["exact_key_accuracy"] = (predicted.tonicPitchClass == referenceKey.tonicPitchClass && predicted.mode == referenceKey.mode) ? 1 : 0
                metrics["tonic_accuracy"] = predicted.tonicPitchClass == referenceKey.tonicPitchClass ? 1 : 0
                metrics["mode_accuracy"] = predicted.mode == referenceKey.mode ? 1 : 0
                metrics["weighted_key_score"] = weightedKeyScore(reference: referenceKey, estimated: predicted)
                if let confidence = predicted.confidence { metrics["confidence"] = confidence }
            } else {
                metrics["decision_emitted"] = 0
            }
            rows.append(row(
                fixture, baseParityEligible, engine, engineVersion, "key", metrics,
                wallSeconds, rtf, baseLimitations
            ))
        }

        if !fixture.reference.chords.isEmpty {
            var metrics = supplementalMetrics
            metrics["evaluator_chord_input_limit"] = Double(evaluator.chordInputLimit)
            metrics["evaluator_input_accepted"] = evaluator.chordInputsAccepted ? 1 : 0
            var limitations = baseLimitations
            var parityEligible = baseParityEligible
            if evaluator.chordInputsAccepted {
                let chord = cancellationEnabled
                    ? try chordMetricsCancellable(reference: fixture.reference.chords, estimated: snapshot.chords, duration: duration)
                    : chordMetrics(reference: fixture.reference.chords, estimated: snapshot.chords, duration: duration)
                metrics.merge(chord) { _, new in new }
            } else {
                parityEligible = false
                limitations.append("EVALUATOR_CHORD_CARDINALITY_REJECTED_NOT_PARITY_EVIDENCE")
                metrics["reference_events"] = Double(fixture.reference.chords.count)
                metrics["estimated_events"] = Double(snapshot.chords.count)
            }
            rows.append(row(
                fixture, parityEligible, engine, engineVersion, "chord", metrics,
                wallSeconds, rtf, limitations
            ))
        }

        if cancellationEnabled { try AnalysisCancellationPolicy.check() }
        return rows
    }

    private static func chordMetricsInternal(
        reference: [ChordEvent],
        estimated: [ChordEvent],
        duration: Double,
        cancellationEnabled: Bool
    ) throws -> [String: Double] {
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
        var boundarySet: Set<Double> = [0, duration]
        for event in clippedReference { boundarySet.insert(event.startSeconds); boundarySet.insert(event.endSeconds) }
        for event in clippedEstimated { boundarySet.insert(event.startSeconds); boundarySet.insert(event.endSeconds) }
        let boundaries = boundarySet.map { min(duration, max(0, $0)) }.sorted()

        var comparableDuration = 0.0
        var rootCorrect = 0.0
        var majMinCorrect = 0.0
        var estimatedNoChord = 0.0
        var referenceNoChord = 0.0
        var noChordIntersection = 0.0
        var decidedDuration = 0.0
        var referenceCursor = 0
        var estimatedCursor = 0

        if boundaries.count >= 2 {
            for index in 0..<(boundaries.count - 1) {
                if cancellationEnabled && index.isMultiple(of: 256) { try AnalysisCancellationPolicy.check() }
                let start = boundaries[index]
                let end = boundaries[index + 1]
                let span = end - start
                guard span > 0 else { continue }
                let midpoint = (start + end) / 2
                let refLabel = advancingChordLabel(at: midpoint, events: clippedReference, cursor: &referenceCursor) ?? "X"
                let estLabel = advancingChordLabel(at: midpoint, events: clippedEstimated, cursor: &estimatedCursor) ?? "X"

                if estLabel != "X" { decidedDuration += span }
                if refLabel == "N" { referenceNoChord += span }
                if estLabel == "N" { estimatedNoChord += span }
                if refLabel == "N", estLabel == "N" { noChordIntersection += span }

                guard refLabel != "N", refLabel != "X", estLabel != "N", estLabel != "X" else { continue }
                comparableDuration += span
                if chordRoot(refLabel) == chordRoot(estLabel) { rootCorrect += span }
                if normalizeMajMinLabel(refLabel) == normalizeMajMinLabel(estLabel) { majMinCorrect += span }
            }
        }

        var metrics: [String: Double] = [:]
        metrics["root_weighted_accuracy"] = comparableDuration > 0 ? rootCorrect / comparableDuration : 0
        metrics["majmin_weighted_accuracy"] = comparableDuration > 0 ? majMinCorrect / comparableDuration : 0
        metrics["no_chord_precision"] = estimatedNoChord > 0 ? noChordIntersection / estimatedNoChord : (referenceNoChord == 0 ? 1 : 0)
        metrics["no_chord_recall"] = referenceNoChord > 0 ? noChordIntersection / referenceNoChord : 1
        metrics["coverage"] = decidedDuration / duration
        metrics["reference_events"] = Double(clippedReference.count)
        metrics["estimated_events"] = Double(clippedEstimated.count)

        let referenceBoundaries = clippedReference.map(\.endSeconds).filter { $0 > 1e-9 && $0 < duration - 1e-9 }
        let estimatedBoundaries = clippedEstimated.map(\.endSeconds).filter { $0 > 1e-9 && $0 < duration - 1e-9 }
        let errors = cancellationEnabled
            ? try BenchmarkTimelineMatcher.nearestAbsoluteErrorsCancellable(source: referenceBoundaries, target: estimatedBoundaries)
            : BenchmarkTimelineMatcher.nearestAbsoluteErrors(source: referenceBoundaries, target: estimatedBoundaries)
        if referenceBoundaries.isEmpty, estimatedBoundaries.isEmpty {
            metrics["boundary_median_abs_error_seconds"] = 0
        } else if let errors, let value = median(errors.sorted()) {
            metrics["boundary_median_abs_error_seconds"] = value
        }
        if cancellationEnabled { try AnalysisCancellationPolicy.check() }
        return metrics
    }

    private static func fMeasure(matches: Int, referenceCount: Int, estimatedCount: Int) -> Double {
        let precision = estimatedCount == 0 ? 0 : Double(matches) / Double(estimatedCount)
        let recall = referenceCount == 0 ? 0 : Double(matches) / Double(referenceCount)
        guard precision + recall > 0 else { return 0 }
        return 2 * precision * recall / (precision + recall)
    }

    private static func normalizeChordEvents(_ events: [ChordEvent], duration: Double) -> [ChordEvent] {
        events.compactMap { event in
            guard event.startSeconds.isFinite, event.endSeconds.isFinite else { return nil }
            let start = min(duration, max(0, event.startSeconds))
            let end = min(duration, max(start, event.endSeconds))
            guard end > start else { return nil }
            return ChordEvent(
                startSeconds: start,
                endSeconds: end,
                normalizedLabel: event.normalizedLabel,
                confidence: event.confidence
            )
        }.sorted {
            if $0.startSeconds == $1.startSeconds { return $0.endSeconds < $1.endSeconds }
            return $0.startSeconds < $1.startSeconds
        }
    }

    private static func advancingChordLabel(
        at time: Double,
        events: [ChordEvent],
        cursor: inout Int
    ) -> String? {
        while cursor < events.count, events[cursor].endSeconds <= time { cursor += 1 }
        guard cursor < events.count,
              time >= events[cursor].startSeconds,
              time < events[cursor].endSeconds else { return nil }
        return events[cursor].normalizedLabel
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
        let middle = values.count / 2
        if values.count.isMultiple(of: 2) { return (values[middle - 1] + values[middle]) / 2 }
        return values[middle]
    }

    private static func row(
        _ fixture: AnalysisBenchmarkFixture,
        _ parityEligible: Bool,
        _ engine: String,
        _ engineVersion: String,
        _ domain: String,
        _ metrics: [String: Double],
        _ wallSeconds: Double,
        _ rtf: Double?,
        _ limitations: [String]
    ) -> AnalysisBenchmarkRow {
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
