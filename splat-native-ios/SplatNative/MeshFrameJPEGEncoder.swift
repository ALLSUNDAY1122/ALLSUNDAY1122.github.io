@preconcurrency import CoreImage
@preconcurrency import CoreVideo
import CoreGraphics
import Foundation
import ImageIO

/// Retains the AR camera pixel buffer while encoding happens on the serial capture queue.
/// ARKit delivers the captured image as an immutable frame snapshot; retaining the buffer
/// prevents its storage from being recycled before the queued encoder has consumed it.
final class MeshFrameImage: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer

    init(pixelBuffer: CVPixelBuffer) {
        self.pixelBuffer = pixelBuffer
    }
}

/// Reuses one Core Image context for capture JPEG encoding outside MainActor.
/// The caller serializes access on the mesh capture queue, so there is at most one
/// encode/write in flight and camera frames cannot build an unbounded backlog.
final class MeshFrameJPEGEncoder: @unchecked Sendable {
    private static let maximumInputPixelCount = 50_000_000
    private let context: CIContext
    private let outputColorSpace: CGColorSpace
    private let compressionQualityKey = CIImageRepresentationOption(
        rawValue: kCGImageDestinationLossyCompressionQuality as String
    )

    init() {
        outputColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        context = CIContext(options: [
            .cacheIntermediates: false,
            .outputColorSpace: outputColorSpace,
        ])
    }

    static func normalizedCompressionQuality(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0.91 }
        return min(max(value, 0), 1)
    }

    static func isPlausiblePixelDimensions(width: Int, height: Int) -> Bool {
        guard width > 0, height > 0 else { return false }
        let (pixels, overflow) = width.multipliedReportingOverflow(by: height)
        return !overflow && pixels <= maximumInputPixelCount
    }

    func encode(_ frameImage: MeshFrameImage, compressionQuality: CGFloat = 0.91) -> Data? {
        autoreleasepool {
            // Capture teardown can cancel the task while a retained camera frame is still queued.
            // Do not spend a multi-megapixel Core Image render on a frame that can no longer be
            // committed to the active scan. This also shortens the lifetime of the retained buffer.
            guard !Task.isCancelled else { return nil }
            let width = CVPixelBufferGetWidth(frameImage.pixelBuffer)
            let height = CVPixelBufferGetHeight(frameImage.pixelBuffer)
            guard Self.isPlausiblePixelDimensions(width: width, height: height) else { return nil }

            let image = CIImage(cvPixelBuffer: frameImage.pixelBuffer)
            guard !image.extent.isEmpty,
                  image.extent.width.isFinite,
                  image.extent.height.isFinite else {
                return nil
            }

            // Ask Core Image to render directly into its JPEG representation. This avoids the
            // full-size CGImage materialization that the previous ImageIO bridge required and
            // lowers the transient capture working set for multi-megapixel AR camera frames.
            let quality = Self.normalizedCompressionQuality(compressionQuality)
            guard let data = context.jpegRepresentation(
                of: image,
                colorSpace: outputColorSpace,
                options: [compressionQualityKey: quality]
            ) else { return nil }
            // Cancellation may race the synchronous Core Image call. Do not hand stale encoded data
            // back to persistence after the capture generation has already been abandoned.
            return Task.isCancelled ? nil : data
        }
    }
}
