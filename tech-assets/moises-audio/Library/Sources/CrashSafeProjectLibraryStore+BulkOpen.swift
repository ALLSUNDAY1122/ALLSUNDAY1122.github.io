import Foundation

#if canImport(CoreData)
public extension CrashSafeProjectLibraryStore {
    /// Production open for callers that do not need PreservingCoreDataStoreOpener.
    /// AW24 bounds legacy preparation; AW26 injects targeted live-reference authorization; AW31
    /// reconciles bounded previous-session managed publication intents before AW30 compatibility
    /// census. Census runs only after publication recovery is safe; AW46 deletion-ownership manifest
    /// reconciliation is centralized in CrashSafeProjectLibraryStore initialization so every
    /// construction path receives it exactly once. Corrupt/unsafe publication state leaves inventory
    /// authority absent for this open. In-memory tests retain the full-projection fallback.
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
