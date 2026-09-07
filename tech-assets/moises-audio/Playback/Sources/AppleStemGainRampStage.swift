#if canImport(AVFAudio)
import AVFAudio
import AudioToolbox
import Foundation

public enum AppleStemGainRampStageError: Error, Equatable, Sendable {
    case parameterUnavailable
    case parameterNotRampable
    case invalidGain(Double)
    case invalidFrameCount(Int64)
}

/// One ramp-capable gain stage for one stem.
///
/// The stage deliberately uses the Audio Unit parameter scheduler instead of repeatedly assigning
/// `AVAudioPlayerNode.volume`. Apple documents `AUScheduleParameterBlock` as the host API for a
/// sample-frame-duration parameter ramp, and requires hosts to inspect the parameter's ramp flag.
public final class AppleStemGainRampStage {
    public let mixerNode: AVAudioMixerNode
    private let gainParameter: AUParameter
    private let scheduleParameter: AUScheduleParameterBlock

    public init(mixerNode: AVAudioMixerNode) throws {
        self.mixerNode = mixerNode
        let audioUnit = mixerNode.auAudioUnit
        guard let tree = audioUnit.parameterTree,
              let parameter = tree.parameter(
                withID: kMultiChannelMixerParam_Volume,
                scope: kAudioUnitScope_Input,
                element: 0
              ) ?? tree.parameter(
                withID: kMultiChannelMixerParam_Volume,
                scope: kAudioUnitScope_Global,
                element: 0
              ) else {
            throw AppleStemGainRampStageError.parameterUnavailable
        }
        guard parameter.flags.contains(.flag_CanRamp) else {
            throw AppleStemGainRampStageError.parameterNotRampable
        }
        self.gainParameter = parameter
        self.scheduleParameter = audioUnit.scheduleParameterBlock
    }

    public var renderSampleRate: Double {
        mixerNode.outputFormat(forBus: 0).sampleRate
    }

    /// Safe for graph setup or a paused transport. Do not use this to implement an audible
    /// playing-state transition; use `scheduleRamp` instead.
    public func setImmediate(_ gain: Double) throws {
        guard gain.isFinite, (0...1).contains(gain) else {
            throw AppleStemGainRampStageError.invalidGain(gain)
        }
        gainParameter.value = AUValue(gain)
    }

    /// Schedules a render-side ramp from the Audio Unit's current render value to `targetGain`.
    /// Not forcing an explicit start value is intentional: rapid retargeting during an in-flight
    /// ramp can otherwise jump to a stale prior target and create the very discontinuity this path
    /// exists to avoid.
    public func scheduleRamp(
        to targetGain: Double,
        frameCount: Int64
    ) throws {
        guard targetGain.isFinite, (0...1).contains(targetGain) else {
            throw AppleStemGainRampStageError.invalidGain(targetGain)
        }
        guard frameCount >= 1,
              frameCount <= Int64(UInt32.max) else {
            throw AppleStemGainRampStageError.invalidFrameCount(frameCount)
        }
        scheduleParameter(
            AUEventSampleTimeImmediate,
            AUAudioFrameCount(frameCount),
            gainParameter.address,
            AUValue(targetGain)
        )
    }
}
#endif
