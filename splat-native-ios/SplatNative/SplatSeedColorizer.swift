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

private struct SplatSeedSampleLocation {
    let pointIndex: Int
    let x: Float
    let y: Float
}

private struct SplatSeedAssignmentSet {
    private var first: SplatSeedAssignment?
    private var second: SplatSeedAssignment?
    private var third: SplatSeedAssignment?

    mutating func insert(_ candidate: SplatSeedAssignment) {
        guard let first else {
            self.first = candidate
            return
        }
        if precedes(candidate, first) {
            third = second
            second = first
            self.first = candidate
            return
        }

        guard let second else {
            self.second = candidate
            return
        }
        if precedes(candidate, second) {
            third = second
            self.second = candidate
            return
        }

        guard let third else {
            self.third = candidate
            return
        }
        if precedes(candidate, third) {
            self.third = candidate
        }
    }

    func forEachAccepted(_ body: (SplatSeedAssignment) -> Void) {
        guard let first else { return }
        let scoreCeiling = max(first.score * 1.8, first.score + 0.05)
        body(first)
        if let second, second.score <= scoreCeiling { body(second) }
        if let third, third.score <= scoreCeiling { body(third) }
    }

    private func precedes(_ lhs: SplatSeedAssignment, _ rhs: SplatSeedAssignment) -> Bool {
        if abs(lhs.score - rhs.score) < 0.000_001 {
            return lhs.frameIndex < rhs.frameIndex
        }
        return lhs.score < rhs.score
    }
}

private struct SplatSeedColorAccumulator {
    private(set) var count = 0
    private var first = SplatSeedSample(red: 0, green: 0, blue: 0)
    private var second = SplatSeedSample(red: 0, green: 0, blue: 0)
    private var third = SplatSeedSample(red: 0, green: 0, blue: 0)

    mutating func append(_ sample: SplatSeedSample) {
        switch count {
        case 0: first = sample
        case 1: second = sample
        case 2: third = sample
        default: return
        }
        count += 1
    }

    func robustColor(fallback: SplatSeedSample) -> SplatSeedSample {
        switch count {
        case 0:
            return fallback
        case 1:
            return first
        case 2:
            return SplatSeedSample(
                red: average(first.red, second.red),
                green: average(first.green, second.green),
                blue: average(first.blue, second.blue)
            )
        default:
            return SplatSeedSample(
                red: median3(first.red, second.red, third.red),
                green: median3(first.green, second.green, third.green),
                blue: median3(first.blue, second.blue, third.blue)
            )
        }
    }

    private func average(_ a: UInt8, _ b: UInt8) -> UInt8 {
        UInt8((Int(a) + Int(b)) / 2)
    }

    private func median3(_ a: UInt8, _ b: UInt8, _ c: UInt8) -> UInt8 {
        let total = Int(a) + Int(b) + Int(c)
        return UInt8(total - Int(min(a, min(b, c))) - Int(max(a, max(b, c))))
    }
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
    struct PreparedProjection {
        let frameIndex: Int
        let frame: SplatSeedFrame
        let worldToCamera: simd_float4x4
    }

    static let fallback = SplatSeedSample(red: 128, green: 128, blue: 128)
    static let maxColorViewsPerPoint = 3

    static func colorize(points: [SIMD3<Float>], frames: [SplatSeedFrame], projectURL: URL) -> [SplatSeedSample] {
        guard !points.isEmpty, !frames.isEmpty else {
            return Array(repeating: fallback, count: points.count)
        }

        // Camera transforms are immutable for the entire colorization pass. The old path inverted
        // the same 4x4 matrix for every point x frame candidate; a 100k-point / 100-frame capture
        // could therefore perform up to ten million identical inversions before sampling a pixel.
        // Prepare each usable frame once and reuse its world-to-camera transform for all points.
        let projections = prepareProjections(frames: frames)
        guard !projections.isEmpty else {
            return Array(repeating: fallback, count: points.count)
        }

        // Use several nearby, low-off-axis views instead of trusting one frame. A single projection
        // can land on a temporary occluder, highlight or exposure outlier; a small robust consensus
        // gives the 3DGS initializer a more stable color while keeping raster memory bounded because
        // only one source image is decoded at a time below.
        // Retain only the information needed after view selection. frameIndex is already the bucket
        // key and score is only needed while selecting the best views, so carrying both through the
        // raster pass inflated the up-to-three-per-point grouped payload without changing output.
        var grouped: [Int: [SplatSeedSampleLocation]] = [:]
        var samples = Array(repeating: SplatSeedColorAccumulator(), count: points.count)
        for (pointIndex, point) in points.enumerated() {
            bestAssignments(for: point, projections: projections).forEachAccepted { assignment in
                grouped[assignment.frameIndex, default: []].append(
                    SplatSeedSampleLocation(pointIndex: pointIndex, x: assignment.x, y: assignment.y)
                )
            }
        }

        // Seed colors always come from untouched captures. Decode one raster at a time so adding
        // multi-view consensus does not multiply peak memory by the number of captured frames.
        for (frameIndex, items) in grouped {
            guard frames.indices.contains(frameIndex) else { continue }
            let frame = frames[frameIndex]
            guard let imageURL = containedImageURL(filePath: frame.filePath, projectURL: projectURL),
                  let raster = loadRaster(url: imageURL) else { continue }
            for item in items {
                if let color = raster.sample(
                    x: item.x,
                    y: item.y,
                    sourceWidth: frame.w,
                    sourceHeight: frame.h
                ) {
                    samples[item.pointIndex].append(color)
                }
            }
        }

        return samples.map { $0.robustColor(fallback: fallback) }
    }

    static func prepareProjections(frames: [SplatSeedFrame]) -> [PreparedProjection] {
        frames.enumerated().compactMap { frameIndex, frame in
            guard let worldToCamera = worldToCameraMatrix(frame: frame) else { return nil }
            return PreparedProjection(
                frameIndex: frameIndex,
                frame: frame,
                worldToCamera: worldToCamera
            )
        }
    }

    static func project(point: SIMD3<Float>, frame: SplatSeedFrame) -> SIMD3<Float>? {
        guard let worldToCamera = worldToCameraMatrix(frame: frame) else { return nil }
        return project(point: point, frame: frame, worldToCamera: worldToCamera)
    }

    private static func project(
        point: SIMD3<Float>,
        frame: SplatSeedFrame,
        worldToCamera: simd_float4x4
    ) -> SIMD3<Float>? {
        guard point.x.isFinite, point.y.isFinite, point.z.isFinite else { return nil }
        let cameraPoint = worldToCamera * SIMD4<Float>(point.x, point.y, point.z, 1)
        guard cameraPoint.x.isFinite, cameraPoint.y.isFinite, cameraPoint.z.isFinite else { return nil }
        let depth = -cameraPoint.z
        guard depth.isFinite, depth > 0.05 else { return nil }

        let x = frame.flX * cameraPoint.x / depth + frame.cx
        let y = frame.cy - frame.flY * cameraPoint.y / depth
        guard x.isFinite, y.isFinite else { return nil }
        let margin: Float = 3
        guard x >= margin,
              y >= margin,
              x < Float(frame.w) - margin,
              y < Float(frame.h) - margin else { return nil }

        return SIMD3<Float>(x, y, depth)
    }

    private static func bestAssignments(
        for point: SIMD3<Float>,
        projections: [PreparedProjection]
    ) -> SplatSeedAssignmentSet {
        var best = SplatSeedAssignmentSet()
        for projection in projections {
            let frame = projection.frame
            guard let projected = project(
                point: point,
                frame: frame,
                worldToCamera: projection.worldToCamera
            ) else { continue }
            let nx = (projected.x - frame.cx) / max(frame.flX, 1)
            let ny = (projected.y - frame.cy) / max(frame.flY, 1)
            let offAxis = sqrt(nx * nx + ny * ny)
            let score = projected.z * (1 + 0.35 * offAxis)
            guard score.isFinite else { continue }
            best.insert(SplatSeedAssignment(
                frameIndex: projection.frameIndex,
                x: projected.x,
                y: projected.y,
                score: score
            ))
        }
        return best
    }

    private static func worldToCameraMatrix(frame: SplatSeedFrame) -> simd_float4x4? {
        guard frame.transformMatrix.count == 4,
              frame.transformMatrix.allSatisfy({ $0.count == 4 }),
              frame.w > 0, frame.h > 0,
              frame.flX.isFinite, frame.flY.isFinite,
              frame.cx.isFinite, frame.cy.isFinite,
              frame.flX > 0, frame.flY > 0 else { return nil }

        let cameraToWorld = matrix(fromRows: frame.transformMatrix)
        guard matrixIsFinite(cameraToWorld) else { return nil }
        let worldToCamera = simd_inverse(cameraToWorld)
        guard matrixIsFinite(worldToCamera) else { return nil }
        return worldToCamera
    }

    private static func matrixIsFinite(_ matrix: simd_float4x4) -> Bool {
        for column in 0..<4 {
            for row in 0..<4 where !matrix[column][row].isFinite {
                return false
            }
        }
        return true
    }

    private static func matrix(fromRows rows: [[Float]]) -> simd_float4x4 {
        simd_float4x4(
            SIMD4<Float>(rows[0][0], rows[1][0], rows[2][0], rows[3][0]),
            SIMD4<Float>(rows[0][1], rows[1][1], rows[2][1], rows[3][1]),
            SIMD4<Float>(rows[0][2], rows[1][2], rows[2][2], rows[3][2]),
            SIMD4<Float>(rows[0][3], rows[1][3], rows[2][3], rows[3][3])
        )
    }

    private static func containedImageURL(filePath: String, projectURL: URL) -> URL? {
        guard !filePath.isEmpty else { return nil }
        let root = projectURL.standardizedFileURL.resolvingSymlinksInPath()
        let candidate = projectURL.appendingPathComponent(filePath).standardizedFileURL.resolvingSymlinksInPath()
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard candidate.path.hasPrefix(rootPath) else { return nil }
        return candidate
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
