import Foundation

@main
struct AW11AW05AdapterSelfTest {
    static func main() throws {
        let token = PlaybackTransportRescheduleToken(generation: 41, reason: .tempoChange)
        let binding = PracticeDSPTransportGenerationBinding(
            playbackGeneration: 41,
            clickGeneration: 93,
            reason: .tempoChange
        )
        let receipt = try Lane3CombinedRecoveryAW05Adapter.makeReceipt(
            playbackToken: token,
            binding: binding,
            activeClickGeneration: 93
        )
        precondition(receipt.reason == .tempoChange)
        precondition(!receipt.parityPromotionAllowed)

        do {
            _ = try Lane3CombinedRecoveryAW05Adapter.makeReceipt(
                playbackToken: token,
                binding: PracticeDSPTransportGenerationBinding(
                    playbackGeneration: 40,
                    clickGeneration: 93,
                    reason: .tempoChange
                ),
                activeClickGeneration: 93
            )
            fatalError("generation mismatch accepted")
        } catch {}

        do {
            _ = try Lane3CombinedRecoveryAW05Adapter.makeReceipt(
                playbackToken: token,
                binding: PracticeDSPTransportGenerationBinding(
                    playbackGeneration: 41,
                    clickGeneration: 93,
                    reason: .seek
                ),
                activeClickGeneration: 93
            )
            fatalError("reason mismatch accepted")
        } catch {}

        do {
            _ = try Lane3CombinedRecoveryAW05Adapter.makeReceipt(
                playbackToken: token,
                binding: binding,
                activeClickGeneration: 94
            )
            fatalError("stale click generation accepted")
        } catch {}

        print("L3-AW11 AW05 adapter compatibility PASS")
    }
}
