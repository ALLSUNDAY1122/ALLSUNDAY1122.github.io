import Foundation

public struct AnalysisBenchmarkEvaluatorDiagnostics: Codable, Equatable, Sendable {
    public let referenceBeatCount: Int
    public let estimatedBeatCount: Int
    public let beatInputLimit: Int
    public let referenceChordCount: Int
    public let estimatedChordCount: Int
    public let chordInputLimit: Int
    public let referenceSectionCount: Int
    public let estimatedSectionCount: Int
    public let sectionInputLimit: Int
    public let beatInputsAccepted: Bool
    public let chordInputsAccepted: Bool
    public let sectionInputsAccepted: Bool

    enum CodingKeys: String, CodingKey {
        case referenceBeatCount = "reference_beat_count"
        case estimatedBeatCount = "estimated_beat_count"
        case beatInputLimit = "beat_input_limit"
        case referenceChordCount = "reference_chord_count"
        case estimatedChordCount = "estimated_chord_count"
        case chordInputLimit = "chord_input_limit"
        case referenceSectionCount = "reference_section_count"
        case estimatedSectionCount = "estimated_section_count"
        case sectionInputLimit = "section_input_limit"
        case beatInputsAccepted = "beat_inputs_accepted"
        case chordInputsAccepted = "chord_inputs_accepted"
        case sectionInputsAccepted = "section_inputs_accepted"
    }
}

public enum AnalysisBenchmarkEvaluatorPolicy {
    public static func diagnostics(
        referenceBeatCount: Int,
        estimatedBeatCount: Int,
        referenceChordCount: Int,
        estimatedChordCount: Int,
        referenceSectionCount: Int,
        estimatedSectionCount: Int,
        duration: Double,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> AnalysisBenchmarkEvaluatorDiagnostics {
        let beatLimit = AnalysisSnapshotCardinalityPolicy.beatInputLimit(
            duration: duration,
            configuration: configuration
        )
        let chordLimit = AnalysisSnapshotCardinalityPolicy.chordInputLimit(
            duration: duration,
            configuration: configuration
        )
        let sectionLimit = AnalysisSnapshotCardinalityPolicy.sectionInputLimit(
            duration: duration,
            configuration: configuration
        )
        return AnalysisBenchmarkEvaluatorDiagnostics(
            referenceBeatCount: max(0, referenceBeatCount),
            estimatedBeatCount: max(0, estimatedBeatCount),
            beatInputLimit: beatLimit,
            referenceChordCount: max(0, referenceChordCount),
            estimatedChordCount: max(0, estimatedChordCount),
            chordInputLimit: chordLimit,
            referenceSectionCount: max(0, referenceSectionCount),
            estimatedSectionCount: max(0, estimatedSectionCount),
            sectionInputLimit: sectionLimit,
            beatInputsAccepted: referenceBeatCount <= beatLimit && estimatedBeatCount <= beatLimit,
            chordInputsAccepted: referenceChordCount <= chordLimit && estimatedChordCount <= chordLimit,
            sectionInputsAccepted: referenceSectionCount <= sectionLimit && estimatedSectionCount <= sectionLimit
        )
    }
}

public enum AnalysisBenchmarkSupplementalMetrics {
    public static func snapshotCardinality(
        snapshot: AnalysisSnapshot,
        duration: Double,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> [String: Double] {
        let d = AnalysisSnapshotCardinalityPolicy.diagnostics(
            snapshot: snapshot,
            duration: duration,
            configuration: configuration
        )
        return [
            "w15_snapshot_beat_input_count": Double(d.beatInputCount),
            "w15_snapshot_beat_input_limit": Double(d.beatInputLimit),
            "w15_snapshot_chord_input_count": Double(d.chordInputCount),
            "w15_snapshot_chord_input_limit": Double(d.chordInputLimit),
            "w15_snapshot_section_input_count": Double(d.sectionInputCount),
            "w15_snapshot_section_input_limit": Double(d.sectionInputLimit),
            "w15_snapshot_tempo_cardinality_accepted": d.tempoCardinalityAccepted ? 1 : 0,
            "w15_snapshot_chord_cardinality_accepted": d.chordCardinalityAccepted ? 1 : 0,
            "w15_snapshot_section_cardinality_accepted": d.sectionCardinalityAccepted ? 1 : 0
        ]
    }

    public static func sectionBoundary(
        before: [SongSection],
        after: [SongSection],
        duration: Double,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) -> [String: Double] {
        let d = SongSectionBoundaryHardener.diagnostics(
            before: before,
            after: after,
            duration: duration,
            configuration: configuration
        )
        return [
            "w14_boundary_input_section_count": Double(d.inputSectionCount),
            "w14_boundary_output_section_count": Double(d.outputSectionCount),
            "w14_boundary_removed_count": Double(d.removedBoundaryCount),
            "w14_boundary_preferred_spacing_seconds": d.preferredStructuralSpacingSeconds,
            "w14_boundary_input_short_fragment_count": Double(d.inputShortFragmentCount),
            "w14_boundary_output_short_fragment_count": Double(d.outputShortFragmentCount),
            "w14_boundary_input_density_per_minute": d.inputBoundaryDensityPerMinute,
            "w14_boundary_output_density_per_minute": d.outputBoundaryDensityPerMinute,
            "w14_boundary_input_median_section_seconds": d.inputMedianSectionSeconds,
            "w14_boundary_output_median_section_seconds": d.outputMedianSectionSeconds
        ]
    }
}

struct BenchmarkTimestampMatchResult: Equatable, Sendable {
    let matches: Int
    let matchedAbsoluteErrors: [Double]
}

enum BenchmarkTimelineMatcher {
    static func greedyNearestOneToOne(
        reference: [Double],
        estimated: [Double],
        tolerance: Double
    ) -> BenchmarkTimestampMatchResult {
        try! greedyNearestOneToOne(
            reference: reference,
            estimated: estimated,
            tolerance: tolerance,
            cancellationEnabled: false
        )
    }

    static func greedyNearestOneToOneCancellable(
        reference: [Double],
        estimated: [Double],
        tolerance: Double
    ) throws -> BenchmarkTimestampMatchResult {
        try greedyNearestOneToOne(
            reference: reference,
            estimated: estimated,
            tolerance: tolerance,
            cancellationEnabled: true
        )
    }

    static func nearestAbsoluteErrors(source: [Double], target: [Double]) -> [Double]? {
        try! nearestAbsoluteErrors(source: source, target: target, cancellationEnabled: false)
    }

    static func nearestAbsoluteErrorsCancellable(source: [Double], target: [Double]) throws -> [Double]? {
        try nearestAbsoluteErrors(source: source, target: target, cancellationEnabled: true)
    }

    private static func greedyNearestOneToOne(
        reference: [Double],
        estimated: [Double],
        tolerance: Double,
        cancellationEnabled: Bool
    ) throws -> BenchmarkTimestampMatchResult {
        if cancellationEnabled { try AnalysisCancellationPolicy.check() }
        guard tolerance >= 0 else { return .init(matches: 0, matchedAbsoluteErrors: []) }
        let reference = reference.filter(\.isFinite).sorted()
        let estimated = estimated.filter(\.isFinite).sorted()
        if cancellationEnabled { try AnalysisCancellationPolicy.check() }
        guard !reference.isEmpty, !estimated.isEmpty else {
            return .init(matches: 0, matchedAbsoluteErrors: [])
        }

        var availability = Availability(count: reference.count)
        var errors: [Double] = []
        errors.reserveCapacity(min(reference.count, estimated.count))

        for (iteration, estimate) in estimated.enumerated() {
            if cancellationEnabled && iteration.isMultiple(of: 256) {
                try AnalysisCancellationPolicy.check()
            }
            let successor = availability.nextAvailable(from: lowerBound(reference, estimate))
            let predecessor = availability.previousAvailable(from: upperBound(reference, estimate) - 1)
            var chosen: Int?
            var bestError = Double.greatestFiniteMagnitude

            if predecessor >= 0 {
                let error = abs(reference[predecessor] - estimate)
                if error <= tolerance {
                    chosen = predecessor
                    bestError = error
                }
            }
            if successor < reference.count {
                let error = abs(reference[successor] - estimate)
                if error <= tolerance,
                   error < bestError || (error == bestError && (chosen == nil || successor < chosen!)) {
                    chosen = successor
                    bestError = error
                }
            }
            if let chosen {
                availability.remove(chosen)
                errors.append(bestError)
            }
        }
        if cancellationEnabled { try AnalysisCancellationPolicy.check() }
        return .init(matches: errors.count, matchedAbsoluteErrors: errors)
    }

    private static func nearestAbsoluteErrors(
        source: [Double],
        target: [Double],
        cancellationEnabled: Bool
    ) throws -> [Double]? {
        if cancellationEnabled { try AnalysisCancellationPolicy.check() }
        let source = source.filter(\.isFinite)
        let target = target.filter(\.isFinite).sorted()
        if cancellationEnabled { try AnalysisCancellationPolicy.check() }
        if source.isEmpty { return [] }
        guard !target.isEmpty else { return nil }

        var errors: [Double] = []
        errors.reserveCapacity(source.count)
        for (iteration, value) in source.enumerated() {
            if cancellationEnabled && iteration.isMultiple(of: 256) {
                try AnalysisCancellationPolicy.check()
            }
            let insertion = lowerBound(target, value)
            var best = Double.greatestFiniteMagnitude
            if insertion < target.count { best = min(best, abs(target[insertion] - value)) }
            if insertion > 0 { best = min(best, abs(target[insertion - 1] - value)) }
            errors.append(best)
        }
        if cancellationEnabled { try AnalysisCancellationPolicy.check() }
        return errors
    }

    private static func lowerBound(_ values: [Double], _ value: Double) -> Int {
        var low = 0
        var high = values.count
        while low < high {
            let middle = (low + high) / 2
            if values[middle] < value { low = middle + 1 } else { high = middle }
        }
        return low
    }

    private static func upperBound(_ values: [Double], _ value: Double) -> Int {
        var low = 0
        var high = values.count
        while low < high {
            let middle = (low + high) / 2
            if values[middle] <= value { low = middle + 1 } else { high = middle }
        }
        return low
    }

    private struct Availability {
        var nextParent: [Int]
        var previousParent: [Int]
        let count: Int

        init(count: Int) {
            self.count = count
            self.nextParent = Array(0...count)
            self.previousParent = Array(0...count)
        }

        mutating func nextAvailable(from index: Int) -> Int {
            findNext(min(count, max(0, index)))
        }

        mutating func previousAvailable(from index: Int) -> Int {
            guard index >= 0 else { return -1 }
            return findPrevious(min(count, index + 1)) - 1
        }

        mutating func remove(_ index: Int) {
            nextParent[index] = findNext(index + 1)
            previousParent[index + 1] = findPrevious(index)
        }

        mutating func findNext(_ value: Int) -> Int {
            var node = value
            while nextParent[node] != node { node = nextParent[node] }
            let root = node
            node = value
            while nextParent[node] != node {
                let next = nextParent[node]
                nextParent[node] = root
                node = next
            }
            return root
        }

        mutating func findPrevious(_ value: Int) -> Int {
            var node = value
            while previousParent[node] != node { node = previousParent[node] }
            let root = node
            node = value
            while previousParent[node] != node {
                let next = previousParent[node]
                previousParent[node] = root
                node = next
            }
            return root
        }
    }
}
