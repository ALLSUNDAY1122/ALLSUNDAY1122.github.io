#if canImport(AVFAudio)
import AVFAudio
import AudioToolbox
import Foundation

public enum AppleTransactionalStemGainRampStageError: Error, Equatable, Sendable {
    case parameterUnavailable
    case parameterNotRampable
    case invalidGain(Double)
    case invalidFrameCount(Int64)
}

/// Dedicated per-stem gain stage with an explicit preflight/schedule split.
/// A caller can validate every stem in a batch before scheduling any Audio Unit event, preventing
/// a validation failure on one stem from leaving an already-partially-updated mixer state.
public final class AppleTransactionalStemGainRampStage {
    public let mixerNode: AVAudioMixerNode
    private let gainParameter: AUParameter
    private let scheduleParameter: AUScheduleParameterBlock

    public init(mixerNode: AVAudioMixerNode) throws {
        self.mixerNode = mixerNode
        let audioUnit = mixerNode.auAudioUnit
        guard let tree = audioUnit.parameterTree,
              let parameter = tree.parameter(
                withID: kMultiChannelMixerParam_Volume,
                scope: kAudioUnitScope_Global,
                element: 0
              ) else {
            throw AppleTransactionalStemGainRampStageError.parameterUnavailable
        }
        guard parameter.flags.contains(.flag_CanRamp) else {
            throw AppleTransactionalStemGainRampStageError.parameterNotRampable
        }
        self.gainParameter = parameter
        self.scheduleParameter = audioUnit.scheduleParameterBlock
    }

    public var renderSampleRate: Double {
        mixerNode.outputFormat(forBus: 0).sampleRate
    }

    public func validateImmediate(_ gain: Double) throws {
        guard gain.isFinite, (0...1).contains(gain) else {
            throw AppleTransactionalStemGainRampStageError.invalidGain(gain)
        }
    }

    public func setImmediateValidated(_ gain: Double) {
        gainParameter.value = AUValue(gain)
    }

    public func validateRamp(
        to targetGain: Double,
        frameCount: Int64
    ) throws {
        guard targetGain.isFinite, (0...1).contains(targetGain) else {
            throw AppleTransactionalStemGainRampStageError.invalidGain(targetGain)
        }
        guard frameCount >= 1,
              frameCount <= Int64(UInt32.max) else {
            throw AppleTransactionalStemGainRampStageError.invalidFrameCount(frameCount)
        }
    }

    public func scheduleValidatedRamp(
        to targetGain: Double,
        frameCount: Int64
    ) {
        scheduleParameter(
            AUEventSampleTimeImmediate,
            AUAudioFrameCount(frameCount),
            gainParameter.address,
            AUValue(targetGain)
        )
    }
}
#endif
