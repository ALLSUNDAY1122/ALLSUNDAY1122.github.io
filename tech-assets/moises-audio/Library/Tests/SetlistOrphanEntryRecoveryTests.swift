import Foundation
import XCTest

final class SetlistOrphanEntryRecoveryTests: XCTestCase {
    func testNoOrphansRequiresNoRepair() throws {
        let setlist = UUID()
        let entries = [
            Lane2SetlistEntryOwnership(entryUUID: UUID(), setlistUUID: setlist),
            Lane2SetlistEntryOwnership(entryUUID: UUID(), setlistUUID: setlist)
        ]
        let plan = try Lane2SetlistOrphanEntryPolicy.plan(entries: entries, liveSetlistUUIDs: [setlist])
        XCTAssertEqual(plan.scannedEntries, 2)
        XCTAssertEqual(plan.liveSetlists, 1)
        XCTAssertTrue(plan.orphanEntryUUIDs.isEmpty)
        XCTAssertFalse(plan.requiresRepair)
        XCTAssertNoThrow(try Lane2SetlistOrphanEntryPolicy.requireConverged(entries: entries, liveSetlistUUIDs: [setlist]))
    }

    func testMissingSetlistEntriesAreSelectedExactly() throws {
        let live = UUID()
        let missing = UUID()
        let keep = Lane2SetlistEntryOwnership(entryUUID: UUID(), setlistUUID: live)
        let remove1 = Lane2SetlistEntryOwnership(entryUUID: UUID(), setlistUUID: missing)
        let remove2 = Lane2SetlistEntryOwnership(entryUUID: UUID(), setlistUUID: missing)
        let plan = try Lane2SetlistOrphanEntryPolicy.plan(entries: [remove2, keep, remove1], liveSetlistUUIDs: [live])
        XCTAssertEqual(Set(plan.orphanEntryUUIDs), Set([remove1.entryUUID, remove2.entryUUID]))
        XCTAssertFalse(plan.orphanEntryUUIDs.contains(keep.entryUUID))
    }

    func testEmptySetlistCatalogMakesEveryEntryOrphan() throws {
        let entries = (0..<10).map { _ in
            Lane2SetlistEntryOwnership(entryUUID: UUID(), setlistUUID: UUID())
        }
        let plan = try Lane2SetlistOrphanEntryPolicy.plan(entries: entries, liveSetlistUUIDs: [])
        XCTAssertEqual(plan.orphanEntryUUIDs.count, entries.count)
    }

    func testDuplicateEntryIdentityFailsClosed() throws {
        let duplicate = UUID()
        let first = Lane2SetlistEntryOwnership(entryUUID: duplicate, setlistUUID: UUID())
        let second = Lane2SetlistEntryOwnership(entryUUID: duplicate, setlistUUID: UUID())
        XCTAssertThrowsError(try Lane2SetlistOrphanEntryPolicy.plan(entries: [first, second], liveSetlistUUIDs: [])) { error in
            XCTAssertEqual(error as? Lane2SetlistOrphanEntryFailure, .duplicateEntryIdentity(duplicate))
        }
    }

    func testConvergenceRejectsRemainingOrphan() throws {
        let orphan = Lane2SetlistEntryOwnership(entryUUID: UUID(), setlistUUID: UUID())
        XCTAssertThrowsError(try Lane2SetlistOrphanEntryPolicy.requireConverged(entries: [orphan], liveSetlistUUIDs: []))
    }

    func testRepeatedSetlistReferencesAreNotCollapsed() throws {
        let setlist = UUID()
        let entries = (0..<4).map { _ in
            Lane2SetlistEntryOwnership(entryUUID: UUID(), setlistUUID: setlist)
        }
        let plan = try Lane2SetlistOrphanEntryPolicy.plan(entries: entries, liveSetlistUUIDs: [setlist])
        XCTAssertEqual(plan.scannedEntries, 4)
        XCTAssertTrue(plan.orphanEntryUUIDs.isEmpty)
    }
}
