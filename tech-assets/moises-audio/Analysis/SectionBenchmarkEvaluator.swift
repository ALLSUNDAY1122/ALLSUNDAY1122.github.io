import Foundation

public enum SectionBenchmarkEvaluator {
    public static func evaluate(
        fixture: AnalysisBenchmarkFixture,
        reference: [SongSection],
        snapshot: AnalysisSnapshot,
        wallSeconds: Double,
        engine: String = "project-owned-dsp",
        engineVersion: String = "l4-m04-v1",
        configuration: MusicAnalysisConfiguration = .productBaseline,
        supplementalMetrics: [String: Double] = [:]
    ) -> AnalysisBenchmarkRow {
        try! evaluateInternal(
            fixture: fixture,
            reference: reference,
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
        reference: [SongSection],
        snapshot: AnalysisSnapshot,
        wallSeconds: Double,
        engine: String = "project-owned-dsp",
        engineVersion: String = "lane4-autonomous-w16",
        configuration: MusicAnalysisConfiguration = .productBaseline,
        supplementalMetrics: [String: Double] = [:]
    ) throws -> AnalysisBenchmarkRow {
        try evaluateInternal(
            fixture: fixture,
            reference: reference,
            snapshot: snapshot,
            wallSeconds: wallSeconds,
            engine: engine,
            engineVersion: engineVersion,
            configuration: configuration,
            supplementalMetrics: supplementalMetrics,
            cancellationEnabled: true
        )
    }

    public static func metrics(
        reference: [SongSection],
        estimated: [SongSection],
        duration: Double,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> [String: Double] {
        try! metricsInternal(
            reference: reference,
            estimated: estimated,
            duration: duration,
            configuration: configuration,
            cancellationEnabled: false
        )
    }

    public static func metricsCancellable(
        reference: [SongSection],
        estimated: [SongSection],
        duration: Double,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) throws -> [String: Double] {
        try metricsInternal(
            reference: reference,
            estimated: estimated,
            duration: duration,
            configuration: configuration,
            cancellationEnabled: true
        )
    }

    private static func evaluateInternal(
        fixture: AnalysisBenchmarkFixture,
        reference: [SongSection],
        snapshot: AnalysisSnapshot,
        wallSeconds: Double,
        engine: String,
        engineVersion: String,
        configuration: MusicAnalysisConfiguration,
        supplementalMetrics: [String: Double],
        cancellationEnabled: Bool
    ) throws -> AnalysisBenchmarkRow {
        if cancellationEnabled { try AnalysisCancellationPolicy.check() }
        let duration = fixture.signal.durationSeconds
        let evaluator = AnalysisBenchmarkEvaluatorPolicy.diagnostics(
            referenceBeatCount: 0,
            estimatedBeatCount: 0,
            referenceChordCount: 0,
            estimatedChordCount: 0,
            referenceSectionCount: reference.count,
            estimatedSectionCount: snapshot.sections.count,
            duration: duration,
            configuration: configuration
        )
        var rowMetrics = supplementalMetrics
        let sectionMetrics = try metricsInternal(
            reference: reference,
            estimated: snapshot.sections,
            duration: duration,
            configuration: configuration,
            cancellationEnabled: cancellationEnabled
        )
        rowMetrics.merge(sectionMetrics) { _, new in new }

        var limitations = fixture.syntheticOnly ? ["SYNTHETIC_UNIT_ONLY_NOT_PARITY_EVIDENCE"] : []
        var parityEligible = !fixture.syntheticOnly && evaluator.sectionInputsAccepted
        if !evaluator.sectionInputsAccepted {
            parityEligible = false
            limitations.append("EVALUATOR_SECTION_CARDINALITY_REJECTED_NOT_PARITY_EVIDENCE")
        }
        if cancellationEnabled { try AnalysisCancellationPolicy.check() }
        return AnalysisBenchmarkRow(
            fixtureID: fixture.fixtureID,
            rightsClass: fixture.rightsClass,
            genre: fixture.genre,
            durationSeconds: duration,
            syntheticOnly: fixture.syntheticOnly,
            parityEligible: parityEligible,
            engine: engine,
            engineVersion: engineVersion,
            domain: "structure",
            metrics: rowMetrics,
            wallSeconds: wallSeconds,
            rtf: duration > 0 ? wallSeconds / duration : nil,
            peakRSSMB: nil,
            thermal: nil,
            knownLimitations: limitations
        )
    }

    private static func metricsInternal(
        reference: [SongSection],
        estimated: [SongSection],
        duration: Double,
        configuration: MusicAnalysisConfiguration,
        cancellationEnabled: Bool
    ) throws -> [String: Double] {
        guard duration > 0 else {
            return [
                "boundary_f_0_5s": 0,
                "boundary_f_3_0s": 0,
                "pairwise_f": 0,
                "adjusted_rand_index": 0,
                "structural_coverage": 0,
                "evaluator_input_accepted": 0
            ]
        }

        let evaluator = AnalysisBenchmarkEvaluatorPolicy.diagnostics(
            referenceBeatCount: 0,
            estimatedBeatCount: 0,
            referenceChordCount: 0,
            estimatedChordCount: 0,
            referenceSectionCount: reference.count,
            estimatedSectionCount: estimated.count,
            duration: duration,
            configuration: configuration
        )
        guard evaluator.sectionInputsAccepted else {
            return [
                "boundary_f_0_5s": 0,
                "boundary_f_3_0s": 0,
                "pairwise_f": 0,
                "adjusted_rand_index": 0,
                "structural_coverage": 0,
                "reference_sections": Double(reference.count),
                "estimated_sections": Double(estimated.count),
                "evaluator_section_input_limit": Double(evaluator.sectionInputLimit),
                "evaluator_input_accepted": 0
            ]
        }

        let reference = try normalize(reference, duration: duration, cancellationEnabled: cancellationEnabled)
        let estimated = try normalize(estimated, duration: duration, cancellationEnabled: cancellationEnabled)
        let referenceBoundaries = internalBoundaries(reference, duration: duration)
        let estimatedBoundaries = internalBoundaries(estimated, duration: duration)

        var result: [String: Double] = [
            "reference_sections": Double(reference.count),
            "estimated_sections": Double(estimated.count),
            "evaluator_section_input_limit": Double(evaluator.sectionInputLimit),
            "evaluator_input_accepted": 1
        ]
        for tolerance in [0.5, 3.0] {
            let prf = try boundaryPRF(
                reference: referenceBoundaries,
                estimated: estimatedBoundaries,
                tolerance: tolerance,
                cancellationEnabled: cancellationEnabled
            )
            let suffix = tolerance == 0.5 ? "0_5s" : "3_0s"
            result["boundary_precision_\(suffix)"] = prf.precision
            result["boundary_recall_\(suffix)"] = prf.recall
            result["boundary_f_\(suffix)"] = prf.fMeasure
        }

        if let value = try medianNearestError(
            from: referenceBoundaries,
            to: estimatedBoundaries,
            cancellationEnabled: cancellationEnabled
        ) {
            result["median_reference_to_estimate_boundary_error_seconds"] = value
        }
        if let value = try medianNearestError(
            from: estimatedBoundaries,
            to: referenceBoundaries,
            cancellationEnabled: cancellationEnabled
        ) {
            result["median_estimate_to_reference_boundary_error_seconds"] = value
        }

        let sampled = try sampledLabels(
            reference: reference,
            estimated: estimated,
            duration: duration,
            cancellationEnabled: cancellationEnabled
        )
        let clustering = try clusteringMetrics(
            reference: sampled.referenceStructural,
            estimated: sampled.estimatedStructural,
            cancellationEnabled: cancellationEnabled
        )
        result["pairwise_precision"] = clustering.pairwisePrecision
        result["pairwise_recall"] = clustering.pairwiseRecall
        result["pairwise_f"] = clustering.pairwiseF
        result["adjusted_rand_index"] = clustering.adjustedRandIndex
        result["normalized_ref_given_est_entropy"] = clustering.normalizedReferenceGivenEstimateEntropy
        result["normalized_est_given_ref_entropy"] = clustering.normalizedEstimateGivenReferenceEntropy
        result["structural_coverage"] = sampled.structuralCoverage

        if let functional = try functionalMacroF1(
            reference: sampled.referenceFunctional,
            estimated: sampled.estimatedFunctional,
            cancellationEnabled: cancellationEnabled
        ) {
            result["functional_macro_f1"] = functional.f1
            result["functional_coverage"] = functional.coverage
        }
        if cancellationEnabled { try AnalysisCancellationPolicy.check() }
        return result
    }

    private static func boundaryPRF(
        reference: [Double],
        estimated: [Double],
        tolerance: Double,
        cancellationEnabled: Bool
    ) throws -> (precision: Double, recall: Double, fMeasure: Double) {
        if reference.isEmpty, estimated.isEmpty { return (1, 1, 1) }
        let matching = cancellationEnabled
            ? try BenchmarkTimelineMatcher.greedyNearestOneToOneCancellable(
                reference: reference,
                estimated: estimated,
                tolerance: tolerance
            )
            : BenchmarkTimelineMatcher.greedyNearestOneToOne(
                reference: reference,
                estimated: estimated,
                tolerance: tolerance
            )
        let precision = estimated.isEmpty ? 0 : Double(matching.matches) / Double(estimated.count)
        let recall = reference.isEmpty ? 0 : Double(matching.matches) / Double(reference.count)
        let fMeasure = precision + recall > 0 ? 2 * precision * recall / (precision + recall) : 0
        return (precision, recall, fMeasure)
    }

    private static func clusteringMetrics(
        reference: [String],
        estimated: [String],
        cancellationEnabled: Bool
    ) throws -> (
        pairwisePrecision: Double,
        pairwiseRecall: Double,
        pairwiseF: Double,
        adjustedRandIndex: Double,
        normalizedReferenceGivenEstimateEntropy: Double,
        normalizedEstimateGivenReferenceEntropy: Double
    ) {
        guard reference.count == estimated.count, reference.count >= 2 else {
            return (1, 1, 1, 1, 0, 0)
        }

        var referenceCounts: [String: Int] = [:]
        var estimatedCounts: [String: Int] = [:]
        var contingency: [String: Int] = [:]
        for index in reference.indices {
            if cancellationEnabled && index.isMultiple(of: 256) { try AnalysisCancellationPolicy.check() }
            referenceCounts[reference[index], default: 0] += 1
            estimatedCounts[estimated[index], default: 0] += 1
            contingency[reference[index] + "\u{1F}" + estimated[index], default: 0] += 1
        }

        let sameReference = referenceCounts.values.reduce(0.0) { $0 + choose2($1) }
        let sameEstimated = estimatedCounts.values.reduce(0.0) { $0 + choose2($1) }
        let sameBoth = contingency.values.reduce(0.0) { $0 + choose2($1) }
        let pairwisePrecision = sameEstimated > 0 ? sameBoth / sameEstimated : (sameReference == 0 ? 1 : 0)
        let pairwiseRecall = sameReference > 0 ? sameBoth / sameReference : 1
        let pairwiseF = pairwisePrecision + pairwiseRecall > 0
            ? 2 * pairwisePrecision * pairwiseRecall / (pairwisePrecision + pairwiseRecall)
            : 0

        let totalPairs = choose2(reference.count)
        let expected = totalPairs > 0 ? sameReference * sameEstimated / totalPairs : 0
        let maximum = 0.5 * (sameReference + sameEstimated)
        let denominator = maximum - expected
        let adjustedRandIndex: Double
        if abs(denominator) <= 1e-12 {
            adjustedRandIndex = abs(sameBoth - maximum) <= 1e-12 ? 1 : 0
        } else {
            adjustedRandIndex = (sameBoth - expected) / denominator
        }

        let total = Double(reference.count)
        let referenceEntropy = entropy(referenceCounts.values.map(Double.init), total: total)
        let estimatedEntropy = entropy(estimatedCounts.values.map(Double.init), total: total)
        let jointEntropy = entropy(contingency.values.map(Double.init), total: total)
        let referenceGivenEstimate = max(0, jointEntropy - estimatedEntropy)
        let estimateGivenReference = max(0, jointEntropy - referenceEntropy)
        return (
            pairwisePrecision,
            pairwiseRecall,
            pairwiseF,
            adjustedRandIndex,
            referenceEntropy > 1e-12 ? referenceGivenEstimate / referenceEntropy : 0,
            estimatedEntropy > 1e-12 ? estimateGivenReference / estimatedEntropy : 0
        )
    }

    private static func functionalMacroF1(
        reference: [String?],
        estimated: [String?],
        cancellationEnabled: Bool
    ) throws -> (f1: Double, coverage: Double)? {
        guard reference.count == estimated.count else { return nil }
        let labels = Set(reference.compactMap { $0 })
        guard !labels.isEmpty else { return nil }

        var f1Values: [Double] = []
        var referenceLabeled = 0
        var estimatedLabeledWhereReferenceExists = 0
        for index in reference.indices where reference[index] != nil {
            referenceLabeled += 1
            if estimated[index] != nil { estimatedLabeledWhereReferenceExists += 1 }
        }

        for (labelIteration, label) in labels.enumerated() {
            if cancellationEnabled && labelIteration.isMultiple(of: 8) { try AnalysisCancellationPolicy.check() }
            var truePositive = 0
            var falsePositive = 0
            var falseNegative = 0
            for index in reference.indices {
                let refMatches = reference[index] == label
                let estMatches = estimated[index] == label
                if refMatches && estMatches { truePositive += 1 }
                else if !refMatches && estMatches { falsePositive += 1 }
                else if refMatches && !estMatches { falseNegative += 1 }
            }
            let precision = truePositive + falsePositive > 0
                ? Double(truePositive) / Double(truePositive + falsePositive)
                : 0
            let recall = truePositive + falseNegative > 0
                ? Double(truePositive) / Double(truePositive + falseNegative)
                : 0
            f1Values.append(precision + recall > 0 ? 2 * precision * recall / (precision + recall) : 0)
        }
        return (
            f1Values.reduce(0, +) / Double(f1Values.count),
            referenceLabeled > 0 ? Double(estimatedLabeledWhereReferenceExists) / Double(referenceLabeled) : 1
        )
    }

    private static func sampledLabels(
        reference: [SongSection],
        estimated: [SongSection],
        duration: Double,
        cancellationEnabled: Bool
    ) throws -> (
        referenceStructural: [String],
        estimatedStructural: [String],
        referenceFunctional: [String?],
        estimatedFunctional: [String?],
        structuralCoverage: Double
    ) {
        let sampleCount = min(1_200, max(8, Int(ceil(duration / 0.25))))
        var referenceStructural: [String] = []
        var estimatedStructural: [String] = []
        var referenceFunctional: [String?] = []
        var estimatedFunctional: [String?] = []
        referenceStructural.reserveCapacity(sampleCount)
        estimatedStructural.reserveCapacity(sampleCount)
        referenceFunctional.reserveCapacity(sampleCount)
        estimatedFunctional.reserveCapacity(sampleCount)
        var decided = 0
        var referenceCursor = 0
        var estimatedCursor = 0

        for index in 0..<sampleCount {
            if cancellationEnabled && index.isMultiple(of: 256) { try AnalysisCancellationPolicy.check() }
            let time = (Double(index) + 0.5) * duration / Double(sampleCount)
            let referenceSection = advancingSection(at: time, in: reference, cursor: &referenceCursor)
            let estimatedSection = advancingSection(at: time, in: estimated, cursor: &estimatedCursor)
            referenceStructural.append(referenceSection?.structuralLabel ?? "X")
            estimatedStructural.append(estimatedSection?.structuralLabel ?? "X")
            referenceFunctional.append(referenceSection?.functionalLabel)
            estimatedFunctional.append(estimatedSection?.functionalLabel)
            if let estimatedSection, estimatedSection.structuralLabel != "X" { decided += 1 }
        }
        return (
            referenceStructural,
            estimatedStructural,
            referenceFunctional,
            estimatedFunctional,
            Double(decided) / Double(sampleCount)
        )
    }

    private static func normalize(
        _ sections: [SongSection],
        duration: Double,
        cancellationEnabled: Bool
    ) throws -> [SongSection] {
        var output: [SongSection] = []
        output.reserveCapacity(sections.count)
        for (iteration, section) in sections.enumerated() {
            if cancellationEnabled && iteration.isMultiple(of: 128) { try AnalysisCancellationPolicy.check() }
            guard section.startSeconds.isFinite, section.endSeconds.isFinite else { continue }
            let start = min(duration, max(0, section.startSeconds))
            let end = min(duration, max(start, section.endSeconds))
            guard end > start else { continue }
            output.append(SongSection(
                startSeconds: start,
                endSeconds: end,
                structuralLabel: section.structuralLabel,
                functionalLabel: section.functionalLabel,
                confidence: section.confidence
            ))
        }
        output.sort {
            if $0.startSeconds == $1.startSeconds { return $0.endSeconds < $1.endSeconds }
            return $0.startSeconds < $1.startSeconds
        }
        return output
    }

    private static func advancingSection(
        at time: Double,
        in sections: [SongSection],
        cursor: inout Int
    ) -> SongSection? {
        while cursor < sections.count, sections[cursor].endSeconds <= time { cursor += 1 }
        guard cursor < sections.count,
              time >= sections[cursor].startSeconds,
              time < sections[cursor].endSeconds else { return nil }
        return sections[cursor]
    }

    private static func internalBoundaries(_ sections: [SongSection], duration: Double) -> [Double] {
        Array(Set(sections.map(\.endSeconds).filter { $0 > 1e-9 && $0 < duration - 1e-9 })).sorted()
    }

    private static func medianNearestError(
        from source: [Double],
        to target: [Double],
        cancellationEnabled: Bool
    ) throws -> Double? {
        if source.isEmpty { return 0 }
        let errors = cancellationEnabled
            ? try BenchmarkTimelineMatcher.nearestAbsoluteErrorsCancellable(source: source, target: target)
            : BenchmarkTimelineMatcher.nearestAbsoluteErrors(source: source, target: target)
        guard let errors else { return nil }
        return median(errors.sorted())
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let middle = values.count / 2
        if values.count.isMultiple(of: 2) { return (values[middle - 1] + values[middle]) / 2 }
        return values[middle]
    }

    private static func choose2(_ value: Int) -> Double {
        guard value >= 2 else { return 0 }
        return Double(value) * Double(value - 1) / 2
    }

    private static func entropy(_ counts: [Double], total: Double) -> Double {
        guard total > 0 else { return 0 }
        return counts.reduce(0) { result, count in
            guard count > 0 else { return result }
            let probability = count / total
            return result - probability * log(probability)
        }
    }
}
