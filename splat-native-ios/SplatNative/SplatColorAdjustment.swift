import Foundation
import SplatIO
import simd

enum SplatColorAdjustment {
    static func apply(
        _ color: SplatPoint.Color,
        exposureEV: Double,
        contrast: Double
    ) -> SplatPoint.Color {
        let contrastValue = Float(contrast)
        let linearGain = Float(pow(2.0, exposureEV)) * contrastValue
        let bias = Float(0.5) * (1 - contrastValue)
        let midpoint = SIMD3<Float>(repeating: 0.5)

        switch color {
        case .sphericalHarmonicFloat(var coefficients):
            // A malformed/truncated scene can surface an SH payload with no DC coefficient.
            // Do not ask `asSRGBFloat` to derive a base color until the DC term is known to exist;
            // returning the original payload lets the caller's normal validation/recovery path
            // handle the damaged point instead of turning an appearance edit into a crash.
            guard !coefficients.isEmpty else { return color }
            let base = color.asSRGBFloat
            // The edit is affine before display clipping. Scale every directional
            // SH coefficient by the linear term; apply the constant bias to DC only.
            // Clamping DC here would destroy view-dependent variation, so final
            // display clipping remains the renderer's responsibility.
            let affineBase = base * linearGain + SIMD3<Float>(repeating: bias)
            coefficients[0] = (affineBase - midpoint) * SplatPoint.Color.INV_SH_C0
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
