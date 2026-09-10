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

    static func canUseCanonicalSH3(
        pointCount: Int,
        physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) -> Bool {
        guard pointCount > 0 else { return false }
        let safePointCount = UInt64(pointCount)
        let pointBytes: UInt64
        if safePointCount > (UInt64.max - fixedRendererReserveBytes) / estimatedWorkingBytesPerSH3Point {
            pointBytes = UInt64.max
        } else {
            pointBytes = safePointCount * estimatedWorkingBytesPerSH3Point + fixedRendererReserveBytes
        }
        let proportional = physicalMemoryBytes / physicalMemoryDivisor
        let budget = min(maximumBudgetBytes, max(minimumBudgetBytes, proportional))
        return pointBytes <= budget
    }
}
