import XCTest
import UIKit
import simd

extension SplatSeedColorizerMultiViewTests {
    func testSubpixelProjectionBlendsNeighbouringRasterTexels() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("splat-seed-bilinear-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let size = CGSize(width: 8, height: 8)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            UIColor.red.setFill()
            context.fill(CGRect(x: 4, y: 4, width: 1, height: 1))
            UIColor.green.setFill()
            context.fill(CGRect(x: 5, y: 4, width: 1, height: 1))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 4, y: 5, width: 1, height: 1))
        }
        let imageURL = root.appendingPathComponent("subpixel.png")
        try XCTUnwrap(image.pngData()).write(to: imageURL)

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
