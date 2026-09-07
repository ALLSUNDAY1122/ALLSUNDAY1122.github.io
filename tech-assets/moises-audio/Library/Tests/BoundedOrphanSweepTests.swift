import Foundation
import XCTest

final class Lane2BoundedOrphanSweepTests: XCTestCase {
    func testCursorAdvancesPastReferencedWindowAndReachesLaterOrphans() throws {
        try withEnvironment { root, lifecycle, now in
            let old = now.addingTimeInterval(-7200)
            try write("Imports/a.m4a", root: root, modified: old)
            try write("Imports/b.m4a", root: root, modified: old)
            try write("Stems/c.m4a", root: root, modified: old)
            try write("Stems/d.m4a", root: root, modified: old)

            let first = try lifecycle.prepareBoundedOrphanCandidateSlice(
                gracePeriod: 3600,
                now: now,
                limit: 2
            )
            XCTAssertEqual(first.candidates.map(\.relativePath), ["Imports/a.m4a", "Imports/b.m4a"])
            let firstResult = try lifecycle.applyBoundedOrphanCandidateSlice(
                first,
                referencedRelativePaths: ["Imports/a.m4a", "Imports/b.m4a"],
                gracePeriod: 3600,
                now: now
            )
            XCTAssertTrue(firstResult.removed.isEmpty)
            try lifecycle.persistBoundedOrphanSweepCursor(after: first)

            let second = try lifecycle.prepareBoundedOrphanCandidateSlice(
                gracePeriod: 3600,
                now: now,
                limit: 2
            )
            XCTAssertEqual(second.candidates.map(\.relativePath), ["Stems/c.m4a", "Stems/d.m4a"])
            let secondResult = try lifecycle.applyBoundedOrphanCandidateSlice(
                second,
                referencedRelativePaths: [],
                gracePeriod: 3600,
                now: now
            )
            XCTAssertEqual(secondResult.removed, ["Stems/c.m4a", "Stems/d.m4a"])
        }
    }

    func testCandidateIsRevalidatedAgainstGracePeriodBeforeDelete() throws {
        try withEnvironment { root, lifecycle, now in
            let path = "Imports/rejuvenated.m4a"
            try write(path, root: root, modified: now.addingTimeInterval(-7200))
            let slice = try lifecycle.prepareBoundedOrphanCandidateSlice(
                gracePeriod: 3600,
                now: now,
                limit: 1
            )
            try FileManager.default.setAttributes(
                [.modificationDate: now],
                ofItemAtPath: root.appendingPathComponent(path).path
            )
            let result = try lifecycle.applyBoundedOrphanCandidateSlice(
                slice,
                referencedRelativePaths: [],
                gracePeriod: 3600,
                now: now
            )
            XCTAssertTrue(result.removed.isEmpty)
            XCTAssertGreaterThanOrEqual(result.retainedYoung, 1)
            XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path))
        }
    }

    func testSymlinkIsNeverCandidateOrDeletionTarget() throws {
        try withEnvironment { root, lifecycle, now in
            let outside = root.appendingPathComponent("outside.bin")
            try Data("outside".utf8).write(to: outside)
            let link = root.appendingPathComponent("Imports/link.m4a")
            try FileManager.default.createDirectory(
                at: link.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
            let slice = try lifecycle.prepareBoundedOrphanCandidateSlice(
                gracePeriod: 0,
                now: now,
                limit: 8
            )
            XCTAssertFalse(slice.candidateRelativePaths.contains("Imports/link.m4a"))
            XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
        }
    }

    func testCursorWrapsAfterEndOfEligibleNamespace() throws {
        try withEnvironment { root, lifecycle, now in
            let old = now.addingTimeInterval(-7200)
            try write("Imports/a.m4a", root: root, modified: old)
            try write("Stems/z.m4a", root: root, modified: old)
            let first = try lifecycle.prepareBoundedOrphanCandidateSlice(
                gracePeriod: 3600,
                now: now,
                limit: 2
            )
            try lifecycle.persistBoundedOrphanSweepCursor(after: first)
            let wrapped = try lifecycle.prepareBoundedOrphanCandidateSlice(
                gracePeriod: 3600,
                now: now,
                limit: 1
            )
            XCTAssertTrue(wrapped.wrappedToStart)
            XCTAssertEqual(wrapped.candidates.map(\.relativePath), ["Imports/a.m4a"])
        }
    }

    private func withEnvironment(
        _ body: (URL, LibraryArtifactLifecycle, Date) throws -> Void
    ) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "L2AW28Tests-" + UUID().uuidString,
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try body(root, LibraryArtifactLifecycle(rootURL: root), Date(timeIntervalSince1970: 2_000_000))
    }

    private func write(_ relativePath: String, root: URL, modified: Date) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("artifact".utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
    }
}
