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
            guard let recoveryError = error as? MeshDurabilityRecoveryError else {
                return XCTFail("Expected MeshDurabilityRecoveryError, got \(error)")
            }
            guard case .invalidResult = recoveryError else {
                return XCTFail("Expected invalidResult, got \(recoveryError)")
            }
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: project.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
    }

    func testProtectRejectsSymlinkedWorkingProject() throws {
        let root = try makeRoot()
        let outsideProject = try makeExternalProject()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outsideProject)
        }

        let outsideResult = outsideProject.appendingPathComponent("mesh.obj")
        try Data("v 0 0 0\n".utf8).write(to: outsideResult)
        let projectAlias = root.appendingPathComponent("work.meshproject", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: projectAlias, withDestinationURL: outsideProject)
        let aliasedResult = projectAlias.appendingPathComponent("mesh.obj")

        let store = MeshDurabilityRecoveryStore(appRootURL: root)
        XCTAssertThrowsError(try store.protect(resultURL: aliasedResult)) { error in
            guard let recoveryError = error as? MeshDurabilityRecoveryError else {
                return XCTFail("Expected MeshDurabilityRecoveryError, got \(error)")
            }
            guard case .invalidProject = recoveryError else {
                return XCTFail("Expected invalidProject, got \(recoveryError)")
            }
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: outsideResult.path))
    }

    func testRecoverIgnoresSymlinkedProjectDirectory() throws {
        let root = try makeRoot()
        let outsideProject = try makeExternalProject()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outsideProject)
        }

        let recovery = root.appendingPathComponent(MeshDurabilityRecoveryStore.recoveryDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: recovery, withIntermediateDirectories: true)
        let outsideResult = outsideProject.appendingPathComponent("mesh.obj")
        try Data("v 0 0 0\n".utf8).write(to: outsideResult)
        let alias = recovery.appendingPathComponent("alias.meshproject", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: outsideProject)

        let report = MeshDurabilityRecoveryStore(appRootURL: root).recoverPendingArchives()
        XCTAssertEqual(report.recoveredCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outsideResult.path))
    }

    func testCleanupDoesNotDeleteProjectForSymlinkedResult() throws {
        let root = try makeRoot()
        let outsideProject = try makeExternalProject()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outsideProject)
        }

        let recovery = root.appendingPathComponent(MeshDurabilityRecoveryStore.recoveryDirectoryName, isDirectory: true)
        let project = recovery.appendingPathComponent("protected.meshproject", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let outsideResult = outsideProject.appendingPathComponent("mesh.obj")
        try Data("v 0 0 0\n".utf8).write(to: outsideResult)
        let alias = project.appendingPathComponent("mesh.obj")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: outsideResult)

        MeshDurabilityRecoveryStore(appRootURL: root).cleanupProtectedResult(containing: alias)

        XCTAssertTrue(FileManager.default.fileExists(atPath: project.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outsideResult.path))
    }

    func testRecoverFallsBackWhenPreferredMeshResultIsCorrupt() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let project = root.appendingPathComponent("fallback.meshproject", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try Data("not-a-mesh".utf8).write(to: project.appendingPathComponent("mesh-cropped.obj"))
        let validOBJ = """
        v 0 0 0
        v 1 0 0
        v 0 1 0
        f 1 2 3
        """
        try Data(validOBJ.utf8).write(to: project.appendingPathComponent("mesh.obj"))

        let report = MeshDurabilityRecoveryStore(appRootURL: root).recoverPendingArchives()

        XCTAssertEqual(report.recoveredCount, 1)
        XCTAssertEqual(report.remainingCount, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: project.path))
        let archived = MeshProjectStore(appRootURL: root).listProjects()
        XCTAssertEqual(archived.count, 1)
        XCTAssertEqual(archived.first?.resultURL.lastPathComponent, "mesh.obj")
    }

    func testCorruptRecoveryCandidateCannotReplaceExistingGoodArchive() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let project = root.appendingPathComponent("preserve.meshproject", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let sourceResult = project.appendingPathComponent("mesh.obj")
        let validOBJ = """
        v 0 0 0
        v 1 0 0
        v 0 1 0
        f 1 2 3
        """
        try Data(validOBJ.utf8).write(to: sourceResult)

        let libraryStore = MeshProjectStore(appRootURL: root)
        let goodSummary = try libraryStore.archiveFinishedProject(resultURL: sourceResult)
        _ = try MeshProjectIntegrity.verifyOrSeal(summary: goodSummary)
        let goodBytes = try Data(contentsOf: goodSummary.resultURL)

        try Data("broken-later-result".utf8).write(to: sourceResult, options: .atomic)
        try Data("also-broken".utf8).write(
            to: project.appendingPathComponent("mesh-cropped.obj"),
            options: .atomic
        )

        let report = MeshDurabilityRecoveryStore(appRootURL: root).recoverPendingArchives()

        XCTAssertEqual(report.recoveredCount, 0)
        XCTAssertEqual(report.remainingCount, 1)
        let archived = libraryStore.listProjects()
        XCTAssertEqual(archived.count, 1)
        XCTAssertEqual(try Data(contentsOf: archived[0].resultURL), goodBytes)
        XCTAssertNoThrow(try MeshProjectIntegrity.verifyOrSeal(summary: archived[0]))
        XCTAssertTrue(FileManager.default.fileExists(atPath: project.path))
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeshDurabilityRecoverySymlinkTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func makeExternalProject() throws -> URL {
        let project = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeshDurabilityRecoveryExternal-\(UUID().uuidString)", isDirectory: true)
            .appendingPathExtension(MeshProjectStore.projectExtension)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        return project
    }
}
