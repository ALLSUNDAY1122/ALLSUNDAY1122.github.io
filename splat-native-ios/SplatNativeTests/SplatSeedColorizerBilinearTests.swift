import XCTest
import UIKit
import simd

extension SplatSeedColorizerMultiViewTests {
    func testSubpixelProjectionBlendsNeighbouringRasterTexels() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("splat-seed-bilinear-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let width = 8
        let height = 8
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for pixel in 0..<(width * height) {
            rgba[pixel * 4 + 3] = 255
        }
        func setPixel(x: Int, y: Int, red: UInt8, green: UInt8, blue: UInt8) {
            let offset = (y * width + x) * 4
            rgba[offset] = red
            rgba[offset + 1] = green
            rgba[offset + 2] = blue
            rgba[offset + 3] = 255
        }
        setPixel(x: 4, y: 4, red: 255, green: 0, blue: 0)
        setPixel(x: 5, y: 4, red: 0, green: 255, blue: 0)
        setPixel(x: 4, y: 5, red: 0, green: 0, blue: 255)

        let provider = try XCTUnwrap(CGDataProvider(data: Data(rgba) as CFData))
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let image = try XCTUnwrap(CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))
        let imageURL = root.appendingPathComponent("subpixel.png")
        try XCTUnwrap(UIImage(cgImage: image).pngData()).write(to: imageURL)

        let identityRows: [[Float]] = [
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [0, 0, 0, 1],
        ]
        let frame = SplatSeedFrame(
            filePath: "subpixel.png",
            transformMatrix: identityRows,
            flX: 8,
            flY: 8,
            cx: 4.5,
            cy: 4.5,
            w: 8,
            h: 8
        )
        let color = try XCTUnwrap(SplatSeedColorizer.colorize(
            points: [SIMD3<Float>(0, 0, -1)],
            frames: [frame],
            projectURL: root
        ).first)

        // At (4.5, 4.5), bilinear sampling blends red/green/blue/black equally.
        // Nearest-neighbour sampling would select one texel instead and fail this range.
        XCTAssertGreaterThanOrEqual(color.red, 50)
        XCTAssertLessThanOrEqual(color.red, 80)
        XCTAssertGreaterThanOrEqual(color.green, 50)
        XCTAssertLessThanOrEqual(color.green, 80)
        XCTAssertGreaterThanOrEqual(color.blue, 50)
        XCTAssertLessThanOrEqual(color.blue, 80)
    }
}
