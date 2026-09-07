import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

/// Production composition seam for public/direct URL imports.
///
/// The wrapped importer remains authoritative for media probing, codec compatibility (including WMA)
/// and final Imports/** publication. Remote bytes are first acquired through the bounded transport,
/// then handed to the wrapped importer as an app-owned staged file. The temporary handoff file is
/// always removed after success/failure; stale Staging/** cleanup remains covered by IOStagingRecovery
/// if the process terminates between acquisition and handoff.
public actor IOBoundedRemoteAudioImporter: AudioImporting {
    private let baseImporter: any AudioImporting
    private let downloader: any IODirectDownloading
    private let fileStore: IOFileStore
    private let fileManager: FileManager

    public init(
        rootURL: URL,
        baseImporter: any AudioImporting,
        maximumDownloadBytes: Int64 = 2 * 1024 * 1024 * 1024,
        maximumRedirects: Int = 5,
        storageReserveBytes: Int64 = 64 * 1024 * 1024,
        sessionConfiguration: URLSessionConfiguration = .ephemeral,
        fileManager: FileManager = .default
    ) {
        let store = IOFileStore(rootURL: rootURL)
        self.baseImporter = baseImporter
        self.fileStore = store
        self.fileManager = fileManager
        self.downloader = IOResolutionGuardedDirectDownloadTransport(
            fileStore: store,
            maximumBytes: maximumDownloadBytes,
            maximumRedirects: maximumRedirects,
            storageReserveBytes: storageReserveBytes,
            sessionConfiguration: sessionConfiguration,
            fileManager: fileManager
        )
    }

    public init(
        rootURL: URL,
        baseImporter: any AudioImporting,
        downloader: any IODirectDownloading,
        fileManager: FileManager = .default
    ) {
        self.baseImporter = baseImporter
        self.downloader = downloader
        self.fileStore = IOFileStore(rootURL: rootURL)
        self.fileManager = fileManager
    }

    public func importAudio(from request: ImportRequest) async throws -> LocalAudioAsset {
        switch request {
        case .appOwnedFile:
            return try await baseImporter.importAudio(from: request)

        case .directDownloadURL(let url):
            do {
                try Task.checkCancellation()
                let acquired = try await downloader.download(from: url)
                defer { fileStore.removeIfExists(acquired.stagingURL, fileManager: fileManager) }

                try Task.checkCancellation()
                let stagedRelativePath = try fileStore.relativePath(for: acquired.stagingURL)
                return try await baseImporter.importAudio(
                    from: .appOwnedFile(relativePath: stagedRelativePath)
                )
            } catch let failure as DomainFailure {
                throw failure
            } catch let failure as IODirectDownloadFailure {
                throw Self.map(failure)
            } catch let storeError as IOFileStore.StoreError {
                throw Self.map(storeError)
            } catch let urlError as URLError {
                throw Self.map(urlError)
            } catch is CancellationError {
                throw DomainFailure.cancelled
            } catch {
                let ns = error as NSError
                if ns.domain == NSCocoaErrorDomain && ns.code == NSFileWriteOutOfSpaceError {
                    throw DomainFailure.insufficientStorage
                }
                throw DomainFailure.processingFailed(
                    code: "REMOTE_ACQUISITION_FAILURE_\(ns.code)",
                    retryable: false
                )
            }
        }
    }

    private static func map(_ failure: IODirectDownloadFailure) -> DomainFailure {
        switch failure {
        case .unsupportedScheme:
            return .processingFailed(code: "REMOTE_URL_SCHEME_UNSUPPORTED", retryable: false)
        case .missingHost, .credentialsInURL:
            return .processingFailed(code: "REMOTE_URL_INVALID", retryable: false)
        case .localNetworkHost:
            return .processingFailed(code: "REMOTE_URL_LOCAL_NETWORK_BLOCKED", retryable: false)
        case .redirectLimitExceeded:
            return .processingFailed(code: "REMOTE_REDIRECT_LIMIT", retryable: false)
        case .insecureRedirect:
            return .processingFailed(code: "REMOTE_REDIRECT_DOWNGRADE_BLOCKED", retryable: false)
        case .invalidResponse:
            return .processingFailed(code: "HTTP_RESPONSE_INVALID", retryable: false)
        case .httpStatus(let status, let retryable):
            return .processingFailed(code: "HTTP_ERROR_\(status)", retryable: retryable)
        case .partialContent:
            return .processingFailed(code: "REMOTE_PARTIAL_CONTENT_REJECTED", retryable: false)
        case .responseTooLarge, .streamedTooLarge:
            return .processingFailed(code: "REMOTE_FILE_TOO_LARGE", retryable: false)
        case .nonDirectMedia:
            return .processingFailed(code: "REMOTE_NOT_DIRECT_MEDIA", retryable: false)
        case .emptyDownload:
            return .corruptMedia
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

    private static func map(_ error: URLError) -> DomainFailure {
        switch error.code {
        case .cancelled:
            return .cancelled
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return .networkUnavailable
        case .timedOut:
            return .networkTimeout
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return .processingFailed(code: "REMOTE_HOST_UNAVAILABLE", retryable: true)
        default:
            return .processingFailed(code: "NETWORK_ERROR_\(error.errorCode)", retryable: true)
        }
    }
}
