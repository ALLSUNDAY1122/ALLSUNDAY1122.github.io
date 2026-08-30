import Foundation

extension AnalysisPhysicalRealAudioCorpusAssembler {
    static func buildAuditedReport(
        manifest: AnalysisRealAudioBenchmarkManifest,
        runtime: AnalysisPhysicalRealAudioRuntimeBinding,
        receipts: [AnalysisPhysicalRealAudioFixtureExecutionReceipt],
        configuration: MusicAnalysisConfiguration,
        generatedAt: Date
    ) throws -> AnalysisAuditedRealAudioBenchmarkReport {
        var receiptByFixture: [String: AnalysisPhysicalRealAudioFixtureExecutionReceipt] = [:]
        for receipt in receipts where receiptByFixture[receipt.fixtureID] == nil {
            receiptByFixture[receipt.fixtureID] = receipt
        }
        var rows: [AnalysisBenchmarkRow] = []
        for item in manifest.cases {
            try AnalysisCancellationPolicy.check()
            guard let receipt = receiptByFixture[item.fixtureID],
                  let data = receipt.workloadReceipt.snapshotCanonicalJSON,
                  let snapshot = try? JSONDecoder().decode(AnalysisSnapshot.self, from: data) else {
                throw AnalysisPhysicalRealAudioCorpusExecutionError.canonicalEncodingFailed
            }
            let wallSeconds = max(0, receipt.workloadReceipt.stages.last?.endedOffsetSeconds ?? 0)
            rows.append(contentsOf: try evaluateRows(
                item: item,
                snapshot: snapshot,
                wallSeconds: wallSeconds,
                engine: runtime.engine,
                engineVersion: runtime.engineVersion,
                configuration: configuration
            ))
        }
        rows.sort {
            if $0.fixtureID != $1.fixtureID { return $0.fixtureID < $1.fixtureID }
            return $0.domain < $1.domain
        }
        let rejected = AnalysisBenchmarkAggregation.evaluatorRejectedRows(rows: rows)
        return AnalysisAuditedRealAudioBenchmarkReport(
            manifestID: manifest.manifestID,
            generatedAt: generatedAt,
            engine: runtime.engine,
            engineVersion: runtime.engineVersion,
            parityEligible: !rows.isEmpty && rows.allSatisfy(\.parityEligible) && rejected.isEmpty,
            rows: rows,
            domainQualitySummaries: AnalysisBenchmarkAggregation.domainSummaries(rows: rows),
            genreQualitySummaries: AnalysisBenchmarkAggregation.genreSummaries(rows: rows),
            evaluatorRejectedRows: rejected,
            nonParityRows: AnalysisBenchmarkAggregation.nonParityRows(rows: rows),
            excludedContextMetricNames: AnalysisBenchmarkAggregation.excludedContextMetricNames(rows: rows),
            validationIssues: []
        )
    }

    static func evaluateRows(
        item: AnalysisRealAudioBenchmarkCase,
        snapshot: AnalysisSnapshot,
        wallSeconds: Double,
        engine: String,
        engineVersion: String,
        configuration: MusicAnalysisConfiguration
    ) throws -> [AnalysisBenchmarkRow] {
        let duration = item.expectedDurationSeconds
        let rtf = duration > 0 ? wallSeconds / duration : nil
        let realEligible = item.sourceKind == .realAudio
        let provenance = ["W47_PROJECT_ROW_REBUILT_FROM_RETAINED_PHYSICAL_EXECUTION_SNAPSHOT_PENDING_HQ_ATTESTATION"]
        var rows: [AnalysisBenchmarkRow] = []
        let estimatedBeats = snapshot.tempo?.beatTimesSeconds ?? []
        let evaluator = AnalysisBenchmarkEvaluatorPolicy.diagnostics(
            referenceBeatCount: item.reference.beatTimesSeconds.count,
            estimatedBeatCount: estimatedBeats.count,
            referenceChordCount: item.reference.chords.count,
            estimatedChordCount: snapshot.chords.count,
            referenceSectionCount: item.reference.sections.count,
            estimatedSectionCount: snapshot.sections.count,
            duration: duration,
            configuration: configuration
        )

        if let referenceBPM = item.reference.bpm {
            var metrics: [String: Double] = [:]
            if let predicted = snapshot.tempo?.bpm, predicted.isFinite, referenceBPM > 0 {
                let relativeError = abs(predicted - referenceBPM) / referenceBPM
                metrics["decision_emitted"] = 1
                metrics["tempo_rel_error"] = relativeError
                metrics["exact_within_4pct"] = relativeError <= 0.04 ? 1 : 0
                let ratios = [predicted / referenceBPM, predicted / (referenceBPM * 0.5), predicted / (referenceBPM * 2)]
                metrics["octave_aware_within_4pct"] = ratios.contains { abs($0 - 1) <= 0.04 } ? 1 : 0
                metrics["predicted_bpm"] = predicted
                if let confidence = snapshot.tempo?.confidence, confidence.isFinite { metrics["confidence"] = confidence }
            } else {
                metrics["decision_emitted"] = 0
            }
            rows.append(row(item: item, domain: "tempo", metrics: metrics, parityEligible: realEligible, wallSeconds: wallSeconds, rtf: rtf, engine: engine, engineVersion: engineVersion, limitations: provenance))
        }

        if !item.reference.beatTimesSeconds.isEmpty {
            var metrics: [String: Double] = [
                "reference_beats": Double(item.reference.beatTimesSeconds.count),
                "estimated_beats": Double(estimatedBeats.count),
                "evaluator_beat_input_limit": Double(evaluator.beatInputLimit),
                "evaluator_input_accepted": evaluator.beatInputsAccepted ? 1 : 0
            ]
            if evaluator.beatInputsAccepted {
                metrics["beat_f_70ms"] = try AnalysisBenchmarkRunner.beatFMeasureCancellable(
                    reference: item.reference.beatTimesSeconds,
                    estimated: estimatedBeats,
                    tolerance: 0.070
                )
                if let errors = try BenchmarkTimelineMatcher.nearestAbsoluteErrorsCancellable(
                    source: item.reference.beatTimesSeconds,
                    target: estimatedBeats
                ), let value = median(errors) {
                    metrics["median_abs_error_seconds"] = value
                }
            }
            rows.append(row(item: item, domain: "beat", metrics: metrics, parityEligible: realEligible && evaluator.beatInputsAccepted, wallSeconds: wallSeconds, rtf: rtf, engine: engine, engineVersion: engineVersion, limitations: provenance))
        }

        if let referenceKey = item.reference.key {
            var metrics: [String: Double] = [:]
            if let predicted = snapshot.key {
                metrics["decision_emitted"] = 1
                metrics["exact_key_accuracy"] = (predicted.tonicPitchClass == referenceKey.tonicPitchClass && predicted.mode == referenceKey.mode) ? 1 : 0
                metrics["tonic_accuracy"] = predicted.tonicPitchClass == referenceKey.tonicPitchClass ? 1 : 0
                metrics["mode_accuracy"] = predicted.mode == referenceKey.mode ? 1 : 0
                metrics["weighted_key_score"] = AnalysisBenchmarkRunner.weightedKeyScore(reference: referenceKey, estimated: predicted)
                if let confidence = predicted.confidence, confidence.isFinite { metrics["confidence"] = confidence }
            } else {
                metrics["decision_emitted"] = 0
            }
            rows.append(row(item: item, domain: "key", metrics: metrics, parityEligible: realEligible, wallSeconds: wallSeconds, rtf: rtf, engine: engine, engineVersion: engineVersion, limitations: provenance))
        }

        if !item.reference.chords.isEmpty {
            var metrics: [String: Double] = [
                "evaluator_chord_input_limit": Double(evaluator.chordInputLimit),
                "evaluator_input_accepted": evaluator.chordInputsAccepted ? 1 : 0
            ]
            if evaluator.chordInputsAccepted {
                metrics.merge(try AnalysisBenchmarkRunner.chordMetricsCancellable(
                    reference: item.reference.chords,
                    estimated: snapshot.chords,
                    duration: duration
                )) { _, new in new }
            } else {
                metrics["reference_events"] = Double(item.reference.chords.count)
                metrics["estimated_events"] = Double(snapshot.chords.count)
            }
            rows.append(row(item: item, domain: "chord", metrics: metrics, parityEligible: realEligible && evaluator.chordInputsAccepted, wallSeconds: wallSeconds, rtf: rtf, engine: engine, engineVersion: engineVersion, limitations: provenance))
        }

        if !item.reference.sections.isEmpty {
            var metrics = try SectionBenchmarkEvaluator.metricsCancellable(
                reference: item.reference.sections,
                estimated: snapshot.sections,
                duration: duration,
                configuration: configuration
            )
            metrics["evaluator_section_input_limit"] = Double(evaluator.sectionInputLimit)
            metrics["evaluator_input_accepted"] = evaluator.sectionInputsAccepted ? 1 : 0
            rows.append(row(item: item, domain: "structure", metrics: metrics, parityEligible: realEligible && evaluator.sectionInputsAccepted, wallSeconds: wallSeconds, rtf: rtf, engine: engine, engineVersion: engineVersion, limitations: provenance))
        }
        return rows
    }

    static func row(
        item: AnalysisRealAudioBenchmarkCase,
        domain: String,
        metrics: [String: Double],
        parityEligible: Bool,
        wallSeconds: Double,
        rtf: Double?,
        engine: String,
        engineVersion: String,
        limitations: [String]
    ) -> AnalysisBenchmarkRow {
        AnalysisBenchmarkRow(
            fixtureID: item.fixtureID,
            rightsClass: item.rights.rightsClass,
            genre: item.genre,
            durationSeconds: item.expectedDurationSeconds,
            syntheticOnly: item.sourceKind != .realAudio,
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
