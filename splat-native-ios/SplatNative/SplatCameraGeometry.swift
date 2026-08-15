import Foundation
import SplatIO
import simd

enum SplatCameraGeometry {
    struct Framing: Equatable, Sendable {
        let center: SIMD3<Float>
        let distance: Float
    }

    static func robustFraming(for points: [SplatPoint]) -> Framing {
        let strideSize = max(1, points.count / 6_000)
        var xs: [Float] = []
        var ys: [Float] = []
        var zs: [Float] = []
        xs.reserveCapacity(min(points.count, 6_000))
        ys.reserveCapacity(min(points.count, 6_000))
        zs.reserveCapacity(min(points.count, 6_000))

        for index in stride(from: 0, to: points.count, by: strideSize) {
            let p = points[index].position
            guard p.x.isFinite, p.y.isFinite, p.z.isFinite else { continue }
            xs.append(p.x)
            ys.append(p.y)
            zs.append(p.z)
        }

        guard !xs.isEmpty else { return Framing(center: .zero, distance: 2.5) }
        xs.sort(); ys.sort(); zs.sort()
        let middle = xs.count / 2
        let center = SIMD3<Float>(xs[middle], ys[middle], zs[middle])

        var radii: [Float] = []
        radii.reserveCapacity(xs.count)
        for index in stride(from: 0, to: points.count, by: strideSize) {
            let p = points[index].position
            guard p.x.isFinite, p.y.isFinite, p.z.isFinite else { continue }
            radii.append(simd_distance(p, center))
        }
        radii.sort()
        guard !radii.isEmpty else { return Framing(center: center, distance: 2.5) }
        let percentileIndex = min(radii.count - 1, Int(Float(radii.count - 1) * 0.90))
        let radius = max(0.10, radii[percentileIndex])
        let framingDistance = max(0.35, min(12.0, radius * 2.8))
        return Framing(center: center, distance: framingDistance)
    }

    static func eye(center: SIMD3<Float>, distance: Float, yaw: Float, pitch: Float) -> SIMD3<Float> {
        center + SIMD3<Float>(
            sin(yaw) * cos(pitch) * distance,
            sin(pitch) * distance,
            cos(yaw) * cos(pitch) * distance
        )
    }

    static func perspective(fovY: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
        let y = 1 / tan(fovY * 0.5)
        let x = y / aspect
        let z = far / (near - far)
        return simd_float4x4(columns: (
            SIMD4<Float>(x, 0, 0, 0),
            SIMD4<Float>(0, y, 0, 0),
            SIMD4<Float>(0, 0, z, -1),
            SIMD4<Float>(0, 0, z * near, 0)
        ))
    }

    static func lookAt(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
        let z = simd_normalize(eye - center)
        var x = simd_cross(up, z)
        if simd_length_squared(x) < 1e-8 {
            x = SIMD3<Float>(1, 0, 0)
        } else {
            x = simd_normalize(x)
        }
        let y = simd_cross(z, x)
        return simd_float4x4(columns: (
            SIMD4<Float>(x.x, y.x, z.x, 0),
            SIMD4<Float>(x.y, y.y, z.y, 0),
            SIMD4<Float>(x.z, y.z, z.z, 0),
            SIMD4<Float>(-simd_dot(x, eye), -simd_dot(y, eye), -simd_dot(z, eye), 1)
        ))
    }

    static func rotationZ(_ angle: Float) -> simd_float4x4 {
        let c = cos(angle), s = sin(angle)
        return simd_float4x4(columns: (
            SIMD4<Float>(c, s, 0, 0),
            SIMD4<Float>(-s, c, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    }
}
