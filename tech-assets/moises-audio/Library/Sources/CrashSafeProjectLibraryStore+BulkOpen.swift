import Foundation

#if canImport(CoreData)
public extension CrashSafeProjectLibraryStore {
    /// Production open for callers that do not need PreservingCoreDataStoreOpener.
    /// AW24 bounds legacy preparation; AW26 injects targeted live-reference authorization; AW31
    /// reconciles bounded previous-session managed publication intents before AW30 compatibility
    /// census. Recovery/census failures do not block user data: inventory authority is invalidated
    /// or remains absent and AW28 compatibility behavior stays active. In-memory tests retain the
    /// full-projection fallback.
    static func openBulkPrepared(
        metadataConfiguration: CoreDataProjectLibraryStore.Configuration,
        artifactRootURL: URL
    ) async throws -> CrashSafeProjectLibraryStore {
        let metadata = try CoreDataProjectLibraryStore(configuration: metadataConfiguration)
        let resolver: (any Lane2LiveArtifactReferenceResolving)?
        if !metadataConfiguration.inMemory,
           let metadataStoreURL = metadataConfiguration.storeURL {
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
            resolver = Lane2CoreDataLiveArtifactReferenceResolver(storeURL: metadataStoreURL)
        } else {
            resolver = nil
        }
        let store = try CrashSafeProjectLibraryStore(
            metadata: metadata,
            artifactRootURL: artifactRootURL,
            liveReferenceResolver: resolver
        )
        _ = try await store.recoverInterruptedOperations()
        return store
    }
}
#endif
