import Foundation
#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

/// Product-composition seam for picker / Files / File Provider imports.
/// The provider lease is converted to a verified app-owned staging snapshot first; the existing
/// AudioImporting implementation then performs codec/media validation using `.appOwnedFile`.
public actor IOProviderSnapshotAudioImporter {
    private let baseImporter: any AudioImporting
    private let acquirer: IOProviderSnapshotAcquirer
    private let fileStore: IOFileStore
    private let fileManager: FileManager

    public init(
        baseImporter: any AudioImporting,
        rootURL: URL,
        maximumFileBytes: Int64,
        storageReserveBytes: Int64,
        chunkBytes: Int = 1024 * 1024,
        fileManager: FileManager = .default
    ) {
        let store = IOFileStore(rootURL: rootURL)
        self.baseImporter = baseImporter
        self.fileStore = store
        self.acquirer = IOProviderSnapshotAcquirer(
            fileStore: store,
            maximumFileBytes: maximumFileBytes,
            storageReserveBytes: storageReserveBytes,
            chunkBytes: chunkBytes
        )
        self.fileManager = fileManager
    }

    public func importExternalFile(
        at sourceURL: URL,
        accessMode: IOExternalFileAccessMode = .securityScoped
    ) async throws -> LocalAudioAsset {
        let staged: IOStagedExternalFile
        do {
            staged = try acquirer.stageProviderFile(
                at: sourceURL,
                accessMode: accessMode,
                fileManager: fileManager
            )
        } catch is CancellationError {
            throw DomainFailure.cancelled
        } catch let error as IOProviderSnapshotAcquisitionError {
            throw Self.map(error)
        } catch let error as IOFileStore.StoreError {
            throw Self.map(error)
        } catch {
            let ns = error as NSError
            throw DomainFailure.processingFailed(code: "PROVIDER_IMPORT_\(ns.code)", retryable: true)
        }

        defer { fileStore.removeIfExists(staged.stagingURL, fileManager: fileManager) }
        let relativePath: String
        do {
            relativePath = try fileStore.relativePath(for: staged.stagingURL)
        } catch {
            throw DomainFailure.processingFailed(code: "PROVIDER_STAGE_PATH_INVALID", retryable: false)
        }
        return try await baseImporter.importAudio(from: .appOwnedFile(relativePath: relativePath))
    }

    private static func map(_ error: IOProviderSnapshotAcquisitionError) -> DomainFailure {
        switch error {
        case .invalidConfiguration, .invalidSourceURL, .sourceInsideAppRoot:
            return .processingFailed(code: "EXTERNAL_SOURCE_URL_INVALID", retryable: false)
        case .sourceMissing, .sourceEmpty:
            return .corruptMedia
        case .sourceNotRegularFile:
            return .unsupportedMedia
        case .sourceTooLarge:
            return .processingFailed(code: "IMPORT_FILE_TOO_LARGE", retryable: false)
        case .securityScopeDenied:
            return .accessDenied
        case .providerCoordinationFailed:
            return .providerUnavailable
        case .sourceChangedDuringAcquisition:
            return .processingFailed(code: "PROVIDER_SOURCE_CHANGED_DURING_ACQUISITION", retryable: true)
        case .partialPublishFailed:
            return .processingFailed(code: "PROVIDER_STAGE_PUBLISH_FAILED", retryable: true)
        }
    }

    private static func map(_ error: IOFileStore.StoreError) -> DomainFailure {
        switch error {
        case .invalidRelativePath:
            return .accessDenied
        case .sourceMissing:
            return .corruptMedia
        case .insufficientStorage:
            return .insufficientStorage
        case .fileOperationFailed(let code):
            return .processingFailed(code: code, retryable: true)
        }
    }
}
