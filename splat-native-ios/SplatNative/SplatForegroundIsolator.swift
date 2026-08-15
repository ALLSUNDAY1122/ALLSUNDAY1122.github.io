import CoreImage
import Foundation
import UIKit
import Vision

struct SplatBackgroundIsolationStats: Codable, Sendable {
    let attemptedFrames: Int
    let isolatedFrames: Int
    let fallbackFrames: Int
}

/// Creates a derived, background-suppressed training image set while preserving every original
/// capture under raw-images/. Vision's foreground-instance mask is deliberately treated as a
/// conservative object-scan fallback, not as proof of true semantic sky parity.
enum SplatForegroundIsolator {
    private static let markerName = "background-isolation.json"
    private static let rawDirectoryName = "raw-images"
    private static let context = CIContext(options: [.cacheIntermediates: false])

    static func prepareProjectImages(projectURL: URL, frames: [SplatSeedFrame]) -> SplatBackgroundIsolationStats {
        let markerURL = projectURL.appendingPathComponent(markerName)
        if let data = try? Data(contentsOf: markerURL),
           let cached = try? JSONDecoder().decode(SplatBackgroundIsolationStats.self, from: data) {
            return cached
        }

        let rawDirectory = projectURL.appendingPathComponent(rawDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: rawDirectory, withIntermediateDirectories: true)

        var isolated = 0
        var fallback = 0
        for frame in frames {
            autoreleasepool {
                let activeURL = projectURL.appendingPathComponent(frame.filePath)
                let rawURL = rawDirectory.appendingPathComponent(activeURL.lastPathComponent)

                if !FileManager.default.fileExists(atPath: rawURL.path) {
                    try? FileManager.default.copyItem(at: activeURL, to: rawURL)
                }
                guard FileManager.default.fileExists(atPath: rawURL.path) else {
                    fallback += 1
                    return
                }

                if let isolatedData = makeIsolatedJPEG(from: rawURL) {
                    do {
                        try isolatedData.write(to: activeURL, options: .atomic)
                        isolated += 1
                    } catch {
                        fallback += 1
                        restoreRaw(from: rawURL, to: activeURL)
                    }
                } else {
                    fallback += 1
                    restoreRaw(from: rawURL, to: activeURL)
                }
            }
        }

        let stats = SplatBackgroundIsolationStats(
            attemptedFrames: frames.count,
            isolatedFrames: isolated,
            fallbackFrames: fallback
        )
        if let data = try? JSONEncoder().encode(stats) {
            try? data.write(to: markerURL, options: .atomic)
        }
        return stats
    }

    static func shouldApplyMask(globalOccupancy: Double, centerOccupancy: Double) -> Bool {
        (0.04...0.92).contains(globalOccupancy) && centerOccupancy >= 0.10
    }

    private static func makeIsolatedJPEG(from url: URL) -> Data? {
        guard let cgImage = UIImage(contentsOfFile: url.path)?.cgImage else { return nil }
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        let request = VNGenerateForegroundInstanceMaskRequest()
        do {
            try handler.perform([request])
            guard let observation = request.results?.first,
                  !observation.allInstances.isEmpty else { return nil }
            let maskBuffer = try observation.generateScaledMaskForImage(
                forInstances: observation.allInstances,
                from: handler
            )
            let source = CIImage(cgImage: cgImage)
            let mask = normalizedMask(CIImage(cvPixelBuffer: maskBuffer), targetExtent: source.extent)
            let global = averageMaskValue(mask, rect: source.extent)
            let centerRect = source.extent.insetBy(
                dx: source.extent.width * 0.30,
                dy: source.extent.height * 0.30
            )
            let center = averageMaskValue(mask, rect: centerRect)
            guard shouldApplyMask(globalOccupancy: global, centerOccupancy: center) else { return nil }

            let background = CIImage(color: CIColor(red: 0.02, green: 0.02, blue: 0.025, alpha: 1))
                .cropped(to: source.extent)
            let composited = source.applyingFilter(
                "CIBlendWithMask",
                parameters: [
                    kCIInputBackgroundImageKey: background,
                    kCIInputMaskImageKey: mask,
                ]
            )
            guard let output = context.createCGImage(composited, from: source.extent) else { return nil }
            return UIImage(cgImage: output).jpegData(compressionQuality: 0.90)
        } catch {
            return nil
        }
    }

    private static func normalizedMask(_ mask: CIImage, targetExtent: CGRect) -> CIImage {
        guard mask.extent.width > 0, mask.extent.height > 0 else { return mask }
        let sx = targetExtent.width / mask.extent.width
        let sy = targetExtent.height / mask.extent.height
        return mask
            .transformed(by: CGAffineTransform(scaleX: sx, y: sy))
            .cropped(to: targetExtent)
    }

    private static func averageMaskValue(_ mask: CIImage, rect: CGRect) -> Double {
        guard rect.width > 0, rect.height > 0 else { return 0 }
        let average = mask
            .cropped(to: rect)
            .applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: rect)])
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            average,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return Double(pixel[0]) / 255.0
    }

    private static func restoreRaw(from rawURL: URL, to activeURL: URL) {
        guard let data = try? Data(contentsOf: rawURL) else { return }
        try? data.write(to: activeURL, options: .atomic)
    }
}
