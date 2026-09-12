import CoreGraphics
import Foundation
import UIKit
import simd

struct SplatSeedSample: Sendable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
}

struct SplatSeedFrame: Sendable {
    let filePath: String
    let transformMatrix: [[Float]]
    let flX: Float
    let flY: Float
    let cx: Float
    let cy: Float
    let w: Int
    let h: Int
}

private struct SplatSeedAssignment {
    let frameIndex: Int
    let x: Float
    let y: Float
    let score: Float
}

private struct SplatSeedRaster {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    func sample(x: Float, y: Float, sourceWidth: Int, sourceHeight: Int) -> SplatSeedSample? {
        guard width > 0, height > 0, sourceWidth > 0, sourceHeight > 0 else { return nil }
        let scaledX = x * Float(width) / Float(sourceWidth)
        let scaledY = y * Float(height) / Float(sourceHeight)
        let ix = min(width - 1, max(0, Int(scaledX.rounded())))
        let iy = min(height - 1, max(0, Int(scaledY.rounded())))
        let offset = (iy * width + ix) * 4
        guard offset + 2 < bytes.count else { return nil }
        return SplatSeedSample(red: bytes[offset], green: bytes[offset + 1], blue: bytes[offset + 2])
    }
}

enum SplatSeedColorizer {
    static let fallback = SplatSeedSample(red: 128, green: 128, blue: 128)
    static let maxColorViewsPerPoint = 3

    static func colorize(points: [SIMD3<Float>], frames: [SplatSeedFrame], projectURL: URL) -> [SplatSeedSample] {
        guard !points.isEmpty, !frames.isEmpty else {
            return Array(repeating: fallback, count: points.count)
        }

        // Use several nearby, low-off-axis views instead of trusting one frame. A single projection
        // can land on a temporary occluder, highlight or exposure outlier; a small robust consensus
        // gives the 3DGS initializer a more stable color while keeping raster memory bounded because
        // only one source image is decoded at a time below.
        let assignments = points.map {
            bestAssignments(for: $0, frames: frames, maxCount: maxColorViewsPerPoint)
        }
        var grouped: [Int: [(pointIndex: Int, assignment: SplatSeedAssignment)]] = [:]
        var samples = Array(repeating: [SplatSeedSample](), count: points.count)

        for (pointIndex, pointAssignments) in assignments.enumerated() {
            for assignment in pointAssignments {
                grouped[assignment.frameIndex, default: []].append((pointIndex, assignment))
            }
        }

        // Seed colors always come from untouched captures. Decode one raster at a time so adding
        // multi-view consensus does not multiply peak memory by the number of captured frames.
        for (frameIndex, items) in grouped {
            guard frames.indices.contains(frameIndex) else { continue }
            let frame = frames[frameIndex]
            let imageURL = projectURL.appendingPathComponent(frame.filePath)
            guard let raster = loadRaster(url: imageURL) else { continue }
            for item in items {
                if let color = raster.sample(
                    x: item.assignment.x,
                    y: item.assignment.y,
                    sourceWidth: frame.w,
                    sourceHeight: frame.h
                ) {
                    samples[item.pointIndex].append(color)
                }
            }
        }

        return samples.map(robustColor)
    }

    static func project(point: SIMD3<Float>, frame: SplatSeedFrame) -> SIMD3<Float>? {
        guard frame.transformMatrix.count == 4,
              frame.transformMatrix.allSatisfy({ $0.count == 4 }),
              frame.w > 0, frame.h > 0,
              frame.flX > 0, frame.flY > 0 else { return nil }

        let cameraToWorld = matrix(fromRows: frame.transformMatrix)
        let worldToCamera = simd_inverse(cameraToWorld)
        let cameraPoint = worldToCamera * SIMD4<Float>(point.x, point.y, point.z, 1)
        let depth = -cameraPoint.z
        guard depth > 0.05 else { return nil }

        let x = frame.flX * cameraPoint.x / depth + frame.cx
        let y = frame.cy - frame.flY * cameraPoint.y / depth
        let margin: Float = 3
        guard x >= margin,
              y >= margin,
              x < Float(frame.w) - margin,
              y < Float(frame.h) - margin else { return nil }

        return SIMD3<Float>(x, y, depth)
    }

    private static func bestAssignments(
        for point: SIMD3<Float>,
        frames: [SplatSeedFrame],
        maxCount: Int
    ) -> [SplatSeedAssignment] {
        guard maxCount > 0 else { return [] }
        var candidates: [SplatSeedAssignment] = []
        candidates.reserveCapacity(frames.count)

        for (frameIndex, frame) in frames.enumerated() {
            guard let projected = project(point: point, frame: frame) else { continue }
            let nx = (projected.x - frame.cx) / max(frame.flX, 1)
            let ny = (projected.y - frame.cy) / max(frame.flY, 1)
            let offAxis = sqrt(nx * nx + ny * ny)
            let score = projected.z * (1 + 0.35 * offAxis)
            candidates.append(SplatSeedAssignment(
                frameIndex: frameIndex,
                x: projected.x,
                y: projected.y,
                score: score
            ))
        }

        candidates.sort {
            if abs($0.score - $1.score) < 0.000_001 {
                return $0.frameIndex < $1.frameIndex
            }
            return $0.score < $1.score
        }
        guard let bestScore = candidates.first?.score else { return [] }

        // Avoid blending a very distant/grazing observation merely to reach three samples.
        let scoreCeiling = max(bestScore * 1.8, bestScore + 0.05)
        return Array(candidates.lazy.filter { $0.score <= scoreCeiling }.prefix(maxCount))
    }

    private static func robustColor(_ samples: [SplatSeedSample]) -> SplatSeedSample {
        guard !samples.isEmpty else { return fallback }
        return SplatSeedSample(
            red: robustChannel(samples.map(\.red)),
            green: robustChannel(samples.map(\.green)),
            blue: robustChannel(samples.map(\.blue))
        )
    }

    private static func robustChannel(_ values: [UInt8]) -> UInt8 {
        guard !values.isEmpty else { return 128 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return UInt8((Int(sorted[middle - 1]) + Int(sorted[middle])) / 2)
        }
        return sorted[middle]
    }

    private static func matrix(fromRows rows: [[Float]]) -> simd_float4x4 {
        simd_float4x4(
            SIMD4<Float>(rows[0][0], rows[1][0], rows[2][0], rows[3][0]),
            SIMD4<Float>(rows[0][1], rows[1][1], rows[2][1], rows[3][1]),
            SIMD4<Float>(rows[0][2], rows[1][2], rows[2][2], rows[3][2]),
            SIMD4<Float>(rows[0][3], rows[1][3], rows[2][3], rows[3][3])
        )
    }

    private static func loadRaster(url: URL) -> SplatSeedRaster? {
        guard let image = UIImage(contentsOfFile: url.path)?.cgImage else { return nil }
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }

        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return SplatSeedRaster(width: width, height: height, bytes: bytes)
    }
}
