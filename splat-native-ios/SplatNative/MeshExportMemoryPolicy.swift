import Foundation

enum MeshExportMemoryPolicy {
    struct Estimate: Equatable, Sendable {
        let sourceBytes: UInt64
        let estimatedPeakBytes: UInt64
        let budgetBytes: UInt64

        var estimatedPeakMegabytes: Int { Int((estimatedPeakBytes + mib - 1) / mib) }
        var budgetMegabytes: Int { Int((budgetBytes + mib - 1) / mib) }
    }

    enum PolicyError: LocalizedError, Equatable {
        case sourceSizeUnavailable
        case conversionTooLarge(estimatedPeakMegabytes: Int, budgetMegabytes: Int)

        var errorDescription: String? {
            switch self {
            case .sourceSizeUnavailable:
                return "Meshデータのサイズを確認できないため、安全な変換を開始できません。"
            case .conversionTooLarge(let estimated, let budget):
                return "Meshが大きすぎるため、この端末では安全に変換できません（推定\(estimated)MB / 上限\(budget)MB）。元形式のまま共有するか、Meshを軽量化してから再試行してください。"
            }
        }
    }

    private static let mib: UInt64 = 1_048_576
    static let minimumBudgetBytes: UInt64 = 256 * mib
    static let maximumBudgetBytes: UInt64 = 768 * mib
    static let physicalMemoryDivisor: UInt64 = 6

    @discardableResult
    static func preflight(
        sourceURL: URL,
        format: MeshExportService.Format,
        physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) throws -> Estimate {
        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        guard let size = attributes[.size] as? NSNumber, size.uint64Value > 0 else {
            throw PolicyError.sourceSizeUnavailable
        }
        let estimate = estimate(
            sourceBytes: size.uint64Value,
            sourceExtension: sourceURL.pathExtension.lowercased(),
            format: format,
            physicalMemoryBytes: physicalMemoryBytes
        )
        guard estimate.estimatedPeakBytes <= estimate.budgetBytes else {
            throw PolicyError.conversionTooLarge(
                estimatedPeakMegabytes: estimate.estimatedPeakMegabytes,
                budgetMegabytes: estimate.budgetMegabytes
            )
        }
        return estimate
    }

    static func estimate(
        sourceBytes: UInt64,
        sourceExtension: String,
        format: MeshExportService.Format,
        physicalMemoryBytes: UInt64
    ) -> Estimate {
        let sourceExtension = sourceExtension.lowercased()
        let exactPassthrough = sourceExtension == format.rawValue

        let estimatedPeakBytes: UInt64
        if exactPassthrough {
            // copyItem + bounded container probing; the entire asset is not decoded.
            estimatedPeakBytes = 32 * mib
        } else if sourceExtension == "obj" {
            switch format {
            case .ply, .las:
                // OBJ input is mapped, decoded to text and expanded into vertex/UV/triangle arrays.
                // Texture sampling is capped at 4096² RGBA (~64 MiB).
                estimatedPeakBytes = saturatingAdd(
                    saturatingMultiply(sourceBytes, by: 8),
                    96 * mib
                )
            case .fbx, .obj, .glb, .usdz, .stl:
                // Assimp/ModelIO build an in-memory scene before serialization.
                estimatedPeakBytes = saturatingAdd(
                    saturatingMultiply(sourceBytes, by: 8),
                    128 * mib
                )
            }
        } else {
            // Non-OBJ inputs may first be decoded by ModelIO and bridged through OBJ before
            // the final exporter parses them again, so reserve more than the direct OBJ path.
            estimatedPeakBytes = saturatingAdd(
                saturatingMultiply(sourceBytes, by: 10),
                160 * mib
            )
        }

        let proportionalBudget = physicalMemoryBytes / physicalMemoryDivisor
        let budgetBytes = min(maximumBudgetBytes, max(minimumBudgetBytes, proportionalBudget))
        return Estimate(
            sourceBytes: sourceBytes,
            estimatedPeakBytes: estimatedPeakBytes,
            budgetBytes: budgetBytes
        )
    }

    private static func saturatingMultiply(_ value: UInt64, by multiplier: UInt64) -> UInt64 {
        guard value > 0, multiplier > 0 else { return 0 }
        if value > UInt64.max / multiplier { return UInt64.max }
        return value * multiplier
    }

    private static func saturatingAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        if lhs > UInt64.max - rhs { return UInt64.max }
        return lhs + rhs
    }
}
