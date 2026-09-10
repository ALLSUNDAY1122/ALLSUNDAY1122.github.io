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

    func testValidatedCandidateReplacesUnreadableCanonicalTarget() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("scanlab-canonical-repair-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let target = directory.appendingPathComponent("result.sh3-test.ply")
        let candidate = directory.appendingPathComponent(".result.sh3-test.ply.candidate.ply")
        try Data("truncated".utf8).write(to: target, options: .atomic)
        let candidateData = validSH3PLY(pointCount: 2, comment: "fresh")
        try candidateData.write(to: candidate, options: .atomic)

        let installed = try SplatCanonicalSHAsset.installCollisionSafeTemporaryPLY(
            candidate,
            targetURL: target,
            expectedPointCount: 2
        )

        XCTAssertEqual(installed.url, target)
        XCTAssertEqual(installed.descriptor.pointCount, 2)
        XCTAssertEqual(installed.descriptor.shDegree, 3)
        XCTAssertEqual(try Data(contentsOf: target), candidateData)
        XCTAssertFalse(fileManager.fileExists(atPath: candidate.path))
    }

    func testValidDifferentCanonicalTargetStillRejectsCollision() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("scanlab-canonical-collision-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let target = directory.appendingPathComponent("result.sh3-test.ply")
        let candidate = directory.appendingPathComponent(".result.sh3-test.ply.candidate.ply")
        let existingData = validSH3PLY(pointCount: 2, comment: "existing")
        let candidateData = validSH3PLY(pointCount: 2, comment: "different")
        try existingData.write(to: target, options: .atomic)
        try candidateData.write(to: candidate, options: .atomic)

        XCTAssertThrowsError(
            try SplatCanonicalSHAsset.installCollisionSafeTemporaryPLY(
                candidate,
                targetURL: target,
                expectedPointCount: 2
            )
        ) { error in
            guard case SplatCanonicalSHAsset.DurabilityError.lossyFingerprintCollision = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: target), existingData)
        XCTAssertTrue(fileManager.fileExists(atPath: candidate.path))
    }

    func testHeaderValidButTruncatedCanonicalTargetIsRepaired() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("scanlab-canonical-body-repair-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let target = directory.appendingPathComponent("result.sh3-test.ply")
        let candidate = directory.appendingPathComponent(".result.sh3-test.ply.candidate.ply")
        try validSH3Header(pointCount: 2, comment: "old-header-only").write(to: target, options: .atomic)
        let candidateData = validSH3PLY(pointCount: 2, comment: "fresh-complete")
        try candidateData.write(to: candidate, options: .atomic)

        XCTAssertFalse(SplatCanonicalSHAsset.hasCompleteVertexPayload(at: target, expectedPointCount: 2))
        let installed = try SplatCanonicalSHAsset.installCollisionSafeTemporaryPLY(
            candidate,
            targetURL: target,
            expectedPointCount: 2
        )
        XCTAssertEqual(installed.url, target)
        XCTAssertTrue(SplatCanonicalSHAsset.hasCompleteVertexPayload(at: target, expectedPointCount: 2))
        XCTAssertEqual(try Data(contentsOf: target), candidateData)
    }

    func testHeaderValidButTruncatedCandidateIsRejectedBeforePromotion() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("scanlab-canonical-candidate-truncated-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let target = directory.appendingPathComponent("result.sh3-test.ply")
        let candidate = directory.appendingPathComponent(".result.sh3-test.ply.candidate.ply")
        try validSH3Header(pointCount: 2, comment: "candidate-header-only").write(to: candidate, options: .atomic)

        XCTAssertThrowsError(
            try SplatCanonicalSHAsset.installCollisionSafeTemporaryPLY(
                candidate,
                targetURL: target,
                expectedPointCount: 2
            )
        ) { error in
            guard case SplatCanonicalSHAsset.DurabilityError.incompleteCanonicalPayload = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }
        XCTAssertFalse(fileManager.fileExists(atPath: target.path))
        XCTAssertTrue(fileManager.fileExists(atPath: candidate.path))
    }

    private func validSH3PLY(pointCount: Int, comment: String) -> Data {
        var data = validSH3Header(pointCount: pointCount, comment: comment)
        let scalarCountPerVertex = 3 + 3 + 45
        data.append(Data(count: pointCount * scalarCountPerVertex * MemoryLayout<Float>.size))
        return data
    }

    private func validSH3Header(pointCount: Int, comment: String) -> Data {
        var lines = [
            "ply",
            "format binary_little_endian 1.0",
            "comment \(comment)",
            "element vertex \(pointCount)",
            "property float x",
            "property float y",
            "property float z",
            "property float f_dc_0",
            "property float f_dc_1",
            "property float f_dc_2"
        ]
        for index in 0..<45 {
            lines.append("property float f_rest_\(index)")
        }
        lines.append("end_header")
        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }
}