#if canImport(AVFAudio)
import AVFAudio
import Foundation

@main
struct L3AW29AppleDSPCompileSurfaceSelfTest {
    static func main() throws {
        let collector = Lane3DSPRuntimeTelemetryCollector()
        let projectID = ProjectID()
        let node = AVAudioUnitTimePitch()
        let stack = try Lane3AppleDSPProductionStack.make(
            projectID: projectID,
            collector: collector,
            node: node
        )
        precondition(stack.node === node)
        precondition(stack.compositionReceipt.telemetryWrapped)
        precondition(stack.compositionReceipt.transactionalConformance)
        precondition(stack.compositionReceipt.tempoTransitionConformance)
        precondition(stack.compositionReceipt.pitchTransitionConformance)
        precondition(stack.compositionReceipt.backendNodeIdentityShared)
        precondition(!stack.compositionReceipt.directBackendAccessExposed)
        precondition(!stack.compositionReceipt.parityPromotionAllowed)
        _ = AppleSampleAccurateClickExecutor.self
        print("L3-AW29 Apple DSP compile surface PASS")
    }
}
#else
import Foundation

@main
struct L3AW29AppleDSPCompileSurfaceSelfTest {
    static func main() {
        print("L3-AW29 Apple DSP compile surface SKIPPED_NO_AVFAUDIO")
    }
}
#endif
