import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Isolated compile/runtime harness for ServerStableStartCapability.swift. The production repository
// does not yet contain a concrete SeparationServerConfiguration / ServerSeparationProvider because
// authenticated app↔server transport/deployment composition is still an external integration gate.
// These stubs exist only to execute the isolated capability's transport preflight contract.
public struct ProjectID: Sendable {
    public let rawValue: UUID
    public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue }
}

public struct AssetID: Sendable {
    public let rawValue: UUID
    public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue }
}

public struct ProcessingJobID: Sendable {
    public let rawValue: UUID
    public init(rawValue: UUID) { self.rawValue = rawValue }
}

public struct StemRole: Hashable, Sendable {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let vocals = StemRole("vocals")
}

public struct LocalAudioAsset: Sendable {
    public let id: AssetID
    public let relativePath: String
}

public struct SeparationRequest: Sendable {
    public let projectID: ProjectID
    public let asset: LocalAudioAsset
    public let requestedRoles: Set<StemRole>
    public let qualityProfile: String
}

public enum DomainFailure: Error, Equatable, Sendable {
    case accessDenied
    case providerUnavailable
    case networkUnavailable
    case networkTimeout
    case unsupportedMedia
    case protectedMedia
    case corruptMedia
    case noAudioTrack
    case insufficientStorage
    case cancelled
    case processingFailed(code: String, retryable: Bool)
    case exportFailed(code: String)
}

public protocol StableIdempotentSeparationStarting: Sendable {
    func start(_ request: SeparationRequest, idempotencyKey: String) async throws -> ProcessingJobID
}

public struct SeparationServerConfiguration: Sendable {
    public let baseURL: URL
    public let requestTimeoutSeconds: TimeInterval
    public let appDataRoot: URL
    private let auth: @Sendable () async throws -> String?

    public init(
        baseURL: URL,
        appDataRoot: URL,
        auth: @escaping @Sendable () async throws -> String?
    ) {
        self.baseURL = baseURL
        self.requestTimeoutSeconds = 10
        self.appDataRoot = appDataRoot
        self.auth = auth
    }

    public func authorizationHeader() async throws -> String? {
        try await auth()
    }
}

private func makeFixture() throws -> (URL, SeparationRequest) {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("stable-start-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data([1, 2, 3]).write(to: root.appendingPathComponent("source.bin"))
    let request = SeparationRequest(
        projectID: ProjectID(),
        asset: LocalAudioAsset(id: AssetID(), relativePath: "source.bin"),
        requestedRoles: [.vocals],
        qualityProfile: "standard"
    )
    return (root, request)
}

private func expect(
    _ label: String,
    _ expected: DomainFailure,
    operation: @Sendable () async throws -> Void
) async throws {
    do {
        try await operation()
        fatalError("\(label): expected failure")
    } catch let failure as DomainFailure {
        guard failure == expected else {
            fatalError("\(label): got \(failure), expected \(expected)")
        }
    }
}

@main
struct ServerStableStartTransportPreflightHarness {
    static func main() async throws {
        let (root, request) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: root) }

        try await expect(
            "plain-http",
            .processingFailed(code: "SEP_UNSAFE_SERVER_URL", retryable: false)
        ) {
            let capability = ServerStableStartCapability(
                configuration: .init(
                    baseURL: URL(string: "http://example.com")!,
                    appDataRoot: root,
                    auth: { "Bearer ok" }
                )
            )
            _ = try await capability.start(request, idempotencyKey: "proc-test")
        }

        try await expect("nil-authorization", .accessDenied) {
            let capability = ServerStableStartCapability(
                configuration: .init(
                    baseURL: URL(string: "https://example.com")!,
                    appDataRoot: root,
                    auth: { nil }
                )
            )
            _ = try await capability.start(request, idempotencyKey: "proc-test")
        }

        try await expect("blank-authorization", .accessDenied) {
            let capability = ServerStableStartCapability(
                configuration: .init(
                    baseURL: URL(string: "https://example.com")!,
                    appDataRoot: root,
                    auth: { "   " }
                )
            )
            _ = try await capability.start(request, idempotencyKey: "proc-test")
        }

        try await expect("authorization-crlf", .accessDenied) {
            let capability = ServerStableStartCapability(
                configuration: .init(
                    baseURL: URL(string: "https://example.com")!,
                    appDataRoot: root,
                    auth: { "Bearer ok\r\nX-Evil: 1" }
                )
            )
            _ = try await capability.start(request, idempotencyKey: "proc-test")
        }

        try await expect(
            "url-embedded-credentials",
            .processingFailed(code: "SEP_UNSAFE_SERVER_URL", retryable: false)
        ) {
            let capability = ServerStableStartCapability(
                configuration: .init(
                    baseURL: URL(string: "https://user:pass@example.com")!,
                    appDataRoot: root,
                    auth: { "Bearer ok" }
                )
            )
            _ = try await capability.start(request, idempotencyKey: "proc-test")
        }

        print("L1_STABLE_START_TRANSPORT_PREFLIGHT_PASS scenarios=5")
    }
}
