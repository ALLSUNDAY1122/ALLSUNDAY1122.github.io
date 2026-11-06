import Foundation

/// Emits integrity/coverage diagnostics into the same durable benchmark schema
/// used by tempo/key/chord/section evaluation. This row supplements accuracy
/// metrics; it never substitutes for rights-cleared real-audio or Moises A/B.
public enum AnalysisSnapshotHealthBenchmark {
    public static func evaluate(
        fixture: AnalysisBenchmarkFixture,
        snapshot: AnalysisSnapshot,
        wallSeconds: Double,
        engine: String = "project-owned-dsp",
        engineVersion: String = "l4-w10-v1"
    ) -> AnalysisBenchmarkRow {
        let duration = fixture.signal.durationSeconds
        var metrics = AnalysisSnapshotRobustness.diagnostics(snapshot: snapshot, duration: duration)
        if let canonical = try? AnalysisSnapshotRobustness.canonicalJSON(snapshot) {
            metrics["canonical_encode_ok"] = 1
            metrics["canonical_json_bytes"] = Double(canonical.count)
        } else {
            metrics["canonical_encode_ok"] = 0
        }

        var limitations = ["INTEGRITY_METRICS_NOT_MIR_ACCURACY_EVIDENCE"]
        if fixture.syntheticOnly {
            limitations.append("SYNTHETIC_UNIT_ONLY_NOT_PARITY_EVIDENCE")
        }

        return AnalysisBenchmarkRow(
            fixtureID: fixture.fixtureID,
            rightsClass: fixture.rightsClass,
            genre: fixture.genre,
            durationSeconds: duration,
            syntheticOnly: fixture.syntheticOnly,
            parityEligible: !fixture.syntheticOnly,
            engine: engine,
            engineVersion: engineVersion,
            domain: "analysis_snapshot_health",
            metrics: metrics,
            wallSeconds: wallSeconds,
            rtf: duration > 0 ? wallSeconds / duration : nil,
            peakRSSMB: nil,
            thermal: nil,
            knownLimitations: limitations
        )
    }
}
