import Foundation
import ImageIO

/// Cheap preflight for saved RAW before launching PhotogrammetrySession.
///
/// Discovery intentionally stays lightweight, but the actual reprocess path must not spend
/// reconstruction time on zero-byte, renamed, or structurally unreadable image placeholders.
/// ImageIO is asked for container metadata only; pixel data is not decoded or cached.
enum MeshRawInputValidator {
    static let minimumPhotogrammetryImageCount = 20
    private static let supportedExtensions = Set(["jpg", "jpeg", "heic", "png"])

    /// Privacy/storage truth: report retained RAW whenever at least one supported regular image
    /// still occupies bytes, even when there is no longer enough trustworthy input to reprocess.
    static func hasAnyRawImageBytes(
        in directory: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        rawImageFileCount(in: directory, fileManager: fileManager, stopAfter: 1) > 0
    }

    /// Lightweight count for labels/storage state. This intentionally checks file metadata only;
    /// callers must use `hasMinimumUsableImages` before treating these files as reprocessable.
    static func rawImageFileCount(
        in directory: URL,
        fileManager: FileManager = .default,
        stopAfter: Int? = nil
    ) -> Int {
        if let stopAfter, stopAfter <= 0 { return 0 }
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var count = 0
        for url in files {
            guard supportedExtensions.contains(url.pathExtension.lowercased()),
                  let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true,
                  (values.fileSize ?? 0) > 0 else {
                continue
            }
            count += 1
            if let stopAfter, count >= stopAfter { return count }
        }
        return count
    }

    static func hasMinimumUsableImages(
        in directory: URL,
        fileManager: FileManager = .default,
        minimumCount: Int = minimumPhotogrammetryImageCount
    ) -> Bool {
        guard minimumCount > 0 else { return false }
        return usableImageCount(
            in: directory,
            fileManager: fileManager,
            stopAfter: minimumCount
        ) >= minimumCount
    }

    static func usableImageCount(
        in directory: URL,
        fileManager: FileManager = .default,
        stopAfter: Int? = nil
    ) -> Int {
        if let stopAfter, stopAfter <= 0 { return 0 }
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var usableCount = 0
        for url in files {
            guard supportedExtensions.contains(url.pathExtension.lowercased()),
                  let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true,
                  (values.fileSize ?? 0) > 0,
                  isStructurallyReadableImage(url) else {
                continue
            }
            usableCount += 1
            if let stopAfter, usableCount >= stopAfter { return usableCount }
        }
        return usableCount
    }

    private static func isStructurallyReadableImage(_ url: URL) -> Bool {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
            return false
        }
        return width.intValue > 0 && height.intValue > 0
    }
}
