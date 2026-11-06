import Foundation

public struct Lane2SetlistIntegrityEntry: Hashable, Sendable {
    public let entryUUID: UUID
    public let projectUUID: UUID
    public let position: Int

    public init(entryUUID: UUID, projectUUID: UUID, position: Int) {
        self.entryUUID = entryUUID
        self.projectUUID = projectUUID
        self.position = position
    }
}

public struct Lane2SetlistIntegritySnapshot: Equatable, Sendable {
    public let setlistUUID: UUID
    public let entries: [Lane2SetlistIntegrityEntry]

    public init(setlistUUID: UUID, entries: [Lane2SetlistIntegrityEntry]) {
        self.setlistUUID = setlistUUID
        self.entries = entries
    }
}

public struct Lane2SetlistIntegrityPlan: Equatable, Sendable {
    public let orderedProjectUUIDs: [UUID]
    public let removedDeadEntryUUIDs: [UUID]
    public let normalizedEntryUUIDs: [UUID]

    public init(
        orderedProjectUUIDs: [UUID],
        removedDeadEntryUUIDs: [UUID],
        normalizedEntryUUIDs: [UUID]
    ) {
        self.orderedProjectUUIDs = orderedProjectUUIDs
        self.removedDeadEntryUUIDs = removedDeadEntryUUIDs.sorted { $0.uuidString < $1.uuidString }
        self.normalizedEntryUUIDs = normalizedEntryUUIDs.sorted { $0.uuidString < $1.uuidString }
    }

    public var requiresRewrite: Bool {
        !removedDeadEntryUUIDs.isEmpty || !normalizedEntryUUIDs.isEmpty
    }
}

public struct Lane2SetlistIntegrityRecoveryReport: Equatable, Sendable {
    public let scannedSetlists: Int
    public let rewrittenSetlists: Int
    public let removedDeadEntries: Int
    public let normalizedPositions: Int

    public init(
        scannedSetlists: Int,
        rewrittenSetlists: Int,
        removedDeadEntries: Int,
        normalizedPositions: Int
    ) {
        self.scannedSetlists = scannedSetlists
        self.rewrittenSetlists = rewrittenSetlists
        self.removedDeadEntries = removedDeadEntries
        self.normalizedPositions = normalizedPositions
    }
}

public enum Lane2SetlistIntegrityFailure: Error, Equatable, Sendable {
    case duplicateSetlistIdentity(UUID)
    case duplicateEntryIdentity(UUID)
    case nonCanonicalPosition(entryUUID: UUID, expected: Int, actual: Int)
    case deadProjectReference(entryUUID: UUID, projectUUID: UUID)
}

public enum Lane2SetlistIntegrityPolicy {
    /// Produces a deterministic repair plan while preserving repeated project references.
    /// Entry identity is the tie-breaker when legacy/corrupt positions collide.
    public static func plan(
        entries: [Lane2SetlistIntegrityEntry],
        liveProjectUUIDs: Set<UUID>
    ) throws -> Lane2SetlistIntegrityPlan {
        try requireUniqueEntryIdentity(entries)

        let survivors = entries
            .filter { liveProjectUUIDs.contains($0.projectUUID) }
            .sorted(by: canonicalLessThan)
        let removed = entries
            .filter { !liveProjectUUIDs.contains($0.projectUUID) }
            .map(\.entryUUID)

        var normalized: [UUID] = []
        normalized.reserveCapacity(survivors.count)
        for (index, entry) in survivors.enumerated() where entry.position != index {
            normalized.append(entry.entryUUID)
        }

        return Lane2SetlistIntegrityPlan(
            orderedProjectUUIDs: survivors.map(\.projectUUID),
            removedDeadEntryUUIDs: removed,
            normalizedEntryUUIDs: normalized
        )
    }

    /// Fail-closed verification used after recovery and before treating a setlist snapshot as canonical.
    public static func requireCanonical(
        entries: [Lane2SetlistIntegrityEntry],
        liveProjectUUIDs: Set<UUID>
    ) throws {
        try requireUniqueEntryIdentity(entries)
        let ordered = entries.sorted(by: canonicalLessThan)
        for (index, entry) in ordered.enumerated() {
            guard liveProjectUUIDs.contains(entry.projectUUID) else {
                throw Lane2SetlistIntegrityFailure.deadProjectReference(
                    entryUUID: entry.entryUUID,
                    projectUUID: entry.projectUUID
                )
            }
            guard entry.position == index else {
                throw Lane2SetlistIntegrityFailure.nonCanonicalPosition(
                    entryUUID: entry.entryUUID,
                    expected: index,
                    actual: entry.position
                )
            }
        }
    }

    private static func requireUniqueEntryIdentity(_ entries: [Lane2SetlistIntegrityEntry]) throws {
        var seen = Set<UUID>()
        for entry in entries where !seen.insert(entry.entryUUID).inserted {
            throw Lane2SetlistIntegrityFailure.duplicateEntryIdentity(entry.entryUUID)
        }
    }

    private static func canonicalLessThan(
        _ lhs: Lane2SetlistIntegrityEntry,
        _ rhs: Lane2SetlistIntegrityEntry
    ) -> Bool {
        if lhs.position != rhs.position { return lhs.position < rhs.position }
        return lhs.entryUUID.uuidString < rhs.entryUUID.uuidString
    }
}

public protocol Lane2SetlistIntegrityStore: Sendable {
    func setlistIntegrityLiveProjectUUIDs() async throws -> Set<UUID>
    func setlistIntegritySnapshots() async throws -> [Lane2SetlistIntegritySnapshot]
    func setlistIntegrityReplaceEntries(
        setlistUUID: UUID,
        orderedProjectUUIDs: [UUID]
    ) async throws
}

public struct Lane2SetlistIntegrityReconciler: Sendable {
    private let store: any Lane2SetlistIntegrityStore

    public init(store: any Lane2SetlistIntegrityStore) {
        self.store = store
    }

    /// Idempotent startup reconciliation. Each setlist replacement is an atomic store mutation;
    /// a process death between setlists is safe because the next relaunch simply repeats the plan.
    public func reconcile() async throws -> Lane2SetlistIntegrityRecoveryReport {
        let liveBefore = try await store.setlistIntegrityLiveProjectUUIDs()
        let snapshots = try await store.setlistIntegritySnapshots()
        try Self.requireUniqueSetlists(snapshots)

        var rewritten = 0
        var removed = 0
        var normalized = 0

        for snapshot in snapshots.sorted(by: { $0.setlistUUID.uuidString < $1.setlistUUID.uuidString }) {
            let plan = try Lane2SetlistIntegrityPolicy.plan(
                entries: snapshot.entries,
                liveProjectUUIDs: liveBefore
            )
            removed += plan.removedDeadEntryUUIDs.count
            normalized += plan.normalizedEntryUUIDs.count
            guard plan.requiresRewrite else { continue }
            try await store.setlistIntegrityReplaceEntries(
                setlistUUID: snapshot.setlistUUID,
                orderedProjectUUIDs: plan.orderedProjectUUIDs
            )
            rewritten += 1
        }

        // Read back from the store rather than trusting the requested writes. This also catches a
        // racing project deletion or a backend that failed to persist canonical positions.
        let liveAfter = try await store.setlistIntegrityLiveProjectUUIDs()
        let verified = try await store.setlistIntegritySnapshots()
        try Self.requireUniqueSetlists(verified)
        for snapshot in verified {
            try Lane2SetlistIntegrityPolicy.requireCanonical(
                entries: snapshot.entries,
                liveProjectUUIDs: liveAfter
            )
        }

        return Lane2SetlistIntegrityRecoveryReport(
            scannedSetlists: snapshots.count,
            rewrittenSetlists: rewritten,
            removedDeadEntries: removed,
            normalizedPositions: normalized
        )
    }

    private static func requireUniqueSetlists(
        _ snapshots: [Lane2SetlistIntegritySnapshot]
    ) throws {
        var seen = Set<UUID>()
        for snapshot in snapshots where !seen.insert(snapshot.setlistUUID).inserted {
            throw Lane2SetlistIntegrityFailure.duplicateSetlistIdentity(snapshot.setlistUUID)
        }
    }
}
