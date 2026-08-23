import Foundation

public enum SectionBenchmarkEvaluator {
    public static func evaluate(
        fixture: AnalysisBenchmarkFixture,
        reference: [SongSection],
        snapshot: AnalysisSnapshot,
        wallSeconds: Double,
        engine: String = "project-owned-dsp",
        engineVersion: String = "l4-m04-v1"
    ) -> AnalysisBenchmarkRow {
        let duration = fixture.signal.durationSeconds
        let parityEligible = !fixture.syntheticOnly
        let limitations = fixture.syntheticOnly ? ["SYNTHETIC_UNIT_ONLY_NOT_PARITY_EVIDENCE"] : []
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
            metrics: metrics(reference: reference, estimated: snapshot.sections, duration: duration),
            wallSeconds: wallSeconds,
            rtf: duration > 0 ? wallSeconds / duration : nil,
            peakRSSMB: nil,
            thermal: nil,
            knownLimitations: limitations
        )
    }

    public static func metrics(
        reference: [SongSection],
        estimated: [SongSection],
        duration: Double
    ) -> [String: Double] {
        guard duration > 0 else {
            return [
                "boundary_f_0_5s": 0,
                "boundary_f_3_0s": 0,
                "pairwise_f": 0,
                "adjusted_rand_index": 0,
                "structural_coverage": 0
            ]
        }

        let reference = normalize(reference, duration: duration)
        let estimated = normalize(estimated, duration: duration)
        let referenceBoundaries = internalBoundaries(reference, duration: duration)
        let estimatedBoundaries = internalBoundaries(estimated, duration: duration)

        var result: [String: Double] = [:]
        for tolerance in [0.5, 3.0] {
            let prf = boundaryPRF(
                reference: referenceBoundaries,
                estimated: estimatedBoundaries,
                tolerance: tolerance
            )
            let suffix = tolerance == 0.5 ? "0_5s" : "3_0s"
            result["boundary_precision_\(suffix)"] = prf.precision
            result["boundary_recall_\(suffix)"] = prf.recall
            result["boundary_f_\(suffix)"] = prf.fMeasure
        }

        if let value = medianNearestError(from: referenceBoundaries, to: estimatedBoundaries) {
            result["median_reference_to_estimate_boundary_error_seconds"] = value
        }
        if let value = medianNearestError(from: estimatedBoundaries, to: referenceBoundaries) {
            result["median_estimate_to_reference_boundary_error_seconds"] = value
        }

        let sampled = sampledLabels(reference: reference, estimated: estimated, duration: duration)
        let clustering = clusteringMetrics(reference: sampled.referenceStructural, estimated: sampled.estimatedStructural)
        result["pairwise_precision"] = clustering.pairwisePrecision
        result["pairwise_recall"] = clustering.pairwiseRecall
        result["pairwise_f"] = clustering.pairwiseF
        result["adjusted_rand_index"] = clustering.adjustedRandIndex
        result["normalized_ref_given_est_entropy"] = clustering.normalizedReferenceGivenEstimateEntropy
        result["normalized_est_given_ref_entropy"] = clustering.normalizedEstimateGivenReferenceEntropy
        result["structural_coverage"] = sampled.structuralCoverage
        result["reference_sections"] = Double(reference.count)
        result["estimated_sections"] = Double(estimated.count)

        if let functional = functionalMacroF1(
            reference: sampled.referenceFunctional,
            estimated: sampled.estimatedFunctional
        ) {
            result["functional_macro_f1"] = functional.f1
            result["functional_coverage"] = functional.coverage
        }
        return result
    }

    private static func boundaryPRF(
        reference: [Double],
        estimated: [Double],
        tolerance: Double
    ) -> (precision: Double, recall: Double, fMeasure: Double) {
        if reference.isEmpty, estimated.isEmpty { return (1, 1, 1) }
        var used = Array(repeating: false, count: reference.count)
        var matches = 0
        for estimate in estimated {
            var bestIndex: Int?
            var bestError = Double.infinity
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
        let fMeasure = precision + recall > 0 ? 2 * precision * recall / (precision + recall) : 0
        return (precision, recall, fMeasure)
    }

    private static func clusteringMetrics(
        reference: [String],
        estimated: [String]
    ) -> (
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
        estimated: [String?]
    ) -> (f1: Double, coverage: Double)? {
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

        for label in labels {
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
        duration: Double
    ) -> (
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
        var decided = 0

        for index in 0..<sampleCount {
            let time = (Double(index) + 0.5) * duration / Double(sampleCount)
            let referenceSection = section(at: time, in: reference)
            let estimatedSection = section(at: time, in: estimated)
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

    private static func normalize(_ sections: [SongSection], duration: Double) -> [SongSection] {
        sections.compactMap { section in
            let start = min(duration, max(0, section.startSeconds))
            let end = min(duration, max(start, section.endSeconds))
            guard end > start else { return nil }
            return SongSection(
                startSeconds: start,
                endSeconds: end,
                structuralLabel: section.structuralLabel,
                functionalLabel: section.functionalLabel,
                confidence: section.confidence
            )
        }.sorted {
            if $0.startSeconds == $1.startSeconds { return $0.endSeconds < $1.endSeconds }
            return $0.startSeconds < $1.startSeconds
        }
    }

    private static func section(at time: Double, in sections: [SongSection]) -> SongSection? {
        sections.first { time >= $0.startSeconds && time < $0.endSeconds }
    }

    private static func internalBoundaries(_ sections: [SongSection], duration: Double) -> [Double] {
        Array(Set(sections.map(\.endSeconds).filter { $0 > 1e-9 && $0 < duration - 1e-9 })).sorted()
    }

    private static func medianNearestError(from source: [Double], to target: [Double]) -> Double? {
        if source.isEmpty { return 0 }
        guard !target.isEmpty else { return nil }
        let values = source.map { item in target.map { abs($0 - item) }.min() ?? 0 }.sorted()
        return median(values)
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let middle = values.count / 2
        if values.count % 2 == 0 { return (values[middle - 1] + values[middle]) / 2 }
        return values[middle]
    }

    private static func choose2(_ value: Int) -> Double {
        guard value >= 2 else { return 0 }
        return Double(value * (value - 1)) / 2
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