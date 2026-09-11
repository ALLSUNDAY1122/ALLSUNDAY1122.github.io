@preconcurrency import CoreImage
@preconcurrency import CoreVideo
import CoreGraphics
import Foundation

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
    private let colorSpace: CGColorSpace

    init() {
        context = CIContext(options: [.cacheIntermediates: false])
        colorSpace = CGColorSpaceCreateDeviceRGB()
    }

    func encode(_ frameImage: MeshFrameImage, compressionQuality: CGFloat = 0.91) -> Data? {
        autoreleasepool {
            let image = CIImage(cvPixelBuffer: frameImage.pixelBuffer)
            return context.jpegRepresentation(
                of: image,
                colorSpace: colorSpace,
                options: [.lossyCompressionQuality: compressionQuality]
            )
        }
    }
}
