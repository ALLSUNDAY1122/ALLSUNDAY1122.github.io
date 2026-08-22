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

    public init(bpm: Double?, beatTimesSeconds: [Double] = [], key: MusicalKey? = nil) {
        self.bpm = bpm
        self.beatTimesSeconds = beatTimesSeconds.sorted()
        self.key = key
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
        engineVersion: String = "l4-m02-v1"
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

    private static func medianAbsoluteBeatError(reference: [Double], estimated: [Double]) -> Double? {
        guard !reference.isEmpty, !estimated.isEmpty else { return nil }
        let errors = reference.map { ref in estimated.map { abs($0 - ref) }.min() ?? Double.greatestFiniteMagnitude }.sorted()
        let mid = errors.count / 2
        if errors.count % 2 == 0 { return (errors[mid - 1] + errors[mid]) / 2 }
        return errors[mid]
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
