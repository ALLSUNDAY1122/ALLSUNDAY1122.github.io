import Foundation
import XCTest

private actor AW18MemoryStore: Lane2SetlistIntegrityStore {
    var live: Set<UUID>
    var snapshots: [Lane2SetlistIntegritySnapshot]
    var rewrites: [[UUID]] = []

    init(live: Set<UUID>, snapshots: [Lane2SetlistIntegritySnapshot]) {
        self.live = live
        self.snapshots = snapshots
    }

    func setlistIntegrityLiveProjectUUIDs() async throws -> Set<UUID> { live }
    func setlistIntegritySnapshots() async throws -> [Lane2SetlistIntegritySnapshot] { snapshots }

    func setlistIntegrityReplaceEntries(setlistUUID: UUID, orderedProjectUUIDs: [UUID]) async throws {
        rewrites.append(orderedProjectUUIDs)
        guard let index = snapshots.firstIndex(where: { $0.setlistUUID == setlistUUID }) else { return }
        snapshots[index] = Lane2SetlistIntegritySnapshot(
            setlistUUID: setlistUUID,
            entries: orderedProjectUUIDs.enumerated().map { position, projectUUID in
                Lane2SetlistIntegrityEntry(
                    entryUUID: UUID(),
                    projectUUID: projectUUID,
                    position: position
                )
            }
        )
    }
}

final class SetlistIntegrityRecoveryTests: XCTestCase {
    func testDuplicateProjectReferencesArePreserved() throws {
        let project = UUID()
        let entries = (0..<3).map {
            Lane2SetlistIntegrityEntry(entryUUID: UUID(), projectUUID: project, position: $0)
        }
        let plan = try Lane2SetlistIntegrityPolicy.plan(entries: entries, liveProjectUUIDs: [project])
        XCTAssertFalse(plan.requiresRewrite)
        XCTAssertEqual(plan.orderedProjectUUIDs, [project, project, project])
    }

    func testDeadReferenceIsRemovedAndSurvivorsCompact() throws {
        let liveA = UUID(), liveB = UUID(), dead = UUID()
        let entries = [
            Lane2SetlistIntegrityEntry(entryUUID: UUID(), projectUUID: liveA, position: 5),
            Lane2SetlistIntegrityEntry(entryUUID: UUID(), projectUUID: dead, position: 6),
            Lane2SetlistIntegrityEntry(entryUUID: UUID(), projectUUID: liveB, position: 9)
        ]
        let plan = try Lane2SetlistIntegrityPolicy.plan(entries: entries, liveProjectUUIDs: [liveA, liveB])
        XCTAssertEqual(plan.orderedProjectUUIDs, [liveA, liveB])
        XCTAssertEqual(plan.removedDeadEntryUUIDs.count, 1)
        XCTAssertEqual(plan.normalizedEntryUUIDs.count, 2)
    }

    func testEqualPositionsUseStableEntryIdentityTieBreak() throws {
        let a = UUID(), b = UUID()
        let low = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let high = UUID(uuidString: "ffffffff-ffff-4fff-bfff-ffffffffffff")!
        let plan = try Lane2SetlistIntegrityPolicy.plan(
            entries: [
                Lane2SetlistIntegrityEntry(entryUUID: high, projectUUID: b, position: 0),
                Lane2SetlistIntegrityEntry(entryUUID: low, projectUUID: a, position: 0)
            ],
            liveProjectUUIDs: [a, b]
        )
        XCTAssertEqual(plan.orderedProjectUUIDs, [a, b])
        XCTAssertTrue(plan.requiresRewrite)
    }

    func testDuplicateEntryIdentityFailsClosed() throws {
        let entry = UUID(), project = UUID()
        XCTAssertThrowsError(
            try Lane2SetlistIntegrityPolicy.plan(
                entries: [
                    Lane2SetlistIntegrityEntry(entryUUID: entry, projectUUID: project, position: 0),
                    Lane2SetlistIntegrityEntry(entryUUID: entry, projectUUID: project, position: 1)
                ],
                liveProjectUUIDs: [project]
            )
        )
    }

    func testRequireCanonicalRejectsGapAndDeadReference() throws {
        let live = UUID(), dead = UUID()
        XCTAssertThrowsError(
            try Lane2SetlistIntegrityPolicy.requireCanonical(
                entries: [Lane2SetlistIntegrityEntry(entryUUID: UUID(), projectUUID: live, position: 2)],
                liveProjectUUIDs: [live]
            )
        )
        XCTAssertThrowsError(
            try Lane2SetlistIntegrityPolicy.requireCanonical(
                entries: [Lane2SetlistIntegrityEntry(entryUUID: UUID(), projectUUID: dead, position: 0)],
                liveProjectUUIDs: [live]
            )
        )
    }

    func testReconcilerRewritesThenReadBackVerifies() async throws {
        let live = UUID(), dead = UUID(), setlist = UUID()
        let store = AW18MemoryStore(
            live: [live],
            snapshots: [
                Lane2SetlistIntegritySnapshot(
                    setlistUUID: setlist,
                    entries: [
                        Lane2SetlistIntegrityEntry(entryUUID: UUID(), projectUUID: dead, position: -1),
                        Lane2SetlistIntegrityEntry(entryUUID: UUID(), projectUUID: live, position: 9),
                        Lane2SetlistIntegrityEntry(entryUUID: UUID(), projectUUID: live, position: 10)
                    ]
                )
            ]
        )
        let report = try await Lane2SetlistIntegrityReconciler(store: store).reconcile()
        XCTAssertEqual(report.rewrittenSetlists, 1)
        XCTAssertEqual(report.removedDeadEntries, 1)
        let rewrites = await store.rewrites
        XCTAssertEqual(rewrites, [[live, live]])
    }
}
