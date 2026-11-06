import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum SeparationRunLedgerState: String, Codable, Sendable {
    case prepared
    case committed
    case deleted
}

public enum SeparationRetentionPolicy: String, Codable, Sendable {
    case untilProjectDelete
    case explicitExpiry
    case manualDelete
}

public struct SeparationCostAccounting: Hashable, Codable, Sendable {
    public let currency: String
    public let total: Double
    public let units: Double?
    public let unitName: String?
    public let basis: String
    public let isActual: Bool

    public init(currency: String, total: Double, units: Double?, unitName: String?, basis: String, isActual: Bool) {
        self.currency = currency
        self.total = total
        self.units = units
        self.unitName = unitName
        self.basis = basis
        self.isActual = isActual
    }
}

public struct SeparationRetentionRecord: Hashable, Codable, Sendable {
    public let vendorAssetExpiresAt: Date?
    public let vendorOutputExpiresAt: Date?
    public let vendorDeleteRequestedAt: Date?
    public let vendorDeleteConfirmedAt: Date?
    public let localPolicy: SeparationRetentionPolicy
    public let localExpiresAt: Date?

    public init(
        vendorAssetExpiresAt: Date?,
        vendorOutputExpiresAt: Date?,
        vendorDeleteRequestedAt: Date?,
        vendorDeleteConfirmedAt: Date?,
        localPolicy: SeparationRetentionPolicy,
        localExpiresAt: Date?
    ) {
        self.vendorAssetExpiresAt = vendorAssetExpiresAt
        self.vendorOutputExpiresAt = vendorOutputExpiresAt
        self.vendorDeleteRequestedAt = vendorDeleteRequestedAt
        self.vendorDeleteConfirmedAt = vendorDeleteConfirmedAt
        self.localPolicy = localPolicy
        self.localExpiresAt = localExpiresAt
    }
}

public struct VendorStemOutputDescriptor: Hashable, Codable, Sendable {
    public let stemID: StemID
    public let role: StemRole
    public let downloadURL: URL
    public let expiresAt: Date
    public let container: String
    public let sampleRate: Double
    public let channels: Int
    public let frameCount: Int64
    public let durationSeconds: Double
    public let expectedByteCount: Int64?
    public let expectedSHA256: String?

    public init(
        stemID: StemID,
        role: StemRole,
        downloadURL: URL,
        expiresAt: Date,
        container: String,
        sampleRate: Double,
        channels: Int,
        frameCount: Int64,
        durationSeconds: Double,
        expectedByteCount: Int64? = nil,
        expectedSHA256: String? = nil
    ) {
        self.stemID = stemID
        self.role = role
        self.downloadURL = downloadURL
        self.expiresAt = expiresAt
        self.container = container
        self.sampleRate = sampleRate
        self.channels = channels
        self.frameCount = frameCount
        self.durationSeconds = durationSeconds
        self.expectedByteCount = expectedByteCount
        self.expectedSHA256 = expectedSHA256
    }
}

public struct SeparationProviderRunManifest: Hashable, Codable, Sendable {
    public let schemaVersion: Int
    public let projectID: ProjectID
    public let jobID: ProcessingJobID
    public let providerID: String
    public let providerKind: String
    public let modelName: String
    public let modelVersion: String
    public let qualityProfile: String
    public let requestedRoles: Set<StemRole>
    public let outputs: [VendorStemOutputDescriptor]
    public let cost: SeparationCostAccounting
    public let retention: SeparationRetentionRecord
    public let uploadMilliseconds: Int64?
    public let queueMilliseconds: Int64?
    public let inferenceMilliseconds: Int64?
    public let downloadMilliseconds: Int64?
    public let generatedAt: Date

    public init(
        schemaVersion: Int = 1,
        projectID: ProjectID,
        jobID: ProcessingJobID,
        providerID: String,
        providerKind: String,
        modelName: String,
        modelVersion: String,
        qualityProfile: String,
        requestedRoles: Set<StemRole>,
        outputs: [VendorStemOutputDescriptor],
        cost: SeparationCostAccounting,
        retention: SeparationRetentionRecord,
        uploadMilliseconds: Int64? = nil,
        queueMilliseconds: Int64? = nil,
        inferenceMilliseconds: Int64? = nil,
        downloadMilliseconds: Int64? = nil,
        generatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.projectID = projectID
        self.jobID = jobID
        self.providerID = providerID
        self.providerKind = providerKind
        self.modelName = modelName
        self.modelVersion = modelVersion
        self.qualityProfile = qualityProfile
        self.requestedRoles = requestedRoles
        self.outputs = outputs
        self.cost = cost
        self.retention = retention
        self.uploadMilliseconds = uploadMilliseconds
        self.queueMilliseconds = queueMilliseconds
        self.inferenceMilliseconds = inferenceMilliseconds
        self.downloadMilliseconds = downloadMilliseconds
        self.generatedAt = generatedAt
    }
}

public struct VerifiedSeparationOutput: Hashable, Codable, Sendable {
    public let stemID: StemID
    public let role: StemRole
    public let stagedRelativePath: String
    public let sha256: String
    public let byteCount: Int64
    public let sampleRate: Double
    public let channels: Int
    public let frameCount: Int64
    public let durationSeconds: Double
}

public struct SeparationRunLedger: Hashable, Codable, Sendable {
    public let schemaVersion: Int
    public let state: SeparationRunLedgerState
    public let manifest: SeparationProviderRunManifest
    public let verifiedOutputs: [VerifiedSeparationOutput]
    public let finalArtifacts: [StemArtifact]
    public let preparedAt: Date
    public let committedAt: Date?
    public let deletedAt: Date?

    public init(
        schemaVersion: Int = 1,
        state: SeparationRunLedgerState,
        manifest: SeparationProviderRunManifest,
        verifiedOutputs: [VerifiedSeparationOutput],
        finalArtifacts: [StemArtifact] = [],
        preparedAt: Date,
        committedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.state = state
        self.manifest = manifest
        self.verifiedOutputs = verifiedOutputs
        self.finalArtifacts = finalArtifacts
        self.preparedAt = preparedAt
        self.committedAt = committedAt
        self.deletedAt = deletedAt
    }
}

public protocol VendorOutputFetching: Sendable {
    /// Return a local temporary file containing the complete remote response body.
    func download(_ url: URL) async throws -> URL
}

public actor URLSessionVendorOutputFetcher: VendorOutputFetching {
    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public func download(_ url: URL) async throws -> URL {
        do {
            let (temporary, response) = try await session.download(from: url)
            guard let http = response as? HTTPURLResponse else {
                throw DomainFailure.processingFailed(code: "SEP_OUTPUT_NON_HTTP", retryable: true)
            }
            guard (200..<300).contains(http.statusCode) else {
                let retryable = http.statusCode == 408 || http.statusCode == 429 || http.statusCode >= 500
                throw DomainFailure.processingFailed(code: "SEP_OUTPUT_HTTP_\(http.statusCode)", retryable: retryable)
            }
            return temporary
        } catch let failure as DomainFailure {
            throw failure
        } catch is CancellationError {
            throw DomainFailure.cancelled
        } catch let error as URLError {
            switch error.code {
            case .timedOut: throw DomainFailure.networkTimeout
            case .notConnectedToInternet, .networkConnectionLost: throw DomainFailure.networkUnavailable
            case .cancelled: throw DomainFailure.cancelled
            default: throw DomainFailure.processingFailed(code: "SEP_OUTPUT_NETWORK_\(error.code.rawValue)", retryable: true)
            }
        } catch {
            throw DomainFailure.processingFailed(code: "SEP_OUTPUT_DOWNLOAD_FAILED", retryable: true)
        }
    }
}

public protocol SeparationRunLedgerStoring: Sendable {
    func load(projectID: ProjectID, jobID: ProcessingJobID) async throws -> SeparationRunLedger?
    func save(_ ledger: SeparationRunLedger) async throws
}

public actor FileSeparationRunLedgerStore: SeparationRunLedgerStoring {
    private let root: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(appDataRoot: URL, fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        self.root = appDataRoot.resolvingSymlinksInPath().standardizedFileURL
            .appendingPathComponent("separation-run-ledger", isDirectory: true)
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    public func load(projectID: ProjectID, jobID: ProcessingJobID) async throws -> SeparationRunLedger? {
        let url = ledgerURL(projectID: projectID, jobID: jobID)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let decoded = try decoder.decode(SeparationRunLedger.self, from: Data(contentsOf: url))
            guard decoded.schemaVersion == 1,
                  decoded.manifest.projectID == projectID,
                  decoded.manifest.jobID == jobID else {
                throw DomainFailure.processingFailed(code: "SEP_LEDGER_IDENTITY_MISMATCH", retryable: false)
            }
            return decoded
        } catch let failure as DomainFailure {
            throw failure
        } catch {
            throw DomainFailure.processingFailed(code: "SEP_LEDGER_CORRUPT", retryable: false)
        }
    }

    public func save(_ ledger: SeparationRunLedger) async throws {
        do {
            let url = ledgerURL(projectID: ledger.manifest.projectID, jobID: ledger.manifest.jobID)
            let data = try encoder.encode(ledger)
            try data.write(to: url, options: [.atomic])
        } catch {
            throw DomainFailure.processingFailed(code: "SEP_LEDGER_WRITE_FAILED", retryable: true)
        }
    }

    private func ledgerURL(projectID: ProjectID, jobID: ProcessingJobID) -> URL {
        let project = root.appendingPathComponent(projectID.rawValue.uuidString, isDirectory: true)
        try? fileManager.createDirectory(at: project, withIntermediateDirectories: true)
        return project.appendingPathComponent(jobID.rawValue.uuidString + ".json")
    }
}
