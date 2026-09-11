import Foundation
import simd

enum MeshCaptureCoveragePolicy {
    /// Require physical translation before crediting another coverage viewpoint. The floor keeps
    /// small scans from accepting orientation-only sweeps, while larger targets scale the required
    /// parallax with the path-length expectation used by the capture quality advisor.
    static func translationThreshold(pathThresholdMeters: Float) -> Float {
        max(0.015, pathThresholdMeters * 0.02)
    }

    /// Require real vertical camera displacement before treating pitch changes as useful
    /// top/bottom coverage. This prevents a user from satisfying the elevation gate by simply
    /// tilting the phone from one position, which adds little reconstruction parallax.
    static func verticalSpanThreshold(pathThresholdMeters: Float) -> Float {
        max(0.10, pathThresholdMeters * 0.12)
    }

    /// Reject discontinuous camera-coordinate jumps from coverage accounting. ARKit can return to
    /// normal tracking after relocalization with a shifted world origin; treating that discontinuity
    /// as user motion would falsely satisfy path/height coverage gates.
    static func isPlausibleSampleDisplacement(_ meters: Float) -> Bool {
        meters.isFinite && meters >= 0 && meters <= 0.35
    }

    /// The capture pipeline never accepts translation above 1.6 m/s, even for distant scenes.
    /// Do not let the quality advisor credit motion that the actual RGB capture policy would reject.
    static func isPlausibleSampleDisplacement(_ meters: Float, elapsedSeconds: TimeInterval) -> Bool {
        guard isPlausibleSampleDisplacement(meters),
              elapsedSeconds.isFinite,
              elapsedSeconds > 0 else { return false }
        return meters / Float(elapsedSeconds) <= 1.60
    }

    /// A tracking state of `.normal` is necessary but not sufficient when the camera transform is
    /// malformed. Never let NaN/Inf camera coordinates enter path, height, or coverage accumulators.
    static func isFiniteCameraPosition(_ position: SIMD3<Float>) -> Bool {
        position.x.isFinite && position.y.isFinite && position.z.isFinite
    }
}
