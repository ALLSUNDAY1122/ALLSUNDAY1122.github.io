import XCTest
import Msplat
import UIKit

final class MsplatRuntimeSmokeTests: XCTestCase {
    func testTinyNerfstudioDatasetTrainsAndExportsSplat() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("splat-smoke-\(UUID().uuidString)", isDirectory: true)
        let images = root.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let width = 48
        let height = 48
        for index in 0..<3 {
            let image = makeImage(width: width, height: height, phase: index)
            let data = try XCTUnwrap(image.pngData())
            try data.write(to: images.appendingPathComponent("frame_\(index).png"))
        }

        try makePointCloud().write(
            to: root.appendingPathComponent("points3D.ply"),
            atomically: true,
            encoding: .utf8
        )

        let transforms: [String: Any] = [
            "camera_model": "OPENCV",
            "fl_x": 44.0,
            "fl_y": 44.0,
            "cx": 24.0,
            "cy": 24.0,
            "w": width,
            "h": height,
            "frames": [
                frame(path: "images/frame_0.png", x: -0.20, y: 0.00, z: 1.50),
                frame(path: "images/frame_1.png", x:  0.00, y: 0.10, z: 1.45),
                frame(path: "images/frame_2.png", x:  0.20, y: 0.00, z: 1.50),
            ]
        ]
        let json = try JSONSerialization.data(withJSONObject: transforms, options: [.prettyPrinted, .sortedKeys])
        try json.write(to: root.appendingPathComponent("transforms.json"))

        let dataset = GaussianDataset(path: root.path, downscaleFactor: 1.0, evalMode: false)
        XCTAssertEqual(dataset.numTrain, 3)

        var config = TrainingConfig()
        config.iterations = 2
        config.shDegree = 0
        config.numDownscales = 0
        config.refineEvery = 100
        config.warmupLength = 100
        config.stopScreenSizeAt = 2
        config.bgColor = (0.02, 0.02, 0.025)

        let trainer = GaussianTrainer(dataset: dataset, config: config)
        let first = trainer.step()
        XCTAssertGreaterThan(first.splatCount, 0)
        _ = trainer.step()

        let output = root.appendingPathComponent("smoke.splat")
        trainer.exportSplat(to: output.path)
        msplatSync()

        let attrs = try FileManager.default.attributesOfItem(atPath: output.path)
        let bytes = try XCTUnwrap(attrs[.size] as? NSNumber).intValue
        XCTAssertGreaterThan(bytes, 0)
        XCTAssertEqual(bytes % 32, 0, ".splat must contain complete 32-byte records")
    }

    private func makeImage(width: Int, height: Int, phase: Int) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            UIColor(white: 0.12 + CGFloat(phase) * 0.03, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))

            UIColor.systemMint.setFill()
            context.fill(CGRect(x: 8 + phase * 2, y: 8, width: 17, height: 17))
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 25 - phase, y: 25, width: 14, height: 14))
            UIColor.white.setFill()
            context.fill(CGRect(x: 18, y: 4 + phase, width: 5, height: 38))
        }
    }

    private func frame(path: String, x: Float, y: Float, z: Float) -> [String: Any] {
        [
            "file_path": path,
            "transform_matrix": [
                [1.0, 0.0, 0.0, Double(x)],
                [0.0, 1.0, 0.0, Double(y)],
                [0.0, 0.0, 1.0, Double(z)],
                [0.0, 0.0, 0.0, 1.0],
            ]
        ]
    }

    private func makePointCloud() -> String {
        var points: [(Float, Float, Float, Int, Int, Int)] = []
        for ix in -2...2 {
            for iy in -2...2 {
                for iz in -2...2 {
                    points.append((
                        Float(ix) * 0.055,
                        Float(iy) * 0.055,
                        Float(iz) * 0.055,
                        80 + (ix + 2) * 30,
                        90 + (iy + 2) * 28,
                        100 + (iz + 2) * 25
                    ))
                }
            }
        }

        var text = """
        ply
        format ascii 1.0
        element vertex \(points.count)
        property float x
        property float y
        property float z
        property uchar red
        property uchar green
        property uchar blue
        end_header

        """
        for p in points {
            text += "\(p.0) \(p.1) \(p.2) \(p.3) \(p.4) \(p.5)\n"
        }
        return text
    }
}
