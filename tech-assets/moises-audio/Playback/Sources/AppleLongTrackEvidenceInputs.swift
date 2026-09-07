#if canImport(AVFAudio)
import Foundation

public enum Lane3AppleLongTrackEvidenceInputError: Error, Equatable, Sendable {
    case readBudgetInsufficient(requiredFrames: Int, configuredFrames: Int)
}

public struct Lane3AppleLongTrackEvidenceInputPair: Sendable {
    public let reference: Lane3AppleFilePCMChunkSource
    public let observed: Lane3AppleFilePCMChunkSource
    public let resourceProfile: Lane3LongTrackEvidenceResourceProfile

    public init(
        reference: Lane3AppleFilePCMChunkSource,
        observed: Lane3AppleFilePCMChunkSource,
        resourceProfile: Lane3LongTrackEvidenceResourceProfile
    ) {
        self.reference = reference
        self.observed = observed
        self.resourceProfile = resourceProfile
    }
}

/// Opens candidate/reference evidence inputs without materializing whole-track PCM arrays.
/// The factory derives the AW26 maximum single-read requirement before returning the pair, so a
/// too-small decoder budget fails during preflight instead of deep inside a long analysis run.
public enum Lane3AppleLongTrackEvidenceInputFactory {
    public static func openPair(
        referenceFileURL: URL,
        observedFileURL: URL,
        maximumFramesPerRead: Int = 65_536,
        chunkFrames: Int = 16_384,
        timeConfiguration: Lane3PCMDifferentialConfiguration = Lane3PCMDifferentialConfiguration(),
        spectralConfiguration: Lane3SpectralDifferentialConfiguration = Lane3SpectralDifferentialConfiguration(),
        envelopeConfiguration: Lane3CepstralEnvelopeConfiguration = Lane3CepstralEnvelopeConfiguration()
    ) throws -> Lane3AppleLongTrackEvidenceInputPair {
        let reference = try Lane3AppleFilePCMChunkSource(
            fileURL: referenceFileURL,
            maximumFramesPerRead: maximumFramesPerRead
        )
        let observed = try Lane3AppleFilePCMChunkSource(
            fileURL: observedFileURL,
            maximumFramesPerRead: maximumFramesPerRead
        )

        _ = try Lane3LongTrackPCMAccess.validatePair(
            reference: reference,
            observed: observed,
            chunkFrames: chunkFrames
        )
        let profile = try Lane3LongTrackEvidenceResourcePlanner.profile(
            channels: reference.channels,
            chunkFrames: chunkFrames,
            timeConfiguration: timeConfiguration,
            spectralConfiguration: spectralConfiguration,
            envelopeConfiguration: envelopeConfiguration
        )
        guard maximumFramesPerRead >= profile.maximumSingleReadFrames else {
            throw Lane3AppleLongTrackEvidenceInputError.readBudgetInsufficient(
                requiredFrames: profile.maximumSingleReadFrames,
                configuredFrames: maximumFramesPerRead
            )
        }

        return Lane3AppleLongTrackEvidenceInputPair(
            reference: reference,
            observed: observed,
            resourceProfile: profile
        )
    }
}
#endif
