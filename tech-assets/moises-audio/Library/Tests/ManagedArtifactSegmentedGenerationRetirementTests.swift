import Foundation
import XCTest

final class Lane2ManagedArtifactSegmentedGenerationRetirementTests: XCTestCase {
    func testBoundedPassRetiresOnlySupersededStrictSegmentNames() throws {
        let fixture = try RetirementFixture()
        defer { fixture.cleanup() }
        let current = UUID()
        let old = UUID()
        try fixture.writeManifest(shardIndex: 10, generation: current, segmentCount: 1, entryCount: 1)
        try fixture.writeSegment(shardIndex: 10, generation: current, index: 0, payload: "current")
        for index in 0..<3 {
            try fixture.writeSegment(shardIndex: 10, generation: old, index: index, payload: "old-\(index)")
        }
        let unrecognized = fixture.segmented.appendingPathComponent("0a.notes.json")
        try Data("keep".utf8).write(to: unrecognized)

        let retirement = Lane2ManagedArtifactSegmentedGenerationRetirement(rootURL: fixture.root)
        let first = try retirement.retireSupersededSegments(
            shardIndex: 10,
            scanLimit: 100,
            removalLimit: 2
        )

        XCTAssertEqual(first.removedSegments, 2)
        XCTAssertTrue(first.reachedRemovalLimit)
        XCTAssertTrue(first.needsAnotherPass)
        XCTAssertTrue(fixture.existsSegment(shardIndex: 10, generation: current, index: 0))
        XCTAssertEqual(fixture.existingSegments(shardIndex: 10, generation: old).count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrecognized.path))

        let second = try retirement.retireSupersededSegments(
            shardIndex: 10,
            scanLimit: 100,
            removalLimit: 8
        )
        XCTAssertEqual(second.removedSegments, 1)
        XCTAssertEqual(fixture.existingSegments(shardIndex: 10, generation: old).count, 0)
        XCTAssertTrue(fixture.existsSegment(shardIndex: 10, generation: current, index: 0))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrecognized.path))
    }

    func testScanLimitBoundsDirectoryWorkWithoutDeletingCurrentGeneration() throws {
        let fixture = try RetirementFixture()
        defer { fixture.cleanup() }
        let current = UUID()
        let old = UUID()
        try fixture.writeManifest(shardIndex: 11, generation: current, segmentCount: 1, entryCount: 1)
        try fixture.writeSegment(shardIndex: 11, generation: current, index: 0, payload: "current")
        for index in 0..<8 {
            try fixture.writeSegment(shardIndex: 11, generation: old, index: index, payload: "old")
        }

        let result = try Lane2ManagedArtifactSegmentedGenerationRetirement(rootURL: fixture.root)
            .retireSupersededSegments(shardIndex: 11, scanLimit: 2, removalLimit: 8)

        XCTAssertLessThanOrEqual(result.examinedDirectoryEntries, 2)
        XCTAssertTrue(result.reachedScanLimit)
        XCTAssertTrue(result.needsAnotherPass)
        XCTAssertTrue(fixture.existsSegment(shardIndex: 11, generation: current, index: 0))
    }

    func testSymlinkCandidateFailsClosedWithoutTouchingExternalTarget() throws {
        let fixture = try RetirementFixture()
        let external = try RetirementFixture.makeTemporaryDirectory(prefix: "external")
        defer {
            fixture.cleanup()
            try? FileManager.default.removeItem(at: external)
        }
        let current = UUID()
        let old = UUID()
        try fixture.writeManifest(shardIndex: 12, generation: current, segmentCount: 1, entryCount: 1)
        try fixture.writeSegment(shardIndex: 12, generation: current, index: 0, payload: "current")
        let externalTarget = external.appendingPathComponent("sentinel.json")
        let sentinel = Data("outside-must-survive".utf8)
        try sentinel.write(to: externalTarget)
        let candidate = fixture.segmentURL(shardIndex: 12, generation: old, index: 0)
        try FileManager.default.createSymbolicLink(at: candidate, withDestinationURL: externalTarget)

        let retirement = Lane2ManagedArtifactSegmentedGenerationRetirement(rootURL: fixture.root)
        XCTAssertThrowsError(
            try retirement.retireSupersededSegments(shardIndex: 12, scanLimit: 100, removalLimit: 8)
        ) { error in
            XCTAssertEqual(
                error as? Lane2ManagedArtifactSegmentedRetirementFailure,
                .unsafeCandidate(candidate.lastPathComponent)
            )
        }
        XCTAssertEqual(try Data(contentsOf: externalTarget), sentinel)
        XCTAssertTrue(FileManager.default.fileExists(atPath: candidate.path))
    }

    func testSegmentedAncestorSymlinkCannotRedirectRetirement() throws {
        let fixture = try RetirementFixture(createSegmentedDirectory: false)
        let external = try RetirementFixture.makeTemporaryDirectory(prefix: "ancestor-external")
        defer {
            fixture.cleanup()
            try? FileManager.default.removeItem(at: external)
        }
        try FileManager.default.createDirectory(
            at: fixture.segmented.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(at: fixture.segmented, withDestinationURL: external)

        let current = UUID()
        let old = UUID()
        let externalManifest = external.appendingPathComponent("0d.manifest.json")
        try RetirementFixture.writeManifestPayload(
            shardIndex: 13,
            generation: current,
            segmentCount: 1,
            entryCount: 1,
            to: externalManifest
        )
        let externalCandidate = external.appendingPathComponent(
            String(format: "0d.%@.%04d.json", old.uuidString, 0)
        )
        let sentinel = Data("external-candidate".utf8)
        try sentinel.write(to: externalCandidate)

        let retirement = Lane2ManagedArtifactSegmentedGenerationRetirement(rootURL: fixture.root)
        XCTAssertThrowsError(try retirement.retireSupersededSegments(shardIndex: 13))
        XCTAssertEqual(try Data(contentsOf: externalCandidate), sentinel)
    }

    func testCorruptManifestFailsClosed() throws {
        let fixture = try RetirementFixture()
        defer { fixture.cleanup() }
        let manifest = fixture.segmented.appendingPathComponent("0e.manifest.json")
        try Data("not-json".utf8).write(to: manifest)
        let old = UUID()
        try fixture.writeSegment(shardIndex: 14, generation: old, index: 0, payload: "must-remain")

        let retirement = Lane2ManagedArtifactSegmentedGenerationRetirement(rootURL: fixture.root)
        XCTAssertThrowsError(try retirement.retireSupersededSegments(shardIndex: 14))
        XCTAssertTrue(fixture.existsSegment(shardIndex: 14, generation: old, index: 0))
    }
}

private final class RetirementFixture {
    let root: URL
    let segmented: URL

    init(createSegmentedDirectory: Bool = true) throws {
        root = try Self.makeTemporaryDirectory(prefix: "root")
        segmented = root
            .appendingPathComponent(".LibraryRecovery", isDirectory: true)
            .appendingPathComponent("ArtifactInventory", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("Segmented", isDirectory: true)
        if createSegmentedDirectory {
            try FileManager.default.createDirectory(at: segmented, withIntermediateDirectories: true)
        }
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }

    func writeManifest(
        shardIndex: Int,
        generation: UUID,
        segmentCount: Int,
        entryCount: Int
    ) throws {
        try Self.writeManifestPayload(
            shardIndex: shardIndex,
            generation: generation,
            segmentCount: segmentCount,
            entryCount: entryCount,
            to: segmented.appendingPathComponent(String(format: "%02x.manifest.json", shardIndex))
        )
    }

    static func writeManifestPayload(
        shardIndex: Int,
        generation: UUID,
        segmentCount: Int,
        entryCount: Int,
        to url: URL
    ) throws {
        struct Manifest: Codable {
            let schemaVersion: Int
            let shardIndex: Int
            let generation: UUID
            let segmentCount: Int
            let entryCount: Int
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(
            Manifest(
                schemaVersion: 1,
                shardIndex: shardIndex,
                generation: generation,
                segmentCount: segmentCount,
                entryCount: entryCount
            )
        ).write(to: url, options: [.atomic])
    }

    func writeSegment(shardIndex: Int, generation: UUID, index: Int, payload: String) throws {
        try Data(payload.utf8).write(to: segmentURL(shardIndex: shardIndex, generation: generation, index: index))
    }

    func segmentURL(shardIndex: Int, generation: UUID, index: Int) -> URL {
        segmented.appendingPathComponent(
            String(format: "%02x.%@.%04d.json", shardIndex, generation.uuidString, index)
        )
    }

    func existsSegment(shardIndex: Int, generation: UUID, index: Int) -> Bool {
        FileManager.default.fileExists(
            atPath: segmentURL(shardIndex: shardIndex, generation: generation, index: index).path
        )
    }

    func existingSegments(shardIndex: Int, generation: UUID) -> [URL] {
        let prefix = String(format: "%02x.%@.", shardIndex, generation.uuidString)
        return ((try? FileManager.default.contentsOfDirectory(
            at: segmented,
            includingPropertiesForKeys: nil
        )) ?? []).filter { $0.lastPathComponent.hasPrefix(prefix) }
    }

    static func makeTemporaryDirectory(prefix: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "L2SegmentedRetirement-\(prefix)-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
