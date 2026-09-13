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
        let base = color.asSRGBFloat

        switch color {
        case .sphericalHarmonicFloat(var coefficients):
            guard !coefficients.isEmpty else { return color }
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
