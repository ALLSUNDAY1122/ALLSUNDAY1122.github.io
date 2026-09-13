import Foundation
import SplatIO
import simd

extension SplatPersistedEditMaterializer {
    /// Streaming materialization for video export. Non-default edits no longer require readAll() to
    /// keep the entire unedited scene resident while a second edited array is built. Crop paths make
    /// one bounded sampling pass for robust bounds, then stream the source again into the final array;
    /// color-only paths need just the single materialization pass.
    static func materializeStreamingCancellable(
        sourceURL: URL,
        assetURL: URL,
        sourcePointCount: Int
    ) async throws -> [SplatPoint] {
        try Task.checkCancellation()
        let settings = SplatViewerEditStore.load(sourceURL: sourceURL)?.settings ?? .default

        guard settings != .default else {
            let reader = try AutodetectSceneReader(assetURL)
            let points = try await reader.readAll()
            try Task.checkCancellation()
            return points
        }

        let bounds = settings.hasCrop
            ? try await cancellableSampledCropBounds(
                sourceURL: assetURL,
                sourcePointCount: sourcePointCount
            )
            : nil
        let plan = Plan(settings: settings, bounds: bounds, outputPointCount: sourcePointCount)
        let reader = try AutodetectSceneReader(assetURL)
        let stream = try await reader.read()
        var result: [SplatPoint] = []
        let reserveCapacity = initialOutputReserveCapacity(
            inputPointCount: sourcePointCount,
            hasCrop: settings.hasCrop
        )
        if reserveCapacity > 0 {
            result.reserveCapacity(reserveCapacity)
        }

        for try await points in stream {
            try Task.checkCancellation()
            let edited = try cancellableApply(points, plan: plan)
            result.append(contentsOf: edited)
        }
        try Task.checkCancellation()
        guard !result.isEmpty else { throw MaterializeError.emptyEditedScene }
        return result
    }

    /// Cancellation-aware in-memory materialization for long-running consumers such as video export.
    /// The original synchronous helper remains available for small/synchronous call sites; this path
    /// checks cooperative cancellation in bounded batches so cancelling an export releases its large
    /// edited-point buffer instead of finishing obsolete full-scene work in the background.
    static func materializeInMemoryCancellable(
        sourceURL: URL,
        points: [SplatPoint]
    ) async throws -> [SplatPoint] {
        try Task.checkCancellation()
        // Reuse the durable viewer sidecar gate instead of bypassing it with an unrestricted
        // Data(contentsOf:). Video export must see exactly the same bounded/project-local edit
        // settings as the live viewer, including backup recovery when the primary sidecar is corrupt.
        let settings = SplatViewerEditStore.load(sourceURL: sourceURL)?.settings ?? .default
        guard settings != .default else { return points }

        let bounds = settings.hasCrop
            ? try cancellableRobustCropBounds(for: points)
            : nil
        let plan = Plan(settings: settings, bounds: bounds, outputPointCount: points.count)
        let edited = try applyCancellable(points, plan: plan)
        guard !edited.isEmpty else { throw MaterializeError.emptyEditedScene }
        return edited
    }

    /// Streaming PLY/SPZ export uses the same cooperative-cancellation semantics as video export.
    /// SceneReader chunks can be large enough that checking only between chunks leaves a cancelled
    /// export burning CPU and holding a second point buffer for a noticeable period.
    static func applyCancellable(_ points: [SplatPoint], plan: Plan) throws -> [SplatPoint] {
        try cancellableApply(points, plan: plan)
    }

    /// Count pass used while planning a cropped export. Check cancellation inside the reader chunk,
    /// not only when the next async chunk arrives.
    static func eligiblePointCountCancellable(
        _ points: [SplatPoint],
        settings: SplatEditSettings,
        bounds: CropBounds?
    ) throws -> Int {
        var count = 0
        for (index, point) in points.enumerated() {
            if index & 0x3FF == 0 { try Task.checkCancellation() }
            if cancellableIsEligible(point, settings: settings, bounds: bounds) {
                count += 1
            }
        }
        try Task.checkCancellation()
        return count
    }

    /// Cropped materialization can discard most of a large scene. Reserving the full input count in
    /// that case defeats the purpose of the crop and can transiently duplicate hundreds of MB of SH3
    /// storage during video export. Identity/no-crop edits keep the exact reserve for throughput;
    /// cropped paths grow only with points that actually survive the crop.
    static func initialOutputReserveCapacity(inputPointCount: Int, hasCrop: Bool) -> Int {
        guard inputPointCount > 0 else { return 0 }
        return hasCrop ? 0 : inputPointCount
    }

    private static func cancellableSampledCropBounds(
        sourceURL: URL,
        sourcePointCount: Int
    ) async throws -> CropBounds {
        // Use exactly the same evenly distributed sample convention as the live viewer. The former
        // floor-stride path sampled almost every point for 8,001...15,999-point scenes, while the
        // viewer used at most 8,000 points; percentile crop boundaries could therefore move when the
        // same persisted slider values were materialized for export/video.
        let sampleIndices = SplatCameraGeometry.framingSampleIndices(
            pointCount: sourcePointCount,
            targetSampleCount: 8_000
        )
        let reader = try AutodetectSceneReader(sourceURL)
        let stream = try await reader.read()
        var xs: [Float] = []
        var ys: [Float] = []
        var zs: [Float] = []
        xs.reserveCapacity(sampleIndices.count)
        ys.reserveCapacity(sampleIndices.count)
        zs.reserveCapacity(sampleIndices.count)
        var globalIndex = 0
        var sampleOffset = 0

        for try await points in stream {
            try Task.checkCancellation()
            for point in points {
                if globalIndex & 0x3FF == 0 { try Task.checkCancellation() }
                if sampleOffset < sampleIndices.count,
                   globalIndex == sampleIndices[sampleOffset] {
                    let p = point.position
                    if p.x.isFinite, p.y.isFinite, p.z.isFinite {
                        xs.append(p.x); ys.append(p.y); zs.append(p.z)
                    }
                    sampleOffset += 1
                }
                globalIndex += 1
            }
        }
        try Task.checkCancellation()
        return CropBounds(
            x: cancellablePercentileRange(xs),
            y: cancellablePercentileRange(ys),
            z: cancellablePercentileRange(zs)
        )
    }

    private static func cancellableRobustCropBounds(for points: [SplatPoint]) throws -> CropBounds {
        let sampleIndices = SplatCameraGeometry.framingSampleIndices(
            pointCount: points.count,
            targetSampleCount: 8_000
        )
        var xs: [Float] = []
        var ys: [Float] = []
        var zs: [Float] = []
        xs.reserveCapacity(sampleIndices.count)
        ys.reserveCapacity(sampleIndices.count)
        zs.reserveCapacity(sampleIndices.count)

        for (sampleOffset, index) in sampleIndices.enumerated() {
            if sampleOffset & 0x3FF == 0 { try Task.checkCancellation() }
            let p = points[index].position
            if p.x.isFinite, p.y.isFinite, p.z.isFinite {
                xs.append(p.x); ys.append(p.y); zs.append(p.z)
            }
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
        let needsColorAdjustment = abs(settings.exposureEV) > 0.0001 || abs(settings.contrast - 1) > 0.0001

        var result: [SplatPoint] = []
        let reserveCapacity = initialOutputReserveCapacity(
            inputPointCount: points.count,
            hasCrop: settings.hasCrop
        )
        if reserveCapacity > 0 {
            result.reserveCapacity(reserveCapacity)
        }
        for (index, point) in points.enumerated() {
            if index & 0x3FF == 0 { try Task.checkCancellation() }
            guard cancellableIsEligible(point, settings: settings, bounds: plan.bounds) else { continue }
            guard needsColorAdjustment else {
                result.append(point)
                continue
            }

            var edited = point
    edited.color = SplatColorAdjustment.apply(
        point.color,
        exposureEV: settings.exposureEV,
        contrast: settings.contrast
    )
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
