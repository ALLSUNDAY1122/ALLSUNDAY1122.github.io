import Foundation

public enum GoldenReportFormatter {
    public static func markdown(_ report: GoldenEvaluationReport) -> String {
        var lines: [String] = []
        lines.append("# HQ Golden Gate Metrics")
        lines.append("")
        lines.append("Generated: \(report.generatedAtISO8601)")
        lines.append("Worker verdict: `\(report.workerGoldenVerdict)`")
        lines.append("")
        lines.append("## Metrics")
        lines.append("")
        lines.append("| metric | value | target | fixture threshold |")
        lines.append("|---|---:|---|---|")
        for metric in report.metricEvaluations {
            let rendered = String(format: "%.6f", metric.value)
            lines.append("| \(metric.name) | \(rendered) | \(metric.targetDescription) | \(metric.meetsTarget ? "MEETS" : "MISSES") |")
        }
        lines.append("")
        lines.append("## Counts")
        lines.append("")
        lines.append("- expected pages: \(report.expectedPageCount)")
        lines.append("- corrected pages: \(report.observedCorrectedPageCount)")
        lines.append("- duplicate groups: \(report.duplicateGroupCount)")
        lines.append("- review required: \(report.reviewRequiredCount)")
        lines.append("")
        lines.append("## SHA observations")
        lines.append("")
        for sha in report.shaObservations {
            let expected = sha.expectedSHA256 ?? "not-provided"
            let observed = sha.observedSHA256 ?? "not-observed"
            let match: String
            switch sha.matchesExpected {
            case .some(true): match = "MATCH"
            case .some(false): match = "MISMATCH_HQ_RESOLUTION"
            case .none: match = "UNRESOLVED"
            }
            lines.append("- \(sha.artifact): expected=`\(expected)` observed=`\(observed)` status=`\(match)` owner=`\(sha.ownership)`")
        }
        lines.append("")
        lines.append("> This report contains measurements and fixture target checks only. Formal Golden PASS/FAIL is owned by HQ_GOLDEN_GATE.")
        return lines.joined(separator: "\n") + "\n"
    }
}
