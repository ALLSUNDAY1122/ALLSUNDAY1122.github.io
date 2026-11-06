import Foundation

private enum L2AW33DecoderMode: Sendable {
    case valid
    case invalidContainer
    case mutateSource
}

private struct L2AW33Decoder: IOCompatibilityAudioDecoding {
    let mode: L2AW33DecoderMode

    func decodeToCanonicalWAV(sourceURL: URL, destinationURL: URL) async throws {
        switch mode {
        case .valid:
            try l2aw33MakeWAV(formatTag: 1).write(to: destinationURL)
        case .invalidContainer:
            try Data("not-wave".utf8).write(to: destinationURL)
        case .mutateSource:
            try l2aw33MakeWAV(formatTag: 1).write(to: destinationURL)
            let handle = try FileHandle(forWritingTo: sourceURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: Data([0x7f]))
            try handle.close()
        }
    }
}

@main
struct L2AW33CompatibilityDecodeBoundarySelfCheck {
    static func main() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(
            "L2AW33-" + UUID().uuidString,
            isDirectory: true
        )
        defer { try? fileManager.removeItem(at: root) }

        let fileStore = IOFileStore(rootURL: root)
        try fileStore.prepareDirectories(fileManager: fileManager)
        let staging = IOCompatibilityDecodeStaging(fileStore: fileStore)
        let source = fileStore.stagingURL.appendingPathComponent("source.wma")
        let original = Data((0..<4096).map { UInt8($0 % 251) })
        try original.write(to: source)

        let output = try await staging.decodeToCanonicalWAV(
            stagedSourceURL: source,
            decoder: L2AW33Decoder(mode: .valid),
            fileManager: fileManager
        )
        try IOCanonicalWAVValidator.validate(url: output, fileManager: fileManager)
        let reread = try Data(contentsOf: source)
        precondition(reread == original)
        try fileManager.removeItem(at: output)

        var invalidRejected = false
        do {
            _ = try await staging.decodeToCanonicalWAV(
                stagedSourceURL: source,
                decoder: L2AW33Decoder(mode: .invalidContainer),
                fileManager: fileManager
            )
        } catch {
            invalidRejected = true
        }
        precondition(invalidRejected)

        try original.write(to: source)
        var mutationRejected = false
        do {
            _ = try await staging.decodeToCanonicalWAV(
                stagedSourceURL: source,
                decoder: L2AW33Decoder(mode: .mutateSource),
                fileManager: fileManager
            )
        } catch {
            mutationRejected = true
        }
        precondition(mutationRejected)

        let compressed = root.appendingPathComponent("compressed.wav")
        try l2aw33MakeWAV(formatTag: 6).write(to: compressed)
        var compressedRejected = false
        do {
            try IOCanonicalWAVValidator.validate(url: compressed, fileManager: fileManager)
        } catch {
            compressedRejected = true
        }
        precondition(compressedRejected)

        print(
            "L2_AW33_SELF_TEST_PASS scenarios=4 valid_pcm=true invalid_container_rejected=true source_mutation_rejected=true compressed_wav_rejected=true"
        )
    }
}

private func l2aw33MakeWAV(formatTag: UInt16) -> Data {
    let sampleRate: UInt32 = 44_100
    let channels: UInt16 = 1
    let bits: UInt16 = 16
    let blockAlign = channels * (bits / 8)
    let byteRate = sampleRate * UInt32(blockAlign)
    let pcm = Data(repeating: 0, count: 32)
    var data = Data()
    data.l2aw33AppendASCII("RIFF")
    data.l2aw33AppendLE(UInt32(36 + pcm.count))
    data.l2aw33AppendASCII("WAVE")
    data.l2aw33AppendASCII("fmt ")
    data.l2aw33AppendLE(UInt32(16))
    data.l2aw33AppendLE(formatTag)
    data.l2aw33AppendLE(channels)
    data.l2aw33AppendLE(sampleRate)
    data.l2aw33AppendLE(byteRate)
    data.l2aw33AppendLE(blockAlign)
    data.l2aw33AppendLE(bits)
    data.l2aw33AppendASCII("data")
    data.l2aw33AppendLE(UInt32(pcm.count))
    data.append(pcm)
    return data
}

private extension Data {
    mutating func l2aw33AppendASCII(_ string: String) {
        append(contentsOf: string.utf8)
    }

    mutating func l2aw33AppendLE(_ value: UInt16) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
    }

    mutating func l2aw33AppendLE(_ value: UInt32) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 24) & 0xff))
    }
}
