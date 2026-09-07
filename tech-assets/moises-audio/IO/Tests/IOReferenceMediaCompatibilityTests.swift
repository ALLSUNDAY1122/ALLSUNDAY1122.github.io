import Foundation
import XCTest
#if canImport(MoisesAudioIO)
@testable import MoisesAudioIO
#endif

final class IOReferenceMediaCompatibilityTests: XCTestCase {
    func testReferenceMatrixAndRoutes() {
        let policy = IOReferenceMediaCompatibilityPolicy()
        for ext in ["mp3", "wav", "flac", "m4a", "mp4", "mov"] {
            XCTAssertTrue(policy.isReferenceExtension(ext))
            XCTAssertEqual(policy.route(forPathExtension: ext), .nativeProbe)
        }
        XCTAssertTrue(policy.isReferenceExtension(".WMA "))
        XCTAssertEqual(policy.route(forPathExtension: ".WMA "), .nativeThenCompatibility)
        XCTAssertFalse(policy.isReferenceExtension("aac"))
        XCTAssertEqual(policy.route(forPathExtension: "aac"), .nativeProbe)
    }

    func testCompatibilityDecodeProducesNonEmptyCanonicalWAV() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let source = try fixture.makeStagedSource(name: "legacy.wma", bytes: [1, 2, 3])
        let output = try await fixture.staging.decodeToCanonicalWAV(
            stagedSourceURL: source,
            decoder: WritingDecoder(bytes: [82, 73, 70, 70])
        )
        XCTAssertEqual(output.pathExtension, "wav")
        XCTAssertEqual(try Data(contentsOf: output), Data([82, 73, 70, 70]))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testUnavailableDecoderFailsClosedWithoutDeletingSource() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let source = try fixture.makeStagedSource(name: "legacy.wma", bytes: [1])
        do {
            _ = try await fixture.staging.decodeToCanonicalWAV(stagedSourceURL: source, decoder: nil)
            XCTFail("expected decoderUnavailable")
        } catch let error as IOCompatibilityDecodeStagingError {
            XCTAssertEqual(error, .decoderUnavailable)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testDecoderFailureAndEmptyOutputAreCleanedUp() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let source = try fixture.makeStagedSource(name: "legacy.wma", bytes: [1])

        do {
            _ = try await fixture.staging.decodeToCanonicalWAV(
                stagedSourceURL: source,
                decoder: ThrowingDecoder()
            )
            XCTFail("expected decoderFailed")
        } catch let error as IOCompatibilityDecodeStagingError {
            XCTAssertEqual(error, .decoderFailed)
        }

        do {
            _ = try await fixture.staging.decodeToCanonicalWAV(
                stagedSourceURL: source,
                decoder: WritingDecoder(bytes: [])
            )
            XCTFail("expected outputEmpty")
        } catch let error as IOCompatibilityDecodeStagingError {
            XCTAssertEqual(error, .outputEmpty)
        }

        let children = try FileManager.default.contentsOfDirectory(
            at: fixture.store.stagingURL,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(children.map(\.lastPathComponent), [source.lastPathComponent])
    }

    private struct WritingDecoder: IOCompatibilityAudioDecoding {
        let bytes: [UInt8]
        func decodeToCanonicalWAV(sourceURL: URL, destinationURL: URL) async throws {
            try Data(bytes).write(to: destinationURL, options: .atomic)
        }
    }

    private struct ThrowingDecoder: IOCompatibilityAudioDecoding {
        struct Failure: Error {}
        func decodeToCanonicalWAV(sourceURL: URL, destinationURL: URL) async throws {
            throw Failure()
        }
    }

    private final class Fixture: @unchecked Sendable {
        let root: URL
        let store: IOFileStore
        let staging: IOCompatibilityDecodeStaging

        init() throws {
            root = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("l2-aw06-\(UUID().uuidString)", isDirectory: true)
            store = IOFileStore(rootURL: root)
            try store.prepareDirectories()
            staging = IOCompatibilityDecodeStaging(fileStore: store)
        }

        func makeStagedSource(name: String, bytes: [UInt8]) throws -> URL {
            let url = store.stagingURL.appendingPathComponent(name)
            try Data(bytes).write(to: url, options: .atomic)
            return url
        }

        func cleanup() {
            try? FileManager.default.removeItem(at: root)
        }
    }
}
