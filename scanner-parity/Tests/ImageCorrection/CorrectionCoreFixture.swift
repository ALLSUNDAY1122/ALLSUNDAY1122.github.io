import Foundation

@main
enum CorrectionCoreFixture {
    static func main() {
        let full = PageQuad.fullFrame
        precondition(abs(full.area - 1) < 0.000_001)
        precondition(full.isPlausible())
        precondition(abs(full.residualSkewDegrees) < 0.000_001)
        precondition(abs(full.perspectiveSeverity) < 0.000_001)

        let trapezoid = PageQuad(
            topLeft: .init(x: 0.20, y: 0.92),
            topRight: .init(x: 0.80, y: 0.88),
            bottomRight: .init(x: 0.94, y: 0.08),
            bottomLeft: .init(x: 0.06, y: 0.10)
        )
        precondition(trapezoid.area > 0.50)
        precondition(trapezoid.perspectiveSeverity > 0.10)

        var bimodal = [Int](repeating: 0, count: 256)
        bimodal[35] = 500
        bimodal[210] = 500
        guard let threshold = OtsuThreshold.value(histogram: bimodal) else { fatalError("missing otsu threshold") }
        precondition((35...209).contains(threshold))

        let metrics = LuminanceMetrics.from(histogram: bimodal)
        precondition(metrics != nil)
        precondition(abs((metrics?.mean ?? 0) - (122.5 / 255)) < 0.01)

        let guarded = VariantSelector.choose(scores: [.original: 0.80, .ocrGrayscale: 0.82])
        precondition(guarded.selected == .original)
        let improved = VariantSelector.choose(scores: [.original: 0.80, .ocrGrayscale: 0.86])
        precondition(improved.selected == .ocrGrayscale)

        precondition(OrientationEstimator.rotationDegrees(width: 1200, height: 1800, policy: .preferPortrait) == 0)
        precondition(OrientationEstimator.rotationDegrees(width: 1800, height: 1200, policy: .preferPortrait) == 90)
        precondition(OrientationEstimator.rotationDegrees(width: 1800, height: 1200, policy: .preserve) == 0)

        print("CorrectionCoreFixture PASS")
    }
}
