import Foundation

public enum LongRunReportRenderer {
    public static func json(_ report: LongRunReport) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(decoding: try encoder.encode(report), as: UTF8.self)
    }

    public static func markdown(_ report: LongRunReport) -> String {
        """
        # Long-run Stress Report
        - total_input: \(report.totalInput)
        - processed_this_run: \(report.processedThisRun)
        - skipped_as_completed: \(report.skippedAsCompleted)
        - completed_total: \(report.completedTotal)
        - review_total: \(report.reviewTotal)
        - elapsed_ms: \(report.elapsedMilliseconds)
        - peak_in_flight_pages: \(report.peakInFlightPages)
        - peak_estimated_working_set_bytes: \(report.peakEstimatedWorkingSetBytes)
        - resumed: \(report.resumed)
        """
    }
}
