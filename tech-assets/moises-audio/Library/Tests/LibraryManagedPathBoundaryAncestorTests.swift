import Foundation
import XCTest

final class LibraryManagedPathBoundaryAncestorTests: XCTestCase {
    private let fm = FileManager.default

    func testMissingLeafUnderRealAncestorsRemainsMissing() throws {
        let base = fm.temporaryDirectory.appendingPathComponent(
            "L2-AW50-BOUNDARY-\(UUID().uuidString)",
            isDirectory: true
        )
        let root = base.appendingPathComponent("root", isDirectory: true)
        let safe = root.appendingPathComponent("safe", isDirectory: true)
        try fm.createDirectory(at: safe, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }

        let boundary = LibraryManagedPathBoundary(rootURL: root)
        XCTAssertFalse(
            try boundary.nodeExists(
                safe.appendingPathComponent("missing.json"),
                fileManager: fm
            )
        )
    }

    func testMissingLeafThroughSymlinkAncestorFailsClosed() throws {
        let base = fm.temporaryDirectory.appendingPathComponent(
            "L2-AW50-BOUNDARY-\(UUID().uuidString)",
            isDirectory: true
        )
        let root = base.appendingPathComponent("root", isDirectory: true)
        let external = base.appendingPathComponent("external", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }

        let linked = root.appendingPathComponent("linked", isDirectory: true)
        try fm.createSymbolicLink(at: linked, withDestinationURL: external)

        let boundary = LibraryManagedPathBoundary(rootURL: root)
        XCTAssertThrowsError(
            try boundary.nodeExists(
                linked.appendingPathComponent("missing.json"),
                fileManager: fm
            )
        )
    }
}
