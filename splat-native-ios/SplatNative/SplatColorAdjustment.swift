import Foundation
import SplatIO
import simd

enum SplatColorAdjustment {
    static func apply(
        _ color: SplatPoint.Color,
        exposureEV: Double,
        contrast: Double
    ) -> SplatPoint.Color {
        // Persisted settings are normally normalized before this helper is reached, but keep the
        // shared color primitive safe in isolation too. A NaN/Inf gain can propagate into SH data;
        // on the byte path it can also reach a floating-point-to-Int conversion. Preserve the last
        // valid appearance instead of letting corrupt parameters turn an edit into invalid output.
        guard exposureEV.isFinite, contrast.isFinite else { return color }
        let contrastValue = Float(contrast)
        let linearGain = Float(pow(2.0, exposureEV)) * contrastValue
        let bias = Float(0.5) * (1 - contrastValue)
        guard linearGain.isFinite, bias.isFinite else { return color }
        let midpoint = SIMD3<Float>(repeating: 0.5)

        switch color {
        case .sphericalHarmonicFloat(var coefficients):
            // A malformed/truncated scene can surface an SH payload with no DC coefficient.
            // Returning the original payload lets the caller's normal validation/recovery path
            // handle the damaged point instead of turning an appearance edit into a crash.
            guard !coefficients.isEmpty else { return color }

            // The edit is affine before display clipping. SplatIO's `asSRGBFloat` intentionally
            // clamps SH0 into 0...1, so round-tripping through it would discard valid over/under-range
            // DC energy before applying the edit. Transform the coefficients directly instead:
            //   rgb = 0.5 + C0*dc + directional
            //   rgb' = rgb*linearGain + bias
            // therefore every directional band scales by linearGain and only DC receives the
            // constant offset. Final display clipping remains the renderer's responsibility.
            let dcOffset = (
                midpoint * linearGain
                    + SIMD3<Float>(repeating: bias)
                    - midpoint
            ) * SplatPoint.Color.INV_SH_C0
            coefficients[0] = coefficients[0] * linearGain + dcOffset
            if coefficients.count > 1 {
                for index in 1..<coefficients.count {
                    coefficients[index] = coefficients[index] * linearGain
                }
            }
            return .sphericalHarmonicFloat(coefficients)

        case .sRGBUInt8:
            let base = color.asSRGBFloat
            let adjusted = simd_clamp(
                base * linearGain + SIMD3<Float>(repeating: bias),
                .zero,
                .one
            )
            return .sRGBUInt8(SIMD3<UInt8>(
                byte(adjusted.x), byte(adjusted.y), byte(adjusted.z)
            ))
        }
    }

    private static func byte(_ value: Float) -> UInt8 {
        UInt8(clamping: Int((max(0, min(1, value)) * 255).rounded()))
    }
}
