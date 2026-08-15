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

    static func makeConfig() -> TrainingConfig {
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
        return config
    }

    static func enhancementTarget(from currentIteration: Int) -> Int {
        let base = max(standardIterations, currentIteration)
        return min(trainingHorizon, base + enhancementIncrement)
    }

    static func boundedTarget(_ target: Int, resumedIteration: Int) -> Int {
        min(trainingHorizon, max(resumedIteration, max(1, target)))
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
