import Foundation
import SplatIO
import simd

extension SplatPersistedEditMaterializer {
    /// Cancellation-aware in-memory materialization for long-running consumers such as video export.
    /// The original synchronous helper remains available for small/synchronous call sites; this path
    /// checks cooperative cancellation in bounded batches so cancelling an export releases its large
    /// edited-point buffer instead of finishing obsolete full-scene work in the background.
    static func materializeInMemoryCancellable(
        sourceURL: URL,
        points: [SplatPoint]
    ) async throws -> [SplatPoint] {
        try Task.checkCancellation()
        let settings = loadSettings(sourceURL: sourceURL)
        guard settings != .default else { return points }

        let bounds = settings.hasCrop
            ? try cancellableRobustCropBounds(for: points)
            : nil
        let plan = Plan(settings: settings, bounds: bounds, outputPointCount: points.count)
        let edited = try cancellableApply(points, plan: plan)
        guard !edited.isEmpty else { throw MaterializeError.emptyEditedScene }
        return edited
    }

    private static func cancellableRobustCropBounds(for points: [SplatPoint]) throws -> CropBounds {
        let strideSize = max(1, points.count / 8_000)
        var xs: [Float] = []
        var ys: [Float] = []
        var zs: [Float] = []
        xs.reserveCapacity(min(points.count, 8_001))
        ys.reserveCapacity(min(points.count, 8_001))
        zs.reserveCapacity(min(points.count, 8_001))

        var sampleIndex = 0
        for index in stride(from: 0, to: points.count, by: strideSize) {
            if sampleIndex & 0x3FF == 0 { try Task.checkCancellation() }
            let p = points[index].position
            if p.x.isFinite, p.y.isFinite, p.z.isFinite {
                xs.append(p.x); ys.append(p.y); zs.append(p.z)
            }
            sampleIndex += 1
        }
        try Task.checkCancellation()
        return CropBounds(
            x: cancellablePercentileRange(xs),
            y: cancellablePercentileRange(ys),
            z: cancellablePercentileRange(zs)
        )
    }

    private static func cancellablePercentileRange(_ values: [Float]) -> AxisRange {
        guard !values.isEmpty else { return AxisRange(low: -1, high: 1) }
        let sorted = values.sorted()
        let lowIndex = min(sorted.count - 1, Int(Double(sorted.count - 1) * 0.01))
        let highIndex = min(sorted.count - 1, Int(Double(sorted.count - 1) * 0.99))
        var low = sorted[lowIndex]
        var high = sorted[highIndex]
        if !low.isFinite || !high.isFinite || high - low < 0.0001 {
            low = sorted.first ?? -1
            high = sorted.last ?? 1
        }
        if high - low < 0.0001 { high = low + 0.0001 }
        return AxisRange(low: low, high: high)
    }

    private static func cancellableApply(_ points: [SplatPoint], plan: Plan) throws -> [SplatPoint] {
        guard !plan.isIdentity else {
            try Task.checkCancellation()
            return points
        }

        let settings = plan.settings
        let exposureGain = Float(pow(2.0, settings.exposureEV))
        let contrast = Float(settings.contrast)
        let needsColorAdjustment = abs(settings.exposureEV) > 0.0001 || abs(settings.contrast - 1) > 0.0001

        var result: [SplatPoint] = []
        result.reserveCapacity(points.count)
        for (index, point) in points.enumerated() {
            if index & 0x3FF == 0 { try Task.checkCancellation() }
            guard cancellableIsEligible(point, settings: settings, bounds: plan.bounds) else { continue }
            guard needsColorAdjustment else {
                result.append(point)
                continue
            }

            var edited = point
            let base = point.color.asSRGBFloat
            let exposed = base * exposureGain
            let midpoint = SIMD3<Float>(repeating: 0.5)
            let adjusted = simd_clamp((exposed - midpoint) * contrast + midpoint, .zero, .one)
            switch point.color {
            case .sphericalHarmonicFloat(var coefficients):
                if !coefficients.isEmpty {
                    coefficients[0] = (adjusted - midpoint) * SplatPoint.Color.INV_SH_C0
                    edited.color = .sphericalHarmonicFloat(coefficients)
                }
            case .sRGBUInt8:
                edited.color = .sRGBUInt8(SIMD3<UInt8>(
                    cancellableByte(adjusted.x),
                    cancellableByte(adjusted.y),
                    cancellableByte(adjusted.z)
                ))
            }
            result.append(edited)
        }
        try Task.checkCancellation()
        return result
    }

    private static func cancellableIsEligible(
        _ point: SplatPoint,
        settings: SplatEditSettings,
        bounds: CropBounds?
    ) -> Bool {
        let p = point.position
        guard p.x.isFinite, p.y.isFinite, p.z.isFinite else { return false }
        guard let bounds else { return true }
        if settings.cropXMin > 0.0001, p.x < bounds.x.value(at: settings.cropXMin) { return false }
        if settings.cropXMax < 0.9999, p.x > bounds.x.value(at: settings.cropXMax) { return false }
        if settings.cropYMin > 0.0001, p.y < bounds.y.value(at: settings.cropYMin) { return false }
        if settings.cropYMax < 0.9999, p.y > bounds.y.value(at: settings.cropYMax) { return false }
        if settings.cropZMin > 0.0001, p.z < bounds.z.value(at: settings.cropZMin) { return false }
        if settings.cropZMax < 0.9999, p.z > bounds.z.value(at: settings.cropZMax) { return false }
        return true
    }

    private static func cancellableByte(_ value: Float) -> UInt8 {
        UInt8(clamping: Int((max(0, min(1, value)) * 255).rounded()))
    }
}
