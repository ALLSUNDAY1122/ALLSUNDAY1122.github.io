import Foundation
import XCTest

final class MeshExportSourceSafetyTests: XCTestCase {
    func testPreflightRejectsExternalSourceAlias() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("MeshExportSourceSafetyTests-\(UUID().uuidString)", isDirectory: true)
        let externalRoot = fileManager.temporaryDirectory
            .appendingPathComponent("MeshExportSourceSafetyExternal-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? fileManager.removeItem(at: root)
            try? fileManager.removeItem(at: externalRoot)
        }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: externalRoot, withIntermediateDirectories: true)

        let external = externalRoot.appendingPathComponent("mesh.obj")
        try "v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n"
            .write(to: external, atomically: true, encoding: .utf8)
        let alias = root.appendingPathComponent("mesh.obj")
        try fileManager.createSymbolicLink(at: alias, withDestinationURL: external)

        XCTAssertThrowsError(
            try MeshExportAdmission.preflight(
                sourceURL: alias,
                format: .obj,
                availableCapacityOverride: Int64.max
            )
        ) { error in
            XCTAssertEqual(error as? MeshExportAdmission.AdmissionError, .unsafeSource)
        }
        XCTAssertTrue(fileManager.fileExists(atPath: external.path))
    }

    func testPreflightStillAcceptsRegularSource() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("MeshExportSourceSafetyTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        let source = root.appendingPathComponent("mesh.obj")
        try "v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n"
            .write(to: source, atomically: true, encoding: .utf8)

        XCTAssertNoThrow(
            try MeshExportAdmission.preflight(
                sourceURL: source,
                format: .obj,
                availableCapacityOverride: Int64.max
            )
        )
    }
}
