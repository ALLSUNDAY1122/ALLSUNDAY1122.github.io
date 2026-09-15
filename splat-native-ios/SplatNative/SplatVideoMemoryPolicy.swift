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

        var errorDescription: String? {
            switch self {
            case .sceneTooLarge(let pointCount, let estimatedPeakMegabytes, let budgetMegabytes):
                let formattedPoints = pointCount.formatted(.number.grouping(.automatic))
                return "3Dデータが大きすぎるため、この端末では安全に動画化できません（\(formattedPoints)点 / 推定\(estimatedPeakMegabytes)MB、上限\(budgetMegabytes)MB）。PLYまたはSPZで書き出すか、点数を減らしてから再試行してください。"
            }
        }
    }

    private static let mib: UInt64 = 1_048_576

    // Conservative working-set estimate for one dot-splat point while video export is active.
    // It covers the decoded Swift SplatPoint array, Metal encoded/covariance data,
    // sorting/index buffers, and temporary conversion/staging overhead.
    static let estimatedWorkingBytesPerPoint: UInt64 = 160

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
        let estimate = try estimate(
            sourceURL: sourceURL,
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
        // The reconstruction output is the fixed-width 32-byte .splat format.
        // sourcePointCount validates divisibility and returns the exact point count
        // without decoding the scene into memory.
        let pointCount = try SplatExportService.sourcePointCount(sourceURL)

        let dimensions = configuration.dimensions
        let width = UInt64(max(1, dimensions.width))
        let height = UInt64(max(1, dimensions.height))
        let bytesPerBGRAFrame: UInt64 = width * height * 4

        // AVAssetWriterPixelBufferAdaptor may keep multiple frame surfaces alive while
        // Metal renders and VideoToolbox encodes. Reserve four full BGRA surfaces.
        let videoSurfaceReserveBytes = bytesPerBGRAFrame * 4
        let pointWorkingSetBytes = UInt64(pointCount) * estimatedWorkingBytesPerPoint
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
