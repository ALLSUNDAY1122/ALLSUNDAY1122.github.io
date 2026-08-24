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
    /// roots, then AW30 advances one durable compatibility-census chunk when authority is absent.
    /// Publication/census failures are nonblocking for user data: inventory authority is revoked or
    /// remains absent and compatibility mode continues until a later safe reconciliation succeeds.
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
        do {
            _ = try publicationRecovery.recoverPreviousSessionPublications()
        } catch {
            publicationRecovery.invalidateAuthorityAfterRecoveryFailure()
        }
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
