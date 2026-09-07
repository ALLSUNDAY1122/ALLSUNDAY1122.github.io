import Foundation
import XCTest

#if canImport(CoreData)
#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

final class Lane2TargetedOrphanSweepCoreDataTests: XCTestCase {
    func testBoundedSweepRetainsLiveSourceAndStemWhileRemovingLaterOrphans() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "L2AW28CoreData-" + UUID().uuidString,
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let storeURL = root.appendingPathComponent("Metadata/Library.sqlite")
        let artifacts = root.appendingPathComponent("Artifacts", isDirectory: true)
        let now = Date(timeIntervalSince1970: 2_000_000)
        let old = now.addingTimeInterval(-7200)
        let young = now.addingTimeInterval(-60)

        let liveSource = LocalAudioAsset(
            id: AssetID(),
            relativePath: "Imports/000-live-source.m4a",
            mediaKind: .audio,
            durationSeconds: 120
        )
        try write(liveSource.relativePath, under: artifacts, modified: old)
        let raw = try CoreDataProjectLibraryStore(configuration: .init(storeURL: storeURL))
        let projectID = try await raw.createProject(source: liveSource)
        let liveStem = StemArtifact(
            id: StemID(),
            projectID: projectID,
            role: .vocals,
            relativePath: "Stems/000-live-stem.m4a",
            sampleRate: 44_100,
            channels: 2,
            frameCount: 1000,
            startTimeSeconds: 0
        )
        try write(liveStem.relativePath, under: artifacts, modified: old)
        try await raw.recordStems(projectID: projectID, stems: [liveStem])

        let importOrphan = "Imports/001-orphan.m4a"
        let stemOrphan = "Stems/001-orphan.m4a"
        let exportOrphan = "Exports/001-orphan.m4a"
        let youngOrphan = "Exports/999-young.m4a"
        try write(importOrphan, under: artifacts, modified: old)
        try write(stemOrphan, under: artifacts, modified: old)
        try write(exportOrphan, under: artifacts, modified: old)
        try write(youngOrphan, under: artifacts, modified: young)

        let store = try await CrashSafeProjectLibraryStore.open(
            metadataConfiguration: .init(storeURL: storeURL),
            artifactRootURL: artifacts
        )

        for _ in 0..<4 {
            _ = try await store.sweepOrphanArtifacts(
                gracePeriod: 3600,
                now: now,
                candidateLimit: 2
            )
        }

        XCTAssertTrue(exists(liveSource.relativePath, under: artifacts))
        XCTAssertTrue(exists(liveStem.relativePath, under: artifacts))
        XCTAssertFalse(exists(importOrphan, under: artifacts))
        XCTAssertFalse(exists(stemOrphan, under: artifacts))
        XCTAssertFalse(exists(exportOrphan, under: artifacts))
        XCTAssertTrue(exists(youngOrphan, under: artifacts))
        XCTAssertNotNil(try await store.loadProject(projectID: projectID))
    }

    private func write(_ relativePath: String, under root: URL, modified: Date) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("artifact".utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
    }

    private func exists(_ relativePath: String, under root: URL) -> Bool {
        FileManager.default.fileExists(atPath: root.appendingPathComponent(relativePath).path)
    }
}
#endif
