import Foundation
import SplatIO
import XCTest
import simd

final class ScanLabPublishPackageCleanupTests: XCTestCase {
    func testStaleOwnedPackageIsPrunedButUnownedPrefixedDirectorySurvives() async throws {
        let fileManager = FileManager.default
        let source = try await temporaryValidSPZ()
        defer { try? fileManager.removeItem(at: source.deletingLastPathComponent()) }

        let package = try ScanLabPublishPackageBuilder.build(from: source, fileManager: fileManager)
        let root = package.directoryURL.deletingLastPathComponent()
        let unowned = root.appendingPathComponent("scanlab-publish-unowned-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: unowned, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: unowned) }

        let oldDate = Date(timeIntervalSinceNow: -(48 * 60 * 60))
        try fileManager.setAttributes([.modificationDate: oldDate], ofItemAtPath: package.directoryURL.path)
        try fileManager.setAttributes([.modificationDate: oldDate], ofItemAtPath: unowned.path)

        ScanLabPublishPackageBuilder.cleanupStalePackages(
            in: root,
            olderThan: 24 * 60 * 60,
            now: Date(),
            fileManager: fileManager
        )

        XCTAssertFalse(fileManager.fileExists(atPath: package.directoryURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: unowned.path))
    }

    func testRecentOwnedPackageIsNotPruned() async throws {
        let fileManager = FileManager.default
        let source = try await temporaryValidSPZ()
        defer { try? fileManager.removeItem(at: source.deletingLastPathComponent()) }

        let package = try ScanLabPublishPackageBuilder.build(from: source, fileManager: fileManager)
        defer { ScanLabPublishPackageBuilder.cleanup(package, fileManager: fileManager) }

        ScanLabPublishPackageBuilder.cleanupStalePackages(
            in: package.directoryURL.deletingLastPathComponent(),
            olderThan: 24 * 60 * 60,
            now: Date(),
            fileManager: fileManager
        )

        XCTAssertTrue(fileManager.fileExists(atPath: package.directoryURL.path))
    }

    private func temporaryValidSPZ() async throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanLabPublishCleanup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("input.spz")
        let writer = try SPZSceneWriter(toFileAtPath: url.path)
        try await writer.start(numPoints: 1)
        try await writer.write([
            SplatPoint(
                position: SIMD3<Float>(0.25, -0.5, 1.5),
                color: .sRGBUInt8(SIMD3<UInt8>(64, 128, 192)),
                opacity: .linearFloat(0.75),
                scale: .linearFloat(SIMD3<Float>(0.1, 0.2, 0.3)),
                rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
            )
        ])
        try await writer.close()
        return url
    }
}
