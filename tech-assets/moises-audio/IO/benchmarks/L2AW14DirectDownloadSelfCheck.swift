import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private actor SelfCheckDownloader: IODirectDownloading {
    let result: Result<IODirectDownloadAcquiredFile, Error>
    private(set) var calls = 0
    init(_ result: Result<IODirectDownloadAcquiredFile, Error>) { self.result = result }
    func download(from url: URL) async throws -> IODirectDownloadAcquiredFile {
        calls += 1
        return try result.get()
    }
}

private actor SelfCheckBaseImporter: AudioImporting {
    private(set) var requests: [ImportRequest] = []
    func importAudio(from request: ImportRequest) async throws -> LocalAudioAsset {
        requests.append(request)
        return LocalAudioAsset(id: AssetID(), relativePath: "Imports/final.mp3", mediaKind: .audio, durationSeconds: 1)
    }
}

@main
struct L2AW14DirectDownloadSelfCheck {
    static func main() async throws {
        var scenarios = 0
        func expect(_ value: @autoclosure () -> Bool, _ message: String) throws {
            if !value() { throw NSError(domain: "L2AW14", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        func response(_ url: URL, _ status: Int, _ mime: String, _ length: Int64) -> HTTPURLResponse {
            HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": mime, "Content-Length": String(length)])!
        }
        let p = IODirectDownloadPolicy(maximumBytes: 1024, maximumRedirects: 2)
        try p.validateURL(URL(string: "https://media.example.com/a.mp3")!)
        for raw in ["https://localhost/a", "https://127.0.0.1/a", "https://10.0.0.1/a", "https://192.168.1.1/a", "https://[::1]/a"] {
            do { try p.validateURL(URL(string: raw)!); throw NSError(domain: "L2AW14", code: 2) }
            catch IODirectDownloadFailure.localNetworkHost { }
        }
        scenarios += 1

        do {
            try p.validateRedirect(from: URL(string: "https://a.example/x")!, to: URL(string: "http://a.example/x")!, redirectCount: 1)
            throw NSError(domain: "L2AW14", code: 3)
        } catch IODirectDownloadFailure.insecureRedirect { }
        do {
            try p.validateRedirect(from: URL(string: "https://a.example/x")!, to: URL(string: "https://b.example/x")!, redirectCount: 3)
            throw NSError(domain: "L2AW14", code: 4)
        } catch IODirectDownloadFailure.redirectLimitExceeded { }
        scenarios += 1

        let u = URL(string: "https://example.com/a")!
        do { try p.validateResponse(response(u, 429, "audio/mpeg", 100)); throw NSError(domain: "L2AW14", code: 5) }
        catch IODirectDownloadFailure.httpStatus(let status, let retryable) { try expect(status == 429 && retryable, "429 classification") }
        do { try p.validateResponse(response(u, 404, "audio/mpeg", 100)); throw NSError(domain: "L2AW14", code: 6) }
        catch IODirectDownloadFailure.httpStatus(let status, let retryable) { try expect(status == 404 && !retryable, "404 classification") }
        scenarios += 1

        do { try p.validateResponse(response(u, 206, "audio/mpeg", 100)); throw NSError(domain: "L2AW14", code: 7) }
        catch IODirectDownloadFailure.partialContent { }
        for mime in ["text/html", "application/json", "application/vnd.apple.mpegurl", "application/dash+xml"] {
            do { try p.validateResponse(response(u, 200, mime, 100)); throw NSError(domain: "L2AW14", code: 8) }
            catch IODirectDownloadFailure.nonDirectMedia { }
        }
        scenarios += 1

        do { try p.validateResponse(response(u, 200, "audio/mpeg", 1025)); throw NSError(domain: "L2AW14", code: 9) }
        catch IODirectDownloadFailure.responseTooLarge { }
        try p.validateResponse(response(u, 200, "audio/mpeg", -1))
        try p.validateProgress(totalBytesWritten: 1024)
        do { try p.validateProgress(totalBytesWritten: 1025); throw NSError(domain: "L2AW14", code: 10) }
        catch IODirectDownloadFailure.streamedTooLarge { }
        scenarios += 1

        let finalURL = URL(string: "https://cdn.example.com/object")!
        let metadata = HTTPURLResponse(url: finalURL, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "audio/flac", "Content-Disposition": "attachment; filename=\"Track Name.flac\""])!
        try expect(p.preferredExtension(response: metadata, originalURL: URL(string: "https://example.com/download?id=1")!) == "flac", "extension")
        try expect(p.preferredFilenameStem(response: metadata, originalURL: u) == "Track Name", "name")
        scenarios += 1

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AW14-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let staged = root.appendingPathComponent("Staging/remote.mp3")
        try FileManager.default.createDirectory(at: staged.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("audio".utf8).write(to: staged)
        let fakeDownload = SelfCheckDownloader(.success(.init(stagingURL: staged, preferredName: "remote", byteCount: 5)))
        let base = SelfCheckBaseImporter()
        let wrapper = IOBoundedRemoteAudioImporter(rootURL: root, baseImporter: base, downloader: fakeDownload)
        _ = try await wrapper.importAudio(from: .directDownloadURL(URL(string: "https://example.com/remote.mp3")!))
        let baseRequests = await base.requests
        try expect(baseRequests == [.appOwnedFile(relativePath: "Staging/remote.mp3")], "handoff")
        try expect(!FileManager.default.fileExists(atPath: staged.path), "handoff staging cleanup")
        scenarios += 1

        let bypassDownloader = SelfCheckDownloader(.failure(IODirectDownloadFailure.invalidResponse))
        let bypassBase = SelfCheckBaseImporter()
        let bypass = IOBoundedRemoteAudioImporter(rootURL: root, baseImporter: bypassBase, downloader: bypassDownloader)
        _ = try await bypass.importAudio(from: .appOwnedFile(relativePath: "Imports/existing.mp3"))
        let bypassCalls = await bypassDownloader.calls
        try expect(bypassCalls == 0, "app-owned bypass")
        scenarios += 1

        let failDownloader = SelfCheckDownloader(.failure(IODirectDownloadFailure.streamedTooLarge(2049)))
        let failWrapper = IOBoundedRemoteAudioImporter(rootURL: root, baseImporter: SelfCheckBaseImporter(), downloader: failDownloader)
        do {
            _ = try await failWrapper.importAudio(from: .directDownloadURL(u))
            throw NSError(domain: "L2AW14", code: 11)
        } catch let failure as DomainFailure {
            try expect(failure == .processingFailed(code: "REMOTE_FILE_TOO_LARGE", retryable: false), "mapping")
        }
        scenarios += 1

        let iterations = 100_000
        let start = Date()
        for i in 0..<iterations {
            let url = URL(string: "https://cdn.example.com/audio/\(i).mp3")!
            try p.validateURL(url)
            try p.validateProgress(totalBytesWritten: Int64(i % 1025))
        }
        let elapsed = Date().timeIntervalSince(start)
        scenarios += 1
        let elapsedText = String(format: "%.6f", elapsed)
        print("L2_AW14_SELF_TEST_PASS scenarios=\(scenarios) policy_iterations=\(iterations) elapsed_seconds=\(elapsedText)")
    }
}
