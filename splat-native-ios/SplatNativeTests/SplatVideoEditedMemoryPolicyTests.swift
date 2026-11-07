import XCTest

final class SplatVideoEditedMemoryPolicyTests: XCTestCase {
    func testSH3ColorEditsReservePointCopyAndCoefficientCopy() throws {
        let root = try makeFixtureRoot("sh3-color")
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("result.splat")
        let pointCount = 10
        try Data(repeating: 0x73, count: pointCount * 32).write(to: source, options: .atomic)
        try writeCompleteCanonicalSH3(for: source, pointCount: pointCount)

        let configuration = SplatVideoConfiguration()
        let physicalMemory: UInt64 = 8 * 1_024 * 1_024 * 1_024
        let unedited = try SplatVideoMemoryPolicy.estimate(
            sourceURL: source,
            configuration: configuration,
            physicalMemoryBytes: physicalMemory
        )

        try SplatViewerEditStore.save(
            SplatEditSettings(exposureEV: 0.5),
            sourceURL: source
        )
        let edited = try SplatVideoMemoryPolicy.estimate(
            sourceURL: source,
            configuration: configuration,
            physicalMemoryBytes: physicalMemory
        )

        let expectedDelta = UInt64(pointCount) * (
            SplatVideoMemoryPolicy.editedPointCopyBytesPerPoint +
            SplatVideoMemoryPolicy.editedSH3ColorCopyBytesPerPoint
        )
        XCTAssertEqual(edited.estimatedPeakBytes - unedited.estimatedPeakBytes, expectedDelta)
    }

    func testCropOnlyEditReservesPointCopyWithoutSHCoefficientClone() throws {
        let root = try makeFixtureRoot("sh3-crop")
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("result.splat")
        let pointCount = 10
        try Data(repeating: 0x79, count: pointCount * 32).write(to: source, options: .atomic)
        try writeCompleteCanonicalSH3(for: source, pointCount: pointCount)

        let configuration = SplatVideoConfiguration()
        let physicalMemory: UInt64 = 8 * 1_024 * 1_024 * 1_024
        let unedited = try SplatVideoMemoryPolicy.estimate(
            sourceURL: source,
            configuration: configuration,
            physicalMemoryBytes: physicalMemory
        )

        try SplatViewerEditStore.save(
            SplatEditSettings(cropXMin: 0.1),
            sourceURL: source
        )
        let edited = try SplatVideoMemoryPolicy.estimate(
            sourceURL: source,
            configuration: configuration,
            physicalMemoryBytes: physicalMemory
        )

        XCTAssertEqual(
            edited.estimatedPeakBytes - unedited.estimatedPeakBytes,
            UInt64(pointCount) * SplatVideoMemoryPolicy.editedPointCopyBytesPerPoint
        )
    }

    private func makeFixtureRoot(_ suffix: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("splat-video-edited-memory-\(suffix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func writeCompleteCanonicalSH3(for source: URL, pointCount: Int) throws {
        let canonicalURL = try SplatCanonicalSHAsset.canonicalURL(forLegacySplat: source)
        var header = "ply\nformat binary_little_endian 1.0\nelement vertex \(pointCount)\n"
        header += "property float f_dc_0\nproperty float f_dc_1\nproperty float f_dc_2\n"
        for index in 0..<45 { header += "property float f_rest_\(index)\n" }
        header += "end_header\n"
        var data = Data(header.utf8)
        data.append(Data(repeating: 0, count: pointCount * 48 * MemoryLayout<Float>.size))
        try data.write(to: canonicalURL, options: .atomic)
    }
}
