import Foundation

public extension AnalysisRealAudioBenchmarkRunner {
    /// Canonical Lane-4 differential evaluation path after W16.
    ///
    /// Unlike the legacy compatibility runner, this executes the same bounded,
    /// cancellable Analysis stages used by `ProjectOwnedMusicAnalyzer`, then
    /// evaluates the hardened snapshot with scalable/cancellable metrics.
    /// Rights validation remains mandatory and synthetic cases remain
    /// ineligible for PARITY evidence.
    static func runProductAligned(
        manifest: AnalysisRealAudioBenchmarkManifest,
        loader: any AnalysisBenchmarkSignalLoading,
        configuration: MusicAnalysisConfiguration = .productBaseline,
        engine: String = "project-owned-dsp",
        engineVersion: String = "lane4-autonomous-w16",
        runDate: Date = Date()
    ) async throws -> AnalysisRealAudioBenchmarkReport {
        try AnalysisCancellationPolicy.check()
        let validationIssues = AnalysisRealAudioManifestValidator.validate(manifest, at: runDate)
        guard validationIssues.isEmpty else {
            throw AnalysisRealAudioBenchmarkError.invalidManifest(validationIssues)
        }

        var rows: [AnalysisBenchmarkRow] = []
        var allCasesParityEligible = true
        for (caseIndex, item) in manifest.cases.enumerated() {
            try AnalysisCancellationPolicy.checkIfNeeded(
                enabled: true,
                iteration: caseIndex,
                stride: 1
            )
            let asset = LocalAudioAsset(
                id: AssetID(rawValue: item.assetID),
                relativePath: item.relativePath,
                mediaKind: .audio,
                durationSeconds: item.expectedDurationSeconds
            )
            let loaded = try await loader.loadBenchmarkSignal(
                projectID: ProjectID(rawValue: item.projectID),
                asset: asset
            )
            try AnalysisCancellationPolicy.check()

            guard loaded.sourceSHA256.caseInsensitiveCompare(item.rights.sourceSHA256) == .orderedSame else {
                throw AnalysisRealAudioBenchmarkError.sourceChecksumMismatch(
                    fixtureID: item.fixtureID,
                    expected: item.rights.sourceSHA256,
                    actual: loaded.sourceSHA256
                )
            }
            let sourceSignal = loaded.signal
            let tolerance = max(0.050, item.expectedDurationSeconds * 0.001)
            guard abs(sourceSignal.durationSeconds - item.expectedDurationSeconds) <= tolerance else {
                throw AnalysisRealAudioBenchmarkError.durationMismatch(
                    fixtureID: item.fixtureID,
                    expected: item.expectedDurationSeconds,
                    actual: sourceSignal.durationSeconds
                )
            }
            for (sampleIndex, sample) in sourceSignal.monoSamples.enumerated() {
                try AnalysisCancellationPolicy.checkIfNeeded(
                    enabled: true,
                    iteration: sampleIndex,
                    stride: 8_192
                )
                guard sample.isFinite else {
                    throw AnalysisRealAudioBenchmarkError.nonFiniteSignal(fixtureID: item.fixtureID)
                }
            }

            let startedAt = Date()
            let prepared = try AnalysisWorkingSetPolicy.prepareCancellable(signal: sourceSignal)
            let signal = prepared.signal
            try AnalysisCancellationPolicy.check()
            let tempo = try BoundedTempoBeatAnalyzer.analyzeCancellable(
                signal: signal,
                configuration: configuration
            )
            try AnalysisCancellationPolicy.check()
            let key = try BoundedMusicalKeyAnalyzer.analyzeCancellable(
                signal: signal,
                configuration: configuration
            )
            try AnalysisCancellationPolicy.check()
            let chords = try BoundedChordTimelineAnalyzer.analyzeCancellable(
                signal: signal,
                configuration: configuration
            )
            try AnalysisCancellationPolicy.check()
            let detectedSections = try CancellableSongSectionPipeline.analyze(
                signal: signal,
                chords: chords,
                configuration: configuration
            )
            try AnalysisCancellationPolicy.check()
            let sections = try SongSectionBoundaryHardener.harden(
                sections: detectedSections,
                signal: signal,
                chords: chords,
                configuration: configuration
            )
            try AnalysisCancellationPolicy.check()

            let rawSnapshot = AnalysisSnapshot(
                tempo: tempo,
                key: key,
                chords: chords,
                sections: sections
            )
            let snapshotCardinality = AnalysisBenchmarkSupplementalMetrics.snapshotCardinality(
                snapshot: rawSnapshot,
                duration: signal.durationSeconds,
                configuration: configuration
            )
            let snapshot = try AnalysisSnapshotRobustness.hardenCancellable(
                snapshot: rawSnapshot,
                duration: signal.durationSeconds,
                configuration: configuration
            )
            try AnalysisCancellationPolicy.check()
            let wallSeconds = max(0, Date().timeIntervalSince(startedAt))

            let parityEligible = AnalysisRealAudioManifestValidator.isParityEligible(item, at: runDate)
            allCasesParityEligible = allCasesParityEligible && parityEligible
            let fixture = AnalysisBenchmarkFixture(
                fixtureID: item.fixtureID,
                rightsClass: item.rights.rightsClass,
                genre: item.genre,
                syntheticOnly: item.sourceKind != .realAudio,
                signal: signal,
                reference: TempoBeatKeyReference(
                    bpm: item.reference.bpm,
                    beatTimesSeconds: item.reference.beatTimesSeconds,
                    key: item.reference.key,
                    chords: item.reference.chords
                )
            )

            var commonMetrics = snapshotCardinality
            commonMetrics["w16_product_pipeline"] = 1
            commonMetrics["w16_scalable_evaluator"] = 1
            rows.append(contentsOf: try AnalysisBenchmarkRunner.evaluateCancellable(
                fixture: fixture,
                snapshot: snapshot,
                wallSeconds: wallSeconds,
                engine: engine,
                engineVersion: engineVersion,
                configuration: configuration,
                supplementalMetrics: commonMetrics
            ))

            if !item.reference.sections.isEmpty {
                var structureMetrics = commonMetrics
                structureMetrics.merge(
                    AnalysisBenchmarkSupplementalMetrics.sectionBoundary(
                        before: detectedSections,
                        after: sections,
                        duration: signal.durationSeconds,
                        configuration: configuration
                    )
                ) { _, new in new }
                rows.append(try SectionBenchmarkEvaluator.evaluateCancellable(
                    fixture: fixture,
                    reference: item.reference.sections,
                    snapshot: snapshot,
                    wallSeconds: wallSeconds,
                    engine: engine,
                    engineVersion: engineVersion,
                    configuration: configuration,
                    supplementalMetrics: structureMetrics
                ))
            }
        }

        try AnalysisCancellationPolicy.check()
        return AnalysisRealAudioBenchmarkReport(
            manifestID: manifest.manifestID,
            generatedAt: runDate,
            engine: engine,
            engineVersion: engineVersion,
            parityEligible: allCasesParityEligible && rows.allSatisfy(\.parityEligible),
            rows: rows,
            summaries: summarize(rows),
            validationIssues: []
        )
    }
}
