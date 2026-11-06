import Foundation
import XCTest

final class IOBoundedRemoteAudioImporterTests: XCTestCase {
    func testDirectDownloadHandsOnlyCompletedAppOwnedStageToBaseAndCleansHandoff() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let staged = root.appendingPathComponent("Staging/remote.mp3")
        try FileManager.default.createDirectory(at: staged.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("audio".utf8).write(to: staged)
        let downloader = FakeDownloader(result: .success(.init(stagingURL: staged, preferredName: "remote", byteCount: 5)))
        let base = FakeBaseImporter()
        let importer = IOBoundedRemoteAudioImporter(rootURL: root, baseImporter: base, downloader: downloader)

        let asset = try await importer.importAudio(from: .directDownloadURL(URL(string: "https://example.com/remote.mp3")!))
        XCTAssertEqual(asset.relativePath, "Imports/final.mp3")
        let requests = await base.requests
        XCTAssertEqual(requests, [.appOwnedFile(relativePath: "Staging/remote.mp3")])
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.path))
    }

    func testAppOwnedRequestBypassesDownloader() async throws {
        let root = makeRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let downloader = FakeDownloader(result: .failure(IODirectDownloadFailure.invalidResponse))
        let base = FakeBaseImporter()
        let importer = IOBoundedRemoteAudioImporter(rootURL: root, baseImporter: base, downloader: downloader)
        _ = try await importer.importAudio(from: .appOwnedFile(relativePath: "Imports/existing.mp3"))
        let calls = await downloader.callCount
        let requests = await base.requests
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(requests, [.appOwnedFile(relativePath: "Imports/existing.mp3")])
    }

    func testPolicyFailureMapsToStableDomainFailure() async throws {
        let root = makeRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let downloader = FakeDownloader(result: .failure(IODirectDownloadFailure.streamedTooLarge(2049)))
        let importer = IOBoundedRemoteAudioImporter(rootURL: root, baseImporter: FakeBaseImporter(), downloader: downloader)
        do {
            _ = try await importer.importAudio(from: .directDownloadURL(URL(string: "https://example.com/a")!))
            XCTFail("Expected failure")
        } catch let failure as DomainFailure {
            XCTAssertEqual(failure, .processingFailed(code: "REMOTE_FILE_TOO_LARGE", retryable: false))
        }
    }

    private func makeRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("AW14Tests-" + UUID().uuidString, isDirectory: true)
    }
}

private actor FakeDownloader: IODirectDownloading {
    private let result: Result<IODirectDownloadAcquiredFile, Error>
    private(set) var callCount = 0
    init(result: Result<IODirectDownloadAcquiredFile, Error>) { self.result = result }
    func download(from url: URL) async throws -> IODirectDownloadAcquiredFile {
        callCount += 1
        return try result.get()
    }
}

private actor FakeBaseImporter: AudioImporting {
    private(set) var requests: [ImportRequest] = []
    func importAudio(from request: ImportRequest) async throws -> LocalAudioAsset {
        requests.append(request)
        return LocalAudioAsset(id: AssetID(), relativePath: "Imports/final.mp3", mediaKind: .audio, durationSeconds: 1)
    }
}
