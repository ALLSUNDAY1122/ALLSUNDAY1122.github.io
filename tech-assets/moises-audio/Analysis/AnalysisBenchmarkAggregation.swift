import Foundation

public enum AnalysisBenchmarkMetricDirection: String, Codable, Sendable {
    case higherIsBetter = "HIGHER_IS_BETTER"
    case lowerIsBetter = "LOWER_IS_BETTER"
}

public struct AnalysisBenchmarkMetricWorstCase: Codable, Equatable, Sendable {
    public let fixtureID: String
    public let genre: String
    public let value: Double
}

public struct AnalysisBenchmarkMetricAggregate: Codable, Equatable, Sendable {
    public let metric: String
    public let direction: AnalysisBenchmarkMetricDirection
    public let sampleCount: Int
    public let parityEligibleSampleCount: Int
    public let populationComplete: Bool
    public let parityEligiblePopulationComplete: Bool
    public let mean: Double?
    public let parityEligibleMean: Double?
    public let worst: AnalysisBenchmarkMetricWorstCase?
    public let parityEligibleWorst: AnalysisBenchmarkMetricWorstCase?
}

public struct AnalysisBenchmarkQualityScopeSummary: Codable, Equatable, Sendable {
    public let domain: String
    public let genre: String?
    public let rowCount: Int
    public let acceptedRowCount: Int
    public let parityEligibleRowCount: Int
    public let evaluatorRejectedRowCount: Int
    public let nonParityRowCount: Int
    public let metrics: [AnalysisBenchmarkMetricAggregate]
}

public struct AnalysisBenchmarkRejectedRow: Codable, Equatable, Sendable {
    public let fixtureID: String
    public let domain: String
    public let genre: String
    public let knownLimitations: [String]
}

public struct AnalysisAuditedRealAudioBenchmarkReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let manifestID: String
    public let generatedAt: Date
    public let engine: String
    public let engineVersion: String
    public let parityEligible: Bool
    public let rows: [AnalysisBenchmarkRow]
    public let domainQualitySummaries: [AnalysisBenchmarkQualityScopeSummary]
    public let genreQualitySummaries: [AnalysisBenchmarkQualityScopeSummary]
    public let evaluatorRejectedRows: [AnalysisBenchmarkRejectedRow]
    public let nonParityRows: [AnalysisBenchmarkRejectedRow]
    public let excludedContextMetricNames: [String]
    public let validationIssues: [AnalysisBenchmarkValidationIssue]

    public init(
        schemaVersion: Int = 1,
        manifestID: String,
        generatedAt: Date,
        engine: String,
        engineVersion: String,
        parityEligible: Bool,
        rows: [AnalysisBenchmarkRow],
        domainQualitySummaries: [AnalysisBenchmarkQualityScopeSummary],
        genreQualitySummaries: [AnalysisBenchmarkQualityScopeSummary],
        evaluatorRejectedRows: [AnalysisBenchmarkRejectedRow],
        nonParityRows: [AnalysisBenchmarkRejectedRow],
        excludedContextMetricNames: [String],
        validationIssues: [AnalysisBenchmarkValidationIssue]
    ) {
        self.schemaVersion = schemaVersion
        self.manifestID = manifestID
        self.generatedAt = generatedAt
        self.engine = engine
        self.engineVersion = engineVersion
        self.parityEligible = parityEligible
        self.rows = rows
        self.domainQualitySummaries = domainQualitySummaries
        self.genreQualitySummaries = genreQualitySummaries
        self.evaluatorRejectedRows = evaluatorRejectedRows
        self.nonParityRows = nonParityRows
        self.excludedContextMetricNames = excludedContextMetricNames
        self.validationIssues = validationIssues
    }
}

public enum AnalysisBenchmarkAggregation {
    /// Only metrics with an explicit quality interpretation are aggregatable.
    /// Counts, limits, confidence, runtime metadata, W14/W15 diagnostics and raw
    /// predictions remain present on rows but never receive semantically invalid means.
    public static let metricDirections: [String: AnalysisBenchmarkMetricDirection] = [
        "decision_emitted": .higherIsBetter,
        "exact_within_4pct": .higherIsBetter,
        "octave_aware_within_4pct": .higherIsBetter,
        "beat_f_70ms": .higherIsBetter,
        "exact_key_accuracy": .higherIsBetter,
        "tonic_accuracy": .higherIsBetter,
        "mode_accuracy": .higherIsBetter,
        "weighted_key_score": .higherIsBetter,
        "root_weighted_accuracy": .higherIsBetter,
        "majmin_weighted_accuracy": .higherIsBetter,
        "no_chord_precision": .higherIsBetter,
        "no_chord_recall": .higherIsBetter,
        "coverage": .higherIsBetter,
        "boundary_precision_0_5s": .higherIsBetter,
        "boundary_recall_0_5s": .higherIsBetter,
        "boundary_f_0_5s": .higherIsBetter,
        "boundary_precision_3_0s": .higherIsBetter,
        "boundary_recall_3_0s": .higherIsBetter,
        "boundary_f_3_0s": .higherIsBetter,
        "pairwise_precision": .higherIsBetter,
        "pairwise_recall": .higherIsBetter,
        "pairwise_f": .higherIsBetter,
        "adjusted_rand_index": .higherIsBetter,
        "structural_coverage": .higherIsBetter,
        "functional_macro_f1": .higherIsBetter,
        "functional_coverage": .higherIsBetter,
        "tempo_rel_error": .lowerIsBetter,
        "median_abs_error_seconds": .lowerIsBetter,
        "boundary_median_abs_error_seconds": .lowerIsBetter,
        "median_reference_to_estimate_boundary_error_seconds": .lowerIsBetter,
        "median_estimate_to_reference_boundary_error_seconds": .lowerIsBetter,
        "normalized_ref_given_est_entropy": .lowerIsBetter,
        "normalized_est_given_ref_entropy": .lowerIsBetter
    ]

    public static func domainSummaries(rows: [AnalysisBenchmarkRow]) -> [AnalysisBenchmarkQualityScopeSummary] {
        Dictionary(grouping: rows, by: \.domain)
            .keys
            .sorted()
            .map { domain in
                summarizeScope(rows: rows.filter { $0.domain == domain }, domain: domain, genre: nil)
            }
    }

    public static func genreSummaries(rows: [AnalysisBenchmarkRow]) -> [AnalysisBenchmarkQualityScopeSummary] {
        let keys = Set(rows.map { ScopeKey(domain: $0.domain, genre: $0.genre) })
        return keys.sorted {
            if $0.domain == $1.domain { return $0.genre < $1.genre }
            return $0.domain < $1.domain
        }.map { key in
            summarizeScope(
                rows: rows.filter { $0.domain == key.domain && $0.genre == key.genre },
                domain: key.domain,
                genre: key.genre
            )
        }
    }

    public static func evaluatorRejectedRows(rows: [AnalysisBenchmarkRow]) -> [AnalysisBenchmarkRejectedRow] {
        rows.filter(isEvaluatorRejected)
            .map(rejectedRow)
            .sorted(by: rejectedRowOrder)
    }

    public static func nonParityRows(rows: [AnalysisBenchmarkRow]) -> [AnalysisBenchmarkRejectedRow] {
        rows.filter { !$0.parityEligible }
            .map(rejectedRow)
            .sorted(by: rejectedRowOrder)
    }

    public static func excludedContextMetricNames(rows: [AnalysisBenchmarkRow]) -> [String] {
        let all = Set(rows.flatMap { $0.metrics.keys })
        return all.subtracting(metricDirections.keys).sorted()
    }

    /// Compatibility helper for the old `AnalysisBenchmarkDomainSummary` shape.
    /// Only explicit quality metrics are averaged and evaluator-rejected rows are excluded.
    public static func qualityMeanMetrics(rows: [AnalysisBenchmarkRow]) -> [String: Double] {
        let accepted = rows.filter { !isEvaluatorRejected($0) }
        var output: [String: Double] = [:]
        for metric in metricDirections.keys.sorted() {
            let values = accepted.compactMap { qualityValue(metric: metric, row: $0) }.filter(\.isFinite)
            guard !values.isEmpty else { continue }
            output[metric] = values.reduce(0, +) / Double(values.count)
        }
        return output
    }

    private static func summarizeScope(
        rows: [AnalysisBenchmarkRow],
        domain: String,
        genre: String?
    ) -> AnalysisBenchmarkQualityScopeSummary {
        let orderedRows = rows.sorted {
            if $0.fixtureID == $1.fixtureID { return $0.genre < $1.genre }
            return $0.fixtureID < $1.fixtureID
        }
        let accepted = orderedRows.filter { !isEvaluatorRejected($0) }
        let parityEligible = accepted.filter(\.parityEligible)
        var metricAggregates: [AnalysisBenchmarkMetricAggregate] = []

        for metric in metricDirections.keys.sorted() {
            guard let direction = metricDirections[metric] else { continue }
            let allSamples = accepted.compactMap { row -> (AnalysisBenchmarkRow, Double)? in
                guard let value = qualityValue(metric: metric, row: row), value.isFinite else { return nil }
                return (row, value)
            }
            let eligibleSamples = parityEligible.compactMap { row -> (AnalysisBenchmarkRow, Double)? in
                guard let value = qualityValue(metric: metric, row: row), value.isFinite else { return nil }
                return (row, value)
            }
            guard !allSamples.isEmpty || !eligibleSamples.isEmpty else { continue }

            metricAggregates.append(
                AnalysisBenchmarkMetricAggregate(
                    metric: metric,
                    direction: direction,
                    sampleCount: allSamples.count,
                    parityEligibleSampleCount: eligibleSamples.count,
                    populationComplete: allSamples.count == accepted.count,
                    parityEligiblePopulationComplete: eligibleSamples.count == parityEligible.count,
                    mean: mean(allSamples.map(\.1)),
                    parityEligibleMean: mean(eligibleSamples.map(\.1)),
                    worst: worstCase(samples: allSamples, direction: direction),
                    parityEligibleWorst: worstCase(samples: eligibleSamples, direction: direction)
                )
            )
        }

        return AnalysisBenchmarkQualityScopeSummary(
            domain: domain,
            genre: genre,
            rowCount: rows.count,
            acceptedRowCount: accepted.count,
            parityEligibleRowCount: parityEligible.count,
            evaluatorRejectedRowCount: rows.filter(isEvaluatorRejected).count,
            nonParityRowCount: rows.filter { !$0.parityEligible }.count,
            metrics: metricAggregates
        )
    }

    private static func qualityValue(metric: String, row: AnalysisBenchmarkRow) -> Double? {
        if metric == "decision_emitted" {
            if let explicit = row.metrics[metric], explicit.isFinite { return explicit }
            if row.domain == "tempo", row.metrics["predicted_bpm"] != nil { return 1 }
            if row.domain == "key", row.metrics["exact_key_accuracy"] != nil { return 1 }
            return nil
        }
        guard let value = row.metrics[metric], value.isFinite else { return nil }
        return value
    }

    private static func isEvaluatorRejected(_ row: AnalysisBenchmarkRow) -> Bool {
        if let accepted = row.metrics["evaluator_input_accepted"], accepted.isFinite {
            return accepted < 0.5
        }
        return false
    }

    private static func rejectedRow(_ row: AnalysisBenchmarkRow) -> AnalysisBenchmarkRejectedRow {
        AnalysisBenchmarkRejectedRow(
            fixtureID: row.fixtureID,
            domain: row.domain,
            genre: row.genre,
            knownLimitations: row.knownLimitations.sorted()
        )
    }

    private static func rejectedRowOrder(_ lhs: AnalysisBenchmarkRejectedRow, _ rhs: AnalysisBenchmarkRejectedRow) -> Bool {
        if lhs.fixtureID != rhs.fixtureID { return lhs.fixtureID < rhs.fixtureID }
        if lhs.domain != rhs.domain { return lhs.domain < rhs.domain }
        return lhs.genre < rhs.genre
    }

    private static func worstCase(
        samples: [(AnalysisBenchmarkRow, Double)],
        direction: AnalysisBenchmarkMetricDirection
    ) -> AnalysisBenchmarkMetricWorstCase? {
        guard let first = samples.first else { return nil }
        var worst = first
        for sample in samples.dropFirst() {
            let isWorse: Bool
            switch direction {
            case .higherIsBetter:
                isWorse = sample.1 < worst.1
            case .lowerIsBetter:
                isWorse = sample.1 > worst.1
            }
            if isWorse {
                worst = sample
            } else if sample.1 == worst.1 {
                if sample.0.fixtureID < worst.0.fixtureID ||
                    (sample.0.fixtureID == worst.0.fixtureID && sample.0.genre < worst.0.genre) {
                    worst = sample
                }
            }
        }
        return AnalysisBenchmarkMetricWorstCase(
            fixtureID: worst.0.fixtureID,
            genre: worst.0.genre,
            value: worst.1
        )
    }

    private static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private struct ScopeKey: Hashable {
        let domain: String
        let genre: String
    }
}

public extension AnalysisRealAudioBenchmarkRunner {
    /// W17 canonical evidence report. It keeps every raw row while preventing
    /// context/count diagnostics from being averaged into quality claims and
    /// exposes genre-level and worst-fixture anti-masking views.
    static func runProductAlignedAudited(
        manifest: AnalysisRealAudioBenchmarkManifest,
        loader: any AnalysisBenchmarkSignalLoading,
        configuration: MusicAnalysisConfiguration = .productBaseline,
        engine: String = "project-owned-dsp",
        engineVersion: String = "lane4-autonomous-w17",
        runDate: Date = Date()
    ) async throws -> AnalysisAuditedRealAudioBenchmarkReport {
        let base = try await runProductAligned(
            manifest: manifest,
            loader: loader,
            configuration: configuration,
            engine: engine,
            engineVersion: engineVersion,
            runDate: runDate
        )
        try AnalysisCancellationPolicy.check()
        let rejected = AnalysisBenchmarkAggregation.evaluatorRejectedRows(rows: base.rows)
        return AnalysisAuditedRealAudioBenchmarkReport(
            manifestID: base.manifestID,
            generatedAt: base.generatedAt,
            engine: base.engine,
            engineVersion: base.engineVersion,
            parityEligible: base.parityEligible && rejected.isEmpty,
            rows: base.rows,
            domainQualitySummaries: AnalysisBenchmarkAggregation.domainSummaries(rows: base.rows),
            genreQualitySummaries: AnalysisBenchmarkAggregation.genreSummaries(rows: base.rows),
            evaluatorRejectedRows: rejected,
            nonParityRows: AnalysisBenchmarkAggregation.nonParityRows(rows: base.rows),
            excludedContextMetricNames: AnalysisBenchmarkAggregation.excludedContextMetricNames(rows: base.rows),
            validationIssues: base.validationIssues
        )
    }
}
