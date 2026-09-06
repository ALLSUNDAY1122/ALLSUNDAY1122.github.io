import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private struct StableStartCreateJobResponse: Decodable {
    let jobID: UUID
}

private struct StableStartFailureEnvelope: Decodable {
    let stableErrorCode: String?
    let retryable: Bool?
}

/// Stable-idempotency start seam for the existing project-controlled separation server.
/// Snapshot/result/cancel remain on `ServerSeparationProvider`; only POST start is specialized.
public actor ServerStableStartCapability: StableIdempotentSeparationStarting {
    private let configuration: SeparationServerConfiguration
    private let session: URLSession
    private let fileManager: FileManager

    public init(
        configuration: SeparationServerConfiguration,
        session: URLSession = .shared,
        fileManager: FileManager = .default
    ) {
        self.configuration = configuration
        self.session = session
        self.fileManager = fileManager
    }

    public func start(_ request: SeparationRequest, idempotencyKey: String) async throws -> ProcessingJobID {
        let sourceURL = try resolvedAppOwnedURL(relativePath: request.asset.relativePath)
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw DomainFailure.processingFailed(code: "SEP_SOURCE_MISSING", retryable: false)
        }
        guard !request.requestedRoles.isEmpty else {
            throw DomainFailure.processingFailed(code: "SEP_NO_ROLES", retryable: false)
        }

        let baseURL = try validatedServerBaseURL(configuration.baseURL)
        let authorization = try await requiredAuthorizationHeader()
        let key = try validatedHeaderValue(idempotencyKey, limit: 128, code: "SEP_INVALID_IDEMPOTENCY_KEY")
        let roles = try validatedHeaderValue(
            request.requestedRoles.map(\.rawValue).sorted().joined(separator: ","),
            limit: 512,
            code: "SEP_INVALID_ROLE_HEADER"
        )
        let quality = try validatedHeaderValue(request.qualityProfile, limit: 512, code: "SEP_INVALID_QUALITY_HEADER")

        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("v1/separations"))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = configuration.requestTimeoutSeconds
        urlRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(key, forHTTPHeaderField: "Idempotency-Key")
        urlRequest.setValue(request.projectID.rawValue.uuidString, forHTTPHeaderField: "X-Project-ID")
        urlRequest.setValue(request.asset.id.rawValue.uuidString, forHTTPHeaderField: "X-Asset-ID")
        urlRequest.setValue(roles, forHTTPHeaderField: "X-Stem-Roles")
        urlRequest.setValue(quality, forHTTPHeaderField: "X-Quality-Profile")
        urlRequest.setValue(authorization, forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await session.upload(for: urlRequest, fromFile: sourceURL)
            try validateHTTP(response: response, data: data)
            let payload = try JSONDecoder().decode(StableStartCreateJobResponse.self, from: data)
            return ProcessingJobID(rawValue: payload.jobID)
        } catch let failure as DomainFailure {
            throw failure
        } catch is CancellationError {
            throw DomainFailure.cancelled
        } catch let error as URLError {
            throw mapNetwork(error)
        } catch {
            throw DomainFailure.processingFailed(code: "SEP_START_DECODE", retryable: false)
        }
    }

    private func validatedHeaderValue(_ value: String, limit: Int, code: String) throws -> String {
        guard !value.isEmpty,
              value.utf8.count <= limit,
              !value.contains("\r"),
              !value.contains("\n") else {
            throw DomainFailure.processingFailed(code: code, retryable: false)
        }
        return value
    }

    private func validatedServerBaseURL(_ url: URL) throws -> URL {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              let host = components.host,
              !host.isEmpty,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil else {
            throw DomainFailure.processingFailed(code: "SEP_UNSAFE_SERVER_URL", retryable: false)
        }
        return url
    }

    private func requiredAuthorizationHeader() async throws -> String {
        let candidate: String?
        do {
            candidate = try await configuration.authorizationHeader()
        } catch let failure as DomainFailure {
            throw failure
        } catch {
            throw DomainFailure.accessDenied
        }
        guard let candidate,
              !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              candidate.utf8.count <= 4096,
              !candidate.contains("\r"),
              !candidate.contains("\n") else {
            throw DomainFailure.accessDenied
        }
        return candidate
    }

    private func resolvedAppOwnedURL(relativePath: String) throws -> URL {
        guard !relativePath.isEmpty, !relativePath.hasPrefix("/") else {
            throw DomainFailure.processingFailed(code: "SEP_UNSAFE_SOURCE_PATH", retryable: false)
        }
        let root = configuration.appDataRoot.resolvingSymlinksInPath().standardizedFileURL
        let candidate = root.appendingPathComponent(relativePath).resolvingSymlinksInPath().standardizedFileURL
        guard candidate.path == root.path || candidate.path.hasPrefix(root.path + "/") else {
            throw DomainFailure.processingFailed(code: "SEP_UNSAFE_SOURCE_PATH", retryable: false)
        }
        return candidate
    }

    private func validateHTTP(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw DomainFailure.processingFailed(code: "SEP_NON_HTTP_RESPONSE", retryable: true)
        }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? JSONDecoder().decode(StableStartFailureEnvelope.self, from: data)
            let code = envelope?.stableErrorCode ?? "SEP_HTTP_\(http.statusCode)"
            let retryable = envelope?.retryable ?? (http.statusCode == 408 || http.statusCode == 429 || http.statusCode >= 500)
            if http.statusCode == 401 || http.statusCode == 403 { throw DomainFailure.accessDenied }
            if http.statusCode == 507 { throw DomainFailure.insufficientStorage }
            throw DomainFailure.processingFailed(code: code, retryable: retryable)
        }
    }

    private func mapNetwork(_ error: URLError) -> DomainFailure {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .networkUnavailable
        case .timedOut:
            return .networkTimeout
        case .cancelled:
            return .cancelled
        default:
            return .processingFailed(code: "SEP_NETWORK_\(error.code.rawValue)", retryable: true)
        }
    }
}
