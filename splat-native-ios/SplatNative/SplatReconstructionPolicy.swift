import Foundation
import Msplat

/// S2 owns these reconstruction defaults. They are intentionally explicit instead of relying on
/// upstream msplat defaults so parity benchmarks remain reproducible across dependency upgrades.
enum SplatReconstructionPolicy {
    static let standardIterations = 7_000
    static let enhancementIterations = 12_000
    static let checkpointInterval = 1_000
    static let thermalCheckInterval = 100
    static let datasetDownscale: Float = 4.0

    static func makeConfig(iterations: Int) -> TrainingConfig {
        let safeIterations = max(1, iterations)
        var config = TrainingConfig()
        config.iterations = Int32(safeIterations)
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
        config.stopScreenSizeAt = Int32(min(4_000, safeIterations))
        config.splitScreenSize = 0.05
        config.keepCrs = false
        config.bgColor = (0.02, 0.02, 0.025)
        return config
    }

    static func requiresThermalPause(_ state: ProcessInfo.ThermalState) -> Bool {
        switch state {
        case .serious, .critical:
            return true
        case .nominal, .fair:
            return false
        @unknown default:
            return true
        }
    }
}
