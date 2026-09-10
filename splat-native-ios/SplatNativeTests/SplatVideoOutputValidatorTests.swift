import XCTest

final class SplatVideoOutputValidatorTests: XCTestCase {
    func testRejectsMissingOutput() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-video-\(UUID().uuidString).mp4")

        do {
            try await SplatVideoOutputValidator.validate(url)
            XCTFail("Missing video must not pass validation")
        } catch let error as SplatVideoOutputValidator.ValidationError {
            XCTAssertEqual(error, .missingOrEmpty)
        }
    }

    func testRejectsNonEmptyMalformedMP4() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("malformed-video-\(UUID().uuidString).mp4")
        try Data(repeating: 0x41, count: 4_096).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            try await SplatVideoOutputValidator.validate(url)
            XCTFail("Non-empty bytes without a valid video track must not pass validation")
        } catch {
            // AVFoundation may report a container parse error before the explicit no-track branch.
            // Either failure is correct: malformed bytes must never reach the share sheet.
        }
    }

    func testCancelledValidationCannotBecomeShareableSuccess() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cancelled-video-validation-\(UUID().uuidString).mp4")
        try Data(repeating: 0x41, count: 4_096).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let task = Task {
            try await SplatVideoOutputValidator.validate(url)
        }
        task.cancel()

        do {
            try await task.value
            XCTFail("A cancelled validation must never return a shareable success")
        } catch is CancellationError {
            // Expected: cancellation has priority over container validation once the caller cancels.
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }
}
