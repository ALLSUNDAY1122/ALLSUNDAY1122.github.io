import Foundation
import XCTest
#if canImport(MoisesAudioIO)
@testable import MoisesAudioIO
#endif

#if canImport(AVFoundation)
final class IOSAudioIOServiceExternalImportTests: XCTestCase {
    func testDirectExternalWAVBecomesAppOwnedImportAndLeavesNoStagingArtifact() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("l2-aw06-ios-\(UUID().uuidString)", isDirectory: true)
        let external = root.deletingLastPathComponent()
            .appendingPathComponent("external-\(UUID().uuidString).wav")
        try minimalPCM16WAV().write(to: external, options: .atomic)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }

        let service = try IOSAudioIOService(
            configuration: .init(rootURL: root, storageReserveBytes: 0),
            exportSourceProvider: EmptyExportSourceProvider()
        )
        let asset = try await service.importExternalFile(at: external, accessMode: .direct)

        XCTAssertTrue(asset.relativePath.hasPrefix("Imports/"))
        XCTAssertEqual(asset.mediaKind, .audio)
        XCTAssertNotNil(asset.durationSeconds)
        let staging = root.appendingPathComponent("Staging", isDirectory: true)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: staging.path), [])
    }

    func testEmptyExternalFileFailsBeforeLibraryVisibility() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("l2-aw06-ios-empty-\(UUID().uuidString)", isDirectory: true)
        let external = root.deletingLastPathComponent()
            .appendingPathComponent("external-empty-\(UUID().uuidString).wav")
        try Data().write(to: external, options: .atomic)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }

        let service = try IOSAudioIOService(
            configuration: .init(rootURL: root, storageReserveBytes: 0),
            exportSourceProvider: EmptyExportSourceProvider()
        )
        do {
            _ = try await service.importExternalFile(at: external, accessMode: .direct)
            XCTFail("expected corruptMedia")
        } catch let failure as DomainFailure {
            XCTAssertEqual(failure, .corruptMedia)
        }
    }

    private struct EmptyExportSourceProvider: IOExportSourceProviding {
        func sources(for request: ExportRequest) async throws -> [IOExportSource] { [] }
    }

    private func minimalPCM16WAV() -> Data {
        let samples: [Int16] = [0, 1200, -1200, 0, 600, -600, 0, 0]
        let sampleRate: UInt32 = 8_000
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let blockAlign = channels * (bitsPerSample / 8)
        let byteRate = sampleRate * UInt32(blockAlign)
        let dataBytes = UInt32(samples.count * MemoryLayout<Int16>.size)

        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        appendLE(UInt32(36) + dataBytes, to: &data)
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        appendLE(UInt32(16), to: &data)
        appendLE(UInt16(1), to: &data)
        appendLE(channels, to: &data)
        appendLE(sampleRate, to: &data)
        appendLE(byteRate, to: &data)
        appendLE(blockAlign, to: &data)
        appendLE(bitsPerSample, to: &data)
        data.append(contentsOf: Array("data".utf8))
        appendLE(dataBytes, to: &data)
        for sample in samples { appendLE(UInt16(bitPattern: sample), to: &data) }
        return data
    }

    private func appendLE(_ value: UInt16, to data: inout Data) {
        data.append(UInt8(truncatingIfNeeded: value))
        data.append(UInt8(truncatingIfNeeded: value >> 8))
    }

    private func appendLE(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(truncatingIfNeeded: value))
        data.append(UInt8(truncatingIfNeeded: value >> 8))
        data.append(UInt8(truncatingIfNeeded: value >> 16))
        data.append(UInt8(truncatingIfNeeded: value >> 24))
    }
}
#endif
