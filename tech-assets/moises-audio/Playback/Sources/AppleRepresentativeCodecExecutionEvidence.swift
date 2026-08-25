#if canImport(AVFAudio)
import AVFAudio
import Foundation

private struct Lane3AppleRepresentativeCodecReadable: Lane3PCMChunkReadable, @unchecked Sendable {
    let base: Lane3AppleFilePCMChunkSource

    var channels: Int { base.channels }
    var sampleRate: Double { base.sampleRate }
    var frameCount: Int64 { base.frameCount }

    func readInterleavedFrames(startFrame: Int64, frameCount: Int) throws -> [Float] {
        do {
            return try base.readInterleavedFrames(startFrame: startFrame, frameCount: frameCount)
        } catch let error as Lane3AppleFilePCMChunkSourceError {
            throw Lane3RepresentativeCodecReadFailure(Self.map(error))
        } catch {
            throw Lane3RepresentativeCodecReadFailure(.unexpectedReadFailure)
        }
    }

    private static func map(_ error: Lane3AppleFilePCMChunkSourceError) -> Lane3RepresentativeCodecFailureCode {
        switch error {
        case .openFailed: .openRejected
        case .invalidProcessingFormat: .invalidProcessingFormat
        case .emptySource: .emptySource
        case .sourceClosed: .sourceClosed
        case .sourceMetadataChanged: .sourceMetadataChanged
        case .policyRejected: .policyRejected
        case .bufferAllocationFailed: .bufferAllocationFailed
        case .seekFailed: .seekFailed
        case .readFailed: .readFailed
        case .shortRead: .shortRead
        case .pcmAccessUnavailable: .pcmAccessUnavailable
        case .positionMismatch: .positionMismatch
        }
    }
}

/// AW43 selected-Apple adapter. The fixture descriptor is supplied by the evidence manifest;
/// this adapter never persists the file URL. It opens the file through the AW27 bounded AVAudioFile
/// reader, maps Apple decoder failures to stable path-free codes, then performs a full sequential
/// chunk sweep so mid-stream corruption cannot be hidden by head/tail spot checks.
public enum Lane3AppleRepresentativeCodecExecutionProbe {
    public static func run(
        fileURL: URL,
        descriptor: Lane3RepresentativeCodecFixtureDescriptor,
        maximumFramesPerRead: Int = 65_536,
        chunkFrames: Int = 16_384
    ) throws -> Lane3RepresentativeCodecExecutionReport {
        let environment: Lane3RepresentativeCodecExecutionEnvironment
        #if os(iOS) && !targetEnvironment(simulator)
        environment = .physicalIPhoneAVFAudio
        #else
        environment = .selectedAppleAVFAudio
        #endif

        let source: Lane3AppleFilePCMChunkSource
        do {
            source = try Lane3AppleFilePCMChunkSource(
                fileURL: fileURL,
                maximumFramesPerRead: maximumFramesPerRead
            )
        } catch let error as Lane3AppleFilePCMChunkSourceError {
            return Lane3RepresentativeCodecExecutionProbe.openRejected(
                descriptor: descriptor,
                environment: environment,
                failureCode: mapOpen(error)
            )
        } catch {
            return Lane3RepresentativeCodecExecutionProbe.openRejected(
                descriptor: descriptor,
                environment: environment,
                failureCode: .openRejected
            )
        }

        return try Lane3RepresentativeCodecExecutionProbe.sweep(
            source: Lane3AppleRepresentativeCodecReadable(base: source),
            descriptor: descriptor,
            environment: environment,
            chunkFrames: chunkFrames
        )
    }

    private static func mapOpen(_ error: Lane3AppleFilePCMChunkSourceError) -> Lane3RepresentativeCodecFailureCode {
        switch error {
        case .openFailed: .openRejected
        case .invalidProcessingFormat: .invalidProcessingFormat
        case .emptySource: .emptySource
        case .sourceClosed: .sourceClosed
        case .sourceMetadataChanged: .sourceMetadataChanged
        case .policyRejected: .policyRejected
        case .bufferAllocationFailed: .bufferAllocationFailed
        case .seekFailed: .seekFailed
        case .readFailed: .readFailed
        case .shortRead: .shortRead
        case .pcmAccessUnavailable: .pcmAccessUnavailable
        case .positionMismatch: .positionMismatch
        }
    }
}
#endif
