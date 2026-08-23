#if canImport(SwiftUI) && canImport(PhotosUI) && canImport(UniformTypeIdentifiers)
import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import ProductFlow

private enum ProductImportStorage {
    static func rootURL() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        var root = base
            .appendingPathComponent("ScannerParity", isDirectory: true)
            .appendingPathComponent("Imports", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try root.setResourceValues(values)
        return root
    }

    static func destination(prefix: String, extension ext: String) throws -> URL {
        try rootURL().appendingPathComponent("\(prefix)-\(UUID().uuidString).\(ext)")
    }

    static func owns(_ url: URL) -> Bool {
        guard let root = try? rootURL().standardizedFileURL.path else { return false }
        let path = url.standardizedFileURL.path
        return path == root || path.hasPrefix(root + "/")
    }
}

private struct ImportedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let destination = try ProductImportStorage.destination(prefix: "scanner-video", extension: ext)
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
                    guard let movie = try await item.loadTransferable(type: ImportedMovie.self) else { throw ImportError.transferFailed }
                    assets.append(ProductInputAsset(kind: .video, localURL: movie.url, displayName: movie.url.lastPathComponent))
                } else if let imageType = item.supportedContentTypes.first(where: { $0.conforms(to: .image) }) {
                    guard let data = try await item.loadTransferable(type: Data.self) else { throw ImportError.transferFailed }
                    let ext = imageType.preferredFilenameExtension ?? "img"
                    let url = try ProductImportStorage.destination(prefix: "scanner-image", extension: ext)
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
            if type?.conforms(to: .movie) == true { kind = .video }
            else if type?.conforms(to: .image) == true { kind = .image }
            else { throw ImportError.unsupportedType }

            let ext = source.pathExtension.isEmpty ? (kind == .video ? "mov" : "img") : source.pathExtension
            let destination = try ProductImportStorage.destination(prefix: "scanner-import", extension: ext)
            try FileManager.default.copyItem(at: source, to: destination)
            return ProductInputAsset(kind: kind, localURL: destination, displayName: source.lastPathComponent)
        }
    }

    public func discardImportedAssets(_ assets: [ProductInputAsset]) {
        for asset in assets where ProductImportStorage.owns(asset.localURL) {
            try? FileManager.default.removeItem(at: asset.localURL)
        }
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
