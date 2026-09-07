import Foundation

@main
struct L2AW20SetlistOrphanEntrySelfCheck {
    static func main() throws {
        let start = Date()
        var scenarios = 0

        let liveA = UUID()
        let liveB = UUID()
        let dead = UUID()
        let keep1 = Lane2SetlistEntryOwnership(entryUUID: UUID(), setlistUUID: liveA)
        let keep2 = Lane2SetlistEntryOwnership(entryUUID: UUID(), setlistUUID: liveB)
        let orphan1 = Lane2SetlistEntryOwnership(entryUUID: UUID(), setlistUUID: dead)
        let orphan2 = Lane2SetlistEntryOwnership(entryUUID: UUID(), setlistUUID: dead)

        let mixed = try Lane2SetlistOrphanEntryPolicy.plan(
            entries: [keep1, orphan2, keep2, orphan1],
            liveSetlistUUIDs: [liveA, liveB]
        )
        precondition(Set(mixed.orphanEntryUUIDs) == Set([orphan1.entryUUID, orphan2.entryUUID]))
        scenarios += 1

        let clean = try Lane2SetlistOrphanEntryPolicy.plan(
            entries: [keep1, keep2],
            liveSetlistUUIDs: [liveA, liveB]
        )
        precondition(!clean.requiresRepair)
        scenarios += 1

        let allDead = try Lane2SetlistOrphanEntryPolicy.plan(
            entries: [orphan1, orphan2],
            liveSetlistUUIDs: []
        )
        precondition(allDead.orphanEntryUUIDs.count == 2)
        scenarios += 1

        do {
            _ = try Lane2SetlistOrphanEntryPolicy.plan(
                entries: [
                    Lane2SetlistEntryOwnership(entryUUID: orphan1.entryUUID, setlistUUID: dead),
                    Lane2SetlistEntryOwnership(entryUUID: orphan1.entryUUID, setlistUUID: liveA)
                ],
                liveSetlistUUIDs: [liveA]
            )
            fatalError("duplicate identity should fail")
        } catch Lane2SetlistOrphanEntryFailure.duplicateEntryIdentity {
            scenarios += 1
        }

        do {
            try Lane2SetlistOrphanEntryPolicy.requireConverged(entries: [orphan1], liveSetlistUUIDs: [])
            fatalError("remaining orphan should fail convergence")
        } catch Lane2SetlistOrphanEntryFailure.repairDidNotConverge {
            scenarios += 1
        }

        try Lane2SetlistOrphanEntryPolicy.requireConverged(entries: [keep1, keep2], liveSetlistUUIDs: [liveA, liveB])
        scenarios += 1

        let setlistCount = 10_000
        let entryCount = 100_000
        let liveSetlists = (0..<setlistCount).map { _ in UUID() }
        let deadSetlists = (0..<500).map { _ in UUID() }
        let liveSet = Set(liveSetlists)
        var scaleEntries: [Lane2SetlistEntryOwnership] = []
        scaleEntries.reserveCapacity(entryCount)
        var expectedOrphans = 0
        for index in 0..<entryCount {
            if index % 20 == 0 {
                scaleEntries.append(
                    Lane2SetlistEntryOwnership(
                        entryUUID: UUID(),
                        setlistUUID: deadSetlists[index % deadSetlists.count]
                    )
                )
                expectedOrphans += 1
            } else {
                scaleEntries.append(
                    Lane2SetlistEntryOwnership(
                        entryUUID: UUID(),
                        setlistUUID: liveSetlists[index % liveSetlists.count]
                    )
                )
            }
        }
        let scale = try Lane2SetlistOrphanEntryPolicy.plan(entries: scaleEntries, liveSetlistUUIDs: liveSet)
        precondition(scale.orphanEntryUUIDs.count == expectedOrphans)
        precondition(scale.scannedEntries == entryCount)
        precondition(scale.liveSetlists == setlistCount)
        scenarios += 1

        let orphanSet = Set(scale.orphanEntryUUIDs)
        let remaining = scaleEntries.filter { !orphanSet.contains($0.entryUUID) }
        try Lane2SetlistOrphanEntryPolicy.requireConverged(entries: remaining, liveSetlistUUIDs: liveSet)
        scenarios += 1

        let elapsed = Date().timeIntervalSince(start)
        print(String(format: "L2_AW20_SELF_TEST_PASS scenarios=%d entries=%d setlists=%d orphans=%d elapsed_seconds=%.6f", scenarios, entryCount, setlistCount, expectedOrphans, elapsed))
    }
}
