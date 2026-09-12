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

    /// Produces a bounded, evenly distributed sample over the complete point ordering. A fixed
    /// ceil-stride keeps memory bounded, but its sample count drops abruptly at stride boundaries
    /// (for example 12,001 points -> only 4,001 samples) and can omit the tail of ordered scans.
    /// Keeping up to 6,000 evenly spaced indices preserves the same O(6k log 6k) framing bound
    /// while avoiding viewer/video framing quality discontinuities as scene size crosses a boundary.
    static func framingSampleIndices(pointCount: Int, targetSampleCount: Int = 6_000) -> [Int] {
        guard pointCount > 0, targetSampleCount > 0 else { return [] }
        let sampleCount = min(pointCount, targetSampleCount)
        guard sampleCount > 1 else { return [0] }
        if sampleCount == pointCount { return Array(0..<pointCount) }

        let lastIndex = pointCount - 1
        let denominator = sampleCount - 1
        return (0..<sampleCount).map { sampleIndex in
            // Compute floor(sampleIndex * lastIndex / denominator) exactly without overflowing the
            // machine word. The previous Double fallback could round Int.max-scale values to 2^63
            // and trap during Double -> Int conversion even though the mathematical quotient fits.
            let product = sampleIndex.multipliedFullWidth(by: lastIndex)
            return denominator.dividingFullWidth(product).quotient
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
        // Most bounded large-scene samples contain exactly 6,000 points. Choosing the upper of the
        // two middle coordinates biases the camera center toward +X/+Y/+Z and can visibly shift the
        // scene as sample parity changes. Use the statistical median for even samples as well.
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
            // Extremely large but individually finite coordinates can still overflow the squared
            // distance operation to Infinity. Do not let that one sample poison framing radius.
            guard radius.isFinite else { continue }
            radii.append(radius)
        }
        radii.sort()
        guard !radii.isEmpty else { return Framing(center: center, distance: 2.5, radius: 0.10) }
        let percentileIndex = min(radii.count - 1, Int(Float(radii.count - 1) * 0.90))
        let radius = max(0.10, radii[percentileIndex])
        // Keep video framing aligned with the live viewer. The previous 12-unit cap could
        // move the export camera materially closer than the viewer for large scenes, clipping
        // geometry that was fully visible before the user tapped Export.
        let framingDistance = max(0.35, min(18.0, radius * 2.8))
        return Framing(center: center, distance: framingDistance, radius: radius)
    }

    /// Returns a camera distance that preserves the robust scene radius through the limiting
    /// dimension of the requested output. The previous fixed 2.8x-radius framing was generous
    /// for square/landscape output, but a 9:16 frame has a much narrower horizontal field of view
    /// and could crop the same scene that appeared complete in the viewer.
    static func aspectFittedDistance(
        framing: Framing,
        fovY: Float,
        aspect: Float,
        margin: Float = 1.10
    ) -> Float {
        // Export dimensions, persisted framing state, or caller-provided FOV can be malformed.
        // Never let NaN/Inf escape into camera distance: a non-finite distance poisons every
        // subsequent view/projection matrix and can make the entire export render disappear.
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
        // Preserve the existing live-view framing as a floor; only move farther away when the
        // output aspect ratio actually needs more room. Keep comfortably inside the far plane.
        return min(60, max(safeFloor, requiredForSphere))
    }

    static func eye(center: SIMD3<Float>, distance: Float, yaw: Float, pitch: Float) -> SIMD3<Float> {
        // Gesture state and persisted camera values can be interrupted mid-write or restored from
        // older schemas. Keep a malformed scalar from poisoning the view matrix before lookAt gets
        // a chance to sanitize it. Finite values preserve the exact existing orbit semantics.
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
        // SwiftUI/Metal surfaces can transiently report malformed dimensions or persisted camera
        // planes. Very large but finite near values are as dangerous as NaN: `near + 1` can round
        // back to `near`, collapsing the projection denominator to zero. Keep planes in the range
        // the viewer can meaningfully use before constructing the matrix.
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
        // A malformed persisted camera state must not inject NaN/Inf into either the orientation
        // basis or the translation column. Sanitize both positions before any matrix arithmetic.
        let safeCenter = isFinite(center) ? center : .zero
        let safeEye = isFinite(eye) ? eye : safeCenter + SIMD3<Float>(0, 0, 1)
        let delta = safeEye - safeCenter
        let z = stableNormalize(delta) ?? SIMD3<Float>(0, 0, 1)

        let normalizedUp = stableNormalize(up) ?? SIMD3<Float>(0, 1, 0)

        var x = simd_cross(normalizedUp, z)
        if stableNormalize(x) == nil {
            // Pick an axis that is not parallel to the viewing direction. Using a fixed X axis
            // fails when the camera itself looks along X and produces a zero Y basis vector.
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
        // Display-correction state should never be able to poison an otherwise valid camera matrix.
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
        // Halving before addition avoids overflow when two large finite coordinates share a sign.
        return values[upperIndex - 1] * 0.5 + values[upperIndex] * 0.5
    }

    /// Normalizes without squaring the original magnitude first. `simd_normalize` can overflow its
    /// length calculation for very large but finite vectors, producing an invalid camera basis.
    /// Scaling by the largest component keeps the intermediate norm near one and preserves direction.
    private static func stableNormalize(_ value: SIMD3<Float>) -> SIMD3<Float>? {
        guard isFinite(value) else { return nil }
        let scale = max(abs(value.x), max(abs(value.y), abs(value.z)))
        guard scale.isFinite, scale > Float.leastNonzeroMagnitude else { return nil }
        let scaled = value / scale
        let lengthSquared = simd_length_squared(scaled)
        guard lengthSquared.isFinite, lengthSquared > 1e-12 else { return nil }
        return scaled / sqrt(lengthSquared)
    }

    /// Computes a translation dot product in Double and clamps it back into the finite Float range.
    /// Unit camera axes multiplied by three individually finite near-Float.max coordinates can sum
    /// beyond Float.max even though every input component is valid.
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
