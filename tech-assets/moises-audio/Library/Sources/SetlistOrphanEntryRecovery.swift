import Foundation

public struct Lane2SetlistEntryOwnership: Hashable, Sendable {
    public let entryUUID: UUID
    public let setlistUUID: UUID

    public init(entryUUID: UUID, setlistUUID: UUID) {
        self.entryUUID = entryUUID
        self.setlistUUID = setlistUUID
    }
}

public struct Lane2SetlistOrphanEntryPlan: Equatable, Sendable {
    public let scannedEntries: Int
    public let liveSetlists: Int
    public let orphanEntryUUIDs: [UUID]

    public init(scannedEntries: Int, liveSetlists: Int, orphanEntryUUIDs: [UUID]) {
        self.scannedEntries = scannedEntries
        self.liveSetlists = liveSetlists
        self.orphanEntryUUIDs = orphanEntryUUIDs.sorted { $0.uuidString < $1.uuidString }
    }

    public var requiresRepair: Bool { !orphanEntryUUIDs.isEmpty }
}

public struct Lane2SetlistOrphanEntryRecoveryReport: Equatable, Sendable {
    public let scannedEntries: Int
    public let liveSetlists: Int
    public let removedOrphanEntries: Int

    public init(scannedEntries: Int, liveSetlists: Int, removedOrphanEntries: Int) {
        self.scannedEntries = scannedEntries
        self.liveSetlists = liveSetlists
        self.removedOrphanEntries = removedOrphanEntries
    }
}

public enum Lane2SetlistOrphanEntryFailure: Error, Equatable, Sendable {
    case duplicateEntryIdentity(UUID)
    case repairDidNotConverge([UUID])
}

public enum Lane2SetlistOrphanEntryPolicy {
    /// Plans deletion only for entries whose owning setlist record no longer exists.
    /// Project repetition and entry ordering are deliberately outside this low-level repair;
    /// AW18 performs those higher-level checks after this pass.
    public static func plan(
        entries: [Lane2SetlistEntryOwnership],
        liveSetlistUUIDs: Set<UUID>
    ) throws -> Lane2SetlistOrphanEntryPlan {
        var seen = Set<UUID>()
        var orphanIDs: [UUID] = []
        orphanIDs.reserveCapacity(entries.count)

        for entry in entries {
            guard seen.insert(entry.entryUUID).inserted else {
                throw Lane2SetlistOrphanEntryFailure.duplicateEntryIdentity(entry.entryUUID)
            }
            if !liveSetlistUUIDs.contains(entry.setlistUUID) {
                orphanIDs.append(entry.entryUUID)
            }
        }

        return Lane2SetlistOrphanEntryPlan(
            scannedEntries: entries.count,
            liveSetlists: liveSetlistUUIDs.count,
            orphanEntryUUIDs: orphanIDs
        )
    }

    public static func requireConverged(
        entries: [Lane2SetlistEntryOwnership],
        liveSetlistUUIDs: Set<UUID>
    ) throws {
        let plan = try plan(entries: entries, liveSetlistUUIDs: liveSetlistUUIDs)
        guard !plan.requiresRepair else {
            throw Lane2SetlistOrphanEntryFailure.repairDidNotConverge(plan.orphanEntryUUIDs)
        }
    }
}
