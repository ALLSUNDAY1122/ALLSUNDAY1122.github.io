import Foundation
#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

#if canImport(AVFoundation)
@preconcurrency import AVFoundation

/// Production-oriented M4A exporter that publishes a multi-stem request as one
/// filesystem transaction. It can be injected independently from the importer
/// because App's frozen coordinator accepts AudioImporting and AudioExporting
/// as separate dependencies.
public actor IOSAtomicM4AExporter: AudioExporting {
    public struct Configuration: Sendable {
        public let rootURL: URL
        public let storageReserveBytes: Int64

        public init(
            rootURL: URL,
            storageReserveBytes: Int64 = 64 * 1024 * 1024
        ) {
            self.rootURL = rootURL
            self.storageReserveBytes = storageReserveBytes
        }
    }

    private let configuration: Configuration
    private let fileStore: IOFileStore
    private let batchTransaction: IOExportBatchTransaction
    private let exportSourceProvider: any IOExportSourceProviding
    private let fileManager: FileManager

    public init(
        configuration: Configuration,
        exportSourceProvider: any IOExportSourceProviding,
        fileManager: FileManager = .default
    ) throws {
        let store = IOFileStore(rootURL: configuration.rootURL)
        self.configuration = configuration
        self.fileStore = store
        self.batchTransaction = IOExportBatchTransaction(fileStore: store)
        self.exportSourceProvider = exportSourceProvider
        self.fileManager = fileManager

        try store.prepareDirectories(fileManager: fileManager)
        _ = try batchTransaction.recoverAbandonedBatches(fileManager: fileManager)
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

        let resolved: [(source: IOExportSource, url: URL, predictedBytes: Int64)]
        do {
            resolved = try sources.map { source in
                let sourceURL = try fileStore.resolve(relativePath: source.relativePath)
                guard fileManager.fileExists(atPath: sourceURL.path) else {
                    throw DomainFailure.exportFailed(code: "EXPORT_SOURCE_MISSING")
                }
                let sourceSize = try fileSize(at: sourceURL)
                return (source, sourceURL, max(sourceSize / 2, 4 * 1024 * 1024))
            }

            var totalRequired: Int64 = 0
            for item in resolved {
                let sum = totalRequired.addingReportingOverflow(item.predictedBytes)
                totalRequired = sum.overflow ? Int64.max : sum.partialValue
            }
            try fileStore.preflight(
                requiredBytes: totalRequired,
                reserveBytes: configuration.storageReserveBytes,
                fileManager: fileManager
            )
        } catch let failure as DomainFailure {
            throw failure
        } catch let storeError as IOFileStore.StoreError {
            throw mapStoreError(storeError)
        } catch {
            throw DomainFailure.exportFailed(code: "EXPORT_PREFLIGHT_FAILED")
        }

        let plan: IOExportBatchTransaction.Plan
        do {
            plan = try batchTransaction.prepare(
                suggestedFilenameStems: resolved.map { $0.source.suggestedFilenameStem },
                fileExtension: "m4a",
                fileManager: fileManager
            )
        } catch let batchError as IOExportBatchTransaction.BatchError {
            throw mapBatchError(batchError)
        }

        do {
            for (resolvedItem, plannedItem) in zip(resolved, plan.items) {
                try Task.checkCancellation()
                try await exportM4A(sourceURL: resolvedItem.url, outputURL: plannedItem.stagingURL)
                try await validateExport(at: plannedItem.stagingURL)
            }

            // No cancellation check after this boundary: one directory rename is
            // the publication point, so the caller receives either the whole batch
            // or an error with no published batch.
            let finalized = try batchTransaction.commit(plan, fileManager: fileManager)
            return finalized.map {
                ExportArtifact(relativePath: $0.relativePath, mediaType: "audio/mp4")
            }
        } catch let failure as DomainFailure {
            batchTransaction.abort(plan, fileManager: fileManager)
            throw failure
        } catch let batchError as IOExportBatchTransaction.BatchError {
            batchTransaction.abort(plan, fileManager: fileManager)
            throw mapBatchError(batchError)
        } catch is CancellationError {
            batchTransaction.abort(plan, fileManager: fileManager)
            throw DomainFailure.cancelled
        } catch {
            batchTransaction.abort(plan, fileManager: fileManager)
            throw DomainFailure.exportFailed(code: "EXPORT_FAILED")
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

    private func validateExport(at url: URL) async throws {
        let asset = AVURLAsset(url: url)
        do {
            let protected = try await asset.load(.hasProtectedContent)
            if protected { throw DomainFailure.protectedMedia }
            let playable = try await asset.load(.isPlayable)
            guard playable else { throw DomainFailure.exportFailed(code: "EXPORT_OUTPUT_UNPLAYABLE") }
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            guard let track = tracks.first else { throw DomainFailure.exportFailed(code: "EXPORT_OUTPUT_NO_AUDIO") }

            let reader = try AVAssetReader(asset: asset)
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
            guard reader.canAdd(output) else {
                throw DomainFailure.exportFailed(code: "EXPORT_OUTPUT_DECODE_UNAVAILABLE")
            }
            reader.add(output)
            guard reader.startReading() else {
                throw DomainFailure.exportFailed(code: "EXPORT_OUTPUT_DECODE_FAILED")
            }
            defer { reader.cancelReading() }
            guard output.copyNextSampleBuffer() != nil else {
                throw DomainFailure.exportFailed(code: "EXPORT_OUTPUT_EMPTY_AUDIO")
            }
        } catch let failure as DomainFailure {
            throw failure
        } catch let avError as AVError {
            if avError.code == .diskFull { throw DomainFailure.insufficientStorage }
            throw DomainFailure.exportFailed(code: "EXPORT_OUTPUT_INVALID")
        } catch {
            throw DomainFailure.exportFailed(code: "EXPORT_OUTPUT_INVALID")
        }
    }

    private func fileSize(at url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let fileSize = values.fileSize, fileSize > 0 else {
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

    private func mapBatchError(_ error: IOExportBatchTransaction.BatchError) -> DomainFailure {
        switch error {
        case .emptyBatch, .invalidExtension, .invalidPlan:
            return .exportFailed(code: "EXPORT_BATCH_INVALID")
        case .outputMissing, .outputNotRegularFile, .outputEmpty:
            return .exportFailed(code: "EXPORT_OUTPUT_INVALID")
        case .destinationConflict:
            return .exportFailed(code: "EXPORT_BATCH_DESTINATION_CONFLICT")
        case .integrityManifestInvalid, .integrityMismatch:
            return .exportFailed(code: "EXPORT_BATCH_INTEGRITY_FAILED")
        case .fileOperationFailed(let code):
            return .processingFailed(code: code, retryable: true)
        }
    }
}
#endif
