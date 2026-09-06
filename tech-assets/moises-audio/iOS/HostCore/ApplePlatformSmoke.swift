import Foundation

#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(AVFAudio)
import AVFAudio
#endif

public struct ApplePlatformSmokeReport: Equatable, Sendable {
    public let avFoundationAvailable: Bool
    public let avFAudioAvailable: Bool
    public let linkedTypeNames: [String]

    public init(avFoundationAvailable: Bool, avFAudioAvailable: Bool, linkedTypeNames: [String]) {
        self.avFoundationAvailable = avFoundationAvailable
        self.avFAudioAvailable = avFAudioAvailable
        self.linkedTypeNames = linkedTypeNames
    }
}

/// Compile/link smoke only. It intentionally does not claim device audio quality,
/// session routing, latency, microphone permission, or physical-device validity.
public enum ApplePlatformSmoke {
    public static func run() -> ApplePlatformSmokeReport {
#if canImport(AVFoundation) && canImport(AVFAudio)
        let engine = AVAudioEngine()
        let timePitch = AVAudioUnitTimePitch()
        return ApplePlatformSmokeReport(
            avFoundationAvailable: true,
            avFAudioAvailable: true,
            linkedTypeNames: [
                String(describing: AVAsset.self),
                String(describing: type(of: engine)),
                String(describing: type(of: timePitch))
            ]
        )
#else
        return ApplePlatformSmokeReport(
            avFoundationAvailable: false,
            avFAudioAvailable: false,
            linkedTypeNames: []
        )
#endif
    }
}
