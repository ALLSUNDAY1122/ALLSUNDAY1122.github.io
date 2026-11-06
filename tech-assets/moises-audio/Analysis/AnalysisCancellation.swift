import Foundation

public enum AnalysisCancellationPolicy {
    public static let preparationCheckStride = 2_048
    public static let tempoFrameCheckStride = 64
    public static let tempoCorrelationCheckStride = 4_096
    public static let tempoPhaseCheckStride = 128
    public static let keyWindowCheckStride = 1
    public static let chordFrameCheckStride = 1
    public static let postProcessCheckStride = 128

    @inline(__always)
    public static func check() throws {
        try Task.checkCancellation()
    }

    @inline(__always)
    static func checkIfNeeded(enabled: Bool, iteration: Int, stride: Int) throws {
        guard enabled else { return }
        let safeStride = max(1, stride)
        if iteration == 0 || iteration % safeStride == 0 {
            try Task.checkCancellation()
        }
    }
}
