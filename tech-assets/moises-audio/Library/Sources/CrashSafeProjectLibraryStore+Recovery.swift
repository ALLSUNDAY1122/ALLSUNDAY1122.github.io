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
    /// Production-safe open path for L2-M03.
    /// Existing metadata is preserved before migration; corruption never triggers a silent empty-store reset.
    /// Delete recovery converges first, raw orphan setlist-entry rows are removed second, then AW18
    /// reconciles visible setlists against the resulting live-project set and canonical ordering.
    static func openPreservingUserData(
        metadataStoreURL: URL,
        artifactRootURL: URL,
        recoveryRootURL: URL? = nil
    ) async throws -> RecoverableLibraryOpenResult {
        let metadataOpen = try await PreservingCoreDataStoreOpener.open(
            storeURL: metadataStoreURL,
            recoveryRootURL: recoveryRootURL
        )
        let library = try CrashSafeProjectLibraryStore(
            metadata: metadataOpen.store,
            artifactRootURL: artifactRootURL
        )
        _ = try await library.recoverInterruptedOperations()
        _ = try await metadataOpen.store.reconcileOrphanSetlistEntries()
        _ = try await library.reconcileSetlistIntegrity()
        return RecoverableLibraryOpenResult(library: library, metadataOpen: metadataOpen)
    }
}
#endif
