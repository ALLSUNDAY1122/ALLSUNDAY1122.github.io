import XCTest
import UIKit
import simd

final class SplatSeedColorizerMultiViewTests: XCTestCase {
    func testThreeViewConsensusRejectsSingleColorOutlier() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("splat-seed-consensus-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try writeSolidImage(color: UIColor(red: 0.10, green: 0.55, blue: 0.20, alpha: 1), name: "a.png", root: root)
        try writeSolidImage(color: UIColor(red: 0.12, green: 0.58, blue: 0.22, alpha: 1), name: "b.png", root: root)
        try writeSolidImage(color: UIColor(red: 0.95, green: 0.05, blue: 0.05, alpha: 1), name: "outlier.png", root: root)

        let frames = ["a.png", "b.png", "outlier.png"].map { name in
            SplatSeedFrame(
                filePath: name,
                transformMatrix: identityRows,
                flX: 10,
                flY: 10,
                cx: 10,
                cy: 10,
                w: 20,
                h: 20
            )
        }

        let colors = SplatSeedColorizer.colorize(
            points: [SIMD3<Float>(0, 0, -1)],
            frames: frames,
            projectURL: root
        )
        let color = try XCTUnwrap(colors.first)

        XCTAssertLessThan(color.red, 60)
        XCTAssertGreaterThan(color.green, 120)
        XCTAssertLessThan(color.blue, 80)
    }

    func testConsensusFallsBackToSingleVisibleView() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("splat-seed-single-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try writeSolidImage(color: .blue, name: "near.png", root: root)
        try writeSolidImage(color: .red, name: "behind.png", root: root)

        let near = SplatSeedFrame(
            filePath: "near.png",
            transformMatrix: identityRows,
            flX: 10,
            flY: 10,
            cx: 10,
            cy: 10,
            w: 20,
            h: 20
        )
        var behindRows = identityRows
        behindRows[2][3] = -2
        let behind = SplatSeedFrame(
            filePath: "behind.png",
            transformMatrix: behindRows,
            flX: 10,
            flY: 10,
            cx: 10,
            cy: 10,
            w: 20,
            h: 20
        )

        let colors = SplatSeedColorizer.colorize(
            points: [SIMD3<Float>(0, 0, -1)],
            frames: [near, behind],
            projectURL: root
        )
        let color = try XCTUnwrap(colors.first)

        XCTAssertGreaterThan(color.blue, 220)
        XCTAssertLessThan(color.red, 40)
    }

    private func writeSolidImage(color: UIColor, name: String, root: URL) throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20))
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
        try XCTUnwrap(image.pngData()).write(to: root.appendingPathComponent(name))
    }

    private var identityRows: [[Float]] {
        [
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [0, 0, 0, 1],
        ]
    }
}
