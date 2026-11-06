import Foundation
import XCTest

private actor AW15RecordingImporter: AudioImporting {
    let rootURL: URL
    var observedRelativePath: String?
    var observedBytes: Data?
    var shouldFail = false

    init(rootURL: URL, shouldFail: Bool = false) {
        self.rootURL = rootURL
        self.shouldFail = shouldFail
    }

    func importAudio(from request: ImportRequest) async throws -> LocalAudioAsset {
        guard case .appOwnedFile(let relativePath) = request else {
            throw DomainFailure.processingFailed(code: "WRONG_ROUTE", retryable: false)
        }
        observedRelativePath = relativePath
        observedBytes = try Data(contentsOf: rootURL.appendingPathComponent(relativePath))
        if shouldFail { throw DomainFailure.corruptMedia }
        return LocalAudioAsset()
    }
}

final class IOProviderSnapshotAudioImporterTests: XCTestCase {
    func testWrapperHandsAppOwnedSnapshotToBaseAndCleansLease() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("AW15-wrap-" + UUID().uuidString, isDirectory: true)
        let root = base.appendingPathComponent("app", isDirectory: true)
        let external = base.appendingPathComponent("provider", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let source = external.appendingPathComponent("clip.wma")
        let expected = Data([9,8,7,6,5,4])
        try expected.write(to: source)

        let recorder = AW15RecordingImporter(rootURL: root)
        let wrapper = IOProviderSnapshotAudioImporter(
            baseImporter: recorder,
            rootURL: root,
            maximumFileBytes: 1024,
            storageReserveBytes: 0,
            chunkBytes: 2
        )
        _ = try await wrapper.importExternalFile(at: source, accessMode: .direct)
        let observed = await recorder.observedBytes
        XCTAssertEqual(observed, expected)
        let staging = root.appendingPathComponent("Staging", isDirectory: true)
        let names = try FileManager.default.contentsOfDirectory(atPath: staging.path)
        XCTAssertTrue(names.isEmpty, "wrapper must remove the handoff staging snapshot")
    }

    func testWrapperCleansSnapshotWhenBaseImporterFails() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("AW15-fail-" + UUID().uuidString, isDirectory: true)
        let root = base.appendingPathComponent("app", isDirectory: true)
        let external = base.appendingPathComponent("provider", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let source = external.appendingPathComponent("bad.mp3")
        try Data([1,2,3]).write(to: source)
        let recorder = AW15RecordingImporter(rootURL: root, shouldFail: true)
        let wrapper = IOProviderSnapshotAudioImporter(
            baseImporter: recorder,
            rootURL: root,
            maximumFileBytes: 1024,
            storageReserveBytes: 0,
            chunkBytes: 2
        )
        do {
            _ = try await wrapper.importExternalFile(at: source, accessMode: .direct)
            XCTFail("expected failure")
        } catch {}
        let staging = root.appendingPathComponent("Staging", isDirectory: true)
        let names = try FileManager.default.contentsOfDirectory(atPath: staging.path)
        XCTAssertTrue(names.isEmpty)
    }
}
