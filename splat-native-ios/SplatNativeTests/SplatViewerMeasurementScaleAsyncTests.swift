import XCTest

@MainActor
final class SplatViewerMeasurementScaleAsyncTests: XCTestCase {
    func testAttachAppliesMeasurementScaleAfterBackgroundTrajectoryDecode() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let source = root.appendingPathComponent("result.splat")
        try Data([0]).write(to: source)
        let transforms = #"{"frames":[{"transform_matrix":[[1,0,0,-2],[0,1,0,0],[0,0,1,0],[0,0,0,1]]},{"transform_matrix":[[1,0,0,2],[0,1,0,0],[0,0,1,0],[0,0,0,1]]}]}"#
        try Data(transforms.utf8).write(to: root.appendingPathComponent("transforms.json"))

        let state = SplatViewerState()
        state.attach(url: source)

        var observed = false
        for _ in 0..<100 {
            state.rendererMeasured(meters: 1)
            if state.measurementText == "2.00 m" {
                observed = true
                break
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(observed, "background trajectory decode should update measurement scale")
    }

    func testSwitchingScansPreventsObsoleteScaleFromWinning() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let slowRoot = root.appendingPathComponent("slow", isDirectory: true)
        let fastRoot = root.appendingPathComponent("fast", isDirectory: true)
        try fileManager.createDirectory(at: slowRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: fastRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let slowSource = slowRoot.appendingPathComponent("result.splat")
        let fastSource = fastRoot.appendingPathComponent("result.splat")
        try Data([0]).write(to: slowSource)
        try Data([0]).write(to: fastSource)

        let slowFrame = #"{"transform_matrix":[[1,0,0,-8],[0,1,0,0],[0,0,1,0],[0,0,0,1]]}"#
        let slowFrames = Array(repeating: slowFrame, count: 20_000).joined(separator: ",")
        try Data("{\"frames\":[\(slowFrames)]}".utf8).write(
            to: slowRoot.appendingPathComponent("transforms.json")
        )
        let fastTransforms = #"{"frames":[{"transform_matrix":[[1,0,0,-3],[0,1,0,0],[0,0,1,0],[0,0,0,1]]},{"transform_matrix":[[1,0,0,3],[0,1,0,0],[0,0,1,0],[0,0,0,1]]}]}"#
        try Data(fastTransforms.utf8).write(to: fastRoot.appendingPathComponent("transforms.json"))

        let state = SplatViewerState()
        state.attach(url: slowSource)
        state.attach(url: fastSource)

        var observedFastScale = false
        for _ in 0..<150 {
            state.rendererMeasured(meters: 1)
            if state.measurementText == "3.00 m" {
                observedFastScale = true
                break
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(observedFastScale)

        // Give the cancelled, much larger first decode enough time to finish if cancellation were
        // accidentally ignored. Its result must not overwrite the currently attached scan.
        try await Task.sleep(nanoseconds: 150_000_000)
        state.rendererMeasured(meters: 1)
        XCTAssertEqual(state.measurementText, "3.00 m")
    }
}
