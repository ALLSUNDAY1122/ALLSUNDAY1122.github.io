import XCTest
import SplatIO
import simd

final class SplatExportServiceTests: XCTestCase {
    func testPLYAndSPZRoundTripThroughIndependentReaders() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("s6-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("result.splat")
        let sourcePoints = makePoints()
        let sourceWriter = try DotSplatSceneWriter(toFileAtPath: source.path)
        try await sourceWriter.write(sourcePoints)
        try await sourceWriter.close()

        XCTAssertEqual(try SplatExportService.sourcePointCount(source), sourcePoints.count)

        for format in SplatExportService.Format.allCases {
            let output = try await SplatExportService.export(sourceURL: source, format: format)
            XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
            XCTAssertGreaterThan(try byteCount(output), 0)

            let reader = try AutodetectSceneReader(output)
            let decoded = try await reader.readAll()
            XCTAssertEqual(decoded.count, sourcePoints.count)

            for (expected, actual) in zip(sourcePoints, decoded) {
                XCTAssertEqual(actual.position.x, expected.position.x, accuracy: 0.01)
                XCTAssertEqual(actual.position.y, expected.position.y, accuracy: 0.01)
                XCTAssertEqual(actual.position.z, expected.position.z, accuracy: 0.01)
                XCTAssertEqual(actual.opacity.asLinearFloat, expected.opacity.asLinearFloat, accuracy: 0.03)

                let expectedColor = expected.color.asSRGBFloat
                let actualColor = actual.color.asSRGBFloat
                XCTAssertEqual(actualColor.x, expectedColor.x, accuracy: 0.03)
                XCTAssertEqual(actualColor.y, expectedColor.y, accuracy: 0.03)
                XCTAssertEqual(actualColor.z, expectedColor.z, accuracy: 0.03)

                let expectedScale = expected.scale.asLinearFloat
                let actualScale = actual.scale.asLinearFloat
                XCTAssertEqual(actualScale.x, expectedScale.x, accuracy: 0.01)
                XCTAssertEqual(actualScale.y, expectedScale.y, accuracy: 0.01)
                XCTAssertEqual(actualScale.z, expectedScale.z, accuracy: 0.01)

                let expectedRotation = expected.rotation.normalized.vector
                let actualRotation = actual.rotation.normalized.vector
                let orientationAgreement = abs(simd_dot(expectedRotation, actualRotation))
                XCTAssertEqual(orientationAgreement, 1, accuracy: 0.03)
            }
        }
    }

    func testBrowserSharePackageContainsIntegrityCheckedSPZAndNoLocation() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("s6-package-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = try await makeCommittedProjectResult(in: root)
        let projectSideSPZ = source.deletingPathExtension().appendingPathExtension("spz")
        XCTAssertFalse(FileManager.default.fileExists(atPath: projectSideSPZ.path))

        let preview = Data([0xff, 0xd8, 0xff, 0xd9])
        let package = try await SplatExportService.makeBrowserSharePackage(
            sourceURL: source,
            previewJPEG: preview,
            rootDirectory: root
        )

        XCTAssertEqual(package.assetURL.lastPathComponent, "scene.spz")
        XCTAssertTrue(FileManager.default.fileExists(atPath: package.assetURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: package.manifestURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(package.previewURL).path))
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: projectSideSPZ.path),
            "Browser packaging must not create a second persistent SPZ beside the project result"
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(
            SplatExportService.BrowserShareManifest.self,
            from: Data(contentsOf: package.manifestURL)
        )
        let assetData = try Data(contentsOf: package.assetURL)

        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertEqual(manifest.representation, "gaussian-splat")
        XCTAssertEqual(manifest.primaryAsset.fileName, "scene.spz")
        XCTAssertEqual(manifest.primaryAsset.byteLength, assetData.count)
        XCTAssertEqual(manifest.primaryAsset.sha256, SplatExportService.sha256Hex(assetData))
        XCTAssertEqual(manifest.primaryAsset.sha256, try SplatExportService.sha256Hex(fileURL: package.assetURL))
        XCTAssertFalse(manifest.containsLocation)
    }

    func testBrowserSharePackageRejectsAlignedButUncommittedResult() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("s6-untrusted-package-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Uncommitted")
        let source = projectURL.appendingPathComponent(ScanProjectStore.splatResultFileName)
        let writer = try DotSplatSceneWriter(toFileAtPath: source.path)
        try await writer.write(makePoints())
        try await writer.close()
        _ = try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }

        do {
            _ = try await SplatExportService.makeBrowserSharePackage(
                sourceURL: source,
                rootDirectory: root
            )
            XCTFail("Expected untrusted completed-result gate to reject package creation")
        } catch {
            guard case SplatExportAdmission.AdmissionError.untrustedSource = error else {
                return XCTFail("Expected untrustedSource, got \(error)")
            }
        }
    }

    func testStreamingSHA256MatchesWholeDataAcrossMultipleChunks() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("s6-streaming-hash-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var data = Data(count: 2_500_123)
        for index in data.indices {
            data[index] = UInt8(truncatingIfNeeded: index &* 31 &+ 7)
        }
        let url = root.appendingPathComponent("large.spz")
        try data.write(to: url, options: .atomic)

        XCTAssertEqual(
            try SplatExportService.sha256Hex(fileURL: url),
            SplatExportService.sha256Hex(data)
        )
    }

    func testRejectsPartialDotSplatRecord() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("s6-corrupt-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("result.splat")
        try Data(repeating: 0, count: 33).write(to: source)

        XCTAssertThrowsError(try SplatExportService.sourcePointCount(source)) { error in
            guard case SplatExportService.ExportError.corruptSource = error else {
                return XCTFail("Expected corruptSource, got \(error)")
            }
        }
    }

    private func makeCommittedProjectResult(in root: URL) async throws -> URL {
        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Committed share")
        let pending = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        let writer = try DotSplatSceneWriter(toFileAtPath: pending.path)
        try await writer.write(makePoints())
        try await writer.close()
        let result = try store.commitPendingSplat(projectURL: projectURL)
        _ = try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
        }
        return result
    }

    private func makePoints() -> [SplatPoint] {
        [
            SplatPoint(
                position: SIMD3<Float>(-0.25, 0.10, 0.40),
                color: .sRGBUInt8(SIMD3<UInt8>(220, 70, 40)),
                opacity: .linearFloat(0.82),
                scale: .linearFloat(SIMD3<Float>(0.025, 0.030, 0.020)),
                rotation: simd_quatf(angle: 0.15, axis: SIMD3<Float>(0, 1, 0))
            ),
            SplatPoint(
                position: SIMD3<Float>(0.15, -0.05, 0.55),
                color: .sRGBUInt8(SIMD3<UInt8>(40, 190, 120)),
                opacity: .linearFloat(0.64),
                scale: .linearFloat(SIMD3<Float>(0.035, 0.018, 0.028)),
                rotation: simd_quatf(angle: -0.28, axis: SIMD3<Float>(1, 0, 0))
            ),
            SplatPoint(
                position: SIMD3<Float>(0.05, 0.22, 0.72),
                color: .sRGBUInt8(SIMD3<UInt8>(60, 110, 235)),
                opacity: .linearFloat(0.91),
                scale: .linearFloat(SIMD3<Float>(0.020, 0.020, 0.040)),
                rotation: simd_quatf(angle: 0.36, axis: simd_normalize(SIMD3<Float>(1, 1, 0)))
            ),
        ]
    }

    private func byteCount(_ url: URL) throws -> Int {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        return try XCTUnwrap(attrs[.size] as? NSNumber).intValue
    }
}
