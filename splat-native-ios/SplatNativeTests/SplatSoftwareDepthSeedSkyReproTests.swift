import XCTest
import UIKit

final class SplatSoftwareDepthSeedSkyReproTests: XCTestCase {
    func testMovingTopBorderSkyCanBeReconstructedAsNearGeometry() throws {
        let project = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: project) }

        let cameraXs: [Float] = [-0.08, -0.04, 0, 0.04, 0.08]
        let width = 96
        let height = 96
        let focalLength: Float = 80
        let syntheticFalseDepth: Float = 0.58

        var frames: [SplatSeedFrame] = []
        for (index, cameraX) in cameraXs.enumerated() {
            let name = "sky-\(index).png"
            try writeMovingSkyFixture(
                to: project.appendingPathComponent(name),
                width: width,
                height: height,
                cameraX: cameraX,
                focalLength: focalLength,
                falseDepth: syntheticFalseDepth
            )
            frames.append(
                frame(
                    filePath: name,
                    cameraX: cameraX,
                    focalLength: focalLength,
                    width: width,
                    height: height
                )
            )
        }

        let result = SplatSoftwareDepthSeedBuilder.makeSeedPoints(projectURL: project, frames: frames)
        let blueNearPoints = zip(result.points, result.colors).filter { point, color in
            let depth = -point.z
            return depth > 0.25 && depth < 1.0
                && Int(color.blue) >= Int(color.red) + 24
                && Int(color.blue) >= Int(color.green) + 8
        }

        // This is intentionally a reproduction gate, not the desired final behavior. A distant
        // top-connected blue sky texture is made to drift between frames like moving clouds. The
        // current plane sweep can interpret that screen-space motion as a confident near surface.
        // Once a conservative top-connected sky rejection is wired into production, this assertion
        // must be inverted to require zero (or a very small bounded count) of these points.
        XCTAssertGreaterThan(
            blueNearPoints.count,
            8,
            "Synthetic moving sky did not reproduce near false geometry; do not add sky rejection without evidence"
        )
    }

    private func frame(
        filePath: String,
        cameraX: Float,
        focalLength: Float,
        width: Int,
        height: Int
    ) -> SplatSeedFrame {
        var transform: [[Float]] = [
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [0, 0, 0, 1]
        ]
        transform[0][3] = cameraX
        return SplatSeedFrame(
            filePath: filePath,
            transformMatrix: transform,
            flX: focalLength,
            flY: focalLength,
            cx: Float(width - 1) * 0.5,
            cy: Float(height - 1) * 0.5,
            w: width,
            h: height
        )
    }

    private func writeMovingSkyFixture(
        to url: URL,
        width: Int,
        height: Int,
        cameraX: Float,
        focalLength: Float,
        falseDepth: Float
    ) throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let phaseShift = CGFloat(focalLength * cameraX / falseDepth)
        let image = renderer.image { context in
            let cg = context.cgContext
            UIColor(red: 0.18, green: 0.20, blue: 0.17, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: 0, width: width, height: height))

            // Top-connected blue region. Its deterministic cloud texture is sampled from a wider
            // virtual field and shifted per camera, creating disparity even though semantically it
            // represents distant sky rather than a physical near surface.
            let skyHeight = Int(Double(height) * 0.46)
            for y in 0..<skyHeight {
                for x in 0..<width {
                    let sx = CGFloat(x) + phaseShift
                    let waveA = sin(sx * 0.43 + CGFloat(y) * 0.19)
                    let waveB = sin(sx * 0.17 - CGFloat(y) * 0.37)
                    let cloud = max(-1, min(1, waveA * 0.65 + waveB * 0.35))
                    let lift = CGFloat(0.10) * cloud
                    UIColor(
                        red: max(0, min(1, 0.30 + lift)),
                        green: max(0, min(1, 0.55 + lift)),
                        blue: max(0, min(1, 0.86 + lift * 0.55)),
                        alpha: 1
                    ).setFill()
                    cg.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }

            // A stationary textured lower region keeps the fixture from being an all-sky special
            // case and proves the builder can still see ordinary scene texture in the same frames.
            for y in skyHeight..<height {
                for x in 0..<width {
                    let checker = ((x / 6) + (y / 6)).isMultiple(of: 2)
                    (checker
                        ? UIColor(red: 0.46, green: 0.38, blue: 0.28, alpha: 1)
                        : UIColor(red: 0.22, green: 0.18, blue: 0.13, alpha: 1)
                    ).setFill()
                    cg.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        guard let data = image.pngData() else {
            XCTFail("Expected PNG data")
            return
        }
        try data.write(to: url, options: .atomic)
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
