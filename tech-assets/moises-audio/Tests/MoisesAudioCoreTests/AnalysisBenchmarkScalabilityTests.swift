import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisBenchmarkScalabilityTests: XCTestCase {
    func testScalableMatcherPreservesLegacyGreedySemanticsAcrossDeterministicCases() {
        var generator = LCG(state: 0x1234_5678)
        let tolerances = [0.0, 0.1, 0.5, 1.0]
        for _ in 0..<2_000 {
            let referenceCount = Int(generator.next() % 8)
            let estimatedCount = Int(generator.next() % 8)
            let tolerance = tolerances[Int(generator.next() % UInt64(tolerances.count))]
            var reference: [Double] = []
            var estimated: [Double] = []
            for _ in 0..<referenceCount {
                reference.append(Double(generator.next() % 11) / 2)
            }
            for _ in 0..<estimatedCount {
                estimated.append(Double(generator.next() % 11) / 2)
            }

            let legacy = legacyGreedyMatch(reference: reference, estimated: estimated, tolerance: tolerance)
            let scalable = BenchmarkTimelineMatcher.greedyNearestOneToOne(
                reference: reference,
                estimated: estimated,
                tolerance: tolerance
            )
            XCTAssertEqual(scalable.matches, legacy.matches)
            XCTAssertEqual(scalable.matchedAbsoluteErrors.count, legacy.errors.count)
            for (lhs, rhs) in zip(scalable.matchedAbsoluteErrors, legacy.errors) {
                XCTAssertEqual(lhs, rhs, accuracy: 1e-12)
            }
        }
    }

    func testAdversarialGreedyCaseDoesNotSilentlyBecomeMaximumCardinalityMatching() {
        let score = AnalysisBenchmarkRunner.beatFMeasure(
            reference: [0, 1],
            estimated: [1, 2],
            tolerance: 1
        )
        XCTAssertEqual(score, 0.5, accuracy: 1e-12)
    }

    func testLargeBeatAndBoundaryArraysRemainExact() {
        let beatCount = 20_000
        let reference = (0..<beatCount).map { Double($0) * 0.5 }
        let estimated = (0..<beatCount).map {
            Double($0) * 0.5 + ($0.isMultiple(of: 2) ? 0.02 : -0.02)
        }
        XCTAssertEqual(
            AnalysisBenchmarkRunner.beatFMeasure(reference: reference, estimated: estimated, tolerance: 0.07),
            1,
            accuracy: 1e-12
        )

        let sections = makeSections(boundaries: [0, 4, 7, 14], labels: ["A", "B", "C"])
        let shifted = makeSections(boundaries: [0, 7, 10, 14], labels: ["A", "B", "C"])
        let metrics = SectionBenchmarkEvaluator.metrics(reference: sections, estimated: shifted, duration: 14)
        XCTAssertEqual(metrics["boundary_f_3_0s"], 0.5, accuracy: 1e-12)
    }

    func testSectionEvaluatorCardinalityOverflowFailsClosed() {
        let duration = 10.0
        let sections = (0..<600).map { index in
            SongSection(
                startSeconds: Double(index) * duration / 600,
                endSeconds: Double(index + 1) * duration / 600,
                structuralLabel: "A",
                functionalLabel: nil,
                confidence: 0.9
            )
        }
        let metrics = SectionBenchmarkEvaluator.metrics(reference: sections, estimated: sections, duration: duration)
        XCTAssertEqual(metrics["evaluator_input_accepted"], 0)
        XCTAssertEqual(metrics["boundary_f_3_0s"], 0)
        XCTAssertEqual(metrics["evaluator_section_input_limit"], 512)
    }

    func testSupplementalMetricsExposeW14AndW15Diagnostics() {
        let snapshot = AnalysisSnapshot(
            tempo: TempoAnalysis(bpm: 120, confidence: 0.8, beatTimesSeconds: [0, 0.5, 1]),
            key: nil,
            chords: [ChordEvent(startSeconds: 0, endSeconds: 2, normalizedLabel: "C", confidence: 0.9)],
            sections: [SongSection(startSeconds: 0, endSeconds: 2, structuralLabel: "A", functionalLabel: nil, confidence: 0.8)]
        )
        let cardinality = AnalysisBenchmarkSupplementalMetrics.snapshotCardinality(snapshot: snapshot, duration: 2)
        XCTAssertEqual(cardinality["w15_snapshot_beat_input_count"], 3)
        XCTAssertEqual(cardinality["w15_snapshot_chord_input_count"], 1)
        XCTAssertEqual(cardinality["w15_snapshot_section_input_count"], 1)

        let before = [
            SongSection(startSeconds: 0, endSeconds: 1, structuralLabel: "A", functionalLabel: nil, confidence: 0.7),
            SongSection(startSeconds: 1, endSeconds: 2, structuralLabel: "B", functionalLabel: nil, confidence: 0.7)
        ]
        let boundary = AnalysisBenchmarkSupplementalMetrics.sectionBoundary(
            before: before,
            after: snapshot.sections,
            duration: 2
        )
        XCTAssertEqual(boundary["w14_boundary_input_section_count"], 2)
        XCTAssertEqual(boundary["w14_boundary_output_section_count"], 1)
        XCTAssertEqual(boundary["w14_boundary_removed_count"], 1)
    }

    func testPrecancelledScalableBeatEvaluationThrowsCancellationError() async {
        let count = 100_000
        let reference = (0..<count).map { Double($0) * 0.5 }
        let estimated = reference.map { $0 + 0.01 }
        let task = Task.detached {
            try AnalysisBenchmarkRunner.beatFMeasureCancellable(
                reference: reference,
                estimated: estimated,
                tolerance: 0.07
            )
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testProductAlignedRunnerAttachesW14W15AndW16EvidenceMetrics() async throws {
        let signal = makeBenchmarkSignal(duration: 8)
        let sha = String(repeating: "a", count: 64)
        let item = AnalysisRealAudioBenchmarkCase(
            fixtureID: "w16-product-aligned-synthetic",
            projectID: UUID(),
            assetID: UUID(),
            relativePath: "bench/w16.wav",
            genre: "synthetic-regression",
            sourceKind: .syntheticTest,
            expectedDurationSeconds: signal.durationSeconds,
            rights: AnalysisRightsEvidence(
                grantID: "w16-test-grant",
                rightsClass: .projectOwned,
                permittedUses: [.analysisBenchmark],
                sourceSHA256: sha
            ),
            reference: AnalysisReferenceAnnotation(
                bpm: 120,
                beatTimesSeconds: stride(from: 0.0, to: 8.0, by: 0.5).map { $0 },
                sections: [SongSection(
                    startSeconds: 0,
                    endSeconds: 8,
                    structuralLabel: "A",
                    functionalLabel: nil,
                    confidence: 1
                )]
            )
        )
        let report = try await AnalysisRealAudioBenchmarkRunner.runProductAligned(
            manifest: AnalysisRealAudioBenchmarkManifest(
                manifestID: "w16-product-aligned",
                createdAt: Date(timeIntervalSince1970: 1),
                cases: [item]
            ),
            loader: BenchmarkMemoryLoader(signal: signal, sha: sha),
            runDate: Date(timeIntervalSince1970: 2)
        )

        XCTAssertFalse(report.parityEligible)
        XCTAssertFalse(report.rows.isEmpty)
        XCTAssertTrue(report.rows.allSatisfy { $0.metrics["w16_product_pipeline"] == 1 })
        XCTAssertTrue(report.rows.allSatisfy { $0.metrics["w16_scalable_evaluator"] == 1 })
        XCTAssertTrue(report.rows.allSatisfy { $0.metrics["w15_snapshot_chord_input_limit"] != nil })
        let structure = try XCTUnwrap(report.rows.first { $0.domain == "structure" })
        XCTAssertNotNil(structure.metrics["w14_boundary_input_section_count"])
        XCTAssertNotNil(structure.metrics["w14_boundary_output_section_count"])
    }
}

private struct BenchmarkMemoryLoader: AnalysisBenchmarkSignalLoading {
    let signal: AnalysisSignal
    let sha: String
    func loadBenchmarkSignal(projectID: ProjectID, asset: LocalAudioAsset) async throws -> AnalysisBenchmarkLoadedSignal {
        AnalysisBenchmarkLoadedSignal(signal: signal, sourceSHA256: sha)
    }
}

private struct LCG {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = 6_364_136_223_846_793_005 &* state &+ 1
        return state
    }
}

private func legacyGreedyMatch(
    reference: [Double],
    estimated: [Double],
    tolerance: Double
) -> (matches: Int, errors: [Double]) {
    let reference = reference.filter(\.isFinite).sorted()
    let estimated = estimated.filter(\.isFinite).sorted()
    var used = Array(repeating: false, count: reference.count)
    var errors: [Double] = []
    for estimate in estimated {
        var bestIndex: Int?
        var bestError = Double.greatestFiniteMagnitude
        for index in reference.indices where !used[index] {
            let error = abs(reference[index] - estimate)
            if error <= tolerance, error < bestError {
                bestIndex = index
                bestError = error
            }
        }
        if let bestIndex {
            used[bestIndex] = true
            errors.append(bestError)
        }
    }
    return (errors.count, errors)
}

private func makeSections(boundaries: [Double], labels: [String]) -> [SongSection] {
    guard boundaries.count == labels.count + 1 else { return [] }
    return labels.indices.map { index in
        SongSection(
            startSeconds: boundaries[index],
            endSeconds: boundaries[index + 1],
            structuralLabel: labels[index],
            functionalLabel: nil,
            confidence: 0.8
        )
    }
}

private func makeBenchmarkSignal(duration: Double) -> AnalysisSignal {
    let sampleRate = 8_000.0
    let count = Int(sampleRate * duration)
    var samples = Array(repeating: Float(0), count: count)
    for index in 0..<count {
        let time = Double(index) / sampleRate
        var value = 0.12 * sin(2 * Double.pi * 261.6256 * time)
            + 0.10 * sin(2 * Double.pi * 329.6276 * time)
            + 0.10 * sin(2 * Double.pi * 391.9954 * time)
        let phase = time.truncatingRemainder(dividingBy: 0.5)
        if phase < 0.015 { value += 0.6 * (1 - phase / 0.015) }
        samples[index] = Float(max(-1, min(1, value)))
    }
    return AnalysisSignal(sampleRate: sampleRate, monoSamples: samples)
}
