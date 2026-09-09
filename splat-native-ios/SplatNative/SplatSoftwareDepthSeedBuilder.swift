import CoreGraphics
import Foundation
import ImageIO
import simd

/// S14 non-LiDAR reconstruction initialization.
///
/// Uses the same ARKit-pose plane-sweep geometry conventions and acceptance thresholds as
/// MeshPlaneSweepMVS, but emits a bounded point cloud for Gaussian initialization instead of a mesh.
/// The reference-frame RGB sample is carried with each accepted point so dense initialization does
/// not invoke the legacy point×frame colorizer path.
enum SplatSoftwareDepthSeedBuilder {
    static let maximumSelectedFrames = 18
    static let maximumReferenceFrames = 8
    static let maximumNeighborFrames = 4
    static let hypothesisCount = 30
    static let refinementHypothesisCount = 7
    static let refinementRadiusInCoarseSteps: Float = 0.55
    static let pixelStride = 2
    static let border = 5
    static let bestCostThreshold: Float = 34
    static let uniquenessMargin: Float = 3.5
    static let minimumBaseline: Float = 0.025
    static let maximumBaseline: Float = 0.75
    static let minimumDirectionDot: Float = 0.50
    static let nearDepth: Float = 0.12
    static let farDepth: Float = 2.8
    static let voxelDensity: Float = 100
    static let maximumPointCount = 120_000
    static let minimumUsablePointCount = 2_000

    struct Result: Sendable {
        let points: [SIMD3<Float>]
        let colors: [SplatSeedSample]
        let framesUsed: Int
        let rawPointCount: Int
    }

    private struct Voxel: Hashable {
        let x: Int
        let y: Int
        let z: Int

        init(_ point: SIMD3<Float>) {
            x = Int(floor(point.x * voxelDensity))
            y = Int(floor(point.y * voxelDensity))
            z = Int(floor(point.z * voxelDensity))
        }
    }

    private struct Candidate {
        let point: SIMD3<Float>
        let color: SplatSeedSample
        let cost: Float
    }

    private struct GrayRaster {
        let pixels: [UInt8]
        let width: Int
        let height: Int

        func sample(_ x: Float, _ y: Float) -> Float? {
            let ix = Int(x.rounded())
            let iy = Int(y.rounded())
            guard ix >= 0, iy >= 0, ix < width, iy < height else { return nil }
            return Float(pixels[iy * width + ix])
        }

        /// Sub-pixel sampling is intentionally reserved for the small post-confidence refinement
        /// pass. Keeping the 30-hypothesis coarse search on nearest-neighbour samples preserves its
        /// bounded cost, while bilinear sampling lets nearby depth hypotheses produce distinct
        /// photometric costs instead of collapsing onto the same rounded pixel.
        func sampleBilinear(_ x: Float, _ y: Float) -> Float? {
            guard x.isFinite, y.isFinite else { return nil }
            let x0 = Int(floor(x))
            let y0 = Int(floor(y))
            let x1 = x0 + 1
            let y1 = y0 + 1
            guard x0 >= 0, y0 >= 0, x1 < width, y1 < height else { return nil }

            let tx = x - Float(x0)
            let ty = y - Float(y0)
            let p00 = Float(pixels[y0 * width + x0])
            let p10 = Float(pixels[y0 * width + x1])
            let p01 = Float(pixels[y1 * width + x0])
            let p11 = Float(pixels[y1 * width + x1])
            let top = p00 + (p10 - p00) * tx
            let bottom = p01 + (p11 - p01) * tx
            return top + (bottom - top) * ty
        }
    }

    private struct RGBRaster {
        let pixels: [UInt8]
        let width: Int
        let height: Int

        func sample(_ x: Float, _ y: Float) -> SplatSeedSample? {
            let ix = Int(x.rounded())
            let iy = Int(y.rounded())
            guard ix >= 0, iy >= 0, ix < width, iy < height else { return nil }
            let offset = (iy * width + ix) * 4
            guard offset + 2 < pixels.count else { return nil }
            return SplatSeedSample(
                red: pixels[offset],
                green: pixels[offset + 1],
                blue: pixels[offset + 2]
            )
        }
    }

    private struct Frame {
        let gray: GrayRaster
        let rgb: RGBRaster
        let cameraToWorld: simd_float4x4
        let worldToCamera: simd_float4x4
        let fx: Float
        let fy: Float
        let cx: Float
        let cy: Float
        let position: SIMD3<Float>
        let forward: SIMD3<Float>
    }

    static func makeSeedPoints(
        projectURL: URL,
        frames sourceFrames: [SplatSeedFrame]
    ) -> Result {
        let selected = selectFrames(sourceFrames, maximumCount: maximumSelectedFrames)
        let maximumPixel = ProcessInfo.processInfo.physicalMemory >= 6_000_000_000 ? 224 : 192
        let frames = selected.compactMap { load($0, projectURL: projectURL, maximumPixel: maximumPixel) }
        guard frames.count >= 5 else {
            return Result(points: [], colors: [], framesUsed: frames.count, rawPointCount: 0)
        }

        let references = referenceIndices(frames.count, maximumCount: maximumReferenceFrames)
        var voxels: [Voxel: Candidate] = [:]
        voxels.reserveCapacity(maximumPointCount)
        var rawPointCount = 0
        var referencesUsed = 0

        for referenceIndex in references {
            if voxels.count >= maximumPointCount { break }
            let reference = frames[referenceIndex]
            let neighbors = neighborIndices(referenceIndex: referenceIndex, frames: frames)
            guard neighbors.count >= 2 else { continue }

            let columns = max(0, (reference.gray.width - border * 2) / pixelStride)
            let rows = max(0, (reference.gray.height - border * 2) / pixelStride)
            guard columns > 2, rows > 2 else { continue }
            var acceptedInReference = 0

            for gridY in 0..<rows {
                if voxels.count >= maximumPointCount { break }
                for gridX in 0..<columns {
                    if voxels.count >= maximumPointCount { break }
                    let u = Float(border + gridX * pixelStride)
                    let v = Float(border + gridY * pixelStride)
                    guard hasTexture(u: u, v: v, raster: reference.gray) else { continue }

                    var bestCost = Float.greatestFiniteMagnitude
                    var secondCost = Float.greatestFiniteMagnitude
                    var bestDepth: Float = 0

                    for hypothesis in 0..<hypothesisCount {
                        let t = Float(hypothesis) / Float(hypothesisCount - 1)
                        let inverseDepth = (1 / nearDepth) * (1 - t) + (1 / farDepth) * t
                        let depth = 1 / inverseDepth
                        guard let cost = patchCost(
                            u: u,
                            v: v,
                            depth: depth,
                            reference: reference,
                            neighborIndices: neighbors,
                            frames: frames
                        ) else { continue }

                        if cost < bestCost {
                            secondCost = bestCost
                            bestCost = cost
                            bestDepth = depth
                        } else if cost < secondCost {
                            secondCost = cost
                        }
                    }

                    // Preserve the shipped coarse confidence gate. The fine search runs only after a
                    // correspondence is already accepted, so nearby refinement hypotheses do not
                    // incorrectly defeat the coarse uniqueness margin.
                    guard bestDepth > 0,
                          bestCost < bestCostThreshold,
                          secondCost.isFinite,
                          secondCost - bestCost > uniquenessMargin,
                          let color = reference.rgb.sample(u, v) else { continue }

                    let refined = refinedDepth(
                        u: u,
                        v: v,
                        coarseDepth: bestDepth,
                        coarseCost: bestCost,
                        reference: reference,
                        neighborIndices: neighbors,
                        frames: frames
                    )
                    let world = backproject(u: u, v: v, depth: refined.depth, frame: reference)
                    guard world.x.isFinite, world.y.isFinite, world.z.isFinite else { continue }
                    rawPointCount += 1
                    acceptedInReference += 1
                    let key = Voxel(world)
                    let candidate = Candidate(point: world, color: color, cost: refined.cost)
                    if let existing = voxels[key] {
                        if candidate.cost < existing.cost { voxels[key] = candidate }
                    } else {
                        voxels[key] = candidate
                    }
                }
            }

            if acceptedInReference > 0 { referencesUsed += 1 }
        }

        let ordered = voxels.sorted { lhs, rhs in
            if lhs.key.x != rhs.key.x { return lhs.key.x < rhs.key.x }
            if lhs.key.y != rhs.key.y { return lhs.key.y < rhs.key.y }
            return lhs.key.z < rhs.key.z
        }.map(\.value)
        return Result(
            points: ordered.map(\.point),
            colors: ordered.map(\.color),
            framesUsed: referencesUsed,
            rawPointCount: rawPointCount
        )
    }

    private static func hasTexture(u: Float, v: Float, raster: GrayRaster) -> Bool {
        guard let center = raster.sample(u, v),
              let left = raster.sample(u - 2, v),
              let right = raster.sample(u + 2, v),
              let up = raster.sample(u, v - 2),
              let down = raster.sample(u, v + 2) else { return false }
        let spread = max(abs(left - right), abs(up - down))
        let localContrast = max(
            max(abs(center - left), abs(center - right)),
            max(abs(center - up), abs(center - down))
        )
        return max(spread, localContrast) >= 8
    }

    private static func refinedDepth(
        u: Float,
        v: Float,
        coarseDepth: Float,
        coarseCost: Float,
        reference: Frame,
        neighborIndices: [Int],
        frames: [Frame]
    ) -> (depth: Float, cost: Float) {
        guard refinementHypothesisCount >= 3,
              hypothesisCount > 1,
              coarseDepth.isFinite,
              coarseDepth > 0 else {
            return (coarseDepth, coarseCost)
        }

        let maximumInverseDepth = 1 / nearDepth
        let minimumInverseDepth = 1 / farDepth
        let coarseStep = (maximumInverseDepth - minimumInverseDepth) / Float(hypothesisCount - 1)
        let centerInverseDepth = 1 / coarseDepth
        let radius = coarseStep * refinementRadiusInCoarseSteps
        let denominator = Float(refinementHypothesisCount - 1)

        var bestDepth = coarseDepth
        var bestCost = coarseCost
        for hypothesis in 0..<refinementHypothesisCount {
            let t = Float(hypothesis) / denominator
            let proposedInverseDepth = centerInverseDepth - radius + (2 * radius * t)
            let inverseDepth = min(maximumInverseDepth, max(minimumInverseDepth, proposedInverseDepth))
            let depth = 1 / inverseDepth
            guard let cost = patchCost(
                u: u,
                v: v,
                depth: depth,
                reference: reference,
                neighborIndices: neighborIndices,
                frames: frames,
                useBilinearNeighborSampling: true
            ) else { continue }
            if cost < bestCost {
                bestCost = cost
                bestDepth = depth
            }
        }
        return (bestDepth, bestCost)
    }

    private static func patchCost(
        u: Float,
        v: Float,
        depth: Float,
        reference: Frame,
        neighborIndices: [Int],
        frames: [Frame],
        useBilinearNeighborSampling: Bool = false
    ) -> Float? {
        let offsets: [Float] = [-2, 0, 2]
        var total: Float = 0
        var samples = 0
        for dy in offsets {
            for dx in offsets {
                guard let referenceValue = reference.gray.sample(u + dx, v + dy) else { continue }
                let world = backproject(u: u + dx, v: v + dy, depth: depth, frame: reference)
                for neighborIndex in neighborIndices {
                    let neighbor = frames[neighborIndex]
                    guard let pixel = project(world, frame: neighbor) else { continue }
                    let neighborValue = useBilinearNeighborSampling
                        ? neighbor.gray.sampleBilinear(pixel.x, pixel.y)
                        : neighbor.gray.sample(pixel.x, pixel.y)
                    guard let neighborValue else { continue }
                    total += abs(neighborValue - referenceValue)
                    samples += 1
                }
            }
        }
        guard samples >= max(12, neighborIndices.count * 5) else { return nil }
        return total / Float(samples)
    }

    private static func load(
        _ source: SplatSeedFrame,
        projectURL: URL,
        maximumPixel: Int
    ) -> Frame? {
        guard source.transformMatrix.count == 4,
              source.transformMatrix.allSatisfy({ $0.count == 4 }),
              source.w > 0, source.h > 0,
              source.flX > 0, source.flY > 0 else { return nil }
        let fileURL = projectURL.appendingPathComponent(source.filePath)
        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(
                imageSource,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: maximumPixel,
                    kCGImageSourceCreateThumbnailWithTransform: false
                ] as CFDictionary
              ) else { return nil }

        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }

        var grayBytes = [UInt8](repeating: 0, count: width * height)
        guard let grayContext = CGContext(
            data: &grayBytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        grayContext.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var rgbaBytes = [UInt8](repeating: 0, count: width * height * 4)
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let rgbContext = CGContext(
            data: &rgbaBytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else { return nil }
        rgbContext.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let cameraToWorld = matrix(source.transformMatrix)
        let position = SIMD3<Float>(
            cameraToWorld.columns.3.x,
            cameraToWorld.columns.3.y,
            cameraToWorld.columns.3.z
        )
        let forwardRaw = SIMD3<Float>(
            -cameraToWorld.columns.2.x,
            -cameraToWorld.columns.2.y,
            -cameraToWorld.columns.2.z
        )
        let forward = simd_length_squared(forwardRaw) > 1e-8
            ? simd_normalize(forwardRaw)
            : SIMD3<Float>(0, 0, -1)
        let scaleX = Float(width) / Float(source.w)
        let scaleY = Float(height) / Float(source.h)

        return Frame(
            gray: GrayRaster(pixels: grayBytes, width: width, height: height),
            rgb: RGBRaster(pixels: rgbaBytes, width: width, height: height),
            cameraToWorld: cameraToWorld,
            worldToCamera: simd_inverse(cameraToWorld),
            fx: source.flX * scaleX,
            fy: source.flY * scaleY,
            cx: source.cx * scaleX,
            cy: source.cy * scaleY,
            position: position,
            forward: forward
        )
    }

    private static func selectFrames(_ frames: [SplatSeedFrame], maximumCount: Int) -> [SplatSeedFrame] {
        guard frames.count > maximumCount else { return frames }
        return (0..<maximumCount).map { index in
            let sourceIndex = Int(
                (Double(index) * Double(frames.count - 1) / Double(maximumCount - 1)).rounded()
            )
            return frames[sourceIndex]
        }
    }

    private static func referenceIndices(_ count: Int, maximumCount: Int) -> [Int] {
        let selectedCount = min(maximumCount, count)
        guard selectedCount > 1 else { return count > 0 ? [0] : [] }
        return (0..<selectedCount).map { index in
            Int((Double(index) * Double(count - 1) / Double(selectedCount - 1)).rounded())
        }
    }

    private static func neighborIndices(referenceIndex: Int, frames: [Frame]) -> [Int] {
        let reference = frames[referenceIndex]
        let candidates: [(index: Int, score: Float)] = frames.indices.compactMap { index in
            guard index != referenceIndex else { return nil }
            let baseline = simd_distance(reference.position, frames[index].position)
            let directionDot = simd_dot(reference.forward, frames[index].forward)
            guard baseline >= minimumBaseline,
                  baseline <= maximumBaseline,
                  directionDot > minimumDirectionDot else { return nil }
            let score = abs(baseline - 0.16) + (1 - directionDot) * 0.12
            return (index, score)
        }
        return candidates.sorted { $0.score < $1.score }.prefix(maximumNeighborFrames).map(\.index)
    }

    private static func backproject(u: Float, v: Float, depth: Float, frame: Frame) -> SIMD3<Float> {
        let x = (u - frame.cx) / frame.fx * depth
        let y = -(v - frame.cy) / frame.fy * depth
        let cameraPoint = SIMD4<Float>(x, y, -depth, 1)
        let world = frame.cameraToWorld * cameraPoint
        return SIMD3<Float>(world.x, world.y, world.z)
    }

    private static func project(_ point: SIMD3<Float>, frame: Frame) -> SIMD2<Float>? {
        let camera = frame.worldToCamera * SIMD4<Float>(point.x, point.y, point.z, 1)
        let depth = -camera.z
        guard depth > 0.05 else { return nil }
        let x = frame.cx + frame.fx * camera.x / depth
        let y = frame.cy - frame.fy * camera.y / depth
        guard x >= 2,
              y >= 2,
              x < Float(frame.gray.width - 2),
              y < Float(frame.gray.height - 2) else { return nil }
        return SIMD2<Float>(x, y)
    }

    private static func matrix(_ rows: [[Float]]) -> simd_float4x4 {
        simd_float4x4(columns: (
            SIMD4<Float>(rows[0][0], rows[1][0], rows[2][0], rows[3][0]),
            SIMD4<Float>(rows[0][1], rows[1][1], rows[2][1], rows[3][1]),
            SIMD4<Float>(rows[0][2], rows[1][2], rows[2][2], rows[3][2]),
            SIMD4<Float>(rows[0][3], rows[1][3], rows[2][3], rows[3][3])
        ))
    }
}
