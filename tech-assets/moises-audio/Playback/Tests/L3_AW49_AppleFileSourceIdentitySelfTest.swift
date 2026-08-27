#if canImport(AVFAudio)
import AVFAudio
import Foundation

private func lane3AW49WriteWAV(url: URL, seed: Float) throws {
    guard let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 48_000,
        channels: 2,
        interleaved: false
    ), let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_096) else {
        preconditionFailure("unable to allocate AW49 WAV fixture")
    }
    buffer.frameLength = 4_096
    guard let channels = buffer.floatChannelData else {
        preconditionFailure("missing AW49 WAV channel data")
    }
    for frame in 0..<4_096 {
        let value = seed + Float(frame % 31) / 1000
        channels[0][frame] = value
        channels[1][frame] = -value
    }
    let file = try AVAudioFile(
        forWriting: url,
        settings: format.settings,
        commonFormat: .pcmFormatFloat32,
        interleaved: false
    )
    try file.write(from: buffer)
}

@main
struct L3AW49AppleFileSourceIdentitySelfTestMain {
    static func main() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("l3-aw49-apple-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let liveURL = root.appendingPathComponent("live.wav")
        let replacementURL = root.appendingPathComponent("replacement.wav")
        try lane3AW49WriteWAV(url: liveURL, seed: 0.1)
        try lane3AW49WriteWAV(url: replacementURL, seed: 0.7)

        let source = try Lane3AppleFilePCMChunkSource(fileURL: liveURL, maximumFramesPerRead: 1_024)
        precondition(source.channels == 2)
        precondition(source.sampleRate.bitPattern == 48_000.0.bitPattern)
        precondition(source.frameCount == 4_096)
        let first = try source.readInterleavedFrames(startFrame: 0, frameCount: 1_024)
        precondition(first.count == 2_048)

        // Replace the path with a different same-format/same-length WAV. The protocol-visible metadata
        // stored on `source` remains identical, so only the AW49 filesystem identity fence can prove
        // that the backing evidence object changed between chunks.
        let replacementBytes = try Data(contentsOf: replacementURL)
        try replacementBytes.write(to: liveURL, options: .atomic)
        precondition(source.channels == 2)
        precondition(source.sampleRate.bitPattern == 48_000.0.bitPattern)
        precondition(source.frameCount == 4_096)

        do {
            _ = try source.readInterleavedFrames(startFrame: 1_024, frameCount: 1_024)
            preconditionFailure("same-metadata WAV replacement escaped AW49 identity fence")
        } catch Lane3AppleFilePCMChunkSourceError.sourceIdentityChanged {
            // expected
        }

        print("L3-AW49 Apple file source identity PASS sameMetadataReplacementRejected=true")
    }
}
#endif
