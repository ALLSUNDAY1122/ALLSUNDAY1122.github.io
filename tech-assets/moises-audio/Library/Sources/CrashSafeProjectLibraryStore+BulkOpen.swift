import Foundation

#if canImport(CoreData)
public extension CrashSafeProjectLibraryStore {
    /// Production open for callers that do not need PreservingCoreDataStoreOpener.
    /// AW24 bounds legacy preparation; AW26 injects targeted live-reference authorization for
    /// file-backed stores. In-memory tests retain the compatibility full-projection fallback.
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
