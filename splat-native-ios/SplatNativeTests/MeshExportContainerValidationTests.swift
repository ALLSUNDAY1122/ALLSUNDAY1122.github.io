import Foundation
import XCTest

final class MeshExportContainerValidationTests: XCTestCase {
    func testGLBPassthroughRejectsMagicOnlyPayloadWithWrongDeclaredLength() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-glb-length-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var bytes = Data([0x67, 0x6c, 0x54, 0x46]) // glTF
        bytes.append(contentsOf: [0x02, 0x00, 0x00, 0x00]) // version 2
        bytes.append(contentsOf: [0x20, 0x00, 0x00, 0x00]) // claims 32 bytes, only 12 exist
        let source = root.appendingPathComponent("truncated.glb")
        try bytes.write(to: source, options: .atomic)

        do {
            _ = try await MeshExportService.export(sourceURL: source, format: .glb, destinationDirectory: root)
            XCTFail("Expected mismatched GLB byte length to be rejected")
        } catch let error as MeshExportService.ExportError {
            guard case .invalidContainer("glb") = error else {
                return XCTFail("Expected invalidContainer(glb), got \(error)")
            }
        }
    }

    func testGLBPassthroughRejectsHeaderOnlyVersionTwoPayload() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-glb-v2-header-only-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var bytes = Data([0x67, 0x6c, 0x54, 0x46]) // glTF
        bytes.append(contentsOf: [0x02, 0x00, 0x00, 0x00]) // GLB v2
        bytes.append(contentsOf: [0x0c, 0x00, 0x00, 0x00]) // exact 12-byte file, but no required JSON chunk
        let source = root.appendingPathComponent("header-only.glb")
        try bytes.write(to: source, options: .atomic)

        do {
            _ = try await MeshExportService.export(sourceURL: source, format: .glb, destinationDirectory: root)
            XCTFail("Expected GLB v2 without a JSON chunk to be rejected")
        } catch let error as MeshExportService.ExportError {
            guard case .invalidContainer("glb") = error else {
                return XCTFail("Expected invalidContainer(glb), got \(error)")
            }
        }
    }

    func testGLBPassthroughRejectsNonJSONFirstChunk() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-glb-v2-bin-first-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var bytes = Data([0x67, 0x6c, 0x54, 0x46]) // glTF
        bytes.append(contentsOf: [0x02, 0x00, 0x00, 0x00]) // GLB v2
        bytes.append(contentsOf: [0x18, 0x00, 0x00, 0x00]) // 24 bytes total
        bytes.append(contentsOf: [0x04, 0x00, 0x00, 0x00]) // 4-byte first chunk
        bytes.append(contentsOf: [0x42, 0x49, 0x4e, 0x00]) // BIN, invalid as first GLB v2 chunk
        bytes.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        let source = root.appendingPathComponent("bin-first.glb")
        try bytes.write(to: source, options: .atomic)

        do {
            _ = try await MeshExportService.export(sourceURL: source, format: .glb, destinationDirectory: root)
            XCTFail("Expected GLB v2 with a non-JSON first chunk to be rejected")
        } catch let error as MeshExportService.ExportError {
            guard case .invalidContainer("glb") = error else {
                return XCTFail("Expected invalidContainer(glb), got \(error)")
            }
        }
    }

    func testGLBPassthroughAcceptsMinimalValidVersionTwoJSONChunk() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-glb-v2-minimal-valid-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var bytes = Data([0x67, 0x6c, 0x54, 0x46]) // glTF
        bytes.append(contentsOf: [0x02, 0x00, 0x00, 0x00]) // GLB v2
        bytes.append(contentsOf: [0x18, 0x00, 0x00, 0x00]) // 24 bytes total
        bytes.append(contentsOf: [0x04, 0x00, 0x00, 0x00]) // 4-byte JSON chunk
        bytes.append(contentsOf: [0x4a, 0x53, 0x4f, 0x4e]) // JSON
        bytes.append(contentsOf: [0x7b, 0x7d, 0x20, 0x20]) // "{}  "
        let source = root.appendingPathComponent("minimal-valid.glb")
        try bytes.write(to: source, options: .atomic)

        let output = try await MeshExportService.export(
            sourceURL: source,
            format: .glb,
            destinationDirectory: root
        )
        XCTAssertEqual(try Data(contentsOf: output), bytes)
    }

    func testGLBPassthroughRejectsTruncatedVersionOneHeader() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-glb-v1-truncated-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var bytes = Data([0x67, 0x6c, 0x54, 0x46]) // glTF
        bytes.append(contentsOf: [0x01, 0x00, 0x00, 0x00]) // GLB v1
        bytes.append(contentsOf: [0x0c, 0x00, 0x00, 0x00]) // claims 12-byte file; v1 header requires 20
        let source = root.appendingPathComponent("truncated-v1.glb")
        try bytes.write(to: source, options: .atomic)

        do {
            _ = try await MeshExportService.export(sourceURL: source, format: .glb, destinationDirectory: root)
            XCTFail("Expected truncated GLB v1 header to be rejected")
        } catch let error as MeshExportService.ExportError {
            guard case .invalidContainer("glb") = error else {
                return XCTFail("Expected invalidContainer(glb), got \(error)")
            }
        }
    }

    func testGLBPassthroughRejectsUnsupportedVersion() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-glb-version-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var bytes = Data([0x67, 0x6c, 0x54, 0x46]) // glTF
        bytes.append(contentsOf: [0x03, 0x00, 0x00, 0x00]) // unsupported GLB v3
        bytes.append(contentsOf: [0x0c, 0x00, 0x00, 0x00])
        let source = root.appendingPathComponent("future.glb")
        try bytes.write(to: source, options: .atomic)

        do {
            _ = try await MeshExportService.export(sourceURL: source, format: .glb, destinationDirectory: root)
            XCTFail("Expected unsupported GLB version to be rejected")
        } catch let error as MeshExportService.ExportError {
            guard case .invalidContainer("glb") = error else {
                return XCTFail("Expected invalidContainer(glb), got \(error)")
            }
        }
    }

    func testUSDZPassthroughRejectsTruncatedZipSignatureOnly() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-usdz-truncated-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("truncated.usdz")
        try Data([0x50, 0x4b, 0x03, 0x04]).write(to: source, options: .atomic)

        do {
            _ = try await MeshExportService.export(sourceURL: source, format: .usdz, destinationDirectory: root)
            XCTFail("Expected truncated USDZ archive to be rejected")
        } catch let error as MeshExportService.ExportError {
            guard case .invalidContainer("usdz") = error else {
                return XCTFail("Expected invalidContainer(usdz), got \(error)")
            }
        }
    }

    func testUSDZPassthroughRejectsEOCDWithoutCentralDirectoryEntries() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-usdz-empty-directory-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var bytes = Data([0x50, 0x4b, 0x03, 0x04]) // fake local-file signature
        bytes.append(contentsOf: [
            0x50, 0x4b, 0x05, 0x06, // EOCD
            0x00, 0x00, 0x00, 0x00, // disk numbers
            0x00, 0x00, 0x00, 0x00, // zero entries
            0x00, 0x00, 0x00, 0x00, // central-directory size
            0x00, 0x00, 0x00, 0x00, // central-directory offset
            0x00, 0x00              // comment length
        ])
        let source = root.appendingPathComponent("fake-empty.usdz")
        try bytes.write(to: source, options: .atomic)

        do {
            _ = try await MeshExportService.export(sourceURL: source, format: .usdz, destinationDirectory: root)
            XCTFail("Expected USDZ without central-directory entries to be rejected")
        } catch let error as MeshExportService.ExportError {
            guard case .invalidContainer("usdz") = error else {
                return XCTFail("Expected invalidContainer(usdz), got \(error)")
            }
        }
    }

    func testUSDZPassthroughAcceptsStructurallyConsistentSingleEntryZip() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-usdz-structural-valid-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var bytes = Data([
            0x50, 0x4b, 0x03, 0x04, // local file header
            0x14, 0x00,             // version needed
            0x00, 0x00,             // flags
            0x00, 0x00,             // stored
            0x00, 0x00, 0x00, 0x00, // time/date
            0x00, 0x00, 0x00, 0x00, // crc32
            0x00, 0x00, 0x00, 0x00, // compressed size
            0x00, 0x00, 0x00, 0x00, // uncompressed size
            0x01, 0x00,             // filename length
            0x00, 0x00,             // extra length
            0x61                    // filename "a"
        ])
        bytes.append(contentsOf: [
            0x50, 0x4b, 0x01, 0x02, // central directory header
            0x14, 0x00,             // version made by
            0x14, 0x00,             // version needed
            0x00, 0x00,             // flags
            0x00, 0x00,             // stored
            0x00, 0x00, 0x00, 0x00, // time/date
            0x00, 0x00, 0x00, 0x00, // crc32
            0x00, 0x00, 0x00, 0x00, // compressed size
            0x00, 0x00, 0x00, 0x00, // uncompressed size
            0x01, 0x00,             // filename length
            0x00, 0x00,             // extra length
            0x00, 0x00,             // comment length
            0x00, 0x00,             // disk start
            0x00, 0x00,             // internal attributes
            0x00, 0x00, 0x00, 0x00, // external attributes
            0x00, 0x00, 0x00, 0x00, // local header offset
            0x61                    // filename "a"
        ])
        bytes.append(contentsOf: [
            0x50, 0x4b, 0x05, 0x06, // EOCD
            0x00, 0x00,             // disk number
            0x00, 0x00,             // central-directory disk
            0x01, 0x00,             // entries on disk
            0x01, 0x00,             // total entries
            0x2f, 0x00, 0x00, 0x00, // central-directory size = 47
            0x1f, 0x00, 0x00, 0x00, // central-directory offset = 31
            0x00, 0x00              // comment length
        ])

        let source = root.appendingPathComponent("structural-valid.usdz")
        try bytes.write(to: source, options: .atomic)
        let output = try await MeshExportService.export(
            sourceURL: source,
            format: .usdz,
            destinationDirectory: root
        )
        XCTAssertEqual(try Data(contentsOf: output), bytes)
    }

    func testSTLPassthroughRejectsArbitraryEightyFourBytePayload() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-stl-validation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("fake.stl")
        try Data(repeating: 0, count: 84).write(to: source, options: .atomic)

        do {
            _ = try await MeshExportService.export(
                sourceURL: source,
                format: .stl,
                destinationDirectory: root
            )
            XCTFail("Expected invalid STL payload to be rejected")
        } catch let error as MeshExportService.ExportError {
            guard case .invalidContainer("stl") = error else {
                return XCTFail("Expected invalidContainer(stl), got \(error)")
            }
        }
    }

    func testSTLPassthroughRejectsTruncatedBinaryTrianglePayload() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-stl-truncated-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var bytes = Data(repeating: 0, count: 84)
        bytes[80] = 1 // binary STL declares one 50-byte triangle but provides none
        let source = root.appendingPathComponent("truncated.stl")
        try bytes.write(to: source, options: .atomic)

        do {
            _ = try await MeshExportService.export(
                sourceURL: source,
                format: .stl,
                destinationDirectory: root
            )
            XCTFail("Expected truncated STL payload to be rejected")
        } catch let error as MeshExportService.ExportError {
            guard case .invalidContainer("stl") = error else {
                return XCTFail("Expected invalidContainer(stl), got \(error)")
            }
        }
    }
}
