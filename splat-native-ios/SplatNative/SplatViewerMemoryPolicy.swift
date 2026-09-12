import Foundation

/// Chooses whether the live viewer can safely retain the canonical SH3 representation in memory.
/// The legacy `.splat` remains a quality-reduced fallback for scenes whose SH3 working set would
/// consume too much device RAM. This keeps view-dependent color where practical without trading it
/// for jetsam or severe edit-time memory pressure on large scans.
enum SplatViewerMemoryPolicy {
    private static let mib: UInt64 = 1_048_576

    // SH3 points coexist with the immutable source array, an edited/cropped candidate during
    // interactive rebuilds, Metal staging/sort data and renderer state. This is deliberately more
    // conservative than the serialized PLY byte width.
    static let estimatedWorkingBytesPerSH3Point: UInt64 = 448
    static let fixedRendererReserveBytes: UInt64 = 96 * mib
    static let minimumBudgetBytes: UInt64 = 256 * mib
    static let maximumBudgetBytes: UInt64 = 768 * mib
    static let physicalMemoryDivisor: UInt64 = 6

    /// Thermal pressure is a useful proxy for sustained device contention during long scans. Keeping
    /// the nominal memory budget while the SoC is already serious/critical can select a large SH3
    /// scene that technically fits RAM but causes sustained frame drops or raises jetsam risk once
    /// Metal sorting and edit buffers overlap. Prefer the legacy representation earlier instead.
    static func budgetBytes(
        physicalMemoryBytes: UInt64,
        thermalState: ProcessInfo.ThermalState
    ) -> UInt64 {
        let proportional = physicalMemoryBytes / physicalMemoryDivisor
        let baseBudget = min(maximumBudgetBytes, max(minimumBudgetBytes, proportional))
        switch thermalState {
        case .nominal, .fair:
            return baseBudget
        case .serious:
            return baseBudget / 4 * 3
        case .critical:
            return baseBudget / 2
        @unknown default:
            // Unknown future states should be conservative rather than silently assuming nominal.
            return baseBudget / 2
        }
    }

    static func canUseCanonicalSH3(
        pointCount: Int,
        physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory,
        thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    ) -> Bool {
        guard pointCount > 0 else { return false }
        let safePointCount = UInt64(pointCount)
        let pointBytes: UInt64
        if safePointCount > (UInt64.max - fixedRendererReserveBytes) / estimatedWorkingBytesPerSH3Point {
            pointBytes = UInt64.max
        } else {
            pointBytes = safePointCount * estimatedWorkingBytesPerSH3Point + fixedRendererReserveBytes
        }
        return pointBytes <= budgetBytes(
            physicalMemoryBytes: physicalMemoryBytes,
            thermalState: thermalState
        )
    }
}
