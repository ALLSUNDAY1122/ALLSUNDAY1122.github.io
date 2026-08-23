import Foundation

public enum Lane3CombinedRecoveryAW05AdapterError: Error, Equatable, Sendable {
    case generationMismatch(playbackToken: UInt64, binding: UInt64)
    case reasonMismatch(playback: String, dsp: String)
    case staleClickGeneration(active: UInt64, binding: UInt64)
}

public struct Lane3CombinedRecoveryAW05Receipt: Equatable, Codable, Sendable {
    public let playbackGeneration: UInt64
    public let clickGeneration: UInt64
    public let reason: Lane3CombinedRecoveryDiscontinuityReason
    public let evidenceScope: String
    public let parityPromotionAllowed: Bool
}

/// Small adapter that lets HQ seed AW11 run/recovery evidence from the exact AW05 token/binding.
/// It rejects mixed-generation, mixed-reason or stale-click pairs before the stress/evidence layer
/// treats them as one coherent transport state.
public enum Lane3CombinedRecoveryAW05Adapter {
    public static func makeReceipt(
        playbackToken: PlaybackTransportRescheduleToken,
        binding: PracticeDSPTransportGenerationBinding,
        activeClickGeneration: UInt64
    ) throws -> Lane3CombinedRecoveryAW05Receipt {
        guard playbackToken.generation == binding.playbackGeneration else {
            throw Lane3CombinedRecoveryAW05AdapterError.generationMismatch(
                playbackToken: playbackToken.generation,
                binding: binding.playbackGeneration
            )
        }
        guard playbackToken.reason.rawValue == binding.reason.rawValue else {
            throw Lane3CombinedRecoveryAW05AdapterError.reasonMismatch(
                playback: playbackToken.reason.rawValue,
                dsp: binding.reason.rawValue
            )
        }
        guard binding.clickGeneration == activeClickGeneration else {
            throw Lane3CombinedRecoveryAW05AdapterError.staleClickGeneration(
                active: activeClickGeneration,
                binding: binding.clickGeneration
            )
        }
        guard let reason = Lane3CombinedRecoveryDiscontinuityReason(rawValue: playbackToken.reason.rawValue) else {
            throw Lane3CombinedRecoveryAW05AdapterError.reasonMismatch(
                playback: playbackToken.reason.rawValue,
                dsp: binding.reason.rawValue
            )
        }
        return Lane3CombinedRecoveryAW05Receipt(
            playbackGeneration: playbackToken.generation,
            clickGeneration: binding.clickGeneration,
            reason: reason,
            evidenceScope: "LANE3_AW05_TO_AW11_GENERATION_RECEIPT_NON_PARITY",
            parityPromotionAllowed: false
        )
    }
}
