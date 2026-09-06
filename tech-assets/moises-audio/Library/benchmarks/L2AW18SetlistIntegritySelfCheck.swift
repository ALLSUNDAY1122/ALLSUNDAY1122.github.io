import Foundation

private actor MemorySetlistStore: Lane2SetlistIntegrityStore {
    private var live: Set<UUID>
    private var snapshots: [Lane2SetlistIntegritySnapshot]
    private(set) var replacements = 0

    init(live: Set<UUID>, snapshots: [Lane2SetlistIntegritySnapshot]) {
        self.live = live
        self.snapshots = snapshots
    }

    func setlistIntegrityLiveProjectUUIDs() async throws -> Set<UUID> { live }
    func setlistIntegritySnapshots() async throws -> [Lane2SetlistIntegritySnapshot] { snapshots }

    func setlistIntegrityReplaceEntries(setlistUUID: UUID, orderedProjectUUIDs: [UUID]) async throws {
        guard let index = snapshots.firstIndex(where: { $0.setlistUUID == setlistUUID }) else { return }
        replacements += 1
        snapshots[index] = Lane2SetlistIntegritySnapshot(
            setlistUUID: setlistUUID,
            entries: orderedProjectUUIDs.enumerated().map { position, projectUUID in
                Lane2SetlistIntegrityEntry(
                    entryUUID: deterministicUUID(seed: "\(setlistUUID.uuidString)-\(position)-\(projectUUID.uuidString)"),
                    projectUUID: projectUUID,
                    position: position
                )
            }
        )
    }
}

private func deterministicUUID(seed: String) -> UUID {
    var bytes = Array(repeating: UInt8(0), count: 16)
    for (index, byte) in seed.utf8.enumerated() {
        bytes[index % 16] = bytes[index % 16] &+ byte &+ UInt8(truncatingIfNeeded: index)
    }
    bytes[6] = (bytes[6] & 0x0f) | 0x40
    bytes[8] = (bytes[8] & 0x3f) | 0x80
    return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
}

@main
struct L2AW18SetlistIntegritySelfCheck {
    static func main() async throws {
        var scenarios = 0
        let a = deterministicUUID(seed: "project-a")
        let b = deterministicUUID(seed: "project-b")
        let dead = deterministicUUID(seed: "project-dead")
        let setlist = deterministicUUID(seed: "setlist")

        do {
            let entries = [
                Lane2SetlistIntegrityEntry(entryUUID: deterministicUUID(seed: "e1"), projectUUID: a, position: 0),
                Lane2SetlistIntegrityEntry(entryUUID: deterministicUUID(seed: "e2"), projectUUID: b, position: 1),
                Lane2SetlistIntegrityEntry(entryUUID: deterministicUUID(seed: "e3"), projectUUID: a, position: 2)
            ]
            let plan = try Lane2SetlistIntegrityPolicy.plan(entries: entries, liveProjectUUIDs: [a, b])
            guard !plan.requiresRewrite, plan.orderedProjectUUIDs == [a, b, a] else { fatalError("canonical duplicate project flow changed") }
            scenarios += 1
        }

        do {
            let low = deterministicUUID(seed: "low")
            let high = deterministicUUID(seed: "high")
            let entries = [
                Lane2SetlistIntegrityEntry(entryUUID: high, projectUUID: b, position: 4),
                Lane2SetlistIntegrityEntry(entryUUID: low, projectUUID: a, position: -2)
            ]
            let plan = try Lane2SetlistIntegrityPolicy.plan(entries: entries, liveProjectUUIDs: [a, b])
            guard plan.requiresRewrite, plan.orderedProjectUUIDs == [a, b], plan.normalizedEntryUUIDs.count == 2 else { fatalError("position normalization") }
            scenarios += 1
        }

        do {
            let entries = [
                Lane2SetlistIntegrityEntry(entryUUID: deterministicUUID(seed: "d1"), projectUUID: a, position: 0),
                Lane2SetlistIntegrityEntry(entryUUID: deterministicUUID(seed: "d2"), projectUUID: dead, position: 1),
                Lane2SetlistIntegrityEntry(entryUUID: deterministicUUID(seed: "d3"), projectUUID: b, position: 2)
            ]
            let plan = try Lane2SetlistIntegrityPolicy.plan(entries: entries, liveProjectUUIDs: [a, b])
            guard plan.orderedProjectUUIDs == [a, b], plan.removedDeadEntryUUIDs.count == 1, plan.normalizedEntryUUIDs.count == 1 else { fatalError("dead project compaction") }
            scenarios += 1
        }

        do {
            let duplicate = deterministicUUID(seed: "duplicate-entry")
            let entries = [
                Lane2SetlistIntegrityEntry(entryUUID: duplicate, projectUUID: a, position: 0),
                Lane2SetlistIntegrityEntry(entryUUID: duplicate, projectUUID: b, position: 1)
            ]
            do {
                _ = try Lane2SetlistIntegrityPolicy.plan(entries: entries, liveProjectUUIDs: [a, b])
                fatalError("duplicate entry identity accepted")
            } catch Lane2SetlistIntegrityFailure.duplicateEntryIdentity {
                scenarios += 1
            }
        }

        do {
            let entries = [Lane2SetlistIntegrityEntry(entryUUID: deterministicUUID(seed: "gap"), projectUUID: a, position: 2)]
            do {
                try Lane2SetlistIntegrityPolicy.requireCanonical(entries: entries, liveProjectUUIDs: [a])
                fatalError("gap accepted")
            } catch Lane2SetlistIntegrityFailure.nonCanonicalPosition {
                scenarios += 1
            }
        }

        do {
            let store = MemorySetlistStore(
                live: [a, b],
                snapshots: [
                    Lane2SetlistIntegritySnapshot(
                        setlistUUID: setlist,
                        entries: [
                            Lane2SetlistIntegrityEntry(entryUUID: deterministicUUID(seed: "r1"), projectUUID: a, position: 7),
                            Lane2SetlistIntegrityEntry(entryUUID: deterministicUUID(seed: "r2"), projectUUID: dead, position: 8),
                            Lane2SetlistIntegrityEntry(entryUUID: deterministicUUID(seed: "r3"), projectUUID: a, position: 9),
                            Lane2SetlistIntegrityEntry(entryUUID: deterministicUUID(seed: "r4"), projectUUID: b, position: 10)
                        ]
                    )
                ]
            )
            let report = try await Lane2SetlistIntegrityReconciler(store: store).reconcile()
            guard report.scannedSetlists == 1, report.rewrittenSetlists == 1, report.removedDeadEntries == 1 else { fatalError("reconcile report") }
            let final = try await store.setlistIntegritySnapshots()[0]
            guard final.entries.map(\.projectUUID) == [a, a, b], final.entries.map(\.position) == [0, 1, 2] else { fatalError("reconcile result") }
            scenarios += 1
        }

        do {
            let s = Lane2SetlistIntegritySnapshot(setlistUUID: setlist, entries: [])
            let store = MemorySetlistStore(live: [a], snapshots: [s, s])
            do {
                _ = try await Lane2SetlistIntegrityReconciler(store: store).reconcile()
                fatalError("duplicate setlist accepted")
            } catch Lane2SetlistIntegrityFailure.duplicateSetlistIdentity {
                scenarios += 1
            }
        }

        let largeSetlist = deterministicUUID(seed: "large-setlist")
        let projectPool = (0..<100).map { deterministicUUID(seed: "p-\($0)") }
        var largeEntries: [Lane2SetlistIntegrityEntry] = []
        largeEntries.reserveCapacity(100_000)
        for index in 0..<100_000 {
            largeEntries.append(
                Lane2SetlistIntegrityEntry(
                    entryUUID: deterministicUUID(seed: "large-entry-\(index)"),
                    projectUUID: projectPool[index % projectPool.count],
                    position: 100_000 - index
                )
            )
        }
        let clock = ContinuousClock()
        let start = clock.now
        let plan = try Lane2SetlistIntegrityPolicy.plan(entries: largeEntries, liveProjectUUIDs: Set(projectPool))
        let elapsed = start.duration(to: clock.now)
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        guard plan.orderedProjectUUIDs.count == 100_000, plan.normalizedEntryUUIDs.count == 100_000 else { fatalError("large plan") }
        _ = largeSetlist
        scenarios += 1

        print(String(format: "L2_AW18_SELF_TEST_PASS scenarios=%d entries=100000 elapsed_seconds=%.6f", scenarios, seconds))
    }
}
