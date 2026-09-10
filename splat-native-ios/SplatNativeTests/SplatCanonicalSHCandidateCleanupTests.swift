import Foundation
import XCTest

final class SplatCanonicalSHCandidateCleanupTests: XCTestCase {
    func testPrunesOnlyOldCanonicalCandidates() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("scanlab-candidate-cleanup-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let oldDate = now.addingTimeInterval(-(SplatCanonicalSHAsset.abandonedCandidateAge + 60))
        let recentDate = now.addingTimeInterval(-60)

        let oldCandidate = directory.appendingPathComponent(".result.sh3-deadbeef.ply.old.candidate.ply")
        let recentCandidate = directory.appendingPathComponent(".result.sh3-cafebabe.ply.recent.candidate.ply")
        let unrelatedOldPLY = directory.appendingPathComponent("result.sh3-deadbeef.ply")
        let unrelatedHiddenFile = directory.appendingPathComponent(".unrelated.candidate.ply")

        for url in [oldCandidate, recentCandidate, unrelatedOldPLY, unrelatedHiddenFile] {
            XCTAssertTrue(fileManager.createFile(atPath: url.path, contents: Data("x".utf8)))
        }
        try fileManager.setAttributes([.modificationDate: oldDate], ofItemAtPath: oldCandidate.path)
        try fileManager.setAttributes([.modificationDate: recentDate], ofItemAtPath: recentCandidate.path)
        try fileManager.setAttributes([.modificationDate: oldDate], ofItemAtPath: unrelatedOldPLY.path)
        try fileManager.setAttributes([.modificationDate: oldDate], ofItemAtPath: unrelatedHiddenFile.path)

        SplatCanonicalSHAsset.pruneAbandonedCandidates(in: directory, now: now, fileManager: fileManager)

        XCTAssertFalse(fileManager.fileExists(atPath: oldCandidate.path))
        XCTAssertTrue(fileManager.fileExists(atPath: recentCandidate.path))
        XCTAssertTrue(fileManager.fileExists(atPath: unrelatedOldPLY.path))
        XCTAssertTrue(fileManager.fileExists(atPath: unrelatedHiddenFile.path))
    }
}
