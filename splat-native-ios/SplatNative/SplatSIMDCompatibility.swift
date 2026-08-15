import simd

/// Swift 6/Xcode 18 does not expose the matrix-vector `*` overload consistently
/// once the renderer packages add their own matrix overloads. Keep the viewer
/// math explicit without changing the S3 editing/measurement implementation.
@inline(__always)
func * (lhs: simd_float4x4, rhs: SIMD4<Float>) -> SIMD4<Float> {
    simd_mul(lhs, rhs)
}
