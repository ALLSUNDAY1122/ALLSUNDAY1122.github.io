import SplatIO
import XCTest
import simd

final class ScanLabPublishPackageTests: XCTestCase {
    func testBuildCreatesSceneAndConsistentManifestFromRealSPZ() async throws {
        let source = try await temporaryValidSPZ(); defer { removeTemporaryTree(containing: source) }
        let sourceData = try Data(contentsOf: source)
        let package = try ScanLabPublishPackageBuilder.build(from: source); defer { ScanLabPublishPackageBuilder.cleanup(package) }
        XCTAssertEqual(package.sceneURL.lastPathComponent, "scene.spz")
        XCTAssertEqual(package.manifestURL.lastPathComponent, "manifest.json")
        XCTAssertEqual(ScanLabPublishPackage.sceneMediaType, "application/octet-stream")
        XCTAssertEqual(package.manifest.mediaType, "application/vnd.scanlab.spz")
        XCTAssertEqual(package.manifest.sceneByteCount, Int64(sourceData.count))
        XCTAssertEqual(package.manifest.sceneSHA256.count, 64)
        XCTAssertTrue(try ScanLabPublishPackageBuilder.verify(package))
    }
    func testRejectsLegacyArbitrarySplatBytes() throws {
        let source = temporaryFile(named: "result.splat", data: Data("not-spz".utf8)); defer { removeTemporaryTree(containing: source) }
        XCTAssertThrowsError(try ScanLabPublishPackageBuilder.build(from: source)) { XCTAssertEqual($0 as? ScanLabPublishPackageError, .invalidSPZ) }
    }
    func testRejectsFakeGzipHeaderThatIsNotSPZ() throws {
        let source = temporaryFile(named: "fake.spz", data: Data([0x1f,0x8b,0x08] + Array(repeating: 0, count: 32))); defer { removeTemporaryTree(containing: source) }
        XCTAssertThrowsError(try ScanLabPublishPackageBuilder.build(from: source)) { XCTAssertEqual($0 as? ScanLabPublishPackageError, .invalidSPZ) }
    }
    func testVerificationDetectsSceneMutation() async throws {
        let source = try await temporaryValidSPZ(); defer { removeTemporaryTree(containing: source) }
        let package = try ScanLabPublishPackageBuilder.build(from: source); defer { ScanLabPublishPackageBuilder.cleanup(package) }
        var mutated = try Data(contentsOf: package.sceneURL); mutated[mutated.index(before: mutated.endIndex)] ^= 0xff; try mutated.write(to: package.sceneURL, options: .atomic)
        XCTAssertFalse(try ScanLabPublishPackageBuilder.verify(package))
    }
    func testVerificationDetectsManifestMutation() async throws {
        let source = try await temporaryValidSPZ(); defer { removeTemporaryTree(containing: source) }
        let package = try ScanLabPublishPackageBuilder.build(from: source); defer { ScanLabPublishPackageBuilder.cleanup(package) }
        let manifest = package.manifest
        let invalid = ScanLabPublishManifest(schemaVersion: manifest.schemaVersion, sceneFile: manifest.sceneFile, sceneByteCount: manifest.sceneByteCount + 1, sceneSHA256: manifest.sceneSHA256, mediaType: manifest.mediaType, createdAt: manifest.createdAt)
        try JSONEncoder().encode(invalid).write(to: package.manifestURL, options: .atomic)
        XCTAssertFalse(try ScanLabPublishPackageBuilder.verify(package))
    }
    func testRejectsOverLimitBeforePackaging() async throws {
        let source = try await temporaryValidSPZ(); defer { removeTemporaryTree(containing: source) }
        XCTAssertThrowsError(try ScanLabPublishPackageBuilder.build(from: source, maximumBytes: 8)) { XCTAssertEqual($0 as? ScanLabPublishPackageError, .sourceTooLarge) }
    }
    func testRejectsSymlinkedSourceOutsideProject() async throws {
        let fileManager = FileManager.default
        let source = try await temporaryValidSPZ()
        let sourceDirectory = source.deletingLastPathComponent()
        let aliasDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: aliasDirectory, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: sourceDirectory)
            try? fileManager.removeItem(at: aliasDirectory)
        }
        let alias = aliasDirectory.appendingPathComponent("input.spz")
        try fileManager.createSymbolicLink(at: alias, withDestinationURL: source)
        XCTAssertThrowsError(try ScanLabPublishPackageBuilder.build(from: alias)) {
            XCTAssertEqual($0 as? ScanLabPublishPackageError, .invalidSource)
        }
    }
    func testVerificationRejectsAliasedScene() async throws {
        let fileManager = FileManager.default
        let source = try await temporaryValidSPZ(); defer { removeTemporaryTree(containing: source) }
        let package = try ScanLabPublishPackageBuilder.build(from: source); defer { ScanLabPublishPackageBuilder.cleanup(package) }
        let external = fileManager.temporaryDirectory.appendingPathComponent("publish-scene-\(UUID().uuidString).spz")
        try fileManager.copyItem(at: package.sceneURL, to: external)
        defer { try? fileManager.removeItem(at: external) }
        try fileManager.removeItem(at: package.sceneURL)
        try fileManager.createSymbolicLink(at: package.sceneURL, withDestinationURL: external)
        XCTAssertFalse(try ScanLabPublishPackageBuilder.verify(package))
    }
    func testCleanupRefusesUnownedNamespacedDirectory() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent("scanlab-publish-unowned-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let sentinel = directory.appendingPathComponent("keep.dat")
        try Data([0x41]).write(to: sentinel)
        defer { try? fileManager.removeItem(at: directory) }
        let package = ScanLabPublishPackage(
            directoryURL: directory,
            sceneURL: directory.appendingPathComponent("scene.spz"),
            manifestURL: directory.appendingPathComponent("manifest.json"),
            manifest: ScanLabPublishManifest(schemaVersion: 1, sceneFile: "scene.spz", sceneByteCount: 1, sceneSHA256: String(repeating: "0", count: 64), mediaType: "application/vnd.scanlab.spz", createdAt: "2026-09-12T00:00:00Z")
        )
        ScanLabPublishPackageBuilder.cleanup(package, fileManager: fileManager)
        XCTAssertTrue(fileManager.fileExists(atPath: sentinel.path))
    }
    private func temporaryValidSPZ() async throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("input.spz")
        let writer = try SPZSceneWriter(toFileAtPath: url.path); try await writer.start(numPoints: 1)
        try await writer.write([SplatPoint(position: SIMD3<Float>(0.25,-0.5,1.5), color: .sRGBUInt8(SIMD3<UInt8>(64,128,192)), opacity: .linearFloat(0.75), scale: .linearFloat(SIMD3<Float>(0.1,0.2,0.3)), rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0,1,0)))])
        try await writer.close(); return url
    }
    private func temporaryFile(named name: String, data: Data) -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true); try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name); try! data.write(to: url); return url
    }
    private func removeTemporaryTree(containing url: URL) { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
}
