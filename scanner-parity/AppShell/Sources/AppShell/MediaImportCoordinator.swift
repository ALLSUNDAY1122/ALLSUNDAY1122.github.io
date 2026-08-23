#if canImport(SwiftUI) && canImport(PhotosUI) && canImport(AVFoundation) && canImport(UniformTypeIdentifiers)
import AVFoundation
import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import ProductFlow

private struct ImportedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("scanner-video-\(UUID().uuidString).\(ext)")
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: received.file, to: destination)
            return ImportedMovie(url: destination)
        }
    }
}

@MainActor
public final class MediaImportCoordinator: ObservableObject {
    @Published public var photoPickerItems: [PhotosPickerItem] = []
    @Published public private(set) var isImporting = false
    @Published public private(set) var lastError: String?

    public init() {}

    public func importPhotoPickerSelection() async -> [ProductInputAsset] {
        isImporting = true
        lastError = nil
        defer { isImporting = false }

        var assets: [ProductInputAsset] = []
        for item in photoPickerItems {
            do {
                if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                    guard let movie = try await item.loadTransferable(type: ImportedMovie.self) else {
                        throw ImportError.transferFailed
                    }
                    assets.append(ProductInputAsset(kind: .video, localURL: movie.url, displayName: movie.url.lastPathComponent))
                } else if let imageType = item.supportedContentTypes.first(where: { $0.conforms(to: .image) }) {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw ImportError.transferFailed
                    }
                    let ext = imageType.preferredFilenameExtension ?? "img"
                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent("scanner-image-\(UUID().uuidString).\(ext)")
                    try data.write(to: url, options: .atomic)
                    assets.append(ProductInputAsset(kind: .image, localURL: url, displayName: url.lastPathComponent))
                }
            } catch {
                lastError = error.localizedDescription
            }
        }
        return assets
    }

    public func importFiles(_ urls: [URL]) throws -> [ProductInputAsset] {
        try urls.map { source in
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }

            let type = try source.resourceValues(forKeys: [.contentTypeKey]).contentType
                ?? UTType(filenameExtension: source.pathExtension)
            let kind: ProductInputKind
            if type?.conforms(to: .movie) == true {
                kind = .video
            } else if type?.conforms(to: .image) == true {
                kind = .image
            } else {
                throw ImportError.unsupportedType
            }

            let ext = source.pathExtension.isEmpty ? (kind == .video ? "mov" : "img") : source.pathExtension
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("scanner-import-\(UUID().uuidString).\(ext)")
            try FileManager.default.copyItem(at: source, to: destination)
            return ProductInputAsset(kind: kind, localURL: destination, displayName: source.lastPathComponent)
        }
    }

    public func currentCameraPermission() -> ProductPermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .restricted
        }
    }

    public func requestCameraPermission() async -> ProductPermissionState {
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        return currentCameraPermission()
    }

    enum ImportError: LocalizedError {
        case transferFailed
        case unsupportedType

        var errorDescription: String? {
            switch self {
            case .transferFailed: return "The selected item could not be imported."
            case .unsupportedType: return "Only image and video files are supported."
            }
        }
    }
}
#endif
