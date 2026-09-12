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
            // Wait until cancellation is observably set before entering validation so this test
            // exercises the validator's cancellation gate rather than racing malformed-file parsing.
            while !Task.isCancelled {
                await Task.yield()
            }
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

    func testStandardExportDurationsProbeQuarterMidAndThreeQuarterWindows() {
        XCTAssertEqual(
            SplatVideoOutputValidator.boundedProbeWindows(duration: 4),
            [
                .init(start: 0.75, duration: 0.5),
                .init(start: 1.75, duration: 0.5),
                .init(start: 2.75, duration: 0.5),
            ]
        )
        XCTAssertEqual(
            SplatVideoOutputValidator.boundedProbeWindows(duration: 10),
            [
                .init(start: 2.25, duration: 0.5),
                .init(start: 4.75, duration: 0.5),
                .init(start: 7.25, duration: 0.5),
            ]
        )
    }

    func testShortNonstandardVideoKeepsSingleCenteredInteriorProbe() {
        XCTAssertEqual(
            SplatVideoOutputValidator.boundedProbeWindows(duration: 2),
            [.init(start: 0.75, duration: 0.5)]
        )
    }

    func testInteriorProbeSkipsShortVideosToAvoidEdgeOverlap() {
        XCTAssertTrue(SplatVideoOutputValidator.boundedProbeWindows(duration: 1.5).isEmpty)
        XCTAssertTrue(SplatVideoOutputValidator.boundedProbeWindows(duration: 0.5).isEmpty)
        XCTAssertTrue(SplatVideoOutputValidator.boundedProbeWindows(duration: .nan).isEmpty)
    }
}
