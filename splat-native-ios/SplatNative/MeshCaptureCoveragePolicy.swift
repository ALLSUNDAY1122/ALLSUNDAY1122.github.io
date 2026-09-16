import Foundation
import simd

enum MeshCaptureCoveragePolicy {
    static func translationThreshold(pathThresholdMeters: Float) -> Float {
        let safePathThreshold = pathThresholdMeters.isFinite && pathThresholdMeters > 0
            ? pathThresholdMeters
            : 0
        return max(0.015, safePathThreshold * 0.02)
    }

    static func verticalSpanThreshold(pathThresholdMeters: Float) -> Float {
        let safePathThreshold = pathThresholdMeters.isFinite && pathThresholdMeters > 0
            ? pathThresholdMeters
            : 0
        return max(0.10, safePathThreshold * 0.12)
    }

    static func isPlausibleSampleDisplacement(_ meters: Float) -> Bool {
        meters.isFinite && meters >= 0 && meters <= 0.35
    }

    static func isPlausibleSampleDisplacement(_ meters: Float, elapsedSeconds: TimeInterval) -> Bool {
        guard isPlausibleSampleDisplacement(meters),
              elapsedSeconds.isFinite,
              elapsedSeconds > 0,
              elapsedSeconds <= 1.0 else { return false }
        return meters / Float(elapsedSeconds) <= 1.60
    }

    static func isFiniteCameraPosition(_ position: SIMD3<Float>) -> Bool {
        position.x.isFinite && position.y.isFinite && position.z.isFinite
    }

    /// Accept only forward vectors whose source magnitude is plausibly normalized. AR transforms
    /// should supply a unit basis; accepting an arbitrary finite vector and normalizing it can turn
    /// a corrupt/scaled transform into apparently valid yaw/elevation coverage. The component-scale
    /// band is deliberately tolerant of normal floating-point drift while rejecting collapsed or
    /// explosively scaled bases before they can advance capture completion.
    static func normalizedForwardDirection(_ vector: SIMD3<Float>) -> SIMD3<Float>? {
        guard isFiniteCameraPosition(vector) else { return nil }
        let scale = max(abs(vector.x), max(abs(vector.y), abs(vector.z)))
        guard scale.isFinite,
              scale >= 0.25,
              scale <= 2.0 else { return nil }
        let scaled = vector / scale
        let lengthSquared = simd_length_squared(scaled)
        guard lengthSquared.isFinite, lengthSquared > 1e-12 else { return nil }
        let normalized = scaled / sqrt(lengthSquared)
        return isFiniteCameraPosition(normalized) ? normalized : nil
    }
}
