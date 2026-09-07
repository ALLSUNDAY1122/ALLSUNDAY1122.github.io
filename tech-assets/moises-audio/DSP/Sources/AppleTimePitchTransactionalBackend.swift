#if canImport(AVFAudio)
import AVFAudio
import Foundation

extension AppleTimePitchBackend: PracticeDSPTransactionalBackendApplying {
    public func snapshotAppliedDSP() throws -> PracticeDSPBackendSnapshot {
        let tempoRatio = Double(node.rate)
        let pitchSemitones = Double(node.pitch) / 100.0
        guard tempoRatio.isFinite,
              capabilities.tempoRatioRange.contains(tempoRatio) else {
            throw ApplePracticeDSPBackendError.invalidTempoRatio(tempoRatio)
        }
        guard pitchSemitones.isFinite,
              capabilities.pitchSemitoneRange.contains(pitchSemitones) else {
            throw ApplePracticeDSPBackendError.invalidPitchSemitones(pitchSemitones)
        }
        return PracticeDSPBackendSnapshot(
            tempoRatio: tempoRatio,
            pitchSemitones: pitchSemitones
        )
    }
}
#endif
