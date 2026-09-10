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

    private static let mib: UInt64 = 1_048_576

    static let estimatedWorkingBytesPerPoint: UInt64 = 160
    static let estimatedSH3WorkingBytesPerPoint: UInt64 = 384
    static let fixedRendererAndEncoderReserveBytes: UInt64 = 96 * mib
    static let minimumBudgetBytes: UInt64 = 256 * mib
    static let maximumBudgetBytes: UInt64 = 512 * mib
    static let physicalMemoryDivisor: UInt64 = 8

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

    static func preflightAdmission(
        sourceURL: URL,
        configuration: SplatVideoConfiguration,
        physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) throws -> Admission {
        // Admission owns canonical selection and returns the exact validated URL to the renderer.
        // Compute the content-addressed URL once here: the canonical helper derives it by hashing
        // the whole legacy result, so calling both existingAsset and existingCompleteAsset would
        // otherwise repeat that O(file-size) read before rendering starts.
        let pointCount = try SplatExportService.sourcePointCount(sourceURL)
        let canonical = inspectCanonicalOnce(
            sourceURL: sourceURL,
            expectedPointCount: pointCount
        )
        if canonical.schemaValid && canonical.completeAsset == nil {
            throw PolicyError.untrustedCanonicalAsset
        }

        _ = SplatViewerEditStore.load(sourceURL: sourceURL)

        let estimate = makeEstimate(
            pointCount: pointCount,
            hasCanonicalSH3: canonical.completeAsset != nil,
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

        return makeEstimate(
            pointCount: pointCount,
            hasCanonicalSH3: hasCanonicalSH3,
            configuration: configuration,
            physicalMemoryBytes: physicalMemoryBytes
        )
    }

    private static func inspectCanonicalOnce(
        sourceURL: URL,
        expectedPointCount: Int
    ) -> (schemaValid: Bool, completeAsset: SplatCanonicalSHAsset.Asset?) {
        guard let canonicalURL = try? SplatCanonicalSHAsset.canonicalURL(forLegacySplat: sourceURL),
              FileManager.default.fileExists(atPath: canonicalURL.path),
              let descriptor = try? SplatCanonicalSHAsset.inspectPLY(canonicalURL),
              descriptor.shDegree == SplatCanonicalSHAsset.requiredSHDegree,
              descriptor.pointCount == expectedPointCount else {
            return (false, nil)
        }

        let asset = SplatCanonicalSHAsset.Asset(url: canonicalURL, descriptor: descriptor)
        guard SplatCanonicalSHAsset.hasCompleteVertexPayload(
            at: canonicalURL,
            expectedPointCount: expectedPointCount
        ) else {
            return (true, nil)
        }
        return (true, asset)
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
