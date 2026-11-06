import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum IODirectDownloadFailure: Error, Equatable, Sendable {
    case unsupportedScheme(String?)
    case missingHost
    case credentialsInURL
    case localNetworkHost(String)
    case redirectLimitExceeded(Int)
    case insecureRedirect
    case invalidResponse
    case httpStatus(Int, retryable: Bool)
    case partialContent
    case responseTooLarge(Int64)
    case streamedTooLarge(Int64)
    case nonDirectMedia(String)
    case emptyDownload
}

public struct IODirectDownloadPolicy: Sendable {
    public let maximumBytes: Int64
    public let maximumRedirects: Int
    public let rejectLocalNetworkHosts: Bool

    public init(
        maximumBytes: Int64,
        maximumRedirects: Int = 5,
        rejectLocalNetworkHosts: Bool = true
    ) {
        self.maximumBytes = max(1, maximumBytes)
        self.maximumRedirects = max(0, maximumRedirects)
        self.rejectLocalNetworkHosts = rejectLocalNetworkHosts
    }

    public func validateURL(_ url: URL) throws {
        let scheme = url.scheme?.lowercased()
        guard scheme == "https" || scheme == "http" else {
            throw IODirectDownloadFailure.unsupportedScheme(scheme)
        }
        guard let host = url.host?.lowercased(), !host.isEmpty else {
            throw IODirectDownloadFailure.missingHost
        }
        guard url.user == nil, url.password == nil else {
            throw IODirectDownloadFailure.credentialsInURL
        }
        if rejectLocalNetworkHosts && Self.isLocalNetworkHost(host) {
            throw IODirectDownloadFailure.localNetworkHost(host)
        }
    }

    public func validateRedirect(from source: URL, to destination: URL, redirectCount: Int) throws {
        guard redirectCount <= maximumRedirects else {
            throw IODirectDownloadFailure.redirectLimitExceeded(maximumRedirects)
        }
        try validateURL(destination)
        if source.scheme?.lowercased() == "https", destination.scheme?.lowercased() == "http" {
            throw IODirectDownloadFailure.insecureRedirect
        }
    }

    public func validateResponse(_ response: HTTPURLResponse) throws {
        guard (200..<300).contains(response.statusCode) else {
            let status = response.statusCode
            let retryable = status == 408 || status == 425 || status == 429 || status >= 500
            throw IODirectDownloadFailure.httpStatus(status, retryable: retryable)
        }
        if response.statusCode == 206 {
            throw IODirectDownloadFailure.partialContent
        }
        let expected = response.expectedContentLength
        if expected > maximumBytes {
            throw IODirectDownloadFailure.responseTooLarge(expected)
        }
        if let mime = response.mimeType?.lowercased(), Self.isClearlyNonMedia(mime) {
            throw IODirectDownloadFailure.nonDirectMedia(mime)
        }
    }

    public func validateProgress(totalBytesWritten: Int64) throws {
        if totalBytesWritten > maximumBytes {
            throw IODirectDownloadFailure.streamedTooLarge(totalBytesWritten)
        }
    }

    public func validateCompletedFile(byteCount: Int64) throws {
        guard byteCount > 0 else { throw IODirectDownloadFailure.emptyDownload }
        if byteCount > maximumBytes {
            throw IODirectDownloadFailure.streamedTooLarge(byteCount)
        }
    }

    public func preferredExtension(response: URLResponse, originalURL: URL) -> String? {
        let candidates: [String?] = [
            response.suggestedFilename.flatMap { URL(fileURLWithPath: $0).pathExtension.nonEmpty },
            response.url?.pathExtension.nonEmpty,
            originalURL.pathExtension.nonEmpty,
            Self.extensionForMIME(response.mimeType)
        ]
        for candidate in candidates {
            if let value = candidate?.lowercased(), Self.isSafeExtension(value) {
                return value
            }
        }
        return nil
    }

    public func preferredFilenameStem(response: URLResponse, originalURL: URL) -> String {
        if let suggested = response.suggestedFilename, !suggested.isEmpty {
            let name = URL(fileURLWithPath: suggested).deletingPathExtension().lastPathComponent
            if !name.isEmpty { return name }
        }
        if let finalURL = response.url {
            let name = finalURL.deletingPathExtension().lastPathComponent
            if !name.isEmpty { return name }
        }
        let original = originalURL.deletingPathExtension().lastPathComponent
        return original.isEmpty ? "audio" : original
    }

    private static func isClearlyNonMedia(_ mime: String) -> Bool {
        if mime.hasPrefix("text/") { return true }
        return mime == "application/json"
            || mime.hasSuffix("+json")
            || mime == "application/xml"
            || mime.hasSuffix("+xml")
            || mime.contains("mpegurl")
            || mime == "application/dash+xml"
    }

    private static func extensionForMIME(_ mime: String?) -> String? {
        switch mime?.lowercased() {
        case "audio/mpeg", "audio/mp3": return "mp3"
        case "audio/wav", "audio/x-wav", "audio/wave": return "wav"
        case "audio/flac", "audio/x-flac": return "flac"
        case "audio/mp4", "audio/m4a", "audio/x-m4a": return "m4a"
        case "video/mp4": return "mp4"
        case "video/quicktime": return "mov"
        case "audio/x-ms-wma", "audio/wma": return "wma"
        default: return nil
        }
    }

    private static func isSafeExtension(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 12 else { return false }
        return value.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
    }

    private static func isLocalNetworkHost(_ host: String) -> Bool {
        let normalized = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]")).lowercased()
        if normalized == "localhost" || normalized.hasSuffix(".localhost") || normalized.hasSuffix(".local") {
            return true
        }
        if normalized == "::" || normalized == "::1" || normalized == "0:0:0:0:0:0:0:1"
            || normalized.hasPrefix("fe80:") || normalized.hasPrefix("fc")
            || normalized.hasPrefix("fd") || normalized.hasPrefix("ff") {
            return true
        }
        if normalized.hasPrefix("::ffff:") {
            return isLocalNetworkHost(String(normalized.dropFirst("::ffff:".count)))
        }
        let pieces = normalized.split(separator: ".")
        guard pieces.count == 4 else { return false }
        let octets = pieces.compactMap { Int($0) }
        guard octets.count == 4, octets.allSatisfy({ (0...255).contains($0) }) else { return false }
        let a = octets[0], b = octets[1]
        if a == 0 || a == 10 || a == 127 { return true }
        if a == 100 && (64...127).contains(b) { return true }
        if a == 169 && b == 254 { return true }
        if a == 172 && (16...31).contains(b) { return true }
        if a == 192 && b == 168 { return true }
        if a >= 224 { return true }
        return false
    }
}

public struct IODirectDownloadAcquiredFile: Sendable {
    public let stagingURL: URL
    public let preferredName: String
    public let byteCount: Int64
    public let responseURL: URL?
    public let mimeType: String?

    public init(
        stagingURL: URL,
        preferredName: String,
        byteCount: Int64,
        responseURL: URL? = nil,
        mimeType: String? = nil
    ) {
        self.stagingURL = stagingURL
        self.preferredName = preferredName
        self.byteCount = byteCount
        self.responseURL = responseURL
        self.mimeType = mimeType
    }
}

public protocol IODirectDownloading: Sendable {
    func download(from url: URL) async throws -> IODirectDownloadAcquiredFile
}

public final class IOBoundedDirectDownloadTransport: IODirectDownloading, @unchecked Sendable {
    private let policy: IODirectDownloadPolicy
    private let fileStore: IOFileStore
    private let storageReserveBytes: Int64
    private let sessionConfiguration: URLSessionConfiguration
    private let fileManager: FileManager

    public init(
        fileStore: IOFileStore,
        maximumBytes: Int64,
        maximumRedirects: Int = 5,
        storageReserveBytes: Int64,
        sessionConfiguration: URLSessionConfiguration = .ephemeral,
        fileManager: FileManager = .default
    ) {
        self.policy = IODirectDownloadPolicy(
            maximumBytes: maximumBytes,
            maximumRedirects: maximumRedirects
        )
        self.fileStore = fileStore
        self.storageReserveBytes = max(0, storageReserveBytes)
        self.sessionConfiguration = sessionConfiguration
        self.fileManager = fileManager
    }

    public func download(from url: URL) async throws -> IODirectDownloadAcquiredFile {
        let oneShot = IOBoundedDirectDownloadDelegate(
            originalURL: url,
            policy: policy,
            fileStore: fileStore,
            storageReserveBytes: storageReserveBytes,
            sessionConfiguration: sessionConfiguration,
            fileManager: fileManager
        )
        return try await oneShot.run()
    }
}

private final class IOBoundedDirectDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let originalURL: URL
    private let policy: IODirectDownloadPolicy
    private let fileStore: IOFileStore
    private let storageReserveBytes: Int64
    private let fileManager: FileManager
    private let sessionConfiguration: URLSessionConfiguration
    private let lock = NSLock()

    private var continuation: CheckedContinuation<IODirectDownloadAcquiredFile, Error>?
    private var task: URLSessionDownloadTask?
    private var oneShotSession: URLSession?
    private var terminalError: Error?
    private var acquired: IODirectDownloadAcquiredFile?
    private var responseValidated = false
    private var redirectCount = 0
    private var completed = false

    init(
        originalURL: URL,
        policy: IODirectDownloadPolicy,
        fileStore: IOFileStore,
        storageReserveBytes: Int64,
        sessionConfiguration: URLSessionConfiguration,
        fileManager: FileManager
    ) {
        self.originalURL = originalURL
        self.policy = policy
        self.fileStore = fileStore
        self.storageReserveBytes = storageReserveBytes
        self.sessionConfiguration = sessionConfiguration
        self.fileManager = fileManager
        super.init()
    }

    func run() async throws -> IODirectDownloadAcquiredFile {
        try policy.validateURL(originalURL)
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                var startTask: URLSessionDownloadTask?
                var immediateFailure: Error?
                lock.withLock {
                    if let terminalError {
                        completed = true
                        immediateFailure = terminalError
                        return
                    }
                    self.continuation = continuation
                    let session = URLSession(
                        configuration: sessionConfiguration,
                        delegate: self,
                        delegateQueue: nil
                    )
                    oneShotSession = session
                    let request = URLRequest(
                        url: originalURL,
                        cachePolicy: .reloadIgnoringLocalCacheData
                    )
                    let task = session.downloadTask(with: request)
                    self.task = task
                    startTask = task
                }
                if let immediateFailure {
                    continuation.resume(throwing: immediateFailure)
                } else {
                    startTask?.resume()
                }
            }
        }, onCancel: {
            self.cancel()
        })
    }

    private func cancel() {
        lock.withLock {
            if terminalError == nil { terminalError = CancellationError() }
            task?.cancel()
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        do {
            guard let destination = request.url else {
                throw IODirectDownloadFailure.invalidResponse
            }
            let count = lock.withLock { () -> Int in
                redirectCount += 1
                return redirectCount
            }
            try policy.validateRedirect(
                from: response.url ?? originalURL,
                to: destination,
                redirectCount: count
            )
            completionHandler(request)
        } catch {
            lock.withLock { if terminalError == nil { terminalError = error } }
            completionHandler(nil)
            task.cancel()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        do {
            if !lock.withLock({ responseValidated }) {
                guard let response = downloadTask.response as? HTTPURLResponse else {
                    throw IODirectDownloadFailure.invalidResponse
                }
                try policy.validateResponse(response)
                let expected = response.expectedContentLength
                try fileStore.preflight(
                    requiredBytes: expected > 0 ? min(expected, policy.maximumBytes) : 0,
                    reserveBytes: storageReserveBytes,
                    fileManager: fileManager
                )
                lock.withLock { responseValidated = true }
            }
            try policy.validateProgress(totalBytesWritten: totalBytesWritten)
        } catch {
            lock.withLock { if terminalError == nil { terminalError = error } }
            downloadTask.cancel()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            guard let response = downloadTask.response as? HTTPURLResponse else {
                throw IODirectDownloadFailure.invalidResponse
            }
            if !lock.withLock({ responseValidated }) {
                try policy.validateResponse(response)
            }
            let values = try location.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true else { throw IODirectDownloadFailure.emptyDownload }
            let size = Int64(values.fileSize ?? 0)
            try policy.validateCompletedFile(byteCount: size)
            try fileStore.preflight(
                requiredBytes: size,
                reserveBytes: storageReserveBytes,
                fileManager: fileManager
            )
            let staged = try fileStore.moveDownloadedTemporaryFile(
                location,
                preferredExtension: policy.preferredExtension(response: response, originalURL: originalURL),
                fileManager: fileManager
            )
            let stagedValues = try staged.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            let stagedSize = Int64(stagedValues.fileSize ?? 0)
            guard stagedValues.isRegularFile == true, stagedSize == size else {
                fileStore.removeIfExists(staged, fileManager: fileManager)
                throw IOFileStore.StoreError.fileOperationFailed(code: "DOWNLOAD_STAGE_SIZE_MISMATCH")
            }
            let value = IODirectDownloadAcquiredFile(
                stagingURL: staged,
                preferredName: policy.preferredFilenameStem(response: response, originalURL: originalURL),
                byteCount: stagedSize,
                responseURL: response.url,
                mimeType: response.mimeType
            )
            lock.withLock { acquired = value }
        } catch {
            lock.withLock { if terminalError == nil { terminalError = error } }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        var cleanupURL: URL?
        let completion: (CheckedContinuation<IODirectDownloadAcquiredFile, Error>?, Result<IODirectDownloadAcquiredFile, Error>) = lock.withLock {
            guard !completed else { return (nil, .failure(CancellationError())) }
            completed = true
            let continuation = self.continuation
            self.continuation = nil
            self.task = nil
            let result: Result<IODirectDownloadAcquiredFile, Error>
            if let terminalError {
                cleanupURL = acquired?.stagingURL
                result = .failure(terminalError)
            } else if let error {
                cleanupURL = acquired?.stagingURL
                result = .failure(error)
            } else if let acquired {
                result = .success(acquired)
            } else {
                result = .failure(IODirectDownloadFailure.invalidResponse)
            }
            return (continuation, result)
        }
        if let cleanupURL { fileStore.removeIfExists(cleanupURL, fileManager: fileManager) }
        oneShotSession?.finishTasksAndInvalidate()
        oneShotSession = nil
        completion.0?.resume(with: completion.1)
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock(); defer { unlock() }
        return try body()
    }
}
