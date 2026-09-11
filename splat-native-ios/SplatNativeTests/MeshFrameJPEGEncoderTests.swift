import CoreGraphics
import CoreVideo
import ImageIO
import XCTest

final class MeshFrameJPEGEncoderTests: XCTestCase {
    func testEncoderProducesDecodableJPEGWithSourceDimensions() throws {
        let width = 32
        let height = 24
        var pixelBuffer: CVPixelBuffer?
        let attributes: CFDictionary = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ] as CFDictionary

        XCTAssertEqual(
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                width,
                height,
                kCVPixelFormatType_32BGRA,
                attributes,
                &pixelBuffer
            ),
            kCVReturnSuccess
        )
        let buffer = try XCTUnwrap(pixelBuffer)
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let baseAddress = try XCTUnwrap(CVPixelBufferGetBaseAddress(buffer))
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<height {
            let row = baseAddress.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in 0..<width {
                let offset = x * 4
                row[offset] = UInt8((x * 7) % 255)
                row[offset + 1] = UInt8((y * 9) % 255)
                row[offset + 2] = UInt8(((x + y) * 5) % 255)
                row[offset + 3] = 255
            }
        }

        let data = try XCTUnwrap(
            MeshFrameJPEGEncoder().encode(MeshFrameImage(pixelBuffer: buffer))
        )
        XCTAssertGreaterThan(data.count, 64)
        XCTAssertEqual(Array(data.prefix(2)), [0xFF, 0xD8])
        XCTAssertEqual(Array(data.suffix(2)), [0xFF, 0xD9])

        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try XCTUnwrap(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        )
        XCTAssertEqual(properties[kCGImagePropertyPixelWidth] as? Int, width)
        XCTAssertEqual(properties[kCGImagePropertyPixelHeight] as? Int, height)
    }
}
