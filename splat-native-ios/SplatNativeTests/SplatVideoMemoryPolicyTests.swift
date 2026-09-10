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

    func testCanonicalSH3SceneUsesLargerPerPointVideoBudget() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("splat-video-sh3-budget-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("result.splat")
        let pointCount = 10
        try Data(repeating: 0x31, count: pointCount * 32).write(to: source, options: .atomic)
        let configuration = SplatVideoConfiguration()
        let physicalMemory: UInt64 = 8 * 1_024 * 1_024 * 1_024

        let legacy = try SplatVideoMemoryPolicy.estimate(
            sourceURL: source,
            configuration: configuration,
            physicalMemoryBytes: physicalMemory
        )

        let canonicalURL = try SplatCanonicalSHAsset.canonicalURL(forLegacySplat: source)
        let header = canonicalSH3Header(pointCount: pointCount)
        var completePLY = Data(header.utf8)
        completePLY.append(Data(repeating: 0, count: pointCount * 48 * MemoryLayout<Float>.size))
        try completePLY.write(to: canonicalURL, options: .atomic)

        let sh3 = try SplatVideoMemoryPolicy.estimate(
            sourceURL: source,
            configuration: configuration,
            physicalMemoryBytes: physicalMemory
        )

        let expectedDelta = UInt64(pointCount) * (
            SplatVideoMemoryPolicy.estimatedSH3WorkingBytesPerPoint -
            SplatVideoMemoryPolicy.estimatedWorkingBytesPerPoint
        )
        XCTAssertEqual(sh3.pointCount, legacy.pointCount)
        XCTAssertEqual(sh3.estimatedPeakBytes - legacy.estimatedPeakBytes, expectedDelta)
        XCTAssertEqual(sh3.budgetBytes, legacy.budgetBytes)
    }

    func testVideoPreflightRejectsSchemaValidCanonicalSH3WithTruncatedBody() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("splat-video-sh3-truncated-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("result.splat")
        let pointCount = 10
        try Data(repeating: 0x42, count: pointCount * 32).write(to: source, options: .atomic)

        let canonicalURL = try SplatCanonicalSHAsset.canonicalURL(forLegacySplat: source)
        try Data(canonicalSH3Header(pointCount: pointCount).utf8).write(to: canonicalURL, options: .atomic)

        XCTAssertThrowsError(
            try SplatVideoMemoryPolicy.preflight(
                sourceURL: source,
                configuration: SplatVideoConfiguration(),
                physicalMemoryBytes: 8 * 1_024 * 1_024 * 1_024
            )
        ) { error in
            XCTAssertEqual(error as? SplatVideoMemoryPolicy.PolicyError, .untrustedCanonicalAsset)
        }

        let estimate = try SplatVideoMemoryPolicy.estimate(
            sourceURL: source,
            configuration: SplatVideoConfiguration(),
            physicalMemoryBytes: 8 * 1_024 * 1_024 * 1_024
        )
        let legacyPointBytes = UInt64(pointCount) * SplatVideoMemoryPolicy.estimatedWorkingBytesPerPoint
        let dimensions = SplatVideoConfiguration().dimensions
        let videoBytes = UInt64(dimensions.width * dimensions.height * 4 * 4)
        XCTAssertEqual(
            estimate.estimatedPeakBytes,
            legacyPointBytes + SplatVideoMemoryPolicy.fixedRendererAndEncoderReserveBytes + videoBytes
        )
    }

    func testVideoAdmissionCarriesTheValidatedCanonicalRenderAsset() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("splat-video-admitted-asset-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("result.splat")
        let pointCount = 10
        try Data(repeating: 0x51, count: pointCount * 32).write(to: source, options: .atomic)

        let canonicalURL = try SplatCanonicalSHAsset.canonicalURL(forLegacySplat: source)
        var completePLY = Data(canonicalSH3Header(pointCount: pointCount).utf8)
        completePLY.append(Data(repeating: 0, count: pointCount * 48 * MemoryLayout<Float>.size))
        try completePLY.write(to: canonicalURL, options: .atomic)

        let admission = try SplatVideoMemoryPolicy.preflightAdmission(
            sourceURL: source,
            configuration: SplatVideoConfiguration(),
            physicalMemoryBytes: 8 * 1_024 * 1_024 * 1_024
        )

        XCTAssertEqual(admission.estimate.pointCount, pointCount)
        XCTAssertEqual(admission.renderAssetURL.standardizedFileURL, canonicalURL.standardizedFileURL)
    }

    func testVerifiedDigestVideoAdmissionSelectsSameCanonicalWithoutResolverHashPath() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("splat-video-digest-admission-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("result.splat")
        let pointCount = 10
        try Data(repeating: 0x5A, count: pointCount * 32).write(to: source, options: .atomic)
        let digest = try SplatExportService.sha256Hex(fileURL: source)
        let canonicalURL = try SplatCanonicalSHAsset.canonicalURL(
            forLegacySplat: source,
            verifiedDigest: digest
        )
        var completePLY = Data(canonicalSH3Header(pointCount: pointCount).utf8)
        completePLY.append(Data(repeating: 0, count: pointCount * 48 * MemoryLayout<Float>.size))
        try completePLY.write(to: canonicalURL, options: .atomic)

        let admission = try SplatVideoMemoryPolicy.preflightAdmission(
            sourceURL: source,
            verifiedDigest: digest,
            configuration: SplatVideoConfiguration(),
            physicalMemoryBytes: 8 * 1_024 * 1_024 * 1_024
        )

        XCTAssertEqual(admission.estimate.pointCount, pointCount)
        XCTAssertEqual(admission.renderAssetURL.standardizedFileURL, canonicalURL.standardizedFileURL)
    }

    func testVideoPreflightRejectsMalformedExistingCanonicalInsteadOfSilentLegacyDowngrade() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("splat-video-sh3-malformed-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("result.splat")
        let pointCount = 10
        try Data(repeating: 0x61, count: pointCount * 32).write(to: source, options: .atomic)

        let canonicalURL = try SplatCanonicalSHAsset.canonicalURL(forLegacySplat: source)
        try Data("ply\nformat binary_little_endian 1.0\nelement vertex 10\nend_header\n".utf8)
            .write(to: canonicalURL, options: .atomic)

        XCTAssertThrowsError(
            try SplatVideoMemoryPolicy.preflightAdmission(
                sourceURL: source,
                configuration: SplatVideoConfiguration(),
                physicalMemoryBytes: 8 * 1_024 * 1_024 * 1_024
            )
        ) { error in
            XCTAssertEqual(error as? SplatVideoMemoryPolicy.PolicyError, .untrustedCanonicalAsset)
        }
    }

    private func canonicalSH3Header(pointCount: Int) -> String {
        var header = "ply\nformat binary_little_endian 1.0\nelement vertex \(pointCount)\n"
        header += "property float f_dc_0\nproperty float f_dc_1\nproperty float f_dc_2\n"
        for index in 0..<45 { header += "property float f_rest_\(index)\n" }
        header += "end_header\n"
        return header
    }
}
