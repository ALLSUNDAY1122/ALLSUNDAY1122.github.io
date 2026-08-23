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
        return RecoverableLibraryOpenResult(library: library, metadataOpen: metadataOpen)
    }
}
#endif
