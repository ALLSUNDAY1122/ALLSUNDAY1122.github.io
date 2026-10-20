import Foundation
import simd

enum MeshCaptureCoveragePolicy {
    static func translationThreshold(pathThresholdMeters: Float) -> Float {
        let safePathThreshold = pathThresholdMeters.isFinite && pathThresholdMeters > 0 ? pathThresholdMeters : 0
        let scaled = safePathThreshold * 0.02
        return scaled.isFinite ? max(0.015, scaled) : 0.015
    }

    static func verticalSpanThreshold(pathThresholdMeters: Float) -> Float {
        let safePathThreshold = pathThresholdMeters.isFinite && pathThresholdMeters > 0 ? pathThresholdMeters : 0
        let scaled = safePathThreshold * 0.12
        return scaled.isFinite ? max(0.10, scaled) : 0.10
    }

    static func isPlausibleSampleDisplacement(_ meters: Float) -> Bool {
        meters.isFinite && meters >= 0 && meters <= 0.35
    }

    static func isPlausibleSampleDisplacement(_ meters: Float, elapsedSeconds: TimeInterval) -> Bool {
        guard isPlausibleSampleDisplacement(meters), elapsedSeconds.isFinite, elapsedSeconds > 0, elapsedSeconds <= 1.0 else { return false }
        let elapsed = Float(elapsedSeconds)
        guard elapsed.isFinite, elapsed > 0 else { return false }
        return meters / elapsed <= 1.60
    }

    static func isFiniteCameraPosition(_ position: SIMD3<Float>) -> Bool {
        position.x.isFinite && position.y.isFinite && position.z.isFinite
    }

    static func normalizedForwardDirection(_ vector: SIMD3<Float>) -> SIMD3<Float>? {
        guard isFiniteCameraPosition(vector) else { return nil }
        let scale = max(abs(vector.x), max(abs(vector.y), abs(vector.z)))
        guard scale.isFinite, scale > Float.leastNonzeroMagnitude else { return nil }
        let scaled = vector / scale
        let lengthSquared = simd_length_squared(scaled)
        guard lengthSquared.isFinite, lengthSquared > 1e-12 else { return nil }
        let normalized = scaled / sqrt(lengthSquared)
        return isFiniteCameraPosition(normalized) ? normalized : nil
    }
}