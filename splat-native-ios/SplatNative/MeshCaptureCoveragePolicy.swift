import Foundation
import simd

enum MeshCaptureCoveragePolicy {
    /// Require physical translation before crediting another coverage viewpoint. The floor keeps
    /// small scans from accepting orientation-only sweeps, while larger targets scale the required
    /// parallax with the path-length expectation used by the capture quality advisor.
    static func translationThreshold(pathThresholdMeters: Float) -> Float {
        let safePathThreshold = pathThresholdMeters.isFinite && pathThresholdMeters > 0
            ? pathThresholdMeters
            : 0
        return max(0.015, safePathThreshold * 0.02)
    }

    /// Require real vertical camera displacement before treating pitch changes as useful
    /// top/bottom coverage. This prevents a user from satisfying the elevation gate by simply
    /// tilting the phone from one position, which adds little reconstruction parallax.
    static func verticalSpanThreshold(pathThresholdMeters: Float) -> Float {
        let safePathThreshold = pathThresholdMeters.isFinite && pathThresholdMeters > 0
            ? pathThresholdMeters
            : 0
        return max(0.10, safePathThreshold * 0.12)
    }

    /// Reject discontinuous camera-coordinate jumps from coverage accounting. ARKit can return to
    /// normal tracking after relocalization with a shifted world origin; treating that discontinuity
    /// as user motion would falsely satisfy path/height coverage gates.
    static func isPlausibleSampleDisplacement(_ meters: Float) -> Bool {
        meters.isFinite && meters >= 0 && meters <= 0.35
    }

    /// The quality advisor samples roughly every 160 ms. A long gap means the trajectory between
    /// the two camera poses was unobserved (for example after a stall, interruption, or resume), so
    /// displacement across that gap must not be credited as continuous capture motion. Otherwise a
    /// user can gain path/height/viewpoint coverage from a jump that the capture pipeline never saw.
    static func isPlausibleSampleDisplacement(_ meters: Float, elapsedSeconds: TimeInterval) -> Bool {
        guard isPlausibleSampleDisplacement(meters),
              elapsedSeconds.isFinite,
              elapsedSeconds > 0,
              elapsedSeconds <= 1.0 else { return false }
        // The capture pipeline never accepts translation above 1.6 m/s, even for distant scenes.
        // Do not let the quality advisor credit motion that the actual RGB capture policy would reject.
        return meters / Float(elapsedSeconds) <= 1.60
    }

    /// A tracking state of `.normal` is necessary but not sufficient when the camera transform is
    /// malformed. Never let NaN/Inf camera coordinates enter path, height, or coverage accumulators.
    static func isFiniteCameraPosition(_ position: SIMD3<Float>) -> Bool {
        position.x.isFinite && position.y.isFinite && position.z.isFinite
    }

    /// Normalize a camera forward vector without first squaring its original magnitude. ARKit
    /// normally supplies a unit vector, but a corrupt/interrupted transform with individually finite
    /// near-Float.max components makes `simd_length_squared` overflow to Infinity and can turn a
    /// direct `simd_normalize` into NaN. Scale first so malformed input fails soft instead of
    /// poisoning yaw/elevation coverage and quality guidance.
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
