import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct SeparationServerConfiguration: Sendable {
    public let baseURL: URL
    public let appDataRoot: URL
    public let requestTimeoutSeconds: TimeInterval
    public let authorizationHeader: @Sendable () async throws -> String?

    public init(
        baseURL: URL,
        appDataRoot: URL,
        requestTimeoutSeconds: TimeInterval = 120,
        authorizationHeader: @escaping @Sendable () async throws -> String? = { nil }
    ) {
        self.baseURL = baseURL
        self.appDataRoot = appDataRoot
        self.requestTimeoutSeconds = requestTimeoutSeconds
        self.authorizationHeader = authorizationHeader
    }
}

private struct CreateJobResponse: Decodable {
    let jobID: UUID
}

private struct JobSnapshotResponse: Decodable {
    let jobID: UUID
    let phase: String
    let fractionComplete: Double?
    let retryable: Bool
    let stableErrorCode: String?
}

private struct StemResultResponse: Decodable {
    let stemID: UUID
    let role: String
    let downloadURL: URL
    let mediaExtension: String
    let sampleRate: Double
    let channels: Int
    let frameCount: Int64
    let startTimeSeconds: Double
}

private struct JobResultResponse: Decodable {
    let jobID: UUID
    let projectID: UUID
    let stems: [StemResultResponse]
}

private struct ServerFailureEnvelope: Decodable {
    let stableErrorCode: String?
    let retryable: Bool?
}

/// Server-backed implementation of the HQ-owned `SourceSeparationProviding` contract.
///
/// No model or fake separator lives in this client. The production backend must pass the project's
/// checkpoint/data-rights gate. Large source audio is uploaded from a file URL so the client does not
/// materialize an entire long track in memory. Downloaded stems are staged and atomically finalized
/// under the app-owned root before a `StemArtifact` is exposed.
public actor ServerSeparationProvider: SourceSeparationProviding {
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

    public func start(_ request: SeparationRequest) async throws -> ProcessingJobID {
        let sourceURL = try resolvedAppOwnedURL(relativePath: request.asset.relativePath)
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw DomainFailure.processingFailed(code: "SEP_SOURCE_MISSING", retryable: false)
        }
        guard !request.requestedRoles.isEmpty else {
            throw DomainFailure.processingFailed(code: "SEP_NO_ROLES", retryable: false)
        }

        let rolesHeader = try validatedHeaderValue(
            request.requestedRoles.map(\.rawValue).sorted().joined(separator: ","),
            code: "SEP_INVALID_ROLE_HEADER"
        )
        let qualityHeader = try validatedHeaderValue(request.qualityProfile, code: "SEP_INVALID_QUALITY_HEADER")

        var urlRequest = URLRequest(url: configuration.baseURL.appendingPathComponent("v1/separations"))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = configuration.requestTimeoutSeconds
        urlRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        urlRequest.setValue(request.projectID.rawValue.uuidString, forHTTPHeaderField: "X-Project-ID")
        urlRequest.setValue(request.asset.id.rawValue.uuidString, forHTTPHeaderField: "X-Asset-ID")
        urlRequest.setValue(rolesHeader, forHTTPHeaderField: "X-Stem-Roles")
        urlRequest.setValue(qualityHeader, forHTTPHeaderField: "X-Quality-Profile")
        try await applyAuthorization(to: &urlRequest)

        do {
            let (data, response) = try await session.upload(for: urlRequest, fromFile: sourceURL)
            try validateHTTP(response: response, data: data)
            let payload = try JSONDecoder().decode(CreateJobResponse.self, from: data)
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

    public func snapshot(jobID: ProcessingJobID) async throws -> ProcessingSnapshot {
        let url = configuration.baseURL
            .appendingPathComponent("v1/separations")
            .appendingPathComponent(jobID.rawValue.uuidString)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = configuration.requestTimeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        try await applyAuthorization(to: &request)

        do {
            let (data, response) = try await session.data(for: request)
            try validateHTTP(response: response, data: data)
            let payload = try JSONDecoder().decode(JobSnapshotResponse.self, from: data)
            guard payload.jobID == jobID.rawValue else {
                throw DomainFailure.processingFailed(code: "SEP_JOB_ID_MISMATCH", retryable: false)
            }
            return ProcessingSnapshot(
                jobID: jobID,
                phase: try mapPhase(payload.phase),
                fractionComplete: payload.fractionComplete,
                retryable: payload.retryable,
                stableErrorCode: payload.stableErrorCode
            )
        } catch let failure as DomainFailure {
            throw failure
        } catch is CancellationError {
            throw DomainFailure.cancelled
        } catch let error as URLError {
            throw mapNetwork(error)
        } catch {
            throw DomainFailure.processingFailed(code: "SEP_SNAPSHOT_DECODE", retryable: true)
        }
    }

    public func result(jobID: ProcessingJobID) async throws -> [StemArtifact] {
        let snapshot = try await snapshot(jobID: jobID)
        guard snapshot.phase == .ready else {
            throw DomainFailure.processingFailed(code: "SEP_RESULT_NOT_READY", retryable: true)
        }

        let url = configuration.baseURL
            .appendingPathComponent("v1/separations")
            .appendingPathComponent(jobID.rawValue.uuidString)
            .appendingPathComponent("result")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = configuration.requestTimeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        try await applyAuthorization(to: &request)

        do {
            let (data, response) = try await session.data(for: request)
            try validateHTTP(response: response, data: data)
            let payload = try JSONDecoder().decode(JobResultResponse.self, from: data)
            guard payload.jobID == jobID.rawValue else {
                throw DomainFailure.processingFailed(code: "SEP_JOB_ID_MISMATCH", retryable: false)
            }
            guard !payload.stems.isEmpty else {
                throw DomainFailure.processingFailed(code: "SEP_EMPTY_RESULT", retryable: false)
            }

            let projectID = ProjectID(rawValue: payload.projectID)
            var artifacts: [StemArtifact] = []
            artifacts.reserveCapacity(payload.stems.count)
            var seenRoles = Set<StemRole>()
            var seenStemIDs = Set<UUID>()

            for remoteStem in payload.stems {
                guard remoteStem.sampleRate > 0,
                      remoteStem.channels > 0,
                      remoteStem.frameCount >= 0 else {
                    throw DomainFailure.processingFailed(code: "SEP_INVALID_STEM_METADATA", retryable: false)
                }

                let role = StemRole(rawValue: remoteStem.role)
                guard seenRoles.insert(role).inserted else {
                    throw DomainFailure.processingFailed(code: "SEP_DUPLICATE_ROLE", retryable: false)
                }
                guard seenStemIDs.insert(remoteStem.stemID).inserted else {
                    throw DomainFailure.processingFailed(code: "SEP_DUPLICATE_STEM_ID", retryable: false)
                }

                let destination = try finalStemURL(
                    projectID: projectID,
                    role: role,
                    mediaExtension: remoteStem.mediaExtension
                )
                let local = try await downloadAtomically(from: remoteStem.downloadURL, to: destination)
                let relativePath = try relativeAppOwnedPath(for: local)

                artifacts.append(
                    StemArtifact(
                        id: StemID(rawValue: remoteStem.stemID),
                        projectID: projectID,
                        role: role,
                        relativePath: relativePath,
                        sampleRate: remoteStem.sampleRate,
                        channels: remoteStem.channels,
                        frameCount: remoteStem.frameCount,
                        startTimeSeconds: remoteStem.startTimeSeconds
                    )
                )
            }

            return artifacts
        } catch let failure as DomainFailure {
            throw failure
        } catch is CancellationError {
            throw DomainFailure.cancelled
        } catch let error as URLError {
            throw mapNetwork(error)
        } catch {
            throw DomainFailure.processingFailed(code: "SEP_RESULT_DECODE", retryable: true)
        }
    }

    public func cancel(jobID: ProcessingJobID) async {
        let url = configuration.baseURL
            .appendingPathComponent("v1/separations")
            .appendingPathComponent(jobID.rawValue.uuidString)

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = configuration.requestTimeoutSeconds
        if let authorization = try? await configuration.authorizationHeader() {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }

        // Shared contract is non-throwing. DELETE must be idempotent; the authoritative cancelled or
        // failed state is observed through a subsequent snapshot poll.
        _ = try? await session.data(for: request)
    }

    private func applyAuthorization(to request: inout URLRequest) async throws {
        if let authorization = try await configuration.authorizationHeader() {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }
    }

    private func validateHTTP(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw DomainFailure.processingFailed(code: "SEP_NON_HTTP_RESPONSE", retryable: true)
        }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? JSONDecoder().decode(ServerFailureEnvelope.self, from: data)
            let code = envelope?.stableErrorCode ?? "SEP_HTTP_\(http.statusCode)"
            let retryable = envelope?.retryable ?? (http.statusCode == 408 || http.statusCode == 429 || http.statusCode >= 500)
            if http.statusCode == 401 || http.statusCode == 403 {
                throw DomainFailure.accessDenied
            }
            if http.statusCode == 507 {
                throw DomainFailure.insufficientStorage
            }
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

    private func mapPhase(_ raw: String) throws -> ProcessingPhase {
        guard let phase = ProcessingPhase(rawValue: raw) else {
            throw DomainFailure.processingFailed(code: "SEP_UNKNOWN_PHASE_\(raw)", retryable: false)
        }
        return phase
    }

    private func validatedHeaderValue(_ value: String, code: String) throws -> String {
        guard !value.isEmpty,
              value.utf8.count <= 512,
              !value.contains("\r"),
              !value.contains("\n") else {
            throw DomainFailure.processingFailed(code: code, retryable: false)
        }
        return value
    }

    private func resolvedAppOwnedURL(relativePath: String) throws -> URL {
        guard !relativePath.isEmpty, !relativePath.hasPrefix("/") else {
            throw DomainFailure.processingFailed(code: "SEP_UNSAFE_SOURCE_PATH", retryable: false)
        }
        let root = configuration.appDataRoot.resolvingSymlinksInPath().standardizedFileURL
        let candidate = root
            .appendingPathComponent(relativePath)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        guard candidate.path == root.path || candidate.path.hasPrefix(root.path + "/") else {
            throw DomainFailure.processingFailed(code: "SEP_UNSAFE_SOURCE_PATH", retryable: false)
        }
        return candidate
    }

    private func finalStemURL(projectID: ProjectID, role: StemRole, mediaExtension: String) throws -> URL {
        let safeExtension = mediaExtension.lowercased().filter { $0.isLetter || $0.isNumber }
        guard !safeExtension.isEmpty, safeExtension.utf8.count <= 8 else {
            throw DomainFailure.processingFailed(code: "SEP_INVALID_EXTENSION", retryable: false)
        }
        guard !role.rawValue.isEmpty,
              role.rawValue.utf8.count <= 64,
              role.rawValue.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else {
            throw DomainFailure.processingFailed(code: "SEP_UNSAFE_ROLE", retryable: false)
        }

        let root = configuration.appDataRoot.resolvingSymlinksInPath().standardizedFileURL
        let directory = root
            .appendingPathComponent("separation-stems", isDirectory: true)
            .appendingPathComponent(projectID.rawValue.uuidString, isDirectory: true)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw DomainFailure.insufficientStorage
        }
        return directory.appendingPathComponent("\(role.rawValue).\(safeExtension)")
    }

    private func downloadAtomically(from remoteURL: URL, to destinationURL: URL) async throws -> URL {
        guard remoteURL.scheme == "https" else {
            throw DomainFailure.processingFailed(code: "SEP_INSECURE_STEM_URL", retryable: false)
        }
        do {
            let (temporaryURL, response) = try await session.download(from: remoteURL)
            try validateHTTP(response: response, data: Data())
            let stagingURL = destinationURL
                .deletingLastPathComponent()
                .appendingPathComponent(".\(destinationURL.lastPathComponent).\(UUID().uuidString).staging")
            if fileManager.fileExists(atPath: stagingURL.path) {
                try fileManager.removeItem(at: stagingURL)
            }
            try fileManager.moveItem(at: temporaryURL, to: stagingURL)
            if fileManager.fileExists(atPath: destinationURL.path) {
                _ = try fileManager.replaceItemAt(destinationURL, withItemAt: stagingURL)
            } else {
                try fileManager.moveItem(at: stagingURL, to: destinationURL)
            }
            return destinationURL
        } catch let failure as DomainFailure {
            throw failure
        } catch let error as URLError {
            throw mapNetwork(error)
        } catch {
            throw DomainFailure.processingFailed(code: "SEP_STEM_PERSIST_FAILED", retryable: true)
        }
    }

    private func relativeAppOwnedPath(for url: URL) throws -> String {
        let root = configuration.appDataRoot.resolvingSymlinksInPath().standardizedFileURL.path
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        guard path.hasPrefix(root + "/") else {
            throw DomainFailure.processingFailed(code: "SEP_OUTPUT_OUTSIDE_ROOT", retryable: false)
        }
        return String(path.dropFirst(root.count + 1))
    }
}
