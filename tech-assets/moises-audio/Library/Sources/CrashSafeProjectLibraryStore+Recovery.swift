import Foundation

#if canImport(CoreData)
#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

public struct RecoverableLibraryOpenResult: Sendable {
    public let library: CrashSafeProjectLibraryStore
    public let metadataOpen: PreservingStoreOpenResult

    public init(library: CrashSafeProjectLibraryStore, metadataOpen: PreservingStoreOpenResult) {
        self.library = library
        self.metadataOpen = metadataOpen
    }
}

public extension CrashSafeProjectLibraryStore {
    /// Production-safe preserving open path. AW24 prepares only one bounded legacy tombstone slice
    /// per launch before crash-safe delete recovery; AW26 injects a targeted read-only resolver;
    /// AW30 advances one durable managed-artifact compatibility census chunk per launch so upgraded
    /// stores converge to AW29's sharded steady-state without granting premature inventory authority.
    /// Census failure is nonblocking for user data: authority remains absent and compatibility mode
    /// continues until a later safe census succeeds.
    static func openPreservingUserData(
        metadataStoreURL: URL,
        artifactRootURL: URL,
        recoveryRootURL: URL? = nil
    ) async throws -> RecoverableLibraryOpenResult {
        let metadataOpen = try await PreservingCoreDataStoreOpener.open(
            storeURL: metadataStoreURL,
            recoveryRootURL: recoveryRootURL
        )
        _ = try await Lane2LegacyTombstoneBoundedMigrator.prepareNextSliceIfNeeded(
            metadataStoreURL: metadataStoreURL,
            artifactRootURL: artifactRootURL
        )
        _ = try? Lane2ManagedArtifactCompatibilityCensus(
            rootURL: artifactRootURL
        ).advance()
        let library = try CrashSafeProjectLibraryStore(
            metadata: metadataOpen.store,
            artifactRootURL: artifactRootURL,
            liveReferenceResolver: Lane2CoreDataLiveArtifactReferenceResolver(
                storeURL: metadataStoreURL
            )
        )
        _ = try await library.recoverInterruptedOperations()
        _ = try await metadataOpen.store.reconcileOrphanSetlistEntries()
        _ = try await library.reconcileSetlistIntegrity()
        return RecoverableLibraryOpenResult(library: library, metadataOpen: metadataOpen)
    }
}
#endif
