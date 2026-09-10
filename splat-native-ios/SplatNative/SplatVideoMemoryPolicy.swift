import Foundation

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

    private static let mib: UInt64 = 1_048_576

    // Conservative working-set estimate for a legacy SH0 dot-splat point while video export is
    // active. It covers the decoded Swift point array, Metal encoded/covariance data,
    // sorting/index buffers, and temporary conversion/staging overhead.
    static let estimatedWorkingBytesPerPoint: UInt64 = 160

    // SH3 retains 16 RGB coefficient vectors per Gaussian. Once video rendering prefers the
    // canonical SH3 PLY, those coefficients remain resident in the decoded point representation
    // in addition to renderer staging, so using the legacy estimate can materially under-budget
    // large scenes and increase jetsam/thermal risk during export.
    static let estimatedSH3WorkingBytesPerPoint: UInt64 = 384

    // Keep headroom for the renderer, AVAssetWriter/VideoToolbox, framework state,
    // and allocations elsewhere in the app that are not proportional to point count.
    static let fixedRendererAndEncoderReserveBytes: UInt64 = 96 * mib

    // Do not let this single feature consume an unbounded fraction of device RAM.
    // On a 3 GiB device this yields 384 MiB; on 4 GiB+ it is capped at 512 MiB.
    static let minimumBudgetBytes: UInt64 = 256 * mib
    static let maximumBudgetBytes: UInt64 = 512 * mib
    static let physicalMemoryDivisor: UInt64 = 8

    @discardableResult
    static func preflight(
        sourceURL: URL,
        configuration: SplatVideoConfiguration,
        physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) throws -> Estimate {
        // Video rendering prefers a committed SH3 generation when present. A schema-valid PLY can
        // still have a truncated binary body after an interrupted copy/write. Reject that state at
        // admission instead of allowing SplatVideoExporter to hand the corrupt file to SplatIO.
        let pointCount = try SplatExportService.sourcePointCount(sourceURL)
        let schemaValidCanonical = SplatCanonicalSHAsset.existingAsset(
            forLegacySplat: sourceURL,
            expectedPointCount: pointCount
        )
        let completeCanonical = SplatCanonicalSHAsset.existingCompleteAsset(
            forLegacySplat: sourceURL,
            expectedPointCount: pointCount
        )
        if schemaValidCanonical != nil && completeCanonical == nil {
            throw PolicyError.untrustedCanonicalAsset
        }

        // Video export materializes the persisted viewer edit sidecar immediately after this
        // memory admission. Repair a corrupt primary from the known-good generation first so a
        // video cannot silently fall back to default edits while the live viewer shows recovered
        // exposure/crop settings.
        _ = SplatViewerEditStore.load(sourceURL: sourceURL)

        // Reuse the canonical resolution performed above. The canonical filename is derived from
        // the legacy result SHA-256, so resolving it again inside estimate() would reread/hash the
        // entire result during every video start. On large scenes that is measurable CPU, storage
        // bandwidth, latency and heat with no change in the answer.
        let estimate = makeEstimate(
            pointCount: pointCount,
            hasCanonicalSH3: completeCanonical != nil,
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
        return estimate
    }

    static func estimate(
        sourceURL: URL,
        configuration: SplatVideoConfiguration,
        physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) throws -> Estimate {
        // Reserve SH3 memory only when the generation is complete enough to be selected by the
        // hardened viewer/export path. A header-only/truncated PLY must not influence the estimate.
        let pointCount = try SplatExportService.sourcePointCount(sourceURL)
        let hasCanonicalSH3 = SplatCanonicalSHAsset.existingCompleteAsset(
            forLegacySplat: sourceURL,
            expectedPointCount: pointCount
        ) != nil

        return makeEstimate(
            pointCount: pointCount,
            hasCanonicalSH3: hasCanonicalSH3,
            configuration: configuration,
            physicalMemoryBytes: physicalMemoryBytes
        )
    }

    private static func makeEstimate(
        pointCount: Int,
        hasCanonicalSH3: Bool,
        configuration: SplatVideoConfiguration,
        physicalMemoryBytes: UInt64
    ) -> Estimate {
        let dimensions = configuration.dimensions
        let width = UInt64(max(1, dimensions.width))
        let height = UInt64(max(1, dimensions.height))
        let bytesPerBGRAFrame: UInt64 = width * height * 4

        // AVAssetWriterPixelBufferAdaptor may keep multiple frame surfaces alive while
        // Metal renders and VideoToolbox encodes. Reserve four full BGRA surfaces.
        let videoSurfaceReserveBytes = bytesPerBGRAFrame * 4
        let workingBytesPerPoint = hasCanonicalSH3
            ? estimatedSH3WorkingBytesPerPoint
            : estimatedWorkingBytesPerPoint
        let pointWorkingSetBytes = UInt64(pointCount) * workingBytesPerPoint
        let estimatedPeakBytes = pointWorkingSetBytes
            + fixedRendererAndEncoderReserveBytes
            + videoSurfaceReserveBytes

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