import CoreGraphics
import Foundation
import UIKit
import simd

struct SplatSkySeed: Sendable {
    let position: SIMD3<Float>
    let color: SplatSeedSample
}

/// Conservative sky seeding for 3DGS initialization.
///
/// Scaniverse splats are expected to retain background and sky, so S2 must not erase the entire
/// background. Instead, this detector only emits far-field seed points when the top border has
/// strong sky evidence and the same image region is not supported by ARKit geometry. The seeds are
/// placed far from the capture so training can represent sky/background appearance without forcing
/// near-object geometry to explain an effectively infinite surface.
enum SplatSkySeeder {
    static let farDistance: Float = 20
    static let maxSeedsPerFrame = 24

    static func makeSeeds(
        frames: [SplatSeedFrame],
        geometryPoints: [SIMD3<Float>],
        projectURL: URL
    ) -> [SplatSkySeed] {
        guard !frames.isEmpty else { return [] }
        var seeds: [SplatSkySeed] = []
        seeds.reserveCapacity(frames.count * maxSeedsPerFrame)

        for frame in frames {
            autoreleasepool {
                let url = projectURL.appendingPathComponent(frame.filePath)
                guard let raster = SkyRaster(url: url) else { return }
                let baseline = lowerSceneLuma(raster: raster)
                let xs: [Float] = [0.08, 0.20, 0.32, 0.44, 0.56, 0.68, 0.80, 0.92]
                let topY: Float = 0.035
                let borderCandidates = xs.filter { x in
                    let pixel = raster.sample(normalizedX: x, normalizedY: topY)
                    return isHighConfidenceSky(pixel, sceneLuma: baseline) &&
                        !hasGeometryNear(normalizedX: x, normalizedY: topY, frame: frame, points: geometryPoints)
                }
                guard borderCandidates.count >= 5 else { return }

                let ys: [Float] = [0.04, 0.11, 0.18]
                var frameSeeds = 0
                for y in ys {
                    for x in xs {
                        guard frameSeeds < maxSeedsPerFrame else { break }
                        let pixel = raster.sample(normalizedX: x, normalizedY: y)
                        guard isHighConfidenceSky(pixel, sceneLuma: baseline),
                              !hasGeometryNear(normalizedX: x, normalizedY: y, frame: frame, points: geometryPoints),
                              let position = worldPoint(
                                normalizedX: x,
                                normalizedY: y,
                                frame: frame,
                                distance: farDistance
                              ) else { continue }
                        seeds.append(SplatSkySeed(position: position, color: pixel))
                        frameSeeds += 1
                    }
                }
            }
        }
        return seeds
    }

    static func isHighConfidenceSky(_ pixel: SplatSeedSample, sceneLuma: Float) -> Bool {
        let r = Float(pixel.red) / 255
        let g = Float(pixel.green) / 255
        let b = Float(pixel.blue) / 255
        let maxValue = max(r, max(g, b))
        let minValue = min(r, min(g, b))
        let saturation = maxValue > 0 ? (maxValue - minValue) / maxValue : 0
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b

        let blueSky = b >= 0.46 && b - r >= 0.08 && g - r >= 0.02
        let brightOvercast = luma >= max(0.72, sceneLuma + 0.12) && saturation <= 0.18
        return blueSky || brightOvercast
    }

    static func worldPoint(
        normalizedX: Float,
        normalizedY: Float,
        frame: SplatSeedFrame,
        distance: Float
    ) -> SIMD3<Float>? {
        guard frame.transformMatrix.count == 4,
              frame.transformMatrix.allSatisfy({ $0.count == 4 }),
              frame.flX > 0, frame.flY > 0,
              frame.w > 0, frame.h > 0,
              distance > 0 else { return nil }

        let px = normalizedX * Float(frame.w)
        let py = normalizedY * Float(frame.h)
        let cameraDirection = simd_normalize(SIMD3<Float>(
            (px - frame.cx) / frame.flX,
            -(py - frame.cy) / frame.flY,
            -1
        ))
        let m = matrix(fromRows: frame.transformMatrix)
        let worldDirection4 = m * SIMD4<Float>(cameraDirection.x, cameraDirection.y, cameraDirection.z, 0)
        let worldDirection = simd_normalize(SIMD3<Float>(worldDirection4.x, worldDirection4.y, worldDirection4.z))
        let origin = SIMD3<Float>(m.columns.3.x, m.columns.3.y, m.columns.3.z)
        return origin + worldDirection * distance
    }

    private static func lowerSceneLuma(raster: SkyRaster) -> Float {
        let xs: [Float] = [0.20, 0.40, 0.60, 0.80]
        let ys: [Float] = [0.55, 0.72]
        var total: Float = 0
        var count: Float = 0
        for y in ys {
            for x in xs {
                let p = raster.sample(normalizedX: x, normalizedY: y)
                total += (0.2126 * Float(p.red) + 0.7152 * Float(p.green) + 0.0722 * Float(p.blue)) / 255
                count += 1
            }
        }
        return count > 0 ? total / count : 0.5
    }

    private static func hasGeometryNear(
        normalizedX: Float,
        normalizedY: Float,
        frame: SplatSeedFrame,
        points: [SIMD3<Float>]
    ) -> Bool {
        let targetX = normalizedX * Float(frame.w)
        let targetY = normalizedY * Float(frame.h)
        let radiusX = Float(frame.w) * 0.055
        let radiusY = Float(frame.h) * 0.055
        let step = max(1, points.count / 1_500)
        for index in stride(from: 0, to: points.count, by: step) {
            guard let projected = SplatSeedColorizer.project(point: points[index], frame: frame) else { continue }
            if abs(projected.x - targetX) <= radiusX && abs(projected.y - targetY) <= radiusY {
                return true
            }
        }
        return false
    }

    private static func matrix(fromRows rows: [[Float]]) -> simd_float4x4 {
        simd_float4x4(
            SIMD4<Float>(rows[0][0], rows[1][0], rows[2][0], rows[3][0]),
            SIMD4<Float>(rows[0][1], rows[1][1], rows[2][1], rows[3][1]),
            SIMD4<Float>(rows[0][2], rows[1][2], rows[2][2], rows[3][2]),
            SIMD4<Float>(rows[0][3], rows[1][3], rows[2][3], rows[3][3])
        )
    }
}

private struct SkyRaster {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init?(url: URL) {
        guard let image = UIImage(contentsOfFile: url.path)?.cgImage else { return nil }
        width = image.width
        height = image.height
        guard width > 0, height > 0 else { return nil }
        var storage = [UInt8](repeating: 0, count: width * height * 4)
        let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: &storage,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: info
        ) else { return nil }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        bytes = storage
    }

    func sample(normalizedX: Float, normalizedY: Float) -> SplatSeedSample {
        let x = min(width - 1, max(0, Int((normalizedX * Float(width - 1)).rounded())))
        let y = min(height - 1, max(0, Int((normalizedY * Float(height - 1)).rounded())))
        let offset = (y * width + x) * 4
        return SplatSeedSample(red: bytes[offset], green: bytes[offset + 1], blue: bytes[offset + 2])
    }
}
