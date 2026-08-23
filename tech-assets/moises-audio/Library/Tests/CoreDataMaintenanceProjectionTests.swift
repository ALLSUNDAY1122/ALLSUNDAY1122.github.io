import Foundation
import XCTest

#if canImport(CoreData)
#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

final class CoreDataMaintenanceProjectionTests: XCTestCase {
    func testMaintenanceProjectionCrossesBatchesAndExcludesTombstones() async throws {
        let store = try CoreDataProjectLibraryStore(
            configuration: .init(inMemory: true, enumerationBatchSize: 17)
        )

        var ids: [ProjectID] = []
        ids.reserveCapacity(257)
        for index in 0..<257 {
            let source = LocalAudioAsset(
                id: AssetID(),
                relativePath: "Imports/\(index)/source.m4a",
                mediaKind: .audio,
                durationSeconds: 120
            )
            let projectID = try await store.createProject(source: source)
            ids.append(projectID)

            if index == 0 || index == 128 || index == 256 {
                try await store.recordProcessing(
                    projectID: projectID,
                    snapshot: ProcessingSnapshot(
                        jobID: ProcessingJobID(),
                        phase: .ready,
                        fractionComplete: 1
                    )
                )
                let stem = StemArtifact(
                    id: StemID(),
                    projectID: projectID,
                    role: .vocals,
                    relativePath: "Stems/\(projectID.rawValue.uuidString)/vocals.m4a",
                    sampleRate: 44_100,
                    channels: 2,
                    frameCount: 44_100,
                    startTimeSeconds: 0
                )
                try await store.recordStems(projectID: projectID, stems: [stem])
            }
        }

        let projection = try await store.listMaintenanceProjects()
        XCTAssertEqual(projection.count, 257)
        XCTAssertEqual(try await store.listLiveProjectIDs().count, 257)
        XCTAssertTrue(try await store.containsLiveProject(projectID: ids[128]))

        let middle = try XCTUnwrap(projection.first(where: { $0.projectID == ids[128] }))
        XCTAssertEqual(middle.sourceRelativePath, "Imports/128/source.m4a")
        XCTAssertEqual(middle.stemRelativePaths.count, 1)

        try await store.deleteProject(projectID: ids[128])

        let afterDelete = try await store.listMaintenanceProjects()
        XCTAssertEqual(afterDelete.count, 256)
        XCTAssertFalse(afterDelete.contains(where: { $0.projectID == ids[128] }))
        XCTAssertFalse(try await store.containsLiveProject(projectID: ids[128]))
    }

    func testCrashSafeDeletePreservesSharedSourceAndRemovesOnlyUniqueArtifact() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AW12-CrashSafe-" + UUID().uuidString, isDirectory: true)
        let storeURL = root.appendingPathComponent("Metadata/Library.sqlite")
        let artifactRoot = root.appendingPathComponent("Artifacts", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let raw = try CoreDataProjectLibraryStore(
            configuration: .init(storeURL: storeURL, enumerationBatchSize: 17)
        )
        let store = try CrashSafeProjectLibraryStore(
            metadata: raw,
            artifactRootURL: artifactRoot
        )

        let sharedSource = LocalAudioAsset(
            id: AssetID(),
            relativePath: "Imports/shared/source.m4a",
            mediaKind: .audio,
            durationSeconds: 90
        )
        try writeArtifact(sharedSource.relativePath, under: artifactRoot)

        let first = try await store.createProject(source: sharedSource)
        let second = try await store.createProject(source: sharedSource)
        let uniqueStem = StemArtifact(
            id: StemID(),
            projectID: first,
            role: .vocals,
            relativePath: "Stems/\(first.rawValue.uuidString)/vocals.m4a",
            sampleRate: 44_100,
            channels: 2,
            frameCount: 4_410,
            startTimeSeconds: 0
        )
        try writeArtifact(uniqueStem.relativePath, under: artifactRoot)
        try await store.recordStems(projectID: first, stems: [uniqueStem])

        try await store.deleteProject(projectID: first)

        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: artifactRoot.appendingPathComponent(sharedSource.relativePath).path
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: artifactRoot.appendingPathComponent(uniqueStem.relativePath).path
            )
        )
        XCTAssertNotNil(try await store.loadProject(projectID: second))
        XCTAssertFalse(try await store.containsLiveProject(projectID: first))
    }

    private func writeArtifact(_ relativePath: String, under root: URL) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("artifact".utf8).write(to: url)
    }
}
#endif
