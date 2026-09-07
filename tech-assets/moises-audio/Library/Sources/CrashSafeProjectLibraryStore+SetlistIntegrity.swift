import Foundation

#if canImport(CoreData)
#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

extension CrashSafeProjectLibraryStore: Lane2SetlistIntegrityStore {
    public func setlistIntegrityLiveProjectUUIDs() async throws -> Set<UUID> {
        Set(try await listLiveProjectIDs().map(\.rawValue))
    }

    public func setlistIntegritySnapshots() async throws -> [Lane2SetlistIntegritySnapshot] {
        try await listSetlists().map { setlist in
            Lane2SetlistIntegritySnapshot(
                setlistUUID: setlist.id.rawValue,
                entries: setlist.entries.map {
                    Lane2SetlistIntegrityEntry(
                        entryUUID: $0.id.rawValue,
                        projectUUID: $0.projectID.rawValue,
                        position: $0.position
                    )
                }
            )
        }
    }

    public func setlistIntegrityReplaceEntries(
        setlistUUID: UUID,
        orderedProjectUUIDs: [UUID]
    ) async throws {
        try await replaceSetlistEntries(
            setlistID: SetlistID(rawValue: setlistUUID),
            orderedProjectIDs: orderedProjectUUIDs.map(ProjectID.init(rawValue:))
        )
    }

    /// Startup/maintenance repair for setlist ordering and dead project references.
    /// Repeated project references are intentionally preserved because the frozen contract allows them.
    @discardableResult
    public func reconcileSetlistIntegrity() async throws -> Lane2SetlistIntegrityRecoveryReport {
        try await Lane2SetlistIntegrityReconciler(store: self).reconcile()
    }
}
#endif
