import Foundation
#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

public struct IOExportSource: Hashable, Sendable {
    public let relativePath: String
    public let suggestedFilenameStem: String

    public init(relativePath: String, suggestedFilenameStem: String) {
        self.relativePath = relativePath
        self.suggestedFilenameStem = suggestedFilenameStem
    }
}

public protocol IOExportSourceProviding: Sendable {
    func sources(for request: ExportRequest) async throws -> [IOExportSource]
}

public enum IOExternalAcquisitionFailure: Sendable {
    case accessDenied
    case providerUnavailable
    case networkUnavailable
    case cancelled
}

public enum IOAcquisitionErrorMapper {
    public static func domainFailure(for failure: IOExternalAcquisitionFailure) -> DomainFailure {
        switch failure {
        case .accessDenied: return .accessDenied
        case .providerUnavailable: return .providerUnavailable
        case .networkUnavailable: return .networkUnavailable
        case .cancelled: return .cancelled
        }
    }
}

#if canImport(AVFoundation)
@preconcurrency import AVFoundation

public actor IOSAudioIOService: AudioImporting, AudioExporting {
    public struct Configuration: Sendable {
        public let rootURL: URL
        public let maximumDownloadBytes: Int64
        public let maximumImportedFileBytes: Int64
        public let storageReserveBytes: Int64

        public init(
            rootURL: URL,
            maximumDownloadBytes: Int64 = 2 * 1024 * 1024 * 1024,
            maximumImportedFileBytes: Int64 = Int64.max,
            storageReserveBytes: Int64 = 64 * 1024 * 1024
        ) {
            self.rootURL = rootURL
            self.maximumDownloadBytes = maximumDownloadBytes
            self.maximumImportedFileBytes = maximumImportedFileBytes
            self.storageReserveBytes = storageReserveBytes
        }
    }

    private struct MediaProbe: Sendable {
        let kind: ImportedMediaKind
        let durationSeconds: Double?
    }

    private let configuration: Configuration
    private let fileStore: IOFileStore
    private let exportSourceProvider: any IOExportSourceProviding
    private let compatibilityDecoder: (any IOCompatibilityAudioDecoding)?
    private let referenceMediaPolicy = IOReferenceMediaCompatibilityPolicy()
    private let compatibilityStaging: IOCompatibilityDecodeStaging
    private let session: URLSession
    private let fileManager: FileManager

    public init(
        configuration: Configuration,
        exportSourceProvider: any IOExportSourceProviding,
        compatibilityDecoder: (any IOCompatibilityAudioDecoding)? = nil,
        session: URLSession = .shared,
        fileManager: FileManager = .default
    ) throws {
        self.configuration = configuration
        self.fileStore = IOFileStore(rootURL: configuration.rootURL)
        self.exportSourceProvider = exportSourceProvider
        self.compatibilityDecoder = compatibilityDecoder
        self.compatibilityStaging = IOCompatibilityDecodeStaging(fileStore: self.fileStore)
        self.session = session
        self.fileManager = fileManager
        try self.fileStore.prepareDirectories(fileManager: fileManager)
    }

    public func importAudio(from request: ImportRequest) async throws -> LocalAudioAsset {
        do {
            switch request {
            case .appOwnedFile(let relativePath):
                let sourceURL = try fileStore.resolve(relativePath: relativePath)
                let size = try fileSize(at: sourceURL)
                try fileStore.preflight(
                    requiredBytes: size,
                    reserveBytes: configuration.storageReserveBytes,
                    fileManager: fileManager
                )
                let staging = try fileStore.stageCopy(from: sourceURL, fileManager: fileManager)
                return try await finalizeValidatedImport(
                    stagingURL: staging,
                    preferredName: sourceURL.deletingPathExtension().lastPathComponent
                )

            case .directDownloadURL(let url):
                return try await importDirectDownload(url)
            }
        } catch let failure as DomainFailure {
            throw failure
        } catch let storeError as IOFileStore.StoreError {
            throw mapStoreError(storeError)
        } catch is CancellationError {
            throw DomainFailure.cancelled
        } catch {
            throw mapFoundationError(error)
        }
    }

    /// Lane-local bridge for Files / File Provider / camera-roll-exported URLs.
    /// App owns picker presentation; IO owns converting the leased external URL into a verified app-owned asset.
    public func importExternalFile(
        at sourceURL: URL,
        accessMode: IOExternalFileAccessMode = .securityScoped
    ) async throws -> LocalAudioAsset {
        do {
            let acquirer = IOExternalFileAcquirer(
                fileStore: fileStore,
                maximumFileBytes: configuration.maximumImportedFileBytes,
                storageReserveBytes: configuration.storageReserveBytes
            )
            let staged = try acquirer.stageExternalFile(
                at: sourceURL,
                accessMode: accessMode,
                fileManager: fileManager
            )
            try Task.checkCancellation()
            return try await finalizeValidatedImport(
                stagingURL: staged.stagingURL,
                preferredName: staged.descriptor.preferredName
            )
        } catch let failure as DomainFailure {
            throw failure
        } catch let acquisitionError as IOExternalFileAcquisitionError {
            throw mapExternalFileAcquisitionError(acquisitionError)
        } catch let storeError as IOFileStore.StoreError {
            throw mapStoreError(storeError)
        } catch is CancellationError {
            throw DomainFailure.cancelled
        } catch {
            throw mapFoundationError(error)
        }
    }

    public func export(_ request: ExportRequest) async throws -> [ExportArtifact] {
        guard isM4ARequest(request.preferredContainer) else {
            throw DomainFailure.exportFailed(code: "EXPORT_UNSUPPORTED")
        }

        let sources = try await exportSourceProvider.sources(for: request)
        guard !sources.isEmpty else {
            throw DomainFailure.exportFailed(code: "EXPORT_SOURCE_MISSING")
        }
        if request.kind == .customMix, sources.count != 1 {
            throw DomainFailure.exportFailed(code: "CUSTOM_MIX_REQUIRES_SINGLE_RENDER")
        }

        var finalizedURLs: [URL] = []
        do {
            var artifacts: [ExportArtifact] = []
            for (index, source) in sources.enumerated() {
                try Task.checkCancellation()
                let sourceURL = try fileStore.resolve(relativePath: source.relativePath)
                guard fileManager.fileExists(atPath: sourceURL.path) else {
                    throw DomainFailure.exportFailed(code: "EXPORT_SOURCE_MISSING")
                }

                let sourceSize = try fileSize(at: sourceURL)
                try fileStore.preflight(
                    requiredBytes: max(sourceSize / 2, 4 * 1024 * 1024),
                    reserveBytes: configuration.storageReserveBytes,
                    fileManager: fileManager
                )

                let staging = fileStore.stagingURL
                    .appendingPathComponent(UUID().uuidString.lowercased())
                    .appendingPathExtension("m4a")
                defer { fileStore.removeIfExists(staging, fileManager: fileManager) }

                try await exportM4A(sourceURL: sourceURL, outputURL: staging)
                _ = try await probeMedia(at: staging, requireDecodeSample: true)

                let stem = IOFileStore.sanitizedFilenameStem(source.suggestedFilenameStem)
                let suffix = sources.count > 1 ? "-\(index + 1)" : ""
                let final = try fileStore.finalizeExport(
                    stagingFile: staging,
                    preferredName: stem + suffix,
                    fileManager: fileManager
                )
                finalizedURLs.append(final.url)
                artifacts.append(ExportArtifact(relativePath: final.relativePath, mediaType: "audio/mp4"))
            }
            return artifacts
        } catch let failure as DomainFailure {
            for url in finalizedURLs { fileStore.removeIfExists(url, fileManager: fileManager) }
            throw failure
        } catch is CancellationError {
            for url in finalizedURLs { fileStore.removeIfExists(url, fileManager: fileManager) }
            throw DomainFailure.cancelled
        } catch {
            for url in finalizedURLs { fileStore.removeIfExists(url, fileManager: fileManager) }
            throw DomainFailure.exportFailed(code: "EXPORT_FAILED")
        }
    }

    /// Returns a finalized app-owned URL suitable for a document exporter or UIActivityViewController.
    /// Presentation remains App-owned; IO only guarantees that the file is complete and inside its sandbox root.
    public func finalizedURL(for artifact: ExportArtifact) throws -> URL {
        let url = try fileStore.resolve(relativePath: artifact.relativePath)
        guard fileManager.fileExists(atPath: url.path) else {
            throw DomainFailure.exportFailed(code: "SHARE_ARTIFACT_MISSING")
        }
        return url
    }

    private func importDirectDownload(_ url: URL) async throws -> LocalAudioAsset {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            throw DomainFailure.processingFailed(code: "REMOTE_URL_SCHEME_UNSUPPORTED", retryable: false)
        }

        try Task.checkCancellation()
        let (temporaryURL, response): (URL, URLResponse)
        do {
            (temporaryURL, response) = try await session.download(from: url)
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        }

        guard let http = response as? HTTPURLResponse else {
            throw DomainFailure.processingFailed(code: "HTTP_RESPONSE_INVALID", retryable: false)
        }
        guard (200..<300).contains(http.statusCode) else {
            let retryable = http.statusCode == 408 || http.statusCode == 429 || http.statusCode >= 500
            throw DomainFailure.processingFailed(code: "HTTP_ERROR_\(http.statusCode)", retryable: retryable)
        }
        if response.expectedContentLength > configuration.maximumDownloadBytes {
            throw DomainFailure.processingFailed(code: "REMOTE_FILE_TOO_LARGE", retryable: false)
        }
        if let mime = response.mimeType?.lowercased(),
           mime == "text/html" || mime == "application/xhtml+xml" || mime.contains("mpegurl") {
            throw DomainFailure.processingFailed(code: "REMOTE_NOT_DIRECT_MEDIA", retryable: false)
        }

        let downloadedSize = try fileSize(at: temporaryURL)
        guard downloadedSize <= configuration.maximumDownloadBytes else {
            throw DomainFailure.processingFailed(code: "REMOTE_FILE_TOO_LARGE", retryable: false)
        }
        try fileStore.preflight(
            requiredBytes: downloadedSize,
            reserveBytes: configuration.storageReserveBytes,
            fileManager: fileManager
        )

        let staged = try fileStore.moveDownloadedTemporaryFile(
            temporaryURL,
            preferredExtension: url.pathExtension,
            fileManager: fileManager
        )
        return try await finalizeValidatedImport(
            stagingURL: staged,
            preferredName: url.deletingPathExtension().lastPathComponent
        )
    }

    private func finalizeValidatedImport(stagingURL: URL, preferredName: String) async throws -> LocalAudioAsset {
        let route = referenceMediaPolicy.route(forPathExtension: stagingURL.pathExtension)
        do {
            let probe = try await probeMedia(at: stagingURL, requireDecodeSample: true)
            return try finalizeProbedImport(stagingURL: stagingURL, preferredName: preferredName, probe: probe)
        } catch let failure as DomainFailure {
            guard route == .nativeThenCompatibility, failure == .unsupportedMedia else {
                fileStore.removeIfExists(stagingURL, fileManager: fileManager)
                throw failure
            }
            return try await finalizeCompatibilityImport(
                originalStagingURL: stagingURL,
                preferredName: preferredName
            )
        } catch {
            fileStore.removeIfExists(stagingURL, fileManager: fileManager)
            throw error
        }
    }

    private func finalizeCompatibilityImport(
        originalStagingURL: URL,
        preferredName: String
    ) async throws -> LocalAudioAsset {
        let converted: URL
        do {
            converted = try await compatibilityStaging.decodeToCanonicalWAV(
                stagedSourceURL: originalStagingURL,
                decoder: compatibilityDecoder,
                fileManager: fileManager
            )
        } catch is CancellationError {
            fileStore.removeIfExists(originalStagingURL, fileManager: fileManager)
            throw DomainFailure.cancelled
        } catch let compatibilityError as IOCompatibilityDecodeStagingError {
            fileStore.removeIfExists(originalStagingURL, fileManager: fileManager)
            throw mapCompatibilityDecodeError(compatibilityError)
        } catch {
            fileStore.removeIfExists(originalStagingURL, fileManager: fileManager)
            throw DomainFailure.processingFailed(code: "COMPATIBILITY_DECODE_FAILED", retryable: false)
        }

        fileStore.removeIfExists(originalStagingURL, fileManager: fileManager)
        do {
            let probe = try await probeMedia(at: converted, requireDecodeSample: true)
            return try finalizeProbedImport(stagingURL: converted, preferredName: preferredName, probe: probe)
        } catch {
            fileStore.removeIfExists(converted, fileManager: fileManager)
            throw error
        }
    }

    private func finalizeProbedImport(
        stagingURL: URL,
        preferredName: String,
        probe: MediaProbe
    ) throws -> LocalAudioAsset {
        let finalized = try fileStore.finalizeImport(
            stagingFile: stagingURL,
            preferredName: preferredName,
            fileManager: fileManager
        )
        return LocalAudioAsset(
            id: AssetID(),
            relativePath: finalized.relativePath,
            mediaKind: probe.kind,
            durationSeconds: probe.durationSeconds
        )
    }

    private func probeMedia(at url: URL, requireDecodeSample: Bool) async throws -> MediaProbe {
        let asset = AVURLAsset(url: url)
        do {
            let protected = try await asset.load(.hasProtectedContent)
            if protected { throw DomainFailure.protectedMedia }

            let playable = try await asset.load(.isPlayable)
            guard playable else { throw DomainFailure.unsupportedMedia }

            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            guard let track = audioTracks.first else { throw DomainFailure.noAudioTrack }
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            let normalizedDuration = seconds.isFinite && seconds >= 0 ? seconds : nil

            if requireDecodeSample {
                try decodeFirstPCMSample(asset: asset, track: track)
            }

            return MediaProbe(
                kind: videoTracks.isEmpty ? .audio : .videoWithAudio,
                durationSeconds: normalizedDuration
            )
        } catch let failure as DomainFailure {
            throw failure
        } catch let avError as AVError {
            throw mapAVError(avError)
        } catch {
            throw DomainFailure.corruptMedia
        }
    }

    private func decodeFirstPCMSample(asset: AVAsset, track: AVAssetTrack) throws {
        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            throw DomainFailure.unsupportedMedia
        }

        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsNonInterleaved: false
            ]
        )
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw DomainFailure.unsupportedMedia }
        reader.add(output)
        guard reader.startReading() else { throw DomainFailure.corruptMedia }
        defer { reader.cancelReading() }

        if output.copyNextSampleBuffer() == nil {
            switch reader.status {
            case .failed:
                throw DomainFailure.corruptMedia
            case .cancelled:
                throw DomainFailure.cancelled
            default:
                throw DomainFailure.unsupportedMedia
            }
        }
    }

    private func exportM4A(sourceURL: URL, outputURL: URL) async throws {
        let asset = AVURLAsset(url: sourceURL)
        let protected = try await asset.load(.hasProtectedContent)
        if protected { throw DomainFailure.protectedMedia }
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else { throw DomainFailure.noAudioTrack }

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw DomainFailure.exportFailed(code: "EXPORT_SESSION_UNAVAILABLE")
        }
        guard exporter.supportedFileTypes.contains(.m4a) else {
            throw DomainFailure.exportFailed(code: "EXPORT_UNSUPPORTED")
        }
        fileStore.removeIfExists(outputURL, fileManager: fileManager)
        exporter.outputURL = outputURL
        exporter.outputFileType = .m4a
        exporter.shouldOptimizeForNetworkUse = false
        let handle = IOAVAssetExportSessionHandle(exporter)

        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                handle.exportAsynchronously {
                    switch handle.status {
                    case .completed:
                        continuation.resume()
                    case .cancelled:
                        continuation.resume(throwing: DomainFailure.cancelled)
                    case .failed:
                        continuation.resume(throwing: DomainFailure.exportFailed(code: "EXPORT_FAILED"))
                    default:
                        continuation.resume(throwing: DomainFailure.exportFailed(code: "EXPORT_INCOMPLETE"))
                    }
                }
            }
        }, onCancel: {
            handle.cancel()
        })
    }

    private func fileSize(at url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let fileSize = values.fileSize else {
            throw DomainFailure.corruptMedia
        }
        return Int64(fileSize)
    }

    private func isM4ARequest(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value == "m4a" || value == "audio/mp4" || value == "public.mpeg-4-audio"
    }

    private func mapStoreError(_ error: IOFileStore.StoreError) -> DomainFailure {
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

    private func mapExternalFileAcquisitionError(_ error: IOExternalFileAcquisitionError) -> DomainFailure {
        switch error {
        case .invalidSourceURL:
            return .processingFailed(code: "EXTERNAL_SOURCE_URL_INVALID", retryable: false)
        case .sourceInsideAppRoot:
            return .processingFailed(code: "EXTERNAL_SOURCE_OWNERSHIP_CONFLICT", retryable: false)
        case .sourceMissing:
            return .corruptMedia
        case .sourceNotRegularFile:
            return .unsupportedMedia
        case .sourceEmpty:
            return .corruptMedia
        case .sourceTooLarge:
            return .processingFailed(code: "IMPORT_FILE_TOO_LARGE", retryable: false)
        case .securityScopeDenied:
            return .accessDenied
        case .providerCoordinationFailed:
            return .providerUnavailable
        case .stagedSizeMismatch:
            return .processingFailed(code: "EXTERNAL_STAGE_SIZE_MISMATCH", retryable: true)
        }
    }

    private func mapCompatibilityDecodeError(_ error: IOCompatibilityDecodeStagingError) -> DomainFailure {
        switch error {
        case .decoderUnavailable:
            return .processingFailed(code: "WMA_COMPATIBILITY_DECODER_UNAVAILABLE", retryable: false)
        case .decoderFailed:
            return .processingFailed(code: "WMA_COMPATIBILITY_DECODE_FAILED", retryable: false)
        case .outputMissing, .outputNotRegularFile, .outputEmpty:
            return .processingFailed(code: "WMA_COMPATIBILITY_OUTPUT_INVALID", retryable: false)
        }
    }

    private func mapURLError(_ error: URLError) -> DomainFailure {
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

    private func mapAVError(_ error: AVError) -> DomainFailure {
        switch error.code {
        case .contentIsProtected:
            return .protectedMedia
        case .decoderNotFound, .decoderTemporarilyUnavailable, .fileFormatNotRecognized, .invalidSourceMedia, .fileFailedToParse:
            return .unsupportedMedia
        case .diskFull:
            return .insufficientStorage
        default:
            return .corruptMedia
        }
    }

    private func mapFoundationError(_ error: Error) -> DomainFailure {
        if let urlError = error as? URLError { return mapURLError(urlError) }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteOutOfSpaceError {
            return .insufficientStorage
        }
        return .processingFailed(code: "IO_FAILURE_\(nsError.code)", retryable: false)
    }
}
#endif
