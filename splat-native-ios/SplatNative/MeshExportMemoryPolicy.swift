import Foundation

enum MeshExportMemoryPolicy {
    struct Estimate: Equatable, Sendable {
        let sourceBytes: UInt64
        let estimatedPeakBytes: UInt64
        let budgetBytes: UInt64

        var estimatedPeakMegabytes: Int {
            MeshExportMemoryPolicy.roundedUpMegabytesClampedToInt(estimatedPeakBytes)
        }

        var budgetMegabytes: Int {
            MeshExportMemoryPolicy.roundedUpMegabytesClampedToInt(budgetBytes)
        }
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
        guard (attributes[.type] as? FileAttributeType) == .typeRegular,
              let size = attributes[.size] as? NSNumber,
              size.uint64Value > 0 else {
            throw PolicyError.sourceSizeUnavailable
        }
        var estimate = estimate(
            sourceBytes: size.uint64Value,
            sourceExtension: sourceURL.pathExtension.lowercased(),
            format: format,
            physicalMemoryBytes: physicalMemoryBytes
        )

        // Scene conversion may hand the complete OBJ material graph to Assimp/ModelIO, so account
        // for referenced companions there. Point-cloud conversion is different: its exporter keeps
        // only one decoded texture sampler active at a time and the estimate below includes enough
        // reserve for the old/new sampler overlap during a material switch. Summing every compressed
        // texture here would therefore reject otherwise safe multi-material PLY/LAS exports solely
        // because the project contains many atlases.
        if sourceURL.pathExtension.lowercased() == "obj" {
            switch format {
            case .fbx, .glb, .usdz, .stl:
                let companionBytes = try MeshOBJShareBundle.referencedCompanionByteCount(sourceOBJ: sourceURL)
                estimate = addingCompanionWorkingSet(companionBytes, to: estimate)
            case .ply, .las, .obj:
                break
            }
        }

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
                // Texture decoding is capped at 4096² RGBA and retains one active sampler. During a
                // material switch Swift can transiently hold the old and new samplers together, so
                // reserve two capped samplers plus parser/streaming overhead instead of scaling with
                // the total number or compressed byte size of texture companions.
                estimatedPeakBytes = saturatingAdd(
                    saturatingMultiply(sourceBytes, by: 8),
                    160 * mib
                )
            case .fbx, .obj, .glb, .usdz, .stl:
                // Assimp/ModelIO build an in-memory scene before serialization.
                estimatedPeakBytes = saturatingAdd(
                    saturatingMultiply(sourceBytes, by: 8),
                    128 * mib
                )
            }
        } else {
            switch format {
            case .ply, .las:
                // Binary/compressed inputs first expand through a text OBJ bridge, then that bridge
                // is mapped and expanded again into vertex/UV/triangle arrays. A multiplier based on
                // the compact source alone must therefore cover both the bridge expansion ratio and
                // point-cloud parser structures; align this path with the conservative 24x disk
                // admission rather than the lighter scene-conversion estimate.
                estimatedPeakBytes = saturatingAdd(
                    saturatingMultiply(sourceBytes, by: 24),
                    160 * mib
                )
            case .fbx, .obj, .glb, .usdz, .stl:
                // Other non-OBJ conversions may bridge through OBJ, but do not subsequently expand
                // every triangle corner into the point-cloud writer's Swift geometry structures.
                estimatedPeakBytes = saturatingAdd(
                    saturatingMultiply(sourceBytes, by: 10),
                    160 * mib
                )
            }
        }

        let proportionalBudget = physicalMemoryBytes / physicalMemoryDivisor
        let budgetBytes = min(maximumBudgetBytes, max(minimumBudgetBytes, proportionalBudget))
        return Estimate(
            sourceBytes: sourceBytes,
            estimatedPeakBytes: estimatedPeakBytes,
            budgetBytes: budgetBytes
        )
    }

    private static func addingCompanionWorkingSet(_ companionBytes: Int64, to estimate: Estimate) -> Estimate {
        let companionWorkingBytes = saturatingMultiply(UInt64(clamping: companionBytes), by: 8)
        return Estimate(
            sourceBytes: estimate.sourceBytes,
            estimatedPeakBytes: saturatingAdd(estimate.estimatedPeakBytes, companionWorkingBytes),
            budgetBytes: estimate.budgetBytes
        )
    }

    /// Round bytes up to MiB without overflowing `UInt64`, then clamp before converting to Int.
    /// Saturating estimates deliberately use UInt64.max; diagnostics must remain safe even for
    /// hostile/corrupt file sizes that drive the estimate to that sentinel.
    private static func roundedUpMegabytesClampedToInt(_ bytes: UInt64) -> Int {
        let quotient = bytes / mib
        let remainder = bytes % mib
        let rounded = remainder == 0 ? quotient : saturatingAdd(quotient, 1)
        guard rounded <= UInt64(Int.max) else { return Int.max }
        return Int(rounded)
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
