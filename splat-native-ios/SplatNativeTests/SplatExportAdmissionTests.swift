import XCTest

final class SplatExportAdmissionTests: XCTestCase {
    func testPLYReservesMoreWorkingSpaceThanSPZForLegacySource() {
        let sourceBytes: Int64 = 96 * 1_024 * 1_024
        let ply = SplatExportAdmission.estimatedRequiredFreeBytes(sourceBytes: sourceBytes, kind: .ply)
        let spz = SplatExportAdmission.estimatedRequiredFreeBytes(sourceBytes: sourceBytes, kind: .spz)
        XCTAssertGreaterThan(ply, spz)
        XCTAssertGreaterThan(ply, sourceBytes)
        XCTAssertGreaterThan(spz, sourceBytes)
    }

    func testCanonicalSHAssetPreventsLegacySplatFromUnderBudgetingExport() {
        let legacy: Int64 = 8 * 1_024 * 1_024
        let canonical: Int64 = 96 * 1_024 * 1_024
        let spz = SplatExportAdmission.estimatedRequiredFreeBytes(sourceBytes: legacy, canonicalAssetBytes: canonical, kind: .spz)
        let video = SplatExportAdmission.estimatedRequiredFreeBytes(sourceBytes: legacy, canonicalAssetBytes: canonical, kind: .video(width: 720, height: 1280, framesPerSecond: 30, duration: 4))
        XCTAssertGreaterThan(spz, canonical)
        XCTAssertGreaterThan(video, canonical)
    }

    func testVideoEstimateGrowsWithDurationAndResolution() {
        let shortPortrait = SplatExportAdmission.estimatedRequiredFreeBytes(sourceBytes: 64 * 1_024 * 1_024, kind: .video(width: 720, height: 1280, framesPerSecond: 30, duration: 4))
        let longHD = SplatExportAdmission.estimatedRequiredFreeBytes(sourceBytes: 64 * 1_024 * 1_024, kind: .video(width: 1920, height: 1080, framesPerSecond: 30, duration: 12))
        XCTAssertGreaterThan(longHD, shortPortrait)
    }

    func testEstimateSaturatesInsteadOfOverflowing() {
        XCTAssertEqual(SplatExportAdmission.estimatedRequiredFreeBytes(sourceBytes: Int64.max, kind: .ply), Int64.max)
    }

    func testCapacityResolutionRejectsWhenNeitherOverrideNorFilesystemValueExists() {
        XCTAssertThrowsError(
            try SplatExportAdmission.resolvedAvailableCapacity(override: nil, detected: nil)
        ) { error in
            guard let admissionError = error as? SplatExportAdmission.AdmissionError else {
                return XCTFail("Expected AdmissionError, got \(error)")
            }
            guard case .availableCapacityUnavailable = admissionError else {
                return XCTFail("Expected availableCapacityUnavailable, got \(admissionError)")
            }
        }
    }

    func testCapacityResolutionPrefersExplicitOverrideAndClampsNegativeValues() throws {
        XCTAssertEqual(
            try SplatExportAdmission.resolvedAvailableCapacity(override: 123, detected: 999),
            123
        )
        XCTAssertEqual(
            try SplatExportAdmission.resolvedAvailableCapacity(override: -1, detected: 999),
            0
        )
    }

    func testTrustedDigestCanonicalURLMatchesHashedCanonicalURL() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("c2-trusted-digest-canonical-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("result.splat")
        try Data((0..<128).map { UInt8($0 & 0xff) }).write(to: source, options: .atomic)

        let digest = try SplatExportService.sha256Hex(fileURL: source)
        let hashedURL = try SplatCanonicalSHAsset.canonicalURL(forLegacySplat: source)
        let trustedURL = try SplatCanonicalSHAsset.canonicalURL(
            forLegacySplat: source,
            verifiedDigest: digest.uppercased()
        )

        XCTAssertEqual(trustedURL, hashedURL)
        XCTAssertTrue(trustedURL.lastPathComponent.hasPrefix("result.sh3-"))
    }

    func testPreflightRecoversViewerEditsBeforeExportMaterialization() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("c2-splat-export-edit-recovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Edit recovery")
        let pending = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try Data(repeating: 0x31, count: 64).write(to: pending, options: .atomic)
        let result = try store.commitPendingSplat(projectURL: projectURL)
        _ = try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }

        let knownGood = SplatEditSettings(exposureEV: 0.35, contrast: 1.1, cropXMin: 0.1, cropXMax: 0.9)
        let newer = SplatEditSettings(exposureEV: -0.4, contrast: 0.9, cropYMin: 0.2, cropYMax: 0.8)
        try SplatViewerEditStore.save(knownGood, sourceURL: result)
        try SplatViewerEditStore.save(newer, sourceURL: result)
        try Data("corrupt".utf8).write(to: SplatViewerEditStore.primaryURL(for: result), options: .atomic)

        _ = try SplatExportAdmission.preflight(sourceURL: result, kind: .spz, availableCapacityOverride: Int64.max)

        let healedData = try Data(contentsOf: SplatViewerEditStore.primaryURL(for: result))
        let healed = try JSONDecoder().decode(SplatEditSettings.self, from: healedData)
        XCTAssertEqual(healed.normalized(), knownGood.normalized())
    }

    func testPreflightRejectsExternalViewerEditAliasWithoutBackup() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("c2-splat-export-edit-alias-\(UUID().uuidString)", isDirectory: true)
        let externalRoot = fileManager.temporaryDirectory.appendingPathComponent("c2-splat-export-edit-external-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? fileManager.removeItem(at: root)
            try? fileManager.removeItem(at: externalRoot)
        }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: externalRoot, withIntermediateDirectories: true)
        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Reject external edits")
        let pending = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try Data(repeating: 0x32, count: 64).write(to: pending, options: .atomic)
        let result = try store.commitPendingSplat(projectURL: projectURL)
        _ = try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }

        let externalSidecar = externalRoot.appendingPathComponent("viewer.json")
        try JSONEncoder().encode(SplatEditSettings(exposureEV: 1.5, contrast: 1.2)).write(to: externalSidecar, options: .atomic)
        try fileManager.createSymbolicLink(
            at: SplatViewerEditStore.primaryURL(for: result),
            withDestinationURL: externalSidecar
        )

        XCTAssertThrowsError(
            try SplatExportAdmission.preflight(sourceURL: result, kind: .spz, availableCapacityOverride: Int64.max)
        ) { error in
            guard let admissionError = error as? SplatExportAdmission.AdmissionError,
                  case .untrustedSource = admissionError else {
                return XCTFail("Expected untrustedSource for external viewer edit alias, got \(error)")
            }
        }
        XCTAssertTrue(fileManager.fileExists(atPath: externalSidecar.path))
    }

    func testPreflightRejectsOversizedViewerEditSidecarWithoutBackup() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("c2-splat-export-edit-oversized-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Reject oversized edits")
        let pending = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try Data(repeating: 0x33, count: 64).write(to: pending, options: .atomic)
        let result = try store.commitPendingSplat(projectURL: projectURL)
        _ = try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }

        try Data(repeating: 0x41, count: 64 * 1024 + 1).write(
            to: SplatViewerEditStore.primaryURL(for: result),
            options: .atomic
        )

        XCTAssertThrowsError(
            try SplatExportAdmission.preflight(sourceURL: result, kind: .ply, availableCapacityOverride: Int64.max)
        ) { error in
            guard let admissionError = error as? SplatExportAdmission.AdmissionError,
                  case .untrustedSource = admissionError else {
                return XCTFail("Expected untrustedSource for oversized viewer edit sidecar, got \(error)")
            }
        }
    }

    func testPreflightRejectsBeforeExportWhenFreeSpaceIsInsufficient() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("c2-splat-low-storage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Low storage")
        let pending = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try Data(repeating: 0x51, count: 64).write(to: pending, options: .atomic)
        let result = try store.commitPendingSplat(projectURL: projectURL)
        _ = try store.updateManifest(projectURL: projectURL) { manifest in manifest.stage = .finished; manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName }
        do {
            _ = try SplatExportAdmission.preflight(sourceURL: result, kind: .ply, availableCapacityOverride: 0)
            XCTFail("Expected low-storage rejection")
        } catch let error as SplatExportAdmission.AdmissionError {
            guard case .insufficientStorage(let required, let available) = error else { return XCTFail("Expected insufficientStorage, got \(error)") }
            XCTAssertGreaterThan(required, 0); XCTAssertEqual(available, 0)
        }
        let children = try FileManager.default.contentsOfDirectory(at: projectURL, includingPropertiesForKeys: nil)
        XCTAssertFalse(children.contains { ["ply", "spz", "mp4"].contains($0.pathExtension.lowercased()) })
    }

    func testPreflightRejectsMalformedExistingCanonicalInsteadOfExportingLegacyFallback() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("c2-splat-export-malformed-sh3-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Malformed SH3")
        let pending = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try Data(repeating: 0x71, count: 64).write(to: pending, options: .atomic)
        let result = try store.commitPendingSplat(projectURL: projectURL)
        _ = try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }

        let canonicalURL = try SplatCanonicalSHAsset.canonicalURL(forLegacySplat: result)
        try Data("ply\nformat binary_little_endian 1.0\nelement vertex 2\nend_header\n".utf8)
            .write(to: canonicalURL, options: .atomic)

        XCTAssertThrowsError(
            try SplatExportAdmission.preflight(
                sourceURL: result,
                kind: .spz,
                availableCapacityOverride: Int64.max
            )
        ) { error in
            guard let admissionError = error as? SplatExportAdmission.AdmissionError else {
                return XCTFail("Expected AdmissionError, got \(error)")
            }
            guard case .untrustedSource = admissionError else {
                return XCTFail("Expected untrustedSource, got \(admissionError)")
            }
        }
    }
}
