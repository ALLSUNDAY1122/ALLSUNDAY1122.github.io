#if canImport(AVFAudio)
import AVFAudio

@main
struct L3AW28AppleTempoTransitionCompileSelfTest {
    static func main() throws {
        let backend = AppleTimePitchBackend(node: AVAudioUnitTimePitch())
        let transitionBackend: any PracticeDSPTempoTransitionBackendApplying = backend
        let snapshot = try transitionBackend.snapshotAppliedDSP()
        precondition(snapshot.tempoRatio.isFinite)
        precondition(snapshot.pitchSemitones.isFinite)
        print("L3-AW28 Apple tempo transition compile self-test: PASS")
    }
}
#else
import Foundation

@main
struct L3AW28AppleTempoTransitionCompileSelfTest {
    static func main() {
        print("L3-AW28 Apple tempo transition compile self-test: SKIPPED_NO_AVFAUDIO")
    }
}
#endif
