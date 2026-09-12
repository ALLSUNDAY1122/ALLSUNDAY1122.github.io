import XCTest

final class SplatVerifiedDigestExportTests: XCTestCase {
    func testVerifiedDigestResolverSelectsCompleteSH3WithoutLegacyRehashPath() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("splat-verified-digest-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("result.splat")
        let pointCount = 10
        try Data(repeating: 0x6A, count: pointCount * 32).write(to: source, options: .atomic)
        let digest = try SplatExportService.sha256Hex(fileURL: source)
        let canonicalURL = try SplatCanonicalSHAsset.canonicalURL(
            forLegacySplat: source,
            verifiedDigest: digest
        )

        var completePLY = Data(canonicalSH3Header(pointCount: pointCount).utf8)
        completePLY.append(Data(repeating: 0, count: pointCount * 48 * MemoryLayout<Float>.size))
        try completePLY.write(to: canonicalURL, options: .atomic)

        let asset = SplatCanonicalSHAsset.existingCompleteAsset(
            forLegacySplat: source,
            verifiedDigest: digest.uppercased(),
            expectedPointCount: pointCount
        )
        XCTAssertEqual(asset?.url.standardizedFileURL, canonicalURL.standardizedFileURL)
        XCTAssertEqual(asset?.descriptor.shDegree, 3)
        XCTAssertEqual(asset?.descriptor.pointCount, pointCount)
    }

    func testVerifiedDigestResolverRejectsTruncatedCanonicalPayload() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("splat-verified-digest-truncated-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("result.splat")
        let pointCount = 10
        try Data(repeating: 0x71, count: pointCount * 32).write(to: source, options: .atomic)
        let digest = try SplatExportService.sha256Hex(fileURL: source)
        let canonicalURL = try SplatCanonicalSHAsset.canonicalURL(
            forLegacySplat: source,
            verifiedDigest: digest
        )
        try Data(canonicalSH3Header(pointCount: pointCount).utf8).write(to: canonicalURL, options: .atomic)

        XCTAssertNil(
            SplatCanonicalSHAsset.existingCompleteAsset(
                forLegacySplat: source,
                verifiedDigest: digest,
                expectedPointCount: pointCount
            )
        )
    }

    func testVerifiedDigestResolverRejectsCanonicalSymlinkOutsideProject() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("splat-verified-digest-alias-\(UUID().uuidString)", isDirectory: true)
        let externalRoot = fileManager.temporaryDirectory
            .appendingPathComponent("splat-verified-digest-external-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: externalRoot, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: root)
            try? fileManager.removeItem(at: externalRoot)
        }

        let source = root.appendingPathComponent("result.splat")
        let pointCount = 10
        try Data(repeating: 0x33, count: pointCount * 32).write(to: source, options: .atomic)
        let digest = try SplatExportService.sha256Hex(fileURL: source)
        let canonicalURL = try SplatCanonicalSHAsset.canonicalURL(
            forLegacySplat: source,
            verifiedDigest: digest
        )
        let external = externalRoot.appendingPathComponent("external-sh3.ply")
        var completePLY = Data(canonicalSH3Header(pointCount: pointCount).utf8)
        completePLY.append(Data(repeating: 0, count: pointCount * 48 * MemoryLayout<Float>.size))
        try completePLY.write(to: external, options: .atomic)
        try fileManager.createSymbolicLink(at: canonicalURL, withDestinationURL: external)

        XCTAssertNil(
            SplatCanonicalSHAsset.existingCompleteAsset(
                forLegacySplat: source,
                verifiedDigest: digest,
                expectedPointCount: pointCount
            )
        )
        XCTAssertEqual(try Data(contentsOf: external), completePLY)
    }

    private func canonicalSH3Header(pointCount: Int) -> String {
        var header = "ply\nformat binary_little_endian 1.0\nelement vertex \(pointCount)\n"
        header += "property float f_dc_0\nproperty float f_dc_1\nproperty float f_dc_2\n"
        for index in 0..<45 {
            header += "property float f_rest_\(index)\n"
        }
        header += "end_header\n"
        return header
    }
}
