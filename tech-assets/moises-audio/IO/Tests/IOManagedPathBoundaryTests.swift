import Foundation
import XCTest
#if canImport(MoisesAudioIO)
@testable import MoisesAudioIO
#endif

final class IOManagedPathBoundaryTests: XCTestCase {
    func testRootSymlinkFailsClosedWithoutCreatingManagedDirectoriesOutsideRoot() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("L2-AW47-root-\(UUID().uuidString)")
        let external = base.appendingPathComponent("external", isDirectory: true)
        let root = base.appendingPathComponent("root", isDirectory: true)
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        try fm.createSymbolicLink(at: root, withDestinationURL: external)
        defer { try? fm.removeItem(at: base) }

        let store = IOFileStore(rootURL: root)
        XCTAssertThrowsError(try store.prepareDirectories(fileManager: fm)) { error in
            XCTAssertEqual(error as? IOFileStore.StoreError, .unsafeManagedPath)
        }
        XCTAssertTrue(try fm.contentsOfDirectory(atPath: external.path).isEmpty)
    }

    func testStagingDirectorySymlinkCannotRedirectStageCopy() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("L2-AW47-stage-\(UUID().uuidString)")
        let root = base.appendingPathComponent("root", isDirectory: true)
        let external = base.appendingPathComponent("external", isDirectory: true)
        let source = base.appendingPathComponent("source.m4a")
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: source)
        defer { try? fm.removeItem(at: base) }

        let store = IOFileStore(rootURL: root)
        try store.prepareDirectories(fileManager: fm)
        try fm.removeItem(at: store.stagingURL)
        try fm.createSymbolicLink(at: store.stagingURL, withDestinationURL: external)

        XCTAssertThrowsError(try store.stageCopy(from: source, fileManager: fm)) { error in
            XCTAssertEqual(error as? IOFileStore.StoreError, .unsafeManagedPath)
        }
        XCTAssertTrue(try fm.contentsOfDirectory(atPath: external.path).isEmpty)
    }

    func testImportsDirectorySymlinkCannotRedirectFinalize() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("L2-AW47-import-\(UUID().uuidString)")
        let root = base.appendingPathComponent("root", isDirectory: true)
        let external = base.appendingPathComponent("external", isDirectory: true)
        let source = base.appendingPathComponent("source.m4a")
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: source)
        defer { try? fm.removeItem(at: base) }

        let store = IOFileStore(rootURL: root)
        let staged = try store.stageCopy(from: source, fileManager: fm)
        try fm.removeItem(at: store.importsURL)
        try fm.createSymbolicLink(at: store.importsURL, withDestinationURL: external)

        XCTAssertThrowsError(
            try store.finalizeImport(stagingFile: staged, preferredName: "song", fileManager: fm)
        ) { error in
            XCTAssertEqual(error as? IOFileStore.StoreError, .unsafeManagedPath)
        }
        XCTAssertTrue(fm.fileExists(atPath: staged.path))
        XCTAssertTrue(try fm.contentsOfDirectory(atPath: external.path).isEmpty)
    }

    func testExportsDirectorySymlinkCannotRedirectFinalize() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("L2-AW47-export-\(UUID().uuidString)")
        let root = base.appendingPathComponent("root", isDirectory: true)
        let external = base.appendingPathComponent("external", isDirectory: true)
        let source = base.appendingPathComponent("source.m4a")
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: source)
        defer { try? fm.removeItem(at: base) }

        let store = IOFileStore(rootURL: root)
        let staged = try store.stageCopy(from: source, fileManager: fm)
        try fm.removeItem(at: store.exportsURL)
        try fm.createSymbolicLink(at: store.exportsURL, withDestinationURL: external)

        XCTAssertThrowsError(
            try store.finalizeExport(stagingFile: staged, preferredName: "mix", fileManager: fm)
        ) { error in
            XCTAssertEqual(error as? IOFileStore.StoreError, .unsafeManagedPath)
        }
        XCTAssertTrue(fm.fileExists(atPath: staged.path))
        XCTAssertTrue(try fm.contentsOfDirectory(atPath: external.path).isEmpty)
    }

    func testSymlinkStagingLeafCannotBeFinalized() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("L2-AW47-leaf-\(UUID().uuidString)")
        let root = base.appendingPathComponent("root", isDirectory: true)
        let external = base.appendingPathComponent("outside.m4a")
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        try Data([9, 8, 7]).write(to: external)
        defer { try? fm.removeItem(at: base) }

        let store = IOFileStore(rootURL: root)
        try store.prepareDirectories(fileManager: fm)
        let stagedLink = store.stagingURL.appendingPathComponent("forged.m4a")
        try fm.createSymbolicLink(at: stagedLink, withDestinationURL: external)

        XCTAssertThrowsError(
            try store.finalizeImport(stagingFile: stagedLink, preferredName: "forged", fileManager: fm)
        ) { error in
            XCTAssertEqual(error as? IOFileStore.StoreError, .unsafeManagedPath)
        }
        XCTAssertEqual(try Data(contentsOf: external), Data([9, 8, 7]))
    }

    func testRemoveIfExistsDoesNotTraverseManagedDirectorySymlink() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("L2-AW47-remove-\(UUID().uuidString)")
        let root = base.appendingPathComponent("root", isDirectory: true)
        let external = base.appendingPathComponent("external", isDirectory: true)
        let victim = external.appendingPathComponent("victim.m4a")
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        try Data([4, 5, 6]).write(to: victim)
        defer { try? fm.removeItem(at: base) }

        let store = IOFileStore(rootURL: root)
        try store.prepareDirectories(fileManager: fm)
        try fm.removeItem(at: store.importsURL)
        try fm.createSymbolicLink(at: store.importsURL, withDestinationURL: external)
        let managedLookingVictim = store.importsURL.appendingPathComponent("victim.m4a")

        store.removeIfExists(managedLookingVictim, fileManager: fm)
        XCTAssertTrue(fm.fileExists(atPath: victim.path))
        XCTAssertEqual(try Data(contentsOf: victim), Data([4, 5, 6]))
    }
}
