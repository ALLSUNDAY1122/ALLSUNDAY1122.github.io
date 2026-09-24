import XCTest

final class SplatPhysicalDiagnosticTests: XCTestCase {
    func testMemoryPauseDiagnosticsStayDistinctAndIncludeMeasuredValues() {
        let mib: UInt64 = 1_048_576
        let limits = SplatResourceLimits(
            residentMemoryBudgetBytes: 1_024 * mib,
            minimumAvailableMemoryReserveBytes: 320 * mib,
            maxSplatCount: 500_000
        )
        let evaluation = SplatResourceEvaluation(
            reason: .residentMemoryBudget,
            residentMemoryBytes: 930 * mib,
            availableMemoryBytes: 245 * mib,
            peakResidentMemoryBytes: 950 * mib,
            minimumAvailableMemoryBytes: 240 * mib,
            peakSplatCount: 187_654
        )

        let reasons: [SplatResourcePauseReason] = [
            .memoryWarning,
            .availableMemoryReserve,
            .residentMemoryBudget,
        ]
        let diagnostics = reasons.map {
            $0.diagnosticText(
                evaluation: evaluation,
                limits: limits,
                iteration: 2_345,
                splatCount: 187_654
            )
        }

        XCTAssertEqual(Set(diagnostics).count, reasons.count)
        for (reason, text) in zip(reasons, diagnostics) {
            XCTAssertTrue(text.contains("reason=\(reason.rawValue)"))
            XCTAssertTrue(text.contains("iteration=2345"))
            XCTAssertTrue(text.contains("splats=187654"))
            XCTAssertTrue(text.contains("resident=930 MiB"))
            XCTAssertTrue(text.contains("budget=1024 MiB"))
            XCTAssertTrue(text.contains("available=245 MiB"))
            XCTAssertTrue(text.contains("reserve=320 MiB"))
        }
    }

    func testDiagnosticFormattingDoesNotChangeResourcePolicy() {
        let mib: UInt64 = 1_048_576
        let limits = SplatResourceLimits.conservative(physicalMemoryBytes: 8 * 1_073_741_824)

        XCTAssertGreaterThanOrEqual(limits.residentMemoryBudgetBytes, 700 * mib)
        XCTAssertLessThanOrEqual(limits.residentMemoryBudgetBytes, 1_536 * mib)
        XCTAssertGreaterThanOrEqual(limits.minimumAvailableMemoryReserveBytes, 256 * mib)
        XCTAssertLessThanOrEqual(limits.minimumAvailableMemoryReserveBytes, 512 * mib)
        XCTAssertEqual(SplatReconstructionPolicy.standardIterations, 7_000)
        XCTAssertEqual(SplatReconstructionPolicy.datasetDownscale, 4.0)
        XCTAssertEqual(SplatReconstructionPolicy.makeConfig().shDegree, 3)
    }
}
