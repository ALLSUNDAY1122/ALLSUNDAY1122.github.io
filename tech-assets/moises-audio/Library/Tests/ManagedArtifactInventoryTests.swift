import Foundation
import XCTest

final class Lane2ManagedArtifactInventoryTests: XCTestCase {
    func testFreshActivationAcceptsOnlyTheSingleReadyArtifact() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let path = "Imports/first.m4a"
        try write(path, root: root, modified: .distantPast)
        let inventory = Lane2ManagedArtifactInventory(rootURL: root)

        XCTAssertTrue(try inventory.activateForFirstManagedArtifactIfSafe(relativePath: path))
        XCTAssertTrue(inventory.isAuthoritative)
        XCTAssertTrue(try inventory.registerIfManaged(relativePath: path))
    }

    func testSecondPreexistingArtifactPreventsFreshActivation() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("Imports/first.m4a", root: root, modified: .distantPast)
        try write("Stems/existing.m4a", root: root, modified: .distantPast)
        let inventory = Lane2ManagedArtifactInventory(rootURL: root)

        XCTAssertFalse(
            try inventory.activateForFirstManagedArtifactIfSafe(relativePath: "Imports/first.m4a")
        )
        XCTAssertFalse(inventory.isAuthoritative)
    }

    func testCandidateAndShardWorkStayWithinExplicitBudgets() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let now = Date(timeIntervalSince1970: 2_000_000)
        let old = now.addingTimeInterval(-7200)
        let paths = try pathsInEarlyShards(count: 12, maxShard: 3)
        for path in paths { try write(path, root: root, modified: old) }

        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        try inventory.registerManaged(relativePaths: paths)
        try inventory.markAuthoritativeAfterCompatibilityCensus()
        let slice = try inventory.prepareOrphanCandidateSlice(
            gracePeriod: 3600,
            now: now,
            candidateLimit: 5,
            shardVisitLimit: 4
        )

        XCTAssertLessThanOrEqual(slice.candidates.count, 5)
        XCTAssertLessThanOrEqual(slice.visitedShards, 4)
        XCTAssertLessThanOrEqual(slice.scannedInventoryEntries, paths.count)
    }

    func testApplyRetainsReferenceAndRevalidatesYoungFile() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let now = Date(timeIntervalSince1970: 2_000_000)
        let old = now.addingTimeInterval(-7200)
        let paths = try pathsInEarlyShards(count: 2, maxShard: 3)
        for path in paths { try write(path, root: root, modified: old) }
        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        try inventory.registerManaged(relativePaths: paths)
        try inventory.markAuthoritativeAfterCompatibilityCensus()

        var slice: Lane2ManagedArtifactInventorySlice?
        for _ in 0..<64 {
            let candidate = try inventory.prepareOrphanCandidateSlice(
                gracePeriod: 3600,
                now: now,
                candidateLimit: 2,
                shardVisitLimit: 4
            )
            if candidate.candidates.count == 2 {
                slice = candidate
                break
            }
            try inventory.persistTraversal(after: candidate)
        }
        let selected = try XCTUnwrap(slice)
        let referenced = selected.candidates[0].relativePath
        let rejuvenated = selected.candidates[1].relativePath
        try FileManager.default.setAttributes(
            [.modificationDate: now],
            ofItemAtPath: root.appendingPathComponent(rejuvenated).path
        )

        let result = try inventory.applyOrphanCandidateSlice(
            selected,
            referencedRelativePaths: [referenced],
            gracePeriod: 3600,
            now: now
        )
        XCTAssertTrue(result.removed.isEmpty)
        XCTAssertEqual(result.retainedReferenced, 1)
        XCTAssertEqual(result.retainedYoung, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(referenced).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(rejuvenated).path))
    }

    func testCorruptShardFailsClosed() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let path = try pathInShard(0)
        try write(path, root: root, modified: .distantPast)
        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        try inventory.registerManaged(relativePaths: [path])
        try inventory.markAuthoritativeAfterCompatibilityCensus()

        let shard = try Lane2ManagedArtifactInventory.shardIndex(for: path)
        let shardURL = root
            .appendingPathComponent(".LibraryRecovery/ArtifactInventory/v1/Shards", isDirectory: true)
            .appendingPathComponent(String(format: "%02x.json", shard))
        try Data("{}".utf8).write(to: shardURL, options: [.atomic])

        XCTAssertThrowsError(
            try inventory.prepareOrphanCandidateSlice(
                gracePeriod: 0,
                now: Date(),
                candidateLimit: 1,
                shardVisitLimit: 1
            )
        )
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "L2AW29Tests-" + UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
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

    private func pathsInEarlyShards(count: Int, maxShard: Int) throws -> [String] {
        var result: [String] = []
        var index = 0
        while result.count < count {
            let path = "Imports/candidate-\(index).m4a"
            if try Lane2ManagedArtifactInventory.shardIndex(for: path) <= maxShard {
                result.append(path)
            }
            index += 1
        }
        return result
    }

    private func pathInShard(_ desiredShard: Int) throws -> String {
        var index = 0
        while true {
            let path = "Imports/shard-\(index).m4a"
            if try Lane2ManagedArtifactInventory.shardIndex(for: path) == desiredShard {
                return path
            }
            index += 1
        }
    }
}
