import XCTest
@testable import SplatNative

final class ScanLabPublishPackageTests: XCTestCase {
    func testBuildCreatesSceneAndConsistentManifest() throws {
        let source = temporaryFile(named: "input.spz", data: validSPZPayload())
        defer { try? FileManager.default.removeItem(at: source) }
        let package = try ScanLabPublishPackageBuilder.build(from: source)
        defer { ScanLabPublishPackageBuilder.cleanup(package) }
        XCTAssertEqual(package.sceneURL.lastPathComponent, "scene.spz")
        XCTAssertEqual(package.manifestURL.lastPathComponent, "manifest.json")
        XCTAssertEqual(package.manifest.sceneByteCount, Int64(validSPZPayload().count))
        XCTAssertEqual(package.manifest.sceneSHA256.count, 64)
        XCTAssertTrue(try ScanLabPublishPackageBuilder.verify(package))
    }

    func testRejectsLegacyArbitrarySplatBytes() throws {
        let source = temporaryFile(named: "result.splat", data: Data("not-spz".utf8))
        defer { try? FileManager.default.removeItem(at: source) }
        XCTAssertThrowsError(try ScanLabPublishPackageBuilder.build(from: source)) { error in
            XCTAssertEqual(error as? ScanLabPublishPackageError, .invalidSPZ)
        }
    }

    func testVerificationDetectsSceneMutation() throws {
        let source = temporaryFile(named: "input.spz", data: validSPZPayload())
        defer { try? FileManager.default.removeItem(at: source) }
        let package = try ScanLabPublishPackageBuilder.build(from: source)
        defer { ScanLabPublishPackageBuilder.cleanup(package) }
        try Data([0x1f, 0x8b, 0x08] + Array(repeating: 0, count: 20)).write(to: package.sceneURL, options: .atomic)
        XCTAssertFalse(try ScanLabPublishPackageBuilder.verify(package))
    }

    func testRejectsOverLimitBeforePackaging() throws {
        let source = temporaryFile(named: "input.spz", data: validSPZPayload())
        defer { try? FileManager.default.removeItem(at: source) }
        XCTAssertThrowsError(try ScanLabPublishPackageBuilder.build(from: source, maximumBytes: 8)) { error in
            XCTAssertEqual(error as? ScanLabPublishPackageError, .sourceTooLarge)
        }
    }

    private func validSPZPayload() -> Data { Data([0x1f, 0x8b, 0x08] + Array(repeating: 0, count: 32)) }
    private func temporaryFile(named name: String, data: Data) -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name); try! data.write(to: url); return url
    }
}
