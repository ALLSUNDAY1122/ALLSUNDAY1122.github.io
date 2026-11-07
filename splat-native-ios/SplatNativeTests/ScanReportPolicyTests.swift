import XCTest

final class ScanReportPolicyTests: XCTestCase {
    func testReasonRawValuesMatchBackendContract() {
        XCTAssertEqual(
            ScanReportReason.allCases.map(\.rawValue),
            ["privacy", "unsafe_location", "copyright", "harassment", "sexual", "violence", "spam", "other"]
        )
    }

    func testDraftAcceptsMaximumDetailsLength() throws {
        let draft = try ScanReportDraft(
            scanID: UUID(),
            reason: .other,
            details: String(repeating: "a", count: 1_000)
        )
        XCTAssertEqual(draft.details.count, 1_000)
    }

    func testDraftRejectsOversizedDetails() {
        XCTAssertThrowsError(
            try ScanReportDraft(
                scanID: UUID(),
                reason: .spam,
                details: String(repeating: "a", count: 1_001)
            )
        ) { error in
            XCTAssertEqual(error as? ScanReportValidationError, .detailsTooLong)
        }
    }

    func testFreshReceiptBecomesPersistedAndDisablesResubmit() {
        let date = Date(timeIntervalSince1970: 100)
        let state = ScanReportPolicy.state(from: .init(reportID: 42, duplicate: false, createdAt: date))
        XCTAssertEqual(state, .persisted(reportID: 42, createdAt: date))
        XCTAssertTrue(state.disablesSubmit)
    }

    func testDuplicateReceiptIsSuccessfulTerminalState() {
        let date = Date(timeIntervalSince1970: 200)
        let state = ScanReportPolicy.state(from: .init(reportID: 42, duplicate: true, createdAt: date))
        XCTAssertEqual(state, .duplicate(reportID: 42, createdAt: date))
        XCTAssertTrue(state.disablesSubmit)
    }

    func testFailureAllowsRetry() {
        XCTAssertFalse(ScanReportSubmissionState.failed(message: "offline").disablesSubmit)
    }
}
