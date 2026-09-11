import Foundation
import XCTest

final class MeshExportContainerValidationTests: XCTestCase {
    func testGLBPassthroughRejectsMagicOnlyPayloadWithWrongDeclaredLength() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mesh-glb-length-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var bytes = Data([0x67, 0x6c, 0x54, 0x46])
        bytes.append(contentsOf: [0x02, 0x00, 0x00, 0x00])
        bytes.append(contentsOf: [0x20, 0x00, 0x00, 0x00])
        let source = root.appendingPathComponent("truncated.glb")
        try bytes.write(to: source, options: .atomic)
        do {
            _ = try await MeshExportService.export(sourceURL: source, format: .glb, destinationDirectory: root)
            XCTFail("Expected mismatched GLB byte length to be rejected")
        } catch let error as MeshExportService.ExportError {
            guard case .invalidContainer("glb") = error else { return XCTFail("Expected invalidContainer(glb), got \(error)") }
        }
    }

    func testGLBPassthroughRejectsTruncatedVersionOneHeader() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mesh-glb-v1-truncated-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var bytes = Data([0x67, 0x6c, 0x54, 0x46])
        bytes.append(contentsOf: [0x01, 0x00, 0x00, 0x00])
        bytes.append(contentsOf: [0x0c, 0x00, 0x00, 0x00])
        let source = root.appendingPathComponent("truncated-v1.glb")
        try bytes.write(to: source, options: .atomic)
        do {
            _ = try await MeshExportService.export(sourceURL: source, format: .glb, destinationDirectory: root)
            XCTFail("Expected truncated GLB v1 header to be rejected")
        } catch let error as MeshExportService.ExportError {
            guard case .invalidContainer("glb") = error else { return XCTFail("Expected invalidContainer(glb), got \(error)") }
        }
    }

    func testGLBPassthroughRejectsUnsupportedVersion() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mesh-glb-version-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var bytes = Data([0x67, 0x6c, 0x54, 0x46])
        bytes.append(contentsOf: [0x03, 0x00, 0x00, 0x00])
        bytes.append(contentsOf: [0x0c, 0x00, 0x00, 0x00])
        let source = root.appendingPathComponent("future.glb")
        try bytes.write(to: source, options: .atomic)
        do {
            _ = try await MeshExportService.export(sourceURL: source, format: .glb, destinationDirectory: root)
            XCTFail("Expected unsupported GLB version to be rejected")
        } catch let error as MeshExportService.ExportError {
            guard case .invalidContainer("glb") = error else { return XCTFail("Expected invalidContainer(glb), got \(error)") }
        }
    }

    func testUSDZPassthroughRejectsTruncatedZipSignatureOnly() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mesh-usdz-truncated-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("truncated.usdz")
        try Data([0x50, 0x4b, 0x03, 0x04]).write(to: source, options: .atomic)
        do {
            _ = try await MeshExportService.export(sourceURL: source, format: .usdz, destinationDirectory: root)
            XCTFail("Expected truncated USDZ archive to be rejected")
        } catch let error as MeshExportService.ExportError {
            guard case .invalidContainer("usdz") = error else { return XCTFail("Expected invalidContainer(usdz), got \(error)") }
        }
    }

    func testSTLPassthroughRejectsArbitraryEightyFourBytePayload() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mesh-stl-validation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("fake.stl")
        try Data(repeating: 0, count: 84).write(to: source, options: .atomic)
        do {
            _ = try await MeshExportService.export(sourceURL: source, format: .stl, destinationDirectory: root)
            XCTFail("Expected invalid STL payload to be rejected")
        } catch let error as MeshExportService.ExportError {
            guard case .invalidContainer("stl") = error else { return XCTFail("Expected invalidContainer(stl), got \(error)") }
        }
    }

    func testSTLPassthroughRejectsTruncatedBinaryTrianglePayload() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mesh-stl-truncated-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var bytes = Data(repeating: 0, count: 84)
        bytes[80] = 1
        let source = root.appendingPathComponent("truncated.stl")
        try bytes.write(to: source, options: .atomic)
        do {
            _ = try await MeshExportService.export(sourceURL: source, format: .stl, destinationDirectory: root)
            XCTFail("Expected truncated STL payload to be rejected")
        } catch let error as MeshExportService.ExportError {
            guard case .invalidContainer("stl") = error else { return XCTFail("Expected invalidContainer(stl), got \(error)") }
        }
    }
}
