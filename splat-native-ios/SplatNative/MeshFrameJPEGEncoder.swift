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

    func encode(_ frameImage: MeshFrameImage, compressionQuality: CGFloat = 0.91) -> Data? {
        autoreleasepool {
            let image = CIImage(cvPixelBuffer: frameImage.pixelBuffer)
            guard !image.extent.isEmpty,
                  image.extent.width.isFinite,
                  image.extent.height.isFinite else {
                return nil
            }

            // Ask Core Image to render directly into its JPEG representation. This avoids the
            // full-size CGImage materialization that the previous ImageIO bridge required and
            // lowers the transient capture working set for multi-megapixel AR camera frames.
            let quality = min(max(compressionQuality, 0), 1)
            return context.jpegRepresentation(
                of: image,
                colorSpace: outputColorSpace,
                options: [compressionQualityKey: quality]
            )
        }
    }
}
