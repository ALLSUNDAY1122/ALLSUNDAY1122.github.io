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

    init() {
        context = CIContext(options: [.cacheIntermediates: false])
    }

    func encode(_ frameImage: MeshFrameImage, compressionQuality: CGFloat = 0.91) -> Data? {
        autoreleasepool {
            let image = CIImage(cvPixelBuffer: frameImage.pixelBuffer)
            guard !image.extent.isEmpty,
                  let cgImage = context.createCGImage(image, from: image.extent),
                  let data = CFDataCreateMutable(nil, 0),
                  let destination = CGImageDestinationCreateWithData(
                    data,
                    "public.jpeg" as CFString,
                    1,
                    nil
                  ) else {
                return nil
            }

            let quality = min(max(compressionQuality, 0), 1)
            let properties = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
            CGImageDestinationAddImage(destination, cgImage, properties)
            guard CGImageDestinationFinalize(destination) else { return nil }
            return data as Data
        }
    }
}
