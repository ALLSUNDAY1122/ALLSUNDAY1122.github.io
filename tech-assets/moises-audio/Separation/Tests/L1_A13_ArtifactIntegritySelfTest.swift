import Foundation

private func a13Require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}

private func a13FailureCode(_ error: Error) -> String {
    guard let failure = error as? DomainFailure else { return "NON_DOMAIN" }
    switch failure {
    case .processingFailed(let code, _): return code
    case .networkTimeout: return "NETWORK_TIMEOUT"
    case .networkUnavailable: return "NETWORK_UNAVAILABLE"
    case .cancelled: return "CANCELLED"
    default: return String(describing: failure)
    }
}

private func a13ExpectFailure(_ expected: String, _ body: () throws -> Void) {
    do {
        try body()
        fatalError("expected failure \(expected)")
    } catch {
        a13Require(a13FailureCode(error) == expected, "expected \(expected), got \(a13FailureCode(error))")
    }
}

private func a13U16(_ value: UInt16, _ data: inout Data) {
    data.append(UInt8(value & 0xff)); data.append(UInt8((value >> 8) & 0xff))
}

private func a13U32(_ value: UInt32, _ data: inout Data) {
    data.append(UInt8(value & 0xff)); data.append(UInt8((value >> 8) & 0xff))
    data.append(UInt8((value >> 16) & 0xff)); data.append(UInt8((value >> 24) & 0xff))
}

private func a13Chunk(_ id: String, _ payload: Data) -> Data {
    var result = Data(id.data(using: .ascii)!)
    a13U32(UInt32(payload.count), &result)
    result.append(payload)
    if payload.count % 2 == 1 { result.append(0) }
    return result
}

private func a13PCM16Data(samples: [Int16]) -> Data {
    var result = Data()
    for value in samples { a13U16(UInt16(bitPattern: value), &result) }
    return result
}

private func a13Float32Data(samples: [Float]) -> Data {
    var result = Data()
    for value in samples { a13U32(value.bitPattern, &result) }
    return result
}

private func a13BuildWAV(
    audioFormat: UInt16 = 1,
    sampleRate: Int = 44_100,
    channels: Int = 2,
    bitsPerSample: Int = 16,
    sampleData: Data,
    duplicateFmt: Bool = false,
    duplicateData: Bool = false,
    byteRateOverride: Int? = nil,
    blockAlignOverride: Int? = nil
) -> Data {
    let blockAlign = blockAlignOverride ?? channels * bitsPerSample / 8
    let byteRate = byteRateOverride ?? sampleRate * blockAlign
    var fmt = Data()
    a13U16(audioFormat, &fmt); a13U16(UInt16(channels), &fmt)
    a13U32(UInt32(sampleRate), &fmt); a13U32(UInt32(byteRate), &fmt)
    a13U16(UInt16(blockAlign), &fmt); a13U16(UInt16(bitsPerSample), &fmt)
    var body = a13Chunk("fmt ", fmt)
    if duplicateFmt { body.append(a13Chunk("fmt ", fmt)) }
    body.append(a13Chunk("data", sampleData))
    if duplicateData { body.append(a13Chunk("data", sampleData)) }
    var result = Data("RIFF".data(using: .ascii)!)
    a13U32(UInt32(body.count + 4), &result)
    result.append("WAVE".data(using: .ascii)!)
    result.append(body)
    return result
}

private func a13Write(_ data: Data, root: URL, name: String) throws -> URL {
    let url = root.appendingPathComponent(name)
    try data.write(to: url)
    return url
}

@main private struct L1A13ArtifactIntegritySelfTest {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("l1a13-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var scenarios = 0

        let normalSamples = Array(repeating: Int16(1200), count: 4_410 * 2)
        let valid = try a13Write(a13BuildWAV(sampleData: a13PCM16Data(samples: normalSamples)), root: root, name: "valid.wav")
        let inspected = try WAVInspection.read(url: valid)
        a13Require(inspected.sampleRate == 44_100 && inspected.channels == 2, "valid metadata")
        a13Require(inspected.analyzedSampleCount == Int64(normalSamples.count), "sample count")
        a13Require(inspected.absolutePeak > 0 && inspected.rms > 0, "metrics")
        a13Require(inspected.samplePathologyFlags.isEmpty, "normal audio must not be flagged")
        scenarios += 4

        var truncated = try Data(contentsOf: valid); truncated.removeLast()
        let truncatedURL = try a13Write(truncated, root: root, name: "truncated.wav")
        a13ExpectFailure("SEP_OUTPUT_RIFF_SIZE_MISMATCH") { _ = try WAVInspection.read(url: truncatedURL) }
        scenarios += 1

        var trailing = try Data(contentsOf: valid); trailing.append(contentsOf: [0, 1, 2, 3])
        let trailingURL = try a13Write(trailing, root: root, name: "trailing.wav")
        a13ExpectFailure("SEP_OUTPUT_RIFF_SIZE_MISMATCH") { _ = try WAVInspection.read(url: trailingURL) }
        scenarios += 1

        var invalid = try Data(contentsOf: valid); invalid.replaceSubrange(0..<4, with: Data("NOPE".utf8))
        let invalidURL = try a13Write(invalid, root: root, name: "invalid.wav")
        a13ExpectFailure("SEP_OUTPUT_WAV_INVALID") { _ = try WAVInspection.read(url: invalidURL) }
        scenarios += 1

        let duplicateFmt = try a13Write(a13BuildWAV(sampleData: a13PCM16Data(samples: normalSamples), duplicateFmt: true), root: root, name: "dup-fmt.wav")
        a13ExpectFailure("SEP_OUTPUT_WAV_DUPLICATE_FMT") { _ = try WAVInspection.read(url: duplicateFmt) }
        scenarios += 1

        let duplicateData = try a13Write(a13BuildWAV(sampleData: a13PCM16Data(samples: normalSamples), duplicateData: true), root: root, name: "dup-data.wav")
        a13ExpectFailure("SEP_OUTPUT_WAV_DUPLICATE_DATA") { _ = try WAVInspection.read(url: duplicateData) }
        scenarios += 1

        let badByteRate = try a13Write(a13BuildWAV(sampleData: a13PCM16Data(samples: normalSamples), byteRateOverride: 1), root: root, name: "bad-rate.wav")
        a13ExpectFailure("SEP_OUTPUT_WAV_BYTE_RATE_INVALID") { _ = try WAVInspection.read(url: badByteRate) }
        scenarios += 1

        let badAlign = try a13Write(a13BuildWAV(sampleData: a13PCM16Data(samples: normalSamples), blockAlignOverride: 2), root: root, name: "bad-align.wav")
        a13ExpectFailure("SEP_OUTPUT_WAV_BLOCK_ALIGN_INVALID") { _ = try WAVInspection.read(url: badAlign) }
        scenarios += 1

        let silence = try a13Write(a13BuildWAV(sampleData: a13PCM16Data(samples: Array(repeating: 0, count: 4_410 * 2))), root: root, name: "silence.wav")
        a13Require(try WAVInspection.read(url: silence).samplePathologyFlags.contains("DIGITAL_SILENCE"), "silence flag")
        scenarios += 1

        let clipping = try a13Write(a13BuildWAV(sampleData: a13PCM16Data(samples: Array(repeating: Int16.max, count: 4_410 * 2))), root: root, name: "clipping.wav")
        a13Require(try WAVInspection.read(url: clipping).samplePathologyFlags.contains("PATHOLOGICAL_CLIPPING"), "clipping flag")
        scenarios += 1

        let nan = try a13Write(a13BuildWAV(audioFormat: 3, bitsPerSample: 32, sampleData: a13Float32Data(samples: Array(repeating: Float.nan, count: 4_410 * 2))), root: root, name: "nan.wav")
        a13ExpectFailure("SEP_OUTPUT_WAV_NONFINITE_SAMPLE") { _ = try WAVInspection.read(url: nan) }
        scenarios += 1

        let huge = try a13Write(a13BuildWAV(audioFormat: 3, bitsPerSample: 32, sampleData: a13Float32Data(samples: Array(repeating: 32.0, count: 4_410 * 2))), root: root, name: "huge.wav")
        a13ExpectFailure("SEP_OUTPUT_WAV_FLOAT_SAMPLE_RANGE_INVALID") { _ = try WAVInspection.read(url: huge) }
        scenarios += 1

        let unsupported = try a13Write(a13BuildWAV(audioFormat: 6, sampleData: a13PCM16Data(samples: normalSamples)), root: root, name: "unsupported.wav")
        a13ExpectFailure("SEP_OUTPUT_WAV_CODEC_UNSUPPORTED") { _ = try WAVInspection.read(url: unsupported) }
        scenarios += 1

        let emptyData = try a13Write(a13BuildWAV(sampleData: Data()), root: root, name: "empty.wav")
        a13ExpectFailure("SEP_OUTPUT_EMPTY") { _ = try WAVInspection.read(url: emptyData) }
        scenarios += 1

        let abc = root.appendingPathComponent("abc.bin"); try Data("abc".utf8).write(to: abc)
        a13Require(try SHA256FileHasher.hash(url: abc) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "sha256 vector")
        scenarios += 1

        print("L1_A13_ARTIFACT_INTEGRITY_SELF_TEST_PASS scenarios=\(scenarios)")
    }
}
