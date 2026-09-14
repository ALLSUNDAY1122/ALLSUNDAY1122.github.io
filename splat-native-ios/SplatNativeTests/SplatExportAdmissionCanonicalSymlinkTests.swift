import XCTest

extension SplatExportAdmissionTests {
    func testPreflightRejectsCanonicalSH3SymlinkOutsideProject() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("c2-splat-export-canonical-alias-\(UUID().uuidString)", isDirectory: true)
        let externalRoot = fileManager.temporaryDirectory
            .appendingPathComponent("c2-splat-export-canonical-external-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? fileManager.removeItem(at: root)
            try? fileManager.removeItem(at: externalRoot)
        }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: externalRoot, withIntermediateDirectories: true)

        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Reject external canonical")
        let pending = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try Data(repeating: 0x42, count: 64).write(to: pending, options: .atomic)
        let result = try store.commitPendingSplat(projectURL: projectURL)
        _ = try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }

        let digest = try SplatExportService.sha256Hex(fileURL: result)
        let canonicalURL = try SplatCanonicalSHAsset.canonicalURL(
            forLegacySplat: result,
            verifiedDigest: digest
        )
        let external = externalRoot.appendingPathComponent("external-sh3.ply")
        let pointCount = 2
        var completePLY = Data(canonicalSH3HeaderForAdmissionSymlinkTest(pointCount: pointCount).utf8)
        completePLY.append(Data(repeating: 0, count: pointCount * 48 * MemoryLayout<Float>.size))
        try completePLY.write(to: external, options: .atomic)
        try fileManager.createSymbolicLink(at: canonicalURL, withDestinationURL: external)

        XCTAssertThrowsError(
            try SplatExportAdmission.preflight(
                sourceURL: result,
                kind: .spz,
                availableCapacityOverride: Int64.max
            )
        ) { error in
            guard let admissionError = error as? SplatExportAdmission.AdmissionError,
                  case .untrustedSource = admissionError else {
                return XCTFail("Expected untrustedSource for external canonical alias, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: external), completePLY)
    }

    private func canonicalSH3HeaderForAdmissionSymlinkTest(pointCount: Int) -> String {
        var header = "ply\nformat binary_little_endian 1.0\nelement vertex \(pointCount)\n"
        header += "property float f_dc_0\nproperty float f_dc_1\nproperty float f_dc_2\n"
        for index in 0..<45 {
            header += "property float f_rest_\(index)\n"
        }
        header += "end_header\n"
        return header
    }
}
