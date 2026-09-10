import XCTest
import simd

final class SplatViewerStateTests: XCTestCase {
    func testDefaultEditSettingsAreNonDestructive() {
        let settings = SplatEditSettings.default
        XCTAssertEqual(settings.exposureEV, 0)
        XCTAssertEqual(settings.contrast, 1)
        XCTAssertFalse(settings.hasCrop)
    }

    func testNormalizationClampsAndRepairsCropRanges() {
        let settings = SplatEditSettings(exposureEV: 8, contrast: 0.1, cropXMin: 0.92, cropXMax: 0.20, cropYMin: -2, cropYMax: 4, cropZMin: 0.40, cropZMax: 0.405).normalized()
        XCTAssertEqual(settings.exposureEV, 2)
        XCTAssertEqual(settings.contrast, 0.5)
        XCTAssertGreaterThanOrEqual(settings.cropXMin, 0)
        XCTAssertLessThanOrEqual(settings.cropXMax, 1)
        XCTAssertGreaterThanOrEqual(settings.cropXMax - settings.cropXMin, 0.0199)
        XCTAssertEqual(settings.cropYMin, 0)
        XCTAssertEqual(settings.cropYMax, 1)
        XCTAssertGreaterThanOrEqual(settings.cropZMax - settings.cropZMin, 0.0199)
    }

    func testEditSettingsRoundTripThroughJSON() throws {
        let expected = SplatEditSettings(exposureEV: 0.7, contrast: 1.25, cropXMin: 0.1, cropXMax: 0.9, cropYMin: 0.2, cropYMax: 0.8, cropZMin: 0.05, cropZMax: 0.95)
        let data = try JSONEncoder().encode(expected)
        XCTAssertEqual(try JSONDecoder().decode(SplatEditSettings.self, from: data), expected)
    }

    func testOlderSparseViewerJSONKeepsMissingFieldsAtSafeDefaults() throws {
        let legacyJSON = Data(#"{"exposureEV":0.6,"contrast":1.2}"#.utf8)
        let decoded = try JSONDecoder().decode(SplatEditSettings.self, from: legacyJSON).normalized()
        XCTAssertEqual(decoded.exposureEV, 0.6)
        XCTAssertEqual(decoded.contrast, 1.2)
        XCTAssertEqual(decoded.cropXMin, 0)
        XCTAssertEqual(decoded.cropXMax, 1)
        XCTAssertEqual(decoded.cropYMin, 0)
        XCTAssertEqual(decoded.cropYMax, 1)
        XCTAssertEqual(decoded.cropZMin, 0)
        XCTAssertEqual(decoded.cropZMax, 1)
        XCTAssertFalse(decoded.hasCrop)
    }

    func testFirstViewerEditSaveSeedsRecoverableBackup() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("result.splat")
        try Data([0]).write(to: source)
        let first = SplatEditSettings(exposureEV: 0.45, contrast: 1.15, cropXMin: 0.1, cropXMax: 0.9)

        try SplatViewerEditStore.save(first, sourceURL: source)
        XCTAssertTrue(FileManager.default.fileExists(atPath: SplatViewerEditStore.backupURL(for: source).path))
        try Data("corrupt".utf8).write(to: SplatViewerEditStore.primaryURL(for: source), options: .atomic)

        let recovered = try XCTUnwrap(SplatViewerEditStore.load(sourceURL: source))
        XCTAssertTrue(recovered.recoveredFromBackup)
        XCTAssertEqual(recovered.settings, first.normalized())
    }

    func testViewerEditStoreRecoversLastKnownGoodSettingsFromBackup() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("result.splat")
        try Data([0]).write(to: source)
        let first = SplatEditSettings(exposureEV: 0.4, contrast: 1.1, cropXMin: 0.1, cropXMax: 0.9, cropYMin: 0, cropYMax: 1, cropZMin: 0, cropZMax: 1)
        let second = SplatEditSettings(exposureEV: -0.5, contrast: 0.9, cropXMin: 0.2, cropXMax: 0.8, cropYMin: 0.1, cropYMax: 0.9, cropZMin: 0, cropZMax: 1)
        try SplatViewerEditStore.save(first, sourceURL: source)
        try SplatViewerEditStore.save(second, sourceURL: source)
        try Data("corrupt".utf8).write(to: SplatViewerEditStore.primaryURL(for: source), options: .atomic)

        let recovered = try XCTUnwrap(SplatViewerEditStore.load(sourceURL: source))
        XCTAssertTrue(recovered.recoveredFromBackup)
        XCTAssertEqual(recovered.settings, first.normalized())
        let healed = try JSONDecoder().decode(SplatEditSettings.self, from: Data(contentsOf: SplatViewerEditStore.primaryURL(for: source)))
        XCTAssertEqual(healed, first.normalized())
    }

    func testViewerEditStoreDoesNotOverwriteGoodBackupWithCorruptPrimary() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("result.splat")
        try Data([0]).write(to: source)
        let good = SplatEditSettings(exposureEV: 0.2, contrast: 1.2, cropXMin: 0, cropXMax: 1, cropYMin: 0, cropYMax: 1, cropZMin: 0.1, cropZMax: 0.9)
        let newer = SplatEditSettings(exposureEV: 0.8, contrast: 1.3, cropXMin: 0.1, cropXMax: 0.9, cropYMin: 0, cropYMax: 1, cropZMin: 0, cropZMax: 1)
        try SplatViewerEditStore.save(good, sourceURL: source)
        try SplatViewerEditStore.save(newer, sourceURL: source)
        let backupBefore = try Data(contentsOf: SplatViewerEditStore.backupURL(for: source))
        try Data("bad".utf8).write(to: SplatViewerEditStore.primaryURL(for: source), options: .atomic)
        try SplatViewerEditStore.save(newer, sourceURL: source)
        XCTAssertEqual(try Data(contentsOf: SplatViewerEditStore.backupURL(for: source)), backupBefore)
    }

    func testViewerEditStoreReseedsCorruptBackupAfterSuccessfulSave() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("result.splat")
        try Data([0]).write(to: source)
        let expected = SplatEditSettings(exposureEV: -0.25, contrast: 1.3, cropYMin: 0.1, cropYMax: 0.9).normalized()

        try Data("truncated-backup".utf8).write(to: SplatViewerEditStore.backupURL(for: source), options: .atomic)
        try SplatViewerEditStore.save(expected, sourceURL: source)
        try Data("corrupt-primary".utf8).write(to: SplatViewerEditStore.primaryURL(for: source), options: .atomic)

        let recovered = try XCTUnwrap(SplatViewerEditStore.load(sourceURL: source))
        XCTAssertTrue(recovered.recoveredFromBackup)
        XCTAssertEqual(recovered.settings, expected)
    }

    @MainActor
    func testSwitchingScansFlushesPendingEditsToPreviousScan() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let firstSource = root.appendingPathComponent("first.splat")
        let secondSource = root.appendingPathComponent("second.splat")
        try Data([0]).write(to: firstSource)
        try Data([0]).write(to: secondSource)

        let state = SplatViewerState()
        state.attach(url: firstSource)
        state.exposureEV = 0.8
        state.contrast = 1.25
        state.schedulePersistence()

        // Switch immediately, before the 220 ms debounce can fire. The old settings must be
        // flushed to first.splat rather than cancelled or written into second.splat.
        state.attach(url: secondSource)

        let firstSaved = try XCTUnwrap(SplatViewerEditStore.load(sourceURL: firstSource))
        XCTAssertEqual(firstSaved.settings.exposureEV, 0.8, accuracy: 0.0001)
        XCTAssertEqual(firstSaved.settings.contrast, 1.25, accuracy: 0.0001)
        XCTAssertNil(SplatViewerEditStore.load(sourceURL: secondSource))
        XCTAssertEqual(state.editSettings, .default)
    }

    func testMeasurementFormattingUsesPracticalUnits() {
        XCTAssertEqual(SplatMeasurementFormatter.string(meters: 0.004), "4.0 mm")
        XCTAssertEqual(SplatMeasurementFormatter.string(meters: 0.245), "24.5 cm")
        XCTAssertEqual(SplatMeasurementFormatter.string(meters: 1.25), "1.25 m")
    }

    func testSceneNormalizationMatchesMsplatScaleAndCenter() {
        let positions: [SIMD3<Float>] = [SIMD3<Float>(-0.20, 0.00, 1.50), SIMD3<Float>(0.00, 0.10, 1.45), SIMD3<Float>(0.20, 0.00, 1.50)]
        let normalization = SplatSceneNormalization(cameraPositions: positions)
        XCTAssertEqual(normalization.scale, 5.0, accuracy: 0.0001)
        XCTAssertEqual(normalization.metersPerSceneUnit, 0.20, accuracy: 0.0001)
        XCTAssertEqual(normalization.normalized(positions[0]).x, -1.0, accuracy: 0.0001)
        XCTAssertEqual(normalization.normalized(positions[2]).x, 1.0, accuracy: 0.0001)
        let normalizedDistance = simd_distance(normalization.normalized(positions[0]), normalization.normalized(positions[2]))
        XCTAssertEqual(normalizedDistance * normalization.metersPerSceneUnit, 0.40, accuracy: 0.0001)
    }
}
