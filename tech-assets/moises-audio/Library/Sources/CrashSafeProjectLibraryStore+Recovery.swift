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
    /// AW31 first reconciles bounded previous-session publication intents without walking managed
    /// roots, then AW30 advances one durable compatibility-census chunk only after publication
    /// recovery is proven safe. AW46 repairs missing/corrupt/stale deletion-ownership active-shard
    /// manifests from the fixed 256-shard namespace before CrashSafe deletion recovery starts.
    /// Corrupt/unsafe publication state leaves authority absent for this open so census can never
    /// re-authorize an unresolved publication gap.
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
        let publicationRecovery = Lane2ManagedArtifactPublicationRecovery(rootURL: artifactRootURL)
        let publicationRecoverySafe: Bool
        do {
            let report = try publicationRecovery.recoverPreviousSessionPublications()
            publicationRecoverySafe = report.retainedUnsafe.isEmpty && !report.authorityInvalidated
        } catch {
            publicationRecovery.invalidateAuthorityAfterRecoveryFailure()
            publicationRecoverySafe = false
        }
        if publicationRecoverySafe {
            _ = try? Lane2ManagedArtifactCompatibilityCensus(
                rootURL: artifactRootURL
            ).advance()
        }
        _ = try Lane2DeletionOwnershipManifestRecovery(
            rootURL: artifactRootURL
        ).reconcile()
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
