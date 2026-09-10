import XCTest

final class SplatVideoMemoryPolicyTests: XCTestCase {
    func testVideoPreflightRecoversPersistedViewerEditsBeforeMaterialization() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("splat-video-edit-recovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("result.splat")
        try Data(repeating: 0x24, count: 32).write(to: source, options: .atomic)

        let expected = SplatEditSettings(
            exposureEV: 0.55,
            contrast: 1.15,
            cropXMin: 0.1,
            cropXMax: 0.9,
            cropYMin: 0.15,
            cropYMax: 0.85
        ).normalized()
        try SplatViewerEditStore.save(expected, sourceURL: source)
        try Data("corrupt".utf8).write(
            to: SplatViewerEditStore.primaryURL(for: source),
            options: .atomic
        )

        _ = try SplatVideoMemoryPolicy.preflight(
            sourceURL: source,
            configuration: SplatVideoConfiguration(),
            physicalMemoryBytes: 8 * 1_024 * 1_024 * 1_024
        )

        let healedData = try Data(contentsOf: SplatViewerEditStore.primaryURL(for: source))
        let healed = try JSONDecoder().decode(SplatEditSettings.self, from: healedData).normalized()
        XCTAssertEqual(healed, expected)
    }
}