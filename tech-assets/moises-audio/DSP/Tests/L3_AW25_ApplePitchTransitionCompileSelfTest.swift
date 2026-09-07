#if canImport(AVFAudio)
import AVFAudio

@main
struct L3AW25ApplePitchTransitionCompileSelfTest {
    static func main() throws {
        let backend = AppleTimePitchBackend(node: AVAudioUnitTimePitch())
        let transitionBackend: any PracticeDSPPitchTransitionBackendApplying = backend
        let snapshot = try transitionBackend.snapshotAppliedDSP()
        precondition(snapshot.tempoRatio.isFinite)
        precondition(snapshot.pitchSemitones.isFinite)
        print("L3-AW25 Apple pitch transition compile self-test: PASS")
    }
}
#else
import Foundation

@main
struct L3AW25ApplePitchTransitionCompileSelfTest {
    static func main() {
        print("L3-AW25 Apple pitch transition compile self-test: SKIPPED_NO_AVFAUDIO")
    }
}
#endif
