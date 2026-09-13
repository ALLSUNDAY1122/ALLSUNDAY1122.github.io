import XCTest

final class SplatViewerPartialCorruptionTests: XCTestCase {
    func testPartialPrimaryCorruptionPreservesNewerValidSiblingFields() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let source = root.appendingPathComponent("result.splat")
        try Data([0]).write(to: source)
        let older = SplatEditSettings(
            exposureEV: -0.6,
            contrast: 1.25,
            cropXMin: 0.05,
            cropXMax: 0.95
        )
        try SplatViewerEditStore.save(older, sourceURL: source)

        let partiallyDamaged = Data(#"{"exposureEV":0.8,"contrast":"damaged","cropXMin":0.2,"cropXMax":0.8,"cropYMin":0.1,"cropYMax":0.9,"cropZMin":0,"cropZMax":1}"#.utf8)
        try partiallyDamaged.write(to: SplatViewerEditStore.primaryURL(for: source), options: .atomic)

        let loaded = try XCTUnwrap(SplatViewerEditStore.load(sourceURL: source))
        XCTAssertFalse(loaded.recoveredFromBackup)
        XCTAssertEqual(loaded.settings.exposureEV, 0.8, accuracy: 0.0001)
        XCTAssertEqual(loaded.settings.contrast, 1, accuracy: 0.0001)
        XCTAssertEqual(loaded.settings.cropXMin, 0.2, accuracy: 0.0001)
        XCTAssertEqual(loaded.settings.cropXMax, 0.8, accuracy: 0.0001)
        XCTAssertEqual(loaded.settings.cropYMin, 0.1, accuracy: 0.0001)
        XCTAssertEqual(loaded.settings.cropYMax, 0.9, accuracy: 0.0001)
    }

    func testBroadPrimaryCorruptionPrefersLastKnownGoodBackup() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let source = root.appendingPathComponent("result.splat")
        try Data([0]).write(to: source)
        let expected = SplatEditSettings(
            exposureEV: -0.4,
            contrast: 1.2,
            cropXMin: 0.08,
            cropXMax: 0.92,
            cropYMin: 0.12,
            cropYMax: 0.88,
            cropZMin: 0.18,
            cropZMax: 0.82
        ).normalized()
        try SplatViewerEditStore.save(expected, sourceURL: source)

        let broadlyDamaged = Data(#"{"exposureEV":0.9,"contrast":"bad","cropXMin":"bad","cropXMax":"bad","cropYMin":"bad","cropYMax":"bad","cropZMin":"bad","cropZMax":"bad"}"#.utf8)
        try broadlyDamaged.write(to: SplatViewerEditStore.primaryURL(for: source), options: .atomic)

        let loaded = try XCTUnwrap(SplatViewerEditStore.load(sourceURL: source))
        XCTAssertTrue(loaded.recoveredFromBackup)
        XCTAssertEqual(loaded.settings, expected)
    }

    func testWeakPrimarySalvageIsUsedWhenNoHealthyBackupExists() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let source = root.appendingPathComponent("result.splat")
        try Data([0]).write(to: source)
        let weakPrimary = Data(#"{"exposureEV":0.7,"contrast":"bad","cropXMin":"bad","cropXMax":"bad","cropYMin":"bad","cropYMax":"bad","cropZMin":"bad","cropZMax":"bad"}"#.utf8)
        try weakPrimary.write(to: SplatViewerEditStore.primaryURL(for: source), options: .atomic)

        let loaded = try XCTUnwrap(SplatViewerEditStore.load(sourceURL: source))
        XCTAssertFalse(loaded.recoveredFromBackup)
        XCTAssertEqual(loaded.settings.exposureEV, 0.7, accuracy: 0.0001)
        XCTAssertEqual(loaded.settings.contrast, 1, accuracy: 0.0001)
        XCTAssertEqual(loaded.settings.cropXMin, 0, accuracy: 0.0001)
        XCTAssertEqual(loaded.settings.cropXMax, 1, accuracy: 0.0001)
    }

    func testPrimaryWithNoUsableKnownFieldStillFallsBackToLastKnownGoodBackup() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let source = root.appendingPathComponent("result.splat")
        try Data([0]).write(to: source)
        let expected = SplatEditSettings(
            exposureEV: -0.35,
            contrast: 1.3,
            cropZMin: 0.15,
            cropZMax: 0.85
        ).normalized()
        try SplatViewerEditStore.save(expected, sourceURL: source)

        let unusable = Data(#"{"exposureEV":"bad","contrast":"bad","cropXMin":"bad"}"#.utf8)
        try unusable.write(to: SplatViewerEditStore.primaryURL(for: source), options: .atomic)

        let loaded = try XCTUnwrap(SplatViewerEditStore.load(sourceURL: source))
        XCTAssertTrue(loaded.recoveredFromBackup)
        XCTAssertEqual(loaded.settings, expected)
    }
}
