import Foundation
import XCTest

private enum ProbeError: Error { case recoveryRemovedActiveFile, wrongRequest }

private actor RecoveryProbingImporter: AudioImporting {
    let rootURL: URL
    let shouldFail: Bool
    init(rootURL: URL, shouldFail: Bool = false) { self.rootURL = rootURL; self.shouldFail = shouldFail }

    func importAudio(from request: ImportRequest) async throws -> LocalAudioAsset {
        guard case .appOwnedFile(let relativePath) = request else { throw ProbeError.wrongRequest }
        try await Task.sleep(for: .milliseconds(350))
        let store = IOFileStore(rootURL: rootURL)
        let staged = rootURL.appendingPathComponent(relativePath)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-7200)], ofItemAtPath: staged.path)
        let removed = try IOStagingRecovery(fileStore: store).sweep(olderThan: 60)
        if !removed.isEmpty || !FileManager.default.fileExists(atPath: staged.path) {
            throw ProbeError.recoveryRemovedActiveFile
        }
        if shouldFail { throw DomainFailure.corruptMedia }
        return LocalAudioAsset()
    }
}

final class IOProviderSnapshotAudioImporterOwnershipTests: XCTestCase {
    private func makeRootAndSource() throws -> (URL, URL) {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let source = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("wma")
        try Data(repeating: 0x44, count: 64 * 1024).write(to: source)
        return (root, source)
    }

    func testLeaseSurvivesDownstreamValidationAndThenCleansUp() async throws {
        let (root, source) = try makeRootAndSource()
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: source) }
        let importer = IOProviderSnapshotAudioImporter(
            baseImporter: RecoveryProbingImporter(rootURL: root),
            rootURL: root,
            maximumFileBytes: 1024 * 1024,
            storageReserveBytes: 0,
            chunkBytes: 4096,
            ownershipHeartbeatBytes: 8192,
            ownershipLeaseDuration: 0.2,
            ownershipKeepAliveInterval: 0.1
        )
        _ = try await importer.importExternalFile(at: source, accessMode: .direct)
        let staging = root.appendingPathComponent("Staging", isDirectory: true)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: staging.path), [])
    }

    func testDownstreamFailureStillReleasesLeaseAndStaging() async throws {
        let (root, source) = try makeRootAndSource()
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: source) }
        let importer = IOProviderSnapshotAudioImporter(
            baseImporter: RecoveryProbingImporter(rootURL: root, shouldFail: true),
            rootURL: root,
            maximumFileBytes: 1024 * 1024,
            storageReserveBytes: 0,
            ownershipLeaseDuration: 0.2,
            ownershipKeepAliveInterval: 0.1
        )
        do {
            _ = try await importer.importExternalFile(at: source, accessMode: .direct)
            XCTFail("expected failure")
        } catch DomainFailure.corruptMedia {
            // expected
        }
        let staging = root.appendingPathComponent("Staging", isDirectory: true)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: staging.path), [])
    }
}
