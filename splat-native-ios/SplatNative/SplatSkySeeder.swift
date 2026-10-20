import CoreGraphics
import Foundation
import ImageIO
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

    private struct GeometryProjection {
        let worldToCamera: simd_float4x4
        let flX: Float
        let flY: Float
        let cx: Float
        let cy: Float
        let width: Int
        let height: Int
    }

    static let farDistance: Float = 20
    static let maxSeedsPerFrame = 24
    static let maxTotalSeeds = 512
    static let azimuthBinCount = 48
    static let elevationBinCount = 12
    static let maxColorSamplesPerDirection = 5
    static let maximumRasterPixel = 512

    static func makeSeeds(
        frames: [SplatSeedFrame],
        geometryPoints: [SIMD3<Float>],
        projectURL: URL
    ) -> [SplatSkySeed] {
        guard !frames.isEmpty else { return [] }

        var order: [DirectionKey] = []
        let (reserveEstimate, reserveOverflow) = frames.count.multipliedReportingOverflow(by: maxSeedsPerFrame)
        let boundedReserve = reserveOverflow ? maxTotalSeeds : min(maxTotalSeeds, reserveEstimate)
        order.reserveCapacity(boundedReserve)
        var accumulators: [DirectionKey: SkyAccumulator] = [:]
        accumulators.reserveCapacity(boundedReserve)

        for frame in frames {
            autoreleasepool {
                guard let url = SplatDepthSeedBuilder.validatedDepthInputURL(
                    projectURL: projectURL,
                    relativePath: frame.filePath
                ),
                      let raster = SkyRaster(url: url, maximumPixel: maximumRasterPixel),
                      let geometryProjection = geometryProjection(frame: frame) else { return }
                let baseline = lowerSceneLuma(raster: raster)
                let xs: [Float] = [0.08, 0.20, 0.32, 0.44, 0.56, 0.68, 0.80, 0.92]
                let topY: Float = 0.035
                let skyBorderCandidates = xs.filter { x in
                    let pixel = raster.sample(normalizedX: x, normalizedY: topY)
                    return isHighConfidenceSkyForSeeding(pixel, sceneLuma: baseline)
                }
                guard skyBorderCandidates.count >= 5 else { return }

                let projectedGeometry = projectedGeometryPoints(
                    points: geometryPoints,
                    projection: geometryProjection
                )
                let borderCandidates = skyBorderCandidates.filter { x in
                    !hasGeometryNear(
                        normalizedX: x,
                        normalizedY: topY,
                        projection: geometryProjection,
                        projectedPoints: projectedGeometry
                    )
                }
                guard borderCandidates.count >= 5 else { return }

                let ys: [Float] = [0.04, 0.11, 0.18]
                var frameContributions = 0
                for y in ys {
                    for x in xs {
                        guard frameContributions < maxSeedsPerFrame else { break }
                        let pixel = raster.sample(normalizedX: x, normalizedY: y)
                        guard isHighConfidenceSkyForSeeding(pixel, sceneLuma: baseline),
                              !hasGeometryNear(
                                normalizedX: x,
                                normalizedY: y,
                                projection: geometryProjection,
                                projectedPoints: projectedGeometry
                              ),
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

    /// Conservative predicate for suppressing near plane-sweep geometry. Keep this blue-sky-only:
    /// bright low-saturation indoor ceilings can look like overcast sky when scene luma is dark.
    static func isHighConfidenceSky(_ pixel: SplatSeedSample, sceneLuma _: Float) -> Bool {
        let r = Float(pixel.red) / 255
        let g = Float(pixel.green) / 255
        let b = Float(pixel.blue) / 255
        return b >= 0.46 && b - r >= 0.08 && g - r >= 0.02
    }

    /// Far-field background seeding can safely be broader than geometry suppression because it also
    /// requires top-border consensus and absence of nearby reconstructed geometry. Preserve bright
    /// overcast support here without allowing that heuristic to erase real indoor surfaces.
    private static func isHighConfidenceSkyForSeeding(_ pixel: SplatSeedSample, sceneLuma: Float) -> Bool {
        if isHighConfidenceSky(pixel, sceneLuma: sceneLuma) { return true }
        let r = Float(pixel.red) / 255
        let g = Float(pixel.green) / 255
        let b = Float(pixel.blue) / 255
        let maxValue = max(r, max(g, b))
        let minValue = min(r, min(g, b))
        let saturation = maxValue > 0 ? (maxValue - minValue) / maxValue : 0
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luma >= max(0.72, sceneLuma + 0.12) && saturation <= 0.18
    }

    static func worldPoint(
        normalizedX: Float,
        normalizedY: Float,
        frame: SplatSeedFrame,
        distance: Float
    ) -> SIMD3<Float>? {
        guard normalizedX.isFinite,
              normalizedY.isFinite,
              distance.isFinite,
              frame.transformMatrix.count == 4,
              frame.transformMatrix.allSatisfy({ row in row.count == 4 && row.allSatisfy({ $0.isFinite }) }),
              frame.flX.isFinite,
              frame.flY.isFinite,
              frame.cx.isFinite,
              frame.cy.isFinite,
              frame.flX > 0, frame.flY > 0,
              frame.w > 0, frame.h > 0,
              distance > 0 else { return nil }

        // Normalized image coordinates elsewhere in sky sampling map 0...1 onto pixel centers
        // 0...(extent-1). Use that same convention for the far-field ray; multiplying by the full
        // extent shifts every sampled sky direction by up to almost one source pixel.
        let px = normalizedX * Float(max(0, frame.w - 1))
        let py = normalizedY * Float(max(0, frame.h - 1))
        let rawDirection = SIMD3<Float>(
            (px - frame.cx) / frame.flX,
            -(py - frame.cy) / frame.flY,
            -1
        )
        let rawLength = simd_length(rawDirection)
        guard rawLength.isFinite, rawLength > 1e-6 else { return nil }
        let cameraDirection = rawDirection / rawLength
        let m = matrix(fromRows: frame.transformMatrix)
        let worldDirection4 = m * SIMD4<Float>(cameraDirection.x, cameraDirection.y, cameraDirection.z, 0)
        let worldDirectionRaw = SIMD3<Float>(worldDirection4.x, worldDirection4.y, worldDirection4.z)
        let worldLength = simd_length(worldDirectionRaw)
        guard worldLength.isFinite, worldLength > 1e-6 else { return nil }
        let worldDirection = worldDirectionRaw / worldLength
        let origin = SIMD3<Float>(m.columns.3.x, m.columns.3.y, m.columns.3.z)
        let result = origin + worldDirection * distance
        guard result.x.isFinite, result.y.isFinite, result.z.isFinite else { return nil }
        return result
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

    static func bilinearSample(
        bytes: [UInt8],
        width: Int,
        height: Int,
        normalizedX: Float,
        normalizedY: Float
    ) -> SplatSeedSample {
        guard width > 0,
              height > 0,
              normalizedX.isFinite,
              normalizedY.isFinite else { return SplatSeedColorizer.fallback }
        let (pixelCount, pixelOverflow) = width.multipliedReportingOverflow(by: height)
        let (requiredBytes, byteOverflow) = pixelCount.multipliedReportingOverflow(by: 4)
        guard !pixelOverflow,
              !byteOverflow,
              requiredBytes > 0,
              bytes.count >= requiredBytes else { return SplatSeedColorizer.fallback }

        let fx = min(Float(width - 1), max(0, normalizedX * Float(width - 1)))
        let fy = min(Float(height - 1), max(0, normalizedY * Float(height - 1)))
        let x0 = Int(floor(fx))
        let y0 = Int(floor(fy))
        let x1 = min(width - 1, x0 + 1)
        let y1 = min(height - 1, y0 + 1)
        let tx = fx - Float(x0)
        let ty = fy - Float(y0)

        func channel(_ x: Int, _ y: Int, _ offset: Int) -> Float {
            Float(bytes[(y * width + x) * 4 + offset])
        }
        func interpolate(_ offset: Int) -> UInt8 {
            let top = channel(x0, y0, offset) * (1 - tx) + channel(x1, y0, offset) * tx
            let bottom = channel(x0, y1, offset) * (1 - tx) + channel(x1, y1, offset) * tx
            let value = top * (1 - ty) + bottom * ty
            return UInt8(min(255, max(0, value.rounded())))
        }

        return SplatSeedSample(red: interpolate(0), green: interpolate(1), blue: interpolate(2))
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
              frame.transformMatrix.allSatisfy({ row in row.count == 4 && row.allSatisfy({ $0.isFinite }) }) else {
            return nil
        }
        let m = matrix(fromRows: frame.transformMatrix)
        let origin = SIMD3<Float>(m.columns.3.x, m.columns.3.y, m.columns.3.z)
        guard origin.x.isFinite, origin.y.isFinite, origin.z.isFinite else { return nil }
        return origin
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

    private static func projectedGeometryPoints(
        points: [SIMD3<Float>],
        projection: GeometryProjection
    ) -> [SIMD2<Float>] {
        guard !points.isEmpty else { return [] }
        let step = max(1, points.count / 1_500)
        var projectedPoints: [SIMD2<Float>] = []
        projectedPoints.reserveCapacity(min(points.count, 1_501))
        for index in stride(from: 0, to: points.count, by: step) {
            guard let projected = project(point: points[index], projection: projection) else { continue }
            projectedPoints.append(SIMD2<Float>(projected.x, projected.y))
        }
        return projectedPoints
    }

    private static func hasGeometryNear(
        normalizedX: Float,
        normalizedY: Float,
        projection: GeometryProjection,
        projectedPoints: [SIMD2<Float>]
    ) -> Bool {
        let targetX = normalizedX * Float(max(0, projection.width - 1))
        let targetY = normalizedY * Float(max(0, projection.height - 1))
        let radiusX = Float(projection.width) * 0.055
        let radiusY = Float(projection.height) * 0.055
        for projected in projectedPoints {
            if abs(projected.x - targetX) <= radiusX && abs(projected.y - targetY) <= radiusY {
                return true
            }
        }
        return false
    }

    private static func geometryProjection(frame: SplatSeedFrame) -> GeometryProjection? {
        guard frame.transformMatrix.count == 4,
              frame.transformMatrix.allSatisfy({ row in row.count == 4 && row.allSatisfy({ $0.isFinite }) }),
              frame.flX.isFinite,
              frame.flY.isFinite,
              frame.cx.isFinite,
              frame.cy.isFinite,
              frame.flX > 0,
              frame.flY > 0,
              frame.w > 0,
              frame.h > 0 else { return nil }
        let worldToCamera = simd_inverse(matrix(fromRows: frame.transformMatrix))
        for column in 0..<4 {
            for row in 0..<4 where !worldToCamera[column][row].isFinite {
                return nil
            }
        }
        return GeometryProjection(
            worldToCamera: worldToCamera,
            flX: frame.flX,
            flY: frame.flY,
            cx: frame.cx,
            cy: frame.cy,
            width: frame.w,
            height: frame.h
        )
    }

    private static func project(point: SIMD3<Float>, projection: GeometryProjection) -> SIMD3<Float>? {
        guard point.x.isFinite, point.y.isFinite, point.z.isFinite else { return nil }
        let cameraPoint = projection.worldToCamera * SIMD4<Float>(point.x, point.y, point.z, 1)
        guard cameraPoint.x.isFinite, cameraPoint.y.isFinite, cameraPoint.z.isFinite else { return nil }
        let depth = -cameraPoint.z
        guard depth.isFinite, depth > 0.05 else { return nil }
        let x = projection.flX * cameraPoint.x / depth + projection.cx
        let y = projection.cy - projection.flY * cameraPoint.y / depth
        guard x.isFinite, y.isFinite else { return nil }
        let margin: Float = 3
        guard x >= margin,
              y >= margin,
              x < Float(projection.width) - margin,
              y < Float(projection.height) - margin else { return nil }
        return SIMD3<Float>(x, y, depth)
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

    init?(url: URL, maximumPixel: Int) {
        guard maximumPixel > 0,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: maximumPixel,
                    kCGImageSourceCreateThumbnailWithTransform: false
                ] as CFDictionary
              ) else { return nil }
        width = image.width
        height = image.height
        guard width > 0,
              height > 0,
              width <= maximumPixel,
              height <= maximumPixel else { return nil }
        let (pixelCount, pixelOverflow) = width.multipliedReportingOverflow(by: height)
        let (byteCount, byteOverflow) = pixelCount.multipliedReportingOverflow(by: 4)
        let (bytesPerRow, rowOverflow) = width.multipliedReportingOverflow(by: 4)
        guard !pixelOverflow, !byteOverflow, !rowOverflow, byteCount > 0 else { return nil }

        var storage = [UInt8](repeating: 0, count: byteCount)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: &storage,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: info
        ) else { return nil }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        bytes = storage
    }

    func sample(normalizedX: Float, normalizedY: Float) -> SplatSeedSample {
        SplatSkySeeder.bilinearSample(
            bytes: bytes,
            width: width,
            height: height,
            normalizedX: normalizedX,
            normalizedY: normalizedY
        )
    }
}
