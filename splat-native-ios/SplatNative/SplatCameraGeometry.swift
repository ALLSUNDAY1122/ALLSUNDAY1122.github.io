import Foundation
import SplatIO
import simd

enum SplatCameraGeometry {
    struct Framing: Equatable, Sendable {
        let center: SIMD3<Float>
        let distance: Float
        let radius: Float
    }

    static func framingSampleStride(pointCount: Int, targetSampleCount: Int = 6_000) -> Int {
        guard pointCount > 0, targetSampleCount > 0 else { return 1 }
        let quotient = pointCount / targetSampleCount
        let remainder = pointCount % targetSampleCount
        return max(1, quotient + (remainder == 0 ? 0 : 1))
    }

    static func framingSampleIndices(pointCount: Int, targetSampleCount: Int = 6_000) -> [Int] {
        guard pointCount > 0, targetSampleCount > 0 else { return [] }
        let sampleCount = min(pointCount, targetSampleCount)
        guard sampleCount > 1 else { return [0] }
        if sampleCount == pointCount { return Array(0..<pointCount) }

        let lastIndex = pointCount - 1
        let denominator = sampleCount - 1
        return (0..<sampleCount).map { sampleIndex in
            let product = sampleIndex.multipliedReportingOverflow(by: lastIndex)
            if !product.overflow {
                return product.partialValue / denominator
            }
            let fraction = Double(sampleIndex) / Double(denominator)
            return min(lastIndex, max(0, Int((fraction * Double(lastIndex)).rounded(.down))))
        }
    }

    static func robustFraming(for points: [SplatPoint]) -> Framing {
        let sampleIndices = framingSampleIndices(pointCount: points.count)
        var xs: [Float] = []
        var ys: [Float] = []
        var zs: [Float] = []
        xs.reserveCapacity(sampleIndices.count)
        ys.reserveCapacity(sampleIndices.count)
        zs.reserveCapacity(sampleIndices.count)

        for index in sampleIndices {
            let p = points[index].position
            guard p.x.isFinite, p.y.isFinite, p.z.isFinite else { continue }
            xs.append(p.x)
            ys.append(p.y)
            zs.append(p.z)
        }

        guard !xs.isEmpty else { return Framing(center: .zero, distance: 2.5, radius: 0.10) }
        xs.sort(); ys.sort(); zs.sort()
        let center = SIMD3<Float>(
            median(ofSorted: xs),
            median(ofSorted: ys),
            median(ofSorted: zs)
        )

        var radii: [Float] = []
        radii.reserveCapacity(xs.count)
        for index in sampleIndices {
            let p = points[index].position
            guard p.x.isFinite, p.y.isFinite, p.z.isFinite else { continue }
            let radius = simd_distance(p, center)
            guard radius.isFinite else { continue }
            radii.append(radius)
        }
        radii.sort()
        guard !radii.isEmpty else { return Framing(center: center, distance: 2.5, radius: 0.10) }
        let percentileIndex = min(radii.count - 1, Int(Float(radii.count - 1) * 0.90))
        let radius = max(0.10, radii[percentileIndex])
        let framingDistance = max(0.35, min(18.0, radius * 2.8))
        return Framing(center: center, distance: framingDistance, radius: radius)
    }

    static func aspectFittedDistance(
        framing: Framing,
        fovY: Float,
        aspect: Float,
        margin: Float = 1.10
    ) -> Float {
        let safeAspect = aspect.isFinite && aspect > 0.1 ? aspect : 1
        let safeFOVY = fovY.isFinite
            ? min(max(fovY, 0.10), Float.pi - 0.10)
            : Float.pi / 3
        let safeRadius = framing.radius.isFinite ? max(0.10, framing.radius) : 0.10
        let safeMargin = margin.isFinite ? max(1, margin) : 1.10
        let safeFloor = framing.distance.isFinite
            ? min(60, max(0.35, framing.distance))
            : 2.5

        let halfVerticalFOV = max(0.05, safeFOVY * 0.5)
        let halfHorizontalFOV = atan(tan(halfVerticalFOV) * safeAspect)
        let limitingHalfFOV = max(0.05, min(halfVerticalFOV, halfHorizontalFOV))
        let requiredForSphere = safeRadius / sin(limitingHalfFOV) * safeMargin
        return min(60, max(safeFloor, requiredForSphere))
    }

    static func eye(center: SIMD3<Float>, distance: Float, yaw: Float, pitch: Float) -> SIMD3<Float> {
        let safeCenter = isFinite(center) ? center : .zero
        let safeDistance = distance.isFinite ? distance : 2.5
        let safeYaw = yaw.isFinite ? yaw : 0
        let safePitch = pitch.isFinite ? pitch : 0
        let eye = safeCenter + SIMD3<Float>(
            sin(safeYaw) * cos(safePitch) * safeDistance,
            sin(safePitch) * safeDistance,
            cos(safeYaw) * cos(safePitch) * safeDistance
        )
        return isFinite(eye) ? eye : safeCenter + SIMD3<Float>(0, 0, 2.5)
    }

    static func perspective(fovY: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
        let safeFOV = fovY.isFinite ? min(max(fovY, 0.01), Float.pi - 0.01) : Float.pi / 3
        let safeAspect = aspect.isFinite && aspect > 0.001 ? aspect : 1
        let safeNear = near.isFinite && near > 0.0001 && near <= 1_000 ? near : 0.01
        let fallbackFar = max(100, safeNear * 100)
        let safeFar = far.isFinite && far > safeNear + 0.001 && far <= 1_000_000
            ? far
            : fallbackFar

        let y = 1 / tan(safeFOV * 0.5)
        let x = y / safeAspect
        let z = safeFar / (safeNear - safeFar)
        return simd_float4x4(columns: (
            SIMD4<Float>(x, 0, 0, 0),
            SIMD4<Float>(0, y, 0, 0),
            SIMD4<Float>(0, 0, z, -1),
            SIMD4<Float>(0, 0, z * safeNear, 0)
        ))
    }

    static func lookAt(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
        let safeCenter = isFinite(center) ? center : .zero
        let safeEye = isFinite(eye) ? eye : safeCenter + SIMD3<Float>(0, 0, 1)
        let delta = safeEye - safeCenter
        let z = stableNormalize(delta) ?? SIMD3<Float>(0, 0, 1)

        let normalizedUp = stableNormalize(up) ?? SIMD3<Float>(0, 1, 0)

        var x = simd_cross(normalizedUp, z)
        if stableNormalize(x) == nil {
            let fallbackUp = abs(z.y) < 0.9
                ? SIMD3<Float>(0, 1, 0)
                : SIMD3<Float>(1, 0, 0)
            x = simd_cross(fallbackUp, z)
        }
        x = stableNormalize(x) ?? SIMD3<Float>(1, 0, 0)
        let y = stableNormalize(simd_cross(z, x)) ?? SIMD3<Float>(0, 1, 0)
        return simd_float4x4(columns: (
            SIMD4<Float>(x.x, y.x, z.x, 0),
            SIMD4<Float>(x.y, y.y, z.y, 0),
            SIMD4<Float>(x.z, y.z, z.z, 0),
            SIMD4<Float>(-finiteDot(x, safeEye), -finiteDot(y, safeEye), -finiteDot(z, safeEye), 1)
        ))
    }

    static func rotationZ(_ angle: Float) -> simd_float4x4 {
        let safeAngle = angle.isFinite ? angle : 0
        let c = cos(safeAngle), s = sin(safeAngle)
        return simd_float4x4(columns: (
            SIMD4<Float>(c, s, 0, 0),
            SIMD4<Float>(-s, c, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    }

    private static func median(ofSorted values: [Float]) -> Float {
        let upperIndex = values.count / 2
        guard values.count.isMultiple(of: 2) else { return values[upperIndex] }
        return values[upperIndex - 1] * 0.5 + values[upperIndex] * 0.5
    }

    private static func stableNormalize(_ value: SIMD3<Float>) -> SIMD3<Float>? {
        guard isFinite(value) else { return nil }
        let scale = max(abs(value.x), max(abs(value.y), abs(value.z)))
        guard scale.isFinite, scale > Float.leastNonzeroMagnitude else { return nil }
        let scaled = value / scale
        let lengthSquared = simd_length_squared(scaled)
        guard lengthSquared.isFinite, lengthSquared > 1e-12 else { return nil }
        return scaled / sqrt(lengthSquared)
    }

    private static func finiteDot(_ lhs: SIMD3<Float>, _ rhs: SIMD3<Float>) -> Float {
        let value = Double(lhs.x) * Double(rhs.x)
            + Double(lhs.y) * Double(rhs.y)
            + Double(lhs.z) * Double(rhs.z)
        guard value.isFinite else { return 0 }
        let limit = Double(Float.greatestFiniteMagnitude)
        return Float(min(limit, max(-limit, value)))
    }

    private static func isFinite(_ value: SIMD3<Float>) -> Bool {
        value.x.isFinite && value.y.isFinite && value.z.isFinite
    }
}
