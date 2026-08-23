import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest

final class IODirectDownloadAcquisitionTests: XCTestCase {
    func testRejectsUnsupportedCredentialedAndLocalURLs() throws {
        let policy = IODirectDownloadPolicy(maximumBytes: 1024)
        XCTAssertThrowsError(try policy.validateURL(URL(string: "ftp://example.com/a.mp3")!))
        XCTAssertThrowsError(try policy.validateURL(URL(string: "https://user:pass@example.com/a.mp3")!))
        for raw in [
            "https://localhost/a.mp3",
            "https://127.0.0.1/a.mp3",
            "https://10.0.0.1/a.mp3",
            "https://169.254.1.1/a.mp3",
            "https://172.16.0.1/a.mp3",
            "https://192.168.1.1/a.mp3",
            "https://[::1]/a.mp3"
        ] {
            XCTAssertThrowsError(try policy.validateURL(URL(string: raw)!))
        }
        XCTAssertNoThrow(try policy.validateURL(URL(string: "https://media.example.com/a.mp3")!))
    }

    func testRedirectPolicyRejectsDowngradePrivateAndLimit() throws {
        let policy = IODirectDownloadPolicy(maximumBytes: 1024, maximumRedirects: 2)
        let https = URL(string: "https://example.com/a")!
        XCTAssertThrowsError(try policy.validateRedirect(from: https, to: URL(string: "http://example.com/a")!, redirectCount: 1))
        XCTAssertThrowsError(try policy.validateRedirect(from: https, to: URL(string: "https://127.0.0.1/a")!, redirectCount: 1))
        XCTAssertThrowsError(try policy.validateRedirect(from: https, to: URL(string: "https://cdn.example.com/a")!, redirectCount: 3))
        XCTAssertNoThrow(try policy.validateRedirect(from: https, to: URL(string: "https://cdn.example.com/a")!, redirectCount: 2))
    }

    func testStatusRetryabilityAndPartialResponse() throws {
        let policy = IODirectDownloadPolicy(maximumBytes: 1024)
        let url = URL(string: "https://example.com/a")!
        XCTAssertThrowsError(try policy.validateResponse(response(url, 429, "audio/mpeg", 100))) { error in
            XCTAssertEqual(error as? IODirectDownloadFailure, .httpStatus(429, retryable: true))
        }
        XCTAssertThrowsError(try policy.validateResponse(response(url, 404, "audio/mpeg", 100))) { error in
            XCTAssertEqual(error as? IODirectDownloadFailure, .httpStatus(404, retryable: false))
        }
        XCTAssertThrowsError(try policy.validateResponse(response(url, 206, "audio/mpeg", 100))) { error in
            XCTAssertEqual(error as? IODirectDownloadFailure, .partialContent)
        }
    }

    func testRejectsClearlyNonMediaPayloads() throws {
        let policy = IODirectDownloadPolicy(maximumBytes: 1024)
        let url = URL(string: "https://example.com/a")!
        for mime in ["text/html", "text/plain", "application/json", "application/problem+json", "application/xml", "application/vnd.apple.mpegurl", "application/dash+xml"] {
            XCTAssertThrowsError(try policy.validateResponse(response(url, 200, mime, 100)))
        }
        XCTAssertNoThrow(try policy.validateResponse(response(url, 200, "application/octet-stream", 100)))
        XCTAssertNoThrow(try policy.validateResponse(response(url, 200, "audio/flac", 100)))
    }

    func testHeaderAndStreamingCapsBothEnforced() throws {
        let policy = IODirectDownloadPolicy(maximumBytes: 1024)
        let url = URL(string: "https://example.com/a")!
        XCTAssertThrowsError(try policy.validateResponse(response(url, 200, "audio/mpeg", 1025)))
        XCTAssertNoThrow(try policy.validateResponse(response(url, 200, "audio/mpeg", -1)))
        XCTAssertNoThrow(try policy.validateProgress(totalBytesWritten: 1024))
        XCTAssertThrowsError(try policy.validateProgress(totalBytesWritten: 1025))
        XCTAssertThrowsError(try policy.validateCompletedFile(byteCount: 0))
    }

    func testFilenameAndExtensionPreferFinalResponseMetadata() throws {
        let policy = IODirectDownloadPolicy(maximumBytes: 1024)
        let original = URL(string: "https://example.com/download?id=1")!
        let final = URL(string: "https://cdn.example.com/object")!
        let response = HTTPURLResponse(
            url: final,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "audio/flac",
                "Content-Disposition": "attachment; filename=\"Track Name.flac\""
            ]
        )!
        XCTAssertEqual(policy.preferredExtension(response: response, originalURL: original), "flac")
        XCTAssertEqual(policy.preferredFilenameStem(response: response, originalURL: original), "Track Name")
    }

    private func response(_ url: URL, _ status: Int, _ mime: String, _ length: Int64) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": mime, "Content-Length": String(length)]
        )!
    }
}
