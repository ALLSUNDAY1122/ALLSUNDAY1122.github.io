import Foundation
import XCTest

final class MeshDurabilityRecoverySymlinkTests: XCTestCase {
    func testProtectRejectsSymlinkedFinishedResult() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let project = root.appendingPathComponent("work.meshproject", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let outside = root.appendingPathComponent("outside.obj")
        try Data("v 0 0 0\n".utf8).write(to: outside)
        let alias = project.appendingPathComponent("mesh.obj")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: outside)

        let store = MeshDurabilityRecoveryStore(appRootURL: root)
        XCTAssertThrowsError(try store.protect(resultURL: alias)) { error in
            XCTAssertEqual(error as? MeshDurabilityRecoveryError, .invalidResult)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: project.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
    }

    func testProtectRejectsSymlinkedWorkingProject() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let outsideProject = root.appendingPathComponent("outside-real.meshproject", isDirectory: true)
        try FileManager.default.createDirectory(at: outsideProject, withIntermediateDirectories: true)
        let outsideResult = outsideProject.appendingPathComponent("mesh.obj")
        try Data("v 0 0 0\n".utf8).write(to: outsideResult)
        let projectAlias = root.appendingPathComponent("work.meshproject", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: projectAlias, withDestinationURL: outsideProject)
        let aliasedResult = projectAlias.appendingPathComponent("mesh.obj")

        let store = MeshDurabilityRecoveryStore(appRootURL: root)
        XCTAssertThrowsError(try store.protect(resultURL: aliasedResult)) { error in
            XCTAssertEqual(error as? MeshDurabilityRecoveryError, .invalidProject)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: outsideResult.path))
    }

    func testRecoverIgnoresSymlinkedProjectDirectory() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let recovery = root.appendingPathComponent(MeshDurabilityRecoveryStore.recoveryDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: recovery, withIntermediateDirectories: true)
        let outsideProject = root.appendingPathComponent("outside.meshproject", isDirectory: true)
        try FileManager.default.createDirectory(at: outsideProject, withIntermediateDirectories: true)
        let outsideResult = outsideProject.appendingPathComponent("mesh.obj")
        try Data("v 0 0 0\n".utf8).write(to: outsideResult)
        let alias = recovery.appendingPathComponent("alias.meshproject", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: outsideProject)

        let report = MeshDurabilityRecoveryStore(appRootURL: root).recoverPendingArchives()
        XCTAssertEqual(report.recoveredCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outsideResult.path))
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeshDurabilityRecoverySymlinkTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
