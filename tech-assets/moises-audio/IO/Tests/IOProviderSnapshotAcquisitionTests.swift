import Foundation
import XCTest

final class IOProviderSnapshotAcquisitionTests: XCTestCase {
    func testStableDirectFilePublishesVerifiedReadyStaging() throws {
        try withRoot { root, external in
            let source = external.appendingPathComponent("song.flac")
            let bytes = Data((0..<4096).map { UInt8($0 % 251) })
            try bytes.write(to: source)
            let store = IOFileStore(rootURL: root)
            let acquirer = IOProviderSnapshotAcquirer(
                fileStore: store,
                maximumFileBytes: 1_000_000,
                storageReserveBytes: 0,
                chunkBytes: 257
            )
            let staged = try acquirer.stageProviderFile(at: source, accessMode: .direct)
            XCTAssertEqual(staged.descriptor.byteCount, Int64(bytes.count))
            XCTAssertEqual(staged.descriptor.pathExtension, "flac")
            XCTAssertEqual(try Data(contentsOf: staged.stagingURL), bytes)
            XCTAssertFalse(staged.stagingURL.lastPathComponent.contains("provider-partial"))
            let siblings = try FileManager.default.contentsOfDirectory(atPath: store.stagingURL.path)
            XCTAssertFalse(siblings.contains { $0.hasSuffix(".provider-partial") })
        }
    }

    func testSameSizeDifferentFingerprintFailsCoherencePolicy() throws {
        let copied = IOProviderContentFingerprint(byteCount: 4, hashA: 1, hashB: 2)
        let changed = IOProviderContentFingerprint(byteCount: 4, hashA: 3, hashB: 4)
        XCTAssertThrowsError(
            try IOProviderSnapshotAcquirer.requireCoherentSnapshot(
                initialBytes: 4,
                copied: copied,
                sourceAfter: changed
            )
        ) { error in
            XCTAssertEqual(error as? IOProviderSnapshotAcquisitionError, .sourceChangedDuringAcquisition)
        }
    }

    func testInitialSizeDriftFailsEvenIfFinalFingerprintMatchesCopy() throws {
        let final = IOProviderContentFingerprint(byteCount: 5, hashA: 10, hashB: 20)
        XCTAssertThrowsError(
            try IOProviderSnapshotAcquirer.requireCoherentSnapshot(
                initialBytes: 4,
                copied: final,
                sourceAfter: final
            )
        )
    }

    func testEmptyOversizeAndAppRootSourcesFailClosed() throws {
        try withRoot { root, external in
            let store = IOFileStore(rootURL: root)
            let acquirer = IOProviderSnapshotAcquirer(
                fileStore: store,
                maximumFileBytes: 3,
                storageReserveBytes: 0,
                chunkBytes: 2
            )
            let empty = external.appendingPathComponent("empty.wav")
            _ = FileManager.default.createFile(atPath: empty.path, contents: Data())
            XCTAssertThrowsError(try acquirer.stageProviderFile(at: empty, accessMode: .direct))

            let large = external.appendingPathComponent("large.wav")
            try Data([1,2,3,4]).write(to: large)
            XCTAssertThrowsError(try acquirer.stageProviderFile(at: large, accessMode: .direct))

            try store.prepareDirectories()
            let inside = root.appendingPathComponent("inside.wav")
            try Data([1]).write(to: inside)
            XCTAssertThrowsError(try acquirer.stageProviderFile(at: inside, accessMode: .direct))
        }
    }

    private func withRoot(_ body: (URL, URL) throws -> Void) throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("AW15-" + UUID().uuidString, isDirectory: true)
        let root = base.appendingPathComponent("app", isDirectory: true)
        let external = base.appendingPathComponent("provider", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        try body(root, external)
    }
}
