import Foundation

enum FixtureFailure: Error { case synthetic(Int) }

@main struct LongRunFixture {
    static func main() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("scan006-checkpoint.json")
        try? FileManager.default.removeItem(at: url)
        let pages = (1...240).map { LongRunPage(index: $0, pageID: String(format: "p-%04d", $0), estimatedBytes: 900_000 + ($0 % 7) * 120_000) }
        let harness = LongRunHarness(checkpointURL: url)
        var firstAttempts: [Int] = []
        do {
            _ = try harness.run(pages: pages, interruptAfterNewAttempts: 123) { page in
                firstAttempts.append(page.index)
                if page.index == 37 { throw FixtureFailure.synthetic(page.index) }
            }
            fatalError("expected interruption")
        } catch LongRunHarnessError.interrupted { }

        var resumedAttempts: [Int] = []
        let report = try harness.run(pages: pages) { page in
            resumedAttempts.append(page.index)
            if page.index == 199 { throw FixtureFailure.synthetic(page.index) }
        }
        let overlap = Set(firstAttempts).intersection(Set(resumedAttempts))
        precondition(overlap.isEmpty, "resume reprocessed prior attempts: \(overlap)")
        precondition(report.totalInput == 240)
        precondition(report.completedTotal == 238)
        precondition(report.reviewTotal == 2)
        precondition(report.skippedAsCompleted == 123)
        precondition(report.peakInFlightPages == 1)
        precondition(report.peakEstimatedWorkingSetBytes <= 1_620_000)
        precondition(report.resumed)
        let json = try LongRunReportRenderer.json(report)
        let markdown = LongRunReportRenderer.markdown(report)
        precondition(json.contains("\"completedTotal\" : 238"))
        precondition(markdown.contains("review_total: 2"))
        print(json)
        print(markdown)
        print("LongRunFixture PASS")
    }
}
