import Foundation
import Msplat

/// S2 owns these reconstruction defaults. They are intentionally explicit instead of relying on
/// upstream msplat defaults so parity benchmarks remain reproducible across dependency upgrades.
enum SplatReconstructionPolicy {
    static let trainingHorizon = 30_000
    static let standardIterations = 7_000
    static let enhancementIncrement = 5_000
    static let checkpointInterval = 1_000
    static let thermalCheckInterval = 100
    static let datasetDownscale: Float = 4.0

    static func makeConfig(
        physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) -> TrainingConfig {
        var config = TrainingConfig()
        // Keep one optimizer schedule across the initial pass and every Enhance pass. Each pass
        // stops early, while the scheduler retains the same 30k horizon as upstream msplat.
        config.iterations = Int32(trainingHorizon)
        config.shDegree = 3
        config.shDegreeInterval = 1_000
        config.ssimWeight = 0.2
        config.numDownscales = 1
        config.resolutionSchedule = 2_000
        config.refineEvery = 100
        config.warmupLength = 500
        config.resetAlphaEvery = 30
        config.densifyGradThresh = 0.0002
        config.densifySizeThresh = 0.01
        config.stopScreenSizeAt = 4_000
        config.splitScreenSize = 0.05
        config.keepCrs = false
        config.bgColor = (0.02, 0.02, 0.025)

        // S12 moves the Gaussian safety line into densification admission. Use
        // the exact same device policy as ResourceGuard instead of duplicating
        // a memory-to-Gaussian formula in Msplat/C++.
        let limits = SplatResourceLimits.conservative(
            physicalMemoryBytes: physicalMemoryBytes
        )
        config.maxGaussianCount = Int32(clamping: limits.densificationBudgetCount)
        return config
    }

    static func enhancementTarget(from currentIteration: Int) -> Int {
        let base = max(standardIterations, currentIteration)
        return min(trainingHorizon, base + enhancementIncrement)
    }

    static func boundedTarget(_ target: Int, resumedIteration: Int) -> Int {
        min(trainingHorizon, max(resumedIteration, max(1, target)))
    }

    /// Serious thermal pressure is a throttling signal, not a terminal reconstruction result.
    /// Preserve the full training/SH3/quality contract and lower GPU submission duty-cycle instead.
    /// Critical pressure still checkpoints and pauses because the device needs to cool down.
    static func requiresThermalPause(_ state: ProcessInfo.ThermalState) -> Bool {
        switch state {
        case .critical:
            return true
        case .nominal, .fair, .serious:
            return false
        @unknown default:
            return true
        }
    }

    /// Wall-clock pacing only. This never changes frame selection, image resolution, Gaussian caps,
    /// optimizer settings, SH degree, or target iteration count.
    static func thermalPacingDelaySeconds(_ state: ProcessInfo.ThermalState) -> TimeInterval {
        switch state {
        case .nominal:
            return 0
        case .fair:
            return 0.010
        case .serious:
            return 0.060
        case .critical:
            return 0
        @unknown default:
            return 0.060
        }
    }
}
