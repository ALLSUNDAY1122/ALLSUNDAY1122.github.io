import Foundation
import XCTest

#if canImport(CoreData)
import CoreData

#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

final class CoreDataSetlistOrphanEntryRecoveryTests: XCTestCase {
    func testRecoveryNoOpPreservesValidRepeatedEntries() async throws {
        let store = try CoreDataProjectLibraryStore(configuration: .init(inMemory: true))
        let first = try await store.createProject(source: makeSource(path: "Imports/aw20/first.m4a"))
        let second = try await store.createProject(source: makeSource(path: "Imports/aw20/second.m4a"))
        let setlist = try await store.createSetlist(name: "AW20")
        try await store.replaceSetlistEntries(
            setlistID: setlist,
            orderedProjectIDs: [second, first, second]
        )

        let report = try await store.reconcileOrphanSetlistEntries()
        XCTAssertEqual(report.liveSetlists, 1)
        XCTAssertEqual(report.scannedEntries, 3)
        XCTAssertEqual(report.removedOrphanEntries, 0)

        let snapshot = try XCTUnwrap(try await store.listSetlists().first)
        XCTAssertEqual(snapshot.entries.map(\.projectID), [second, first, second])
        XCTAssertEqual(snapshot.entries.map(\.position), [0, 1, 2])
    }

    func testRecoveryOnEmptyStoreIsIdempotent() async throws {
        let store = try CoreDataProjectLibraryStore(configuration: .init(inMemory: true))
        let first = try await store.reconcileOrphanSetlistEntries()
        let second = try await store.reconcileOrphanSetlistEntries()
        XCTAssertEqual(first, Lane2SetlistOrphanEntryRecoveryReport(scannedEntries: 0, liveSetlists: 0, removedOrphanEntries: 0))
        XCTAssertEqual(second, first)
    }

    private func makeSource(path: String) -> LocalAudioAsset {
        LocalAudioAsset(
            id: AssetID(),
            relativePath: path,
            mediaKind: .audio,
            durationSeconds: 60
        )
    }
}
#endif
