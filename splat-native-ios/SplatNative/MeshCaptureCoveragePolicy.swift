import Foundation

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
}
