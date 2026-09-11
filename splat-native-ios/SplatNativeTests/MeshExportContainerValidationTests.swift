import Foundation
import XCTest

final class MeshExportContainerValidationTests: XCTestCase {
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