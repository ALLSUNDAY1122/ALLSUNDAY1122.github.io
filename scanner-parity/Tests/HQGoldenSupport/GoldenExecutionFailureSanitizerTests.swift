import XCTest
@testable import HQGoldenSupport

final class GoldenExecutionFailureSanitizerTests: XCTestCase {
    func testKnownRawPathsAreRedacted() {
        let video = "/Users/example/Golden/RPReplay_Final1787451151.mp4"
        let pdf = "/Users/example/Golden/本 2026-08-23 0842.pdf"
        let workspace = "/Users/example/tmp/scanner-parity-hq-golden"
        let message = "failed reading \(video); reference=file://\(pdf); workspace=\(workspace)"

        let sanitized = GoldenExecutionFailureSanitizer.sanitize(
            message: message,
            redactedPaths: [video, pdf, workspace]
        )

        XCTAssertFalse(sanitized.contains(video))
        XCTAssertFalse(sanitized.contains(pdf))
        XCTAssertFalse(sanitized.contains(workspace))
        XCTAssertTrue(sanitized.contains("<REDACTED_PATH>") || sanitized.contains("<REDACTED_URL>"))
    }

    func testNonPathDiagnosticTextIsPreserved() {
        let message = "OCR engine failure on page 12"
        XCTAssertEqual(
            GoldenExecutionFailureSanitizer.sanitize(message: message, redactedPaths: []),
            message
        )
    }
}
