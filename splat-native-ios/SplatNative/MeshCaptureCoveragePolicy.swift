import Foundation

enum MeshCaptureCoveragePolicy {
    /// Require physical translation before crediting another coverage viewpoint. The floor keeps
    /// small scans from accepting orientation-only sweeps, while larger targets scale the required
    /// parallax with the path-length expectation used by the capture quality advisor.
    static func translationThreshold(pathThresholdMeters: Float) -> Float {
        max(0.015, pathThresholdMeters * 0.02)
    }
}
