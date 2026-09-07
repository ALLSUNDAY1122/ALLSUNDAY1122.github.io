import Foundation
import XCTest

final class IOCompatibilityDecodeBoundaryTests: XCTestCase {
    func testValidPCMOutputPassesAndSourceIsPreserved() async throws {
        try await withRoot { root, fileStore in
            let source = try stagedSource(root: root, fileStore: fileStore)
            let original = try Data(contentsOf: source)
            let staging = IOCompatibilityDecodeStaging(fileStore: fileStore)
            let output = try await staging.decodeToCanonicalWAV(
                stagedSourceURL: source,
                decoder: StubDecoder(mode: .validPCM)
            )
            XCTAssertEqual(try Data(contentsOf: source), original)
            XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
            XCTAssertNoThrow(try IOCanonicalWAVValidator.validate(url: output))
        }
    }

    func testNonWAVOutputFailsClosedAndIsRemoved() async throws {
        try await withRoot { root, fileStore in
            let source = try stagedSource(root: root, fileStore: fileStore)
            let staging = IOCompatibilityDecodeStaging(fileStore: fileStore)
            do {
                _ = try await staging.decodeToCanonicalWAV(
                    stagedSourceURL: source,
                    decoder: StubDecoder(mode: .nonWAV)
                )
                XCTFail("expected decoder failure")
            } catch let error as IOCompatibilityDecodeStagingError {
                XCTAssertEqual(error, .decoderFailed)
            }
            let wavs = try FileManager.default.contentsOfDirectory(
                at: fileStore.stagingURL,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "wav" }
            XCTAssertEqual(wavs.count, 0)
        }
    }

    func testDecoderSourceMutationFailsClosed() async throws {
        try await withRoot { root, fileStore in
            let source = try stagedSource(root: root, fileStore: fileStore)
            let staging = IOCompatibilityDecodeStaging(fileStore: fileStore)
            do {
                _ = try await staging.decodeToCanonicalWAV(
                    stagedSourceURL: source,
                    decoder: StubDecoder(mode: .mutateSource)
                )
                XCTFail("expected decoder failure")
            } catch let error as IOCompatibilityDecodeStagingError {
                XCTAssertEqual(error, .decoderFailed)
            }
        }
    }

    func testCompressedWAVFormatTagIsRejected() throws {
        try withTemporaryFile(data: makeTestWAV(formatTag: 6)) { url in
            XCTAssertThrowsError(try IOCanonicalWAVValidator.validate(url: url)) { error in
                XCTAssertEqual(error as? IOCanonicalWAVValidationError, .unsupportedFormat)
            }
        }
    }

    private enum DecoderMode: Sendable {
        case validPCM
        case nonWAV
        case mutateSource
    }

    private struct StubDecoder: IOCompatibilityAudioDecoding {
        let mode: DecoderMode

        func decodeToCanonicalWAV(sourceURL: URL, destinationURL: URL) async throws {
            switch mode {
            case .validPCM:
                try makeTestWAV(formatTag: 1).write(to: destinationURL)
            case .nonWAV:
                try Data("not-wave".utf8).write(to: destinationURL)
            case .mutateSource:
                try makeTestWAV(formatTag: 1).write(to: destinationURL)
                let handle = try FileHandle(forWritingTo: sourceURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: Data([0x7f]))
                try handle.close()
            }
        }
    }

    private func stagedSource(root: URL, fileStore: IOFileStore) throws -> URL {
        try fileStore.prepareDirectories()
        let source = fileStore.stagingURL.appendingPathComponent("source.wma")
        try Data((0..<1024).map { UInt8($0 % 251) }).write(to: source)
        return source
    }

    private func withRoot(
        _ body: (URL, IOFileStore) async throws -> Void
    ) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "AW33-" + UUID().uuidString,
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try await body(root, IOFileStore(rootURL: root))
    }

    private func withTemporaryFile(data: Data, _ body: (URL) throws -> Void) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "AW33-WAV-" + UUID().uuidString + ".wav"
        )
        defer { try? FileManager.default.removeItem(at: url) }
        try data.write(to: url)
        try body(url)
    }
}

private func makeTestWAV(formatTag: UInt16) -> Data {
    let sampleRate: UInt32 = 44_100
    let channels: UInt16 = 1
    let bits: UInt16 = 16
    let blockAlign = channels * (bits / 8)
    let byteRate = sampleRate * UInt32(blockAlign)
    let pcm = Data(repeating: 0, count: 32)
    var data = Data()
    data.appendASCII("RIFF")
    data.appendLE(UInt32(36 + pcm.count))
    data.appendASCII("WAVE")
    data.appendASCII("fmt ")
    data.appendLE(UInt32(16))
    data.appendLE(formatTag)
    data.appendLE(channels)
    data.appendLE(sampleRate)
    data.appendLE(byteRate)
    data.appendLE(blockAlign)
    data.appendLE(bits)
    data.appendASCII("data")
    data.appendLE(UInt32(pcm.count))
    data.append(pcm)
    return data
}

private extension Data {
    mutating func appendASCII(_ string: String) {
        append(contentsOf: string.utf8)
    }

    mutating func appendLE(_ value: UInt16) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
    }

    mutating func appendLE(_ value: UInt32) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 24) & 0xff))
    }
}
