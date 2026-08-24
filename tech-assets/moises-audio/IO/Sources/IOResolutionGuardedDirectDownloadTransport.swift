import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public protocol IOHostResolving: Sendable {
    func resolveNumericAddresses(host: String) throws -> [String]
}

public struct IOSystemHostResolver: IOHostResolving, Sendable {
    public init() {}

    public func resolveNumericAddresses(host: String) throws -> [String] {
        var hints = addrinfo()
        hints.ai_flags = AI_ADDRCONFIG
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = Int32(SOCK_STREAM.rawValue)
        hints.ai_protocol = IPPROTO_TCP

        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(host, nil, &hints, &result)
        guard status == 0, let first = result else {
            throw URLError(.dnsLookupFailed)
        }
        defer { freeaddrinfo(first) }

        var addresses = Set<String>()
        var cursor: UnsafeMutablePointer<addrinfo>? = first
        while let node = cursor {
            guard let address = node.pointee.ai_addr else {
                cursor = node.pointee.ai_next
                continue
            }
            var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let rc = getnameinfo(
                address,
                socklen_t(node.pointee.ai_addrlen),
                &hostBuffer,
                socklen_t(hostBuffer.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            if rc == 0 {
                addresses.insert(String(cString: hostBuffer))
            }
            cursor = node.pointee.ai_next
        }
        guard !addresses.isEmpty else { throw URLError(.dnsLookupFailed) }
        return addresses.sorted()
    }
}

public enum IOPublicHostResolutionPolicy {
    /// Fail closed if any DNS answer is not globally routable. Mixed public/private answers are
    /// blocked because URLSession is free to choose any returned address.
    public static func requirePublic(addresses: [String], host: String) throws {
        guard !addresses.isEmpty else { throw URLError(.dnsLookupFailed) }
        for address in addresses {
            guard isPublicNumericAddress(address) else {
                throw IODirectDownloadFailure.localNetworkHost(host)
            }
        }
    }

    public static func isPublicNumericAddress(_ raw: String) -> Bool {
        let address = raw.split(separator: "%", maxSplits: 1).first.map(String.init) ?? raw
        var ipv4 = in_addr()
        if address.withCString({ inet_pton(AF_INET, $0, &ipv4) }) == 1 {
            let bytes = withUnsafeBytes(of: &ipv4) { Array($0) }
            guard bytes.count == 4 else { return false }
            let a = Int(bytes[0]), b = Int(bytes[1])
            if a == 0 || a == 10 || a == 127 { return false }
            if a == 100 && (64...127).contains(b) { return false }
            if a == 169 && b == 254 { return false }
            if a == 172 && (16...31).contains(b) { return false }
            if a == 192 && b == 0 { return false }
            if a == 192 && b == 168 { return false }
            if a == 198 && (b == 18 || b == 19) { return false }
            if a == 192 && b == 0 && Int(bytes[2]) == 2 { return false }
            if a == 198 && b == 51 && Int(bytes[2]) == 100 { return false }
            if a == 203 && b == 0 && Int(bytes[2]) == 113 { return false }
            if a >= 224 { return false }
            return true
        }

        var ipv6 = in6_addr()
        if address.withCString({ inet_pton(AF_INET6, $0, &ipv6) }) == 1 {
            let bytes = withUnsafeBytes(of: &ipv6) { Array($0) }
            guard bytes.count == 16 else { return false }
            if bytes.allSatisfy({ $0 == 0 }) { return false }
            if bytes.dropLast().allSatisfy({ $0 == 0 }) && bytes[15] == 1 { return false }
            if bytes[0] == 0xff { return false }
            if bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80 { return false }
            if (bytes[0] & 0xfe) == 0xfc { return false }
            if bytes[0] == 0x20 && bytes[1] == 0x01 && bytes[2] == 0x0d && bytes[3] == 0xb8 { return false }
            let mappedPrefix = bytes[0..<10].allSatisfy { $0 == 0 } && bytes[10] == 0xff && bytes[11] == 0xff
            if mappedPrefix {
                return isPublicNumericAddress("\(bytes[12]).\(bytes[13]).\(bytes[14]).\(bytes[15])")
            }
            return true
        }
        return false
    }
}

public struct IOPublicHostResolutionGuard: Sendable {
    private let resolver: any IOHostResolving

    public init(resolver: any IOHostResolving = IOSystemHostResolver()) {
        self.resolver = resolver
    }

    public func validate(url: URL) throws {
        guard let host = url.host?.lowercased(), !host.isEmpty else {
            throw IODirectDownloadFailure.missingHost
        }
        let addresses = try resolver.resolveNumericAddresses(host: host)
        try IOPublicHostResolutionPolicy.requirePublic(addresses: addresses, host: host)
    }
}

/// Canonical direct-download transport for public URL import. It keeps all AW14 byte/redirect/storage
/// guards and additionally resolves both the initial host and every redirect destination before
/// URLSession is allowed to issue the request. This blocks ordinary hostnames that resolve directly
/// to loopback/private/link-local/multicast/reserved addresses.
///
/// DNS validation is still a pre-connect check; a hostile resolver can theoretically rebind between
/// this check and URLSession's own connection resolution. That remaining TOCTOU is explicitly not
/// claimed solved until the connection is pinned/verified on Apple networking.
public final class IOResolutionGuardedDirectDownloadTransport: IODirectDownloading, @unchecked Sendable {
    private let policy: IODirectDownloadPolicy
    private let resolutionGuard: IOPublicHostResolutionGuard
    private let fileStore: IOFileStore
    private let storageReserveBytes: Int64
    private let sessionConfiguration: URLSessionConfiguration
    private let fileManager: FileManager

    public init(
        fileStore: IOFileStore,
        maximumBytes: Int64,
        maximumRedirects: Int = 5,
        storageReserveBytes: Int64,
        resolver: any IOHostResolving = IOSystemHostResolver(),
        sessionConfiguration: URLSessionConfiguration = .ephemeral,
        fileManager: FileManager = .default
    ) {
        self.policy = IODirectDownloadPolicy(
            maximumBytes: maximumBytes,
            maximumRedirects: maximumRedirects
        )
        self.resolutionGuard = IOPublicHostResolutionGuard(resolver: resolver)
        self.fileStore = fileStore
        self.storageReserveBytes = max(0, storageReserveBytes)
        self.sessionConfiguration = sessionConfiguration
        self.fileManager = fileManager
    }

    public func download(from url: URL) async throws -> IODirectDownloadAcquiredFile {
        let oneShot = IOResolutionGuardedDownloadDelegate(
            originalURL: url,
            policy: policy,
            resolutionGuard: resolutionGuard,
            fileStore: fileStore,
            storageReserveBytes: storageReserveBytes,
            sessionConfiguration: sessionConfiguration,
            fileManager: fileManager
        )
        return try await oneShot.run()
    }
}

private final class IOResolutionGuardedDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let originalURL: URL
    private let policy: IODirectDownloadPolicy
    private let resolutionGuard: IOPublicHostResolutionGuard
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
        resolutionGuard: IOPublicHostResolutionGuard,
        fileStore: IOFileStore,
        storageReserveBytes: Int64,
        sessionConfiguration: URLSessionConfiguration,
        fileManager: FileManager
    ) {
        self.originalURL = originalURL
        self.policy = policy
        self.resolutionGuard = resolutionGuard
        self.fileStore = fileStore
        self.storageReserveBytes = storageReserveBytes
        self.sessionConfiguration = sessionConfiguration
        self.fileManager = fileManager
        super.init()
    }

    func run() async throws -> IODirectDownloadAcquiredFile {
        try policy.validateURL(originalURL)
        try resolutionGuard.validate(url: originalURL)
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                var startTask: URLSessionDownloadTask?
                var immediateFailure: Error?
                lock.withLockAW34 {
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
                    let request = URLRequest(url: originalURL, cachePolicy: .reloadIgnoringLocalCacheData)
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
        lock.withLockAW34 {
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
            guard let destination = request.url else { throw IODirectDownloadFailure.invalidResponse }
            let count = lock.withLockAW34 { () -> Int in
                redirectCount += 1
                return redirectCount
            }
            try policy.validateRedirect(
                from: response.url ?? originalURL,
                to: destination,
                redirectCount: count
            )
            try resolutionGuard.validate(url: destination)
            completionHandler(request)
        } catch {
            lock.withLockAW34 { if terminalError == nil { terminalError = error } }
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
            if !lock.withLockAW34({ responseValidated }) {
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
                lock.withLockAW34 { responseValidated = true }
            }
            try policy.validateProgress(totalBytesWritten: totalBytesWritten)
        } catch {
            lock.withLockAW34 { if terminalError == nil { terminalError = error } }
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
            if !lock.withLockAW34({ responseValidated }) {
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
            lock.withLockAW34 { acquired = value }
        } catch {
            lock.withLockAW34 { if terminalError == nil { terminalError = error } }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        var cleanupURL: URL?
        let completion: (CheckedContinuation<IODirectDownloadAcquiredFile, Error>?, Result<IODirectDownloadAcquiredFile, Error>) = lock.withLockAW34 {
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

private extension NSLock {
    func withLockAW34<T>(_ body: () throws -> T) rethrows -> T {
        lock(); defer { unlock() }
        return try body()
    }
}
