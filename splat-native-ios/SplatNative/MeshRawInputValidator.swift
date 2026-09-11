import Foundation
import ImageIO

/// Saved-RAW preflight before launching PhotogrammetrySession.
///
/// Discovery and library refresh run away from the MainActor, so eligibility can probe a tiny
/// decoded thumbnail instead of trusting filename/byte count or container metadata alone. This
/// rejects truncated payloads that still expose width/height but would fail once reconstruction
/// attempts to decode the frame.
enum MeshRawInputValidator {
    static let minimumPhotogrammetryImageCount = 20
    private static let supportedExtensions = Set(["jpg", "jpeg", "heic", "png"])
    private static let decodeProbeMaxPixelSize = 32

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
                  isDecodableImage(url) else {
                continue
            }
            usableCount += 1
            if let stopAfter, usableCount >= stopAfter { return usableCount }
        }
        return usableCount
    }

    private static func isDecodableImage(_ url: URL) -> Bool {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, sourceOptions) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              width.intValue > 0,
              height.intValue > 0 else {
            return false
        }

        // Some truncated JPEG/HEIC/PNG files still retain enough header bytes for ImageIO to
        // report dimensions. Force a tiny decode so those containers cannot be advertised as
        // reconstructable RAW. The 32px cap bounds temporary decode memory during library scans.
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: decodeProbeMaxPixelSize,
            kCGImageSourceShouldCache: false
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) != nil
    }
}
