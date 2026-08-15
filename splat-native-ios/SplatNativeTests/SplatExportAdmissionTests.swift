import XCTest

final class SplatExportAdmissionTests: XCTestCase {
    func testPLYReservesMoreWorkingSpaceThanSPZ() {
        let sourceBytes: Int64 = 96 * 1_024 * 1_024
        let ply = SplatExportAdmission.estimatedRequiredFreeBytes(sourceBytes: sourceBytes, kind: .ply)
        let spz = SplatExportAdmission.estimatedRequiredFreeBytes(sourceBytes: sourceBytes, kind: .spz)

        XCTAssertGreaterThan(ply, spz)
        XCTAssertGreaterThan(ply, sourceBytes)
        XCTAssertGreaterThan(spz, sourceBytes)
    }

    func testVideoEstimateGrowsWithDurationAndResolution() {
        let shortPortrait = SplatExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: 64 * 1_024 * 1_024,
            kind: .video(width: 720, height: 1280, framesPerSecond: 30, duration: 4)
        )
        let longHD = SplatExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: 64 * 1_024 * 1_024,
            kind: .video(width: 1920, height: 1080, framesPerSecond: 30, duration: 12)
        )

        XCTAssertGreaterThan(longHD, shortPortrait)
    }

    func testEstimateSaturatesInsteadOfOverflowing() {
        let required = SplatExportAdmission.estimatedRequiredFreeBytes(
            sourceBytes: Int64.max,
            kind: .ply
        )
        XCTAssertEqual(required, Int64.max)
    }

    func testPreflightRejectsBeforeExportWhenFreeSpaceIsInsufficient() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("c2-splat-low-storage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Low storage")
        let pending = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try Data(repeating: 0x51, count: 64).write(to: pending, options: .atomic)
        let result = try store.commitPendingSplat(projectURL: projectURL)
        _ = try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }

        do {
            _ = try SplatExportAdmission.preflight(
                sourceURL: result,
                kind: .ply,
                availableCapacityOverride: 0
            )
            XCTFail("Expected low-storage rejection")
        } catch let error as SplatExportAdmission.AdmissionError {
            guard case .insufficientStorage(let required, let available) = error else {
                return XCTFail("Expected insufficientStorage, got \(error)")
            }
            XCTAssertGreaterThan(required, 0)
            XCTAssertEqual(available, 0)
        }

        let children = try FileManager.default.contentsOfDirectory(at: projectURL, includingPropertiesForKeys: nil)
        XCTAssertFalse(children.contains { ["ply", "spz", "mp4"].contains($0.pathExtension.lowercased()) })
    }
}
