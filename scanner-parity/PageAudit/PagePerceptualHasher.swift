#if canImport(CoreGraphics) && canImport(ImageIO)
import CoreGraphics
import Foundation
import ImageIO

public enum PagePerceptualHasher {
    public static func dHash64(imageAt url: URL) -> UInt64? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return dHash64(image: image)
    }

    public static func dHash64(image: CGImage) -> UInt64? {
        let width = 9
        let height = 8
        var pixels = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var hash: UInt64 = 0
        var bit: UInt64 = 1
        for row in 0..<height {
            let rowOffset = row * width
            for column in 0..<(width - 1) {
                if pixels[rowOffset + column] > pixels[rowOffset + column + 1] {
                    hash |= bit
                }
                bit <<= 1
            }
        }
        return hash
    }
}
#endif
