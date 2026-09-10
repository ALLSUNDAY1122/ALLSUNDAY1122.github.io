import Foundation

enum SplatViewerFrameRatePolicy {
    static func preferredFramesPerSecond(for thermalState: ProcessInfo.ThermalState) -> Int {
        switch thermalState {
        case .nominal, .fair:
            return 60
        case .serious:
            return 30
        case .critical:
            return 20
        @unknown default:
            return 30
        }
    }
}
