import Foundation
import SplatIO

enum SplatVideoMemoryPolicy {
    struct Estimate: Equatable, Sendable {
        let pointCount: Int
        let estimatedPeakBytes: UInt64
        let budgetBytes: UInt64

        var estimatedPeakMegabytes: Int {
            Int((estimatedPeakBytes + mib - 1) / mib)
        }

        var budgetMegabytes: Int {
            Int((budgetBytes + mib - 1) / mib)
        }
    }

    struct Admission: Equatable, Sendable {
        let estimate: Estimate
        let renderAssetURL: URL
    }

    enum PolicyError: LocalizedError, Equatable {
        case sceneTooLarge(pointCount: Int, estimatedPeakMegabytes: Int, budgetMegabytes: Int)
        case untrustedCanonicalAsset

        var errorDescription: String? {
            switch self {
            case .sceneTooLarge(let pointCount, let estimatedPeakMegabytes, let budgetMegabytes):
                let formattedPoints = pointCount.formatted(.number.grouping(.automatic))
                return "3Dデータが大きすぎるため、この端末では安全に動画化できません（\(formattedPoints)点 / 推定\(estimatedPeakMegabytes)MB、上限\(budgetMegabytes)MB）。PLYまたはSPZで書き出すか、点数を減らしてから再試行してください。"
            case .untrustedCanonicalAsset:
                return "高品質3Dデータが不完全なため、安全に動画化できません。元のスキャン結果を再生成してから再試行してください。"
            }
        }
    }

    private struct CanonicalInspection {
        let candidateExists: Bool
        let completeAsset: SplatCanonicalSHAsset.Asset?
    }

    private static let mib: UInt64 = 1_048_576

    static let estimatedWorkingBytesPerPoint: UInt64 = 160
    static let estimatedSH3WorkingBytesPerPoint: UInt64 = 384
    static let fixedRendererAndEncoderReserveBytes: UInt64 = 96 * mib
    static let minimumBudgetBytes: UInt64 = 256 * mib
    static let maximumBudgetBytes: UInt64 = 512 * mib
    static let physicalMemoryDivisor: UInt64 = 8

    /// Any non-default persisted edit makes the video path allocate an edited point array while the
    /// original reader result is still alive. Reserve at least the concrete SplatPoint stride for
    /// that second array instead of pretending edited and unedited exports have identical peaks.
    static let editedPointCopyBytesPerPoint: UInt64 = UInt64(MemoryLayout<SplatPoint>.stride)

    /// Exposure/contrast edits of SH3 points mutate coefficient[0]. Swift Array copy-on-write then
    /// materializes the 16-coefficient SH payload for edited points. Account for that payload plus a
    /// small per-allocation header reserve; crop-only edits do not need this coefficient clone.
    static let editedSH3ColorCopyBytesPerPoint: UInt64 =
        UInt64(16 * MemoryLayout<SIMD3<Float>>.stride + 32)

    @discardableResult
    static func preflight(
        sourceURL: URL,
        configuration: SplatVideoConfiguration,
        physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) throws -> Estimate {
        try preflightAdmission(
            sourceURL: sourceURL,
            configuration: configuration,
            physicalMemoryBytes: physicalMemoryBytes
        ).estimate
    }

    /// Canonical selection may hash the completed legacy result and can therefore scan hundreds of
    /// megabytes. Run that synchronous filesystem work on an explicit worker so callers from the
    /// SwiftUI export flow never depend on executor inheritance for UI responsiveness. When the
    /// completion gate already produced a trusted digest, reuse it and avoid the extra full-file read.
    static func preflightAdmissionAsync(
        sourceURL: URL,
        verifiedDigest: String? = nil,
        configuration: SplatVideoConfiguration,
        physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) async throws -> Admission {
        let worker = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let admission = try preflightAdmission(
                sourceURL: sourceURL,
                verifiedDigest: verifiedDigest,
                configuration: configuration,
                physicalMemoryBytes: physicalMemoryBytes
            )
            try Task.checkCancellation()
            return admission
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    static func preflightAdmission(
        sourceURL: URL,
        verifiedDigest: String? = nil,
        configuration: SplatVideoConfiguration,
        physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) throws -> Admission {
        // Admission owns canonical selection and returns the exact validated URL to the renderer.
        // Reuse a fresh completion digest when available. Legacy/internal callers without one retain
        // the original fail-safe path that hashes the source to derive the content address.
        let pointCount = try SplatExportService.sourcePointCount(sourceURL)
        let canonical = inspectCanonicalOnce(
            sourceURL: sourceURL,
            verifiedDigest: verifiedDigest,
            expectedPointCount: pointCount
        )
        // A missing canonical is legitimate for older SH0 scans. Once a content-addressed canonical
        // candidate exists, however, malformed schema, mismatched point count/SH degree, or a
        // truncated binary payload must not silently downgrade a new scan's video to legacy SH0.
        if canonical.candidateExists && canonical.completeAsset == nil {
            throw PolicyError.untrustedCanonicalAsset
        }

        // Loading here also performs the established backup-recovery/self-heal. Keep the recovered
        // settings and feed them into memory admission because the renderer will materialize them.
        let editSettings = SplatViewerEditStore.load(sourceURL: sourceURL)?.settings ?? .default

        let estimate = makeEstimate(
            pointCount: pointCount,
            hasCanonicalSH3: canonical.completeAsset != nil,
            editSettings: editSettings,
            configuration: configuration,
            physicalMemoryBytes: physicalMemoryBytes
        )

        guard estimate.estimatedPeakBytes <= estimate.budgetBytes else {
            throw PolicyError.sceneTooLarge(
                pointCount: estimate.pointCount,
                estimatedPeakMegabytes: estimate.estimatedPeakMegabytes,
                budgetMegabytes: estimate.budgetMegabytes
            )
        }

        return Admission(
            estimate: estimate,
            renderAssetURL: canonical.completeAsset?.url ?? sourceURL
        )
    }

    static func estimate(
        sourceURL: URL,
        configuration: SplatVideoConfiguration,
        physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) throws -> Estimate {
        let pointCount = try SplatExportService.sourcePointCount(sourceURL)
        let hasCanonicalSH3 = SplatCanonicalSHAsset.existingCompleteAsset(
            forLegacySplat: sourceURL,
            expectedPointCount: pointCount
        ) != nil
        let editSettings = SplatViewerEditStore.load(sourceURL: sourceURL)?.settings ?? .default

        return makeEstimate(
            pointCount: pointCount,
            hasCanonicalSH3: hasCanonicalSH3,
            editSettings: editSettings,
            configuration: configuration,
            physicalMemoryBytes: physicalMemoryBytes
        )
    }

    private static func inspectCanonicalOnce(
        sourceURL: URL,
        verifiedDigest: String?,
        expectedPointCount: Int
    ) -> CanonicalInspection {
        let resolvedURL: URL?
        if let verifiedDigest {
            resolvedURL = try? SplatCanonicalSHAsset.canonicalURL(
                forLegacySplat: sourceURL,
                verifiedDigest: verifiedDigest
            )
        } else {
            resolvedURL = try? SplatCanonicalSHAsset.canonicalURL(forLegacySplat: sourceURL)
        }
        guard let canonicalURL = resolvedURL else {
            return CanonicalInspection(candidateExists: false, completeAsset: nil)
        }
        guard FileManager.default.fileExists(atPath: canonicalURL.path) else {
            return CanonicalInspection(candidateExists: false, completeAsset: nil)
        }
        guard let descriptor = try? SplatCanonicalSHAsset.inspectPLY(canonicalURL),
              descriptor.shDegree == SplatCanonicalSHAsset.requiredSHDegree,
              descriptor.pointCount == expectedPointCount else {
            return CanonicalInspection(candidateExists: true, completeAsset: nil)
        }

        let asset = SplatCanonicalSHAsset.Asset(url: canonicalURL, descriptor: descriptor)
        guard SplatCanonicalSHAsset.hasCompleteVertexPayload(
            at: canonicalURL,
            expectedPointCount: expectedPointCount
        ) else {
            return CanonicalInspection(candidateExists: true, completeAsset: nil)
        }
        return CanonicalInspection(candidateExists: true, completeAsset: asset)
    }

    private static func makeEstimate(
        pointCount: Int,
        hasCanonicalSH3: Bool,
        editSettings: SplatEditSettings,
        configuration: SplatVideoConfiguration,
        physicalMemoryBytes: UInt64
    ) -> Estimate {
        let dimensions = configuration.dimensions
        let width = UInt64(max(1, dimensions.width))
        let height = UInt64(max(1, dimensions.height))
        let bytesPerBGRAFrame: UInt64 = width * height * 4
        let videoSurfaceReserveBytes = bytesPerBGRAFrame * 4
        let workingBytesPerPoint = hasCanonicalSH3
            ? estimatedSH3WorkingBytesPerPoint
            : estimatedWorkingBytesPerPoint

        let normalizedEdits = editSettings.normalized()
        let hasEdits = normalizedEdits != .default
        let needsColorAdjustment =
            abs(normalizedEdits.exposureEV) > 0.0001 ||
            abs(normalizedEdits.contrast - 1) > 0.0001
        var additionalEditedBytesPerPoint: UInt64 = hasEdits ? editedPointCopyBytesPerPoint : 0
        if hasCanonicalSH3 && needsColorAdjustment {
            additionalEditedBytesPerPoint = additionalEditedBytesPerPoint
                &+ editedSH3ColorCopyBytesPerPoint
        }

        let bytesPerPoint = workingBytesPerPoint &+ additionalEditedBytesPerPoint
        let pointWorkingSetBytes = UInt64(pointCount).multipliedReportingOverflow(by: bytesPerPoint)
        let boundedPointWorkingSet = pointWorkingSetBytes.overflow ? UInt64.max : pointWorkingSetBytes.partialValue
        let basePeak = boundedPointWorkingSet.addingReportingOverflow(fixedRendererAndEncoderReserveBytes)
        let withRendererReserve = basePeak.overflow ? UInt64.max : basePeak.partialValue
        let finalPeak = withRendererReserve.addingReportingOverflow(videoSurfaceReserveBytes)
        let estimatedPeakBytes = finalPeak.overflow ? UInt64.max : finalPeak.partialValue

        let proportionalBudget = physicalMemoryBytes / physicalMemoryDivisor
        let budgetBytes = min(
            maximumBudgetBytes,
            max(minimumBudgetBytes, proportionalBudget)
        )

        return Estimate(
            pointCount: pointCount,
            estimatedPeakBytes: estimatedPeakBytes,
            budgetBytes: budgetBytes
        )
    }
}
