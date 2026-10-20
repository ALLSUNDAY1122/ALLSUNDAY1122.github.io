import Foundation
import XCTest

final class MeshDurabilityRecoveryFreshnessTests: XCTestCase {
    func testRecoveryPrefersNewestValidFinishedResultOverLegacyFilenamePriority() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeshDurabilityRecoveryFreshnessTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let project = root.appendingPathComponent("freshness.meshproject", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        let validOBJ = """
        v 0 0 0
        v 1 0 0
        v 0 1 0
        f 1 2 3
        """
        let cropped = project.appendingPathComponent("mesh-cropped.obj")
        let base = project.appendingPathComponent("mesh.obj")
        try Data(validOBJ.utf8).write(to: cropped)
        try Data(validOBJ.utf8).write(to: base)

        let old = Date(timeIntervalSince1970: 1_700_000_000)
        let newer = old.addingTimeInterval(120)
        try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: cropped.path)
        try FileManager.default.setAttributes([.modificationDate: newer], ofItemAtPath: base.path)

        let report = MeshDurabilityRecoveryStore(appRootURL: root).recoverPendingArchives()

        XCTAssertEqual(report.recoveredCount, 1)
        XCTAssertEqual(report.remainingCount, 0)
        let archived = MeshProjectStore(appRootURL: root).listProjects()
        XCTAssertEqual(archived.count, 1)
        XCTAssertEqual(archived.first?.resultURL.lastPathComponent, "mesh.obj")
        XCTAssertNoThrow(try MeshProjectIntegrity.verifyOrSeal(summary: try XCTUnwrap(archived.first)))
    }
}
