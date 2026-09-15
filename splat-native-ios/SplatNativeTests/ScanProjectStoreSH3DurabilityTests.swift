import Foundation
import XCTest

extension ScanProjectStoreTests {
    func testClearRawDataRetainsRegisteredSH3CanonicalGenerations() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("s7-sh3-durability-\(UUID().uuidString)", isDirectory: true)
        let store = ScanProjectStore(rootURL: root)
        defer { try? FileManager.default.removeItem(at: root) }

        let (projectURL, _) = try store.createProject(title: "SH3 durable")
        let pendingSplat = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try Data(repeating: 1, count: 32).write(to: pendingSplat, options: .atomic)

        let firstURL = projectURL.appendingPathComponent("result.sh3-first.ply")
        let secondURL = projectURL.appendingPathComponent("result.sh3-second.ply")
        try Data("first-sh3".utf8).write(to: firstURL, options: .atomic)
        try Data("second-sh3".utf8).write(to: secondURL, options: .atomic)

        let descriptor = SplatCanonicalSHAsset.Descriptor(
            pointCount: 1,
            shDegree: 3,
            higherOrderPropertyCount: 45
        )
        _ = try SplatCanonicalSHAsset.registerDurableProjectOutput(
            .init(url: firstURL, descriptor: descriptor),
            legacySplatURL: pendingSplat,
            store: store
        )
        _ = try SplatCanonicalSHAsset.registerDurableProjectOutput(
            .init(url: secondURL, descriptor: descriptor),
            legacySplatURL: pendingSplat,
            store: store
        )

        let disposableRaw = projectURL.appendingPathComponent("temporary-raw.bin")
        try Data(repeating: 9, count: 128).write(to: disposableRaw, options: .atomic)

        try store.clearRawData(projectURL: projectURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: firstURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: disposableRaw.path))

        let manifest = try store.loadManifest(projectURL: projectURL)
        let canonicalOutputs = manifest.outputs
            .filter { $0.key.hasPrefix(SplatCanonicalSHAsset.manifestOutputKeyPrefix) }
            .map(\.value)
        XCTAssertEqual(Set(canonicalOutputs), Set([firstURL.lastPathComponent, secondURL.lastPathComponent]))
    }
}
