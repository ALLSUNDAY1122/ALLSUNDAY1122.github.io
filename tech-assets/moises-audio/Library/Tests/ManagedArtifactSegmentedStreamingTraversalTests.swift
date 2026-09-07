import Foundation
import XCTest

final class ManagedArtifactSegmentedStreamingTraversalTests: XCTestCase {
    private struct Entry: Codable { let relativePath: String; let modificationTime: TimeInterval }
    private struct Manifest: Codable { let schemaVersion: Int; let shardIndex: Int; let generation: UUID; let segmentCount: Int; let entryCount: Int }
    private struct Segment: Codable { let schemaVersion: Int; let shardIndex: Int; let generation: UUID; let segmentIndex: Int; let entries: [Entry] }

    func testCandidateLimitStopsBeforeLaterCorruptSegmentAndCursorResumes() throws {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lane2-aw43-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        let directory = root.appendingPathComponent(".LibraryRecovery/ArtifactInventory/v1/Segmented", isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)

        let shard = 7
        var paths: [String] = []
        var index = 0
        while paths.count < 600 {
            let path = String(format: "Exports/f%06d.wav", index)
            if try Lane2ManagedArtifactInventory.shardIndex(for: path) == shard { paths.append(path) }
            index += 1
        }
        paths.sort()

        let generation = UUID()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let first = Segment(schemaVersion: 1, shardIndex: shard, generation: generation, segmentIndex: 0, entries: paths.prefix(512).map { Entry(relativePath: $0, modificationTime: 0) })
        try encoder.encode(first).write(to: directory.appendingPathComponent(String(format: "%02x.%@.%04d.json", shard, generation.uuidString, 0)))
        try Data("corrupt".utf8).write(to: directory.appendingPathComponent(String(format: "%02x.%@.%04d.json", shard, generation.uuidString, 1)))
        let manifest = Manifest(schemaVersion: 1, shardIndex: shard, generation: generation, segmentCount: 2, entryCount: 600)
        try encoder.encode(manifest).write(to: directory.appendingPathComponent(String(format: "%02x.manifest.json", shard)))

        let traversal = Lane2ManagedArtifactSegmentedStreamingTraversal(rootURL: root)
        let firstSlice = try traversal.prepareOrphanCandidateSlice(priorTraversal: .init(shardIndex: shard), gracePeriod: 0, now: Date(timeIntervalSince1970: 1), candidateLimit: 1, shardVisitLimit: 1)
        XCTAssertEqual(firstSlice.candidates.count, 1)
        XCTAssertEqual(firstSlice.scannedInventoryEntries, 1)
        XCTAssertEqual(firstSlice.nextTraversal.afterRelativePath, paths[0])

        XCTAssertThrowsError(try traversal.prepareOrphanCandidateSlice(priorTraversal: .init(shardIndex: shard), gracePeriod: 0, now: Date(timeIntervalSince1970: 1), candidateLimit: 600, shardVisitLimit: 1))
    }

    func testOversizedManifestFailsClosedBeforeDecode() throws {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lane2-segmented-manifest-cap-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        let directory = root.appendingPathComponent(".LibraryRecovery/ArtifactInventory/v1/Segmented", isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)

        let shard = 7
        let manifestURL = directory.appendingPathComponent(String(format: "%02x.manifest.json", shard))
        try Data(repeating: 0x20, count: Lane2ManagedArtifactSegmentedStreamingTraversal.maximumManifestEncodedBytes + 1).write(to: manifestURL)

        let traversal = Lane2ManagedArtifactSegmentedStreamingTraversal(rootURL: root)
        XCTAssertThrowsError(
            try traversal.prepareOrphanCandidateSlice(
                priorTraversal: .init(shardIndex: shard),
                gracePeriod: 0,
                now: Date(timeIntervalSince1970: 1),
                candidateLimit: 1,
                shardVisitLimit: 1
            )
        )
    }

    func testOversizedSegmentFailsClosedBeforeDecode() throws {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lane2-segmented-segment-cap-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        let directory = root.appendingPathComponent(".LibraryRecovery/ArtifactInventory/v1/Segmented", isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)

        let shard = 7
        let generation = UUID()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let manifest = Manifest(schemaVersion: 1, shardIndex: shard, generation: generation, segmentCount: 1, entryCount: 1)
        try encoder.encode(manifest).write(to: directory.appendingPathComponent(String(format: "%02x.manifest.json", shard)))
        let segmentURL = directory.appendingPathComponent(String(format: "%02x.%@.%04d.json", shard, generation.uuidString, 0))
        try Data(repeating: 0x20, count: Lane2ManagedArtifactSegmentedStreamingTraversal.maximumSegmentEncodedBytes + 1).write(to: segmentURL)

        let traversal = Lane2ManagedArtifactSegmentedStreamingTraversal(rootURL: root)
        XCTAssertThrowsError(
            try traversal.prepareOrphanCandidateSlice(
                priorTraversal: .init(shardIndex: shard),
                gracePeriod: 0,
                now: Date(timeIntervalSince1970: 1),
                candidateLimit: 1,
                shardVisitLimit: 1
            )
        )
    }
}
