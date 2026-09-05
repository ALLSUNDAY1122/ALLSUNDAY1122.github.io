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
    struct DirectionKey: Hashable, Sendable {
        let azimuth: Int
        let elevation: Int
    }

    private struct SkyAccumulator {
        let position: SIMD3<Float>
        var samples: [SplatSeedSample]
    }

    static let farDistance: Float = 20
    static let maxSeedsPerFrame = 24
    static let maxTotalSeeds = 512
    static let azimuthBinCount = 48
    static let elevationBinCount = 12
    static let maxColorSamplesPerDirection = 5

    static func makeSeeds(
        frames: [SplatSeedFrame],
        geometryPoints: [SIMD3<Float>],
        projectURL: URL
    ) -> [SplatSkySeed] {
        guard !frames.isEmpty else { return [] }

        // The same far-field direction is visible in many overlapping capture frames. Emitting a
        // fresh Gaussian seed every time can create thousands of nearly duplicate sky points and
        // waste the splat/memory budget before training has learned useful foreground geometry.
        // Keep a bounded world-direction grid instead and use repeated observations to stabilize
        // the seed color rather than increasing seed count.
        var order: [DirectionKey] = []
        order.reserveCapacity(min(maxTotalSeeds, frames.count * maxSeedsPerFrame))
        var accumulators: [DirectionKey: SkyAccumulator] = [:]
        accumulators.reserveCapacity(min(maxTotalSeeds, frames.count * maxSeedsPerFrame))

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
                var frameContributions = 0
                for y in ys {
                    for x in xs {
                        guard frameContributions < maxSeedsPerFrame else { break }
                        let pixel = raster.sample(normalizedX: x, normalizedY: y)
                        guard isHighConfidenceSky(pixel, sceneLuma: baseline),
                              !hasGeometryNear(normalizedX: x, normalizedY: y, frame: frame, points: geometryPoints),
                              let position = worldPoint(
                                normalizedX: x,
                                normalizedY: y,
                                frame: frame,
                                distance: farDistance
                              ),
                              let key = directionKey(position: position, frame: frame) else { continue }

                        if var existing = accumulators[key] {
                            if existing.samples.count < maxColorSamplesPerDirection {
                                existing.samples.append(pixel)
                                accumulators[key] = existing
                            }
                            frameContributions += 1
                            continue
                        }

                        guard order.count < maxTotalSeeds else { continue }
                        accumulators[key] = SkyAccumulator(position: position, samples: [pixel])
                        order.append(key)
                        frameContributions += 1
                    }
                }
            }
        }

        return order.compactMap { key in
            guard let accumulator = accumulators[key] else { return nil }
            return SplatSkySeed(
                position: accumulator.position,
                color: robustColor(accumulator.samples)
            )
        }
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

    static func directionKey(position: SIMD3<Float>, frame: SplatSeedFrame) -> DirectionKey? {
        guard let origin = cameraOrigin(frame: frame) else { return nil }
        let delta = position - origin
        let length = simd_length(delta)
        guard length.isFinite, length > 0.001 else { return nil }
        return directionKey(worldDirection: delta / length)
    }

    static func directionKey(worldDirection: SIMD3<Float>) -> DirectionKey? {
        let length = simd_length(worldDirection)
        guard length.isFinite, length > 0.001 else { return nil }
        let direction = worldDirection / length
        guard direction.x.isFinite, direction.y.isFinite, direction.z.isFinite else { return nil }

        let azimuth = atan2(direction.x, direction.z)
        let azimuthNormalized = (azimuth + .pi) / (2 * .pi)
        let azimuthBin = min(
            azimuthBinCount - 1,
            max(0, Int(floor(azimuthNormalized * Float(azimuthBinCount))))
        )

        let elevation = asin(min(1, max(-1, direction.y)))
        let elevationNormalized = (elevation + .pi / 2) / .pi
        let elevationBin = min(
            elevationBinCount - 1,
            max(0, Int(floor(elevationNormalized * Float(elevationBinCount))))
        )
        return DirectionKey(azimuth: azimuthBin, elevation: elevationBin)
    }

    static func robustColor(_ samples: [SplatSeedSample]) -> SplatSeedSample {
        guard !samples.isEmpty else { return SplatSeedColorizer.fallback }
        return SplatSeedSample(
            red: median(samples.map(\.red)),
            green: median(samples.map(\.green)),
            blue: median(samples.map(\.blue))
        )
    }

    private static func median(_ values: [UInt8]) -> UInt8 {
        guard !values.isEmpty else { return 128 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return UInt8((Int(sorted[middle - 1]) + Int(sorted[middle])) / 2)
        }
        return sorted[middle]
    }

    private static func cameraOrigin(frame: SplatSeedFrame) -> SIMD3<Float>? {
        guard frame.transformMatrix.count == 4,
              frame.transformMatrix.allSatisfy({ $0.count == 4 }) else { return nil }
        let m = matrix(fromRows: frame.transformMatrix)
        return SIMD3<Float>(m.columns.3.x, m.columns.3.y, m.columns.3.z)
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
