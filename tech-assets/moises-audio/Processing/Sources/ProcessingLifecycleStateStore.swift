import Foundation

public enum DurableProcessingState: String, Codable, Sendable {
    case starting
    case startAmbiguous
    case active
    case cancellationRequested
    case ready
    case resultStaged
    case resultPersisted
    case failed
    case cancelled
    case completed
}

public struct DurableProcessingRecord: Hashable, Codable, Sendable {
    public let schemaVersion: Int
    public let projectID: ProjectID
    public let request: SeparationRequest
    public let generationID: UUID
    public let jobID: ProcessingJobID?
    public let state: DurableProcessingState
    public let lastSnapshot: ProcessingSnapshot?
    public let resultArtifacts: [StemArtifact]?
    public let retryCount: Int
    public let retryable: Bool
    public let stableErrorCode: String?
    public let updatedAt: Date

    public init(
        schemaVersion: Int = 1,
        projectID: ProjectID,
        request: SeparationRequest,
        generationID: UUID,
        jobID: ProcessingJobID?,
        state: DurableProcessingState,
        lastSnapshot: ProcessingSnapshot?,
        resultArtifacts: [StemArtifact]? = nil,
        retryCount: Int,
        retryable: Bool,
        stableErrorCode: String?,
        updatedAt: Date = Date()
    ) {
        precondition(schemaVersion > 0)
        precondition(retryCount >= 0)
        self.schemaVersion = schemaVersion
        self.projectID = projectID
        self.request = request
        self.generationID = generationID
        self.jobID = jobID
        self.state = state
        self.lastSnapshot = lastSnapshot
        self.resultArtifacts = resultArtifacts
        self.retryCount = retryCount
        self.retryable = retryable
        self.stableErrorCode = stableErrorCode
        self.updatedAt = updatedAt
    }

    public func replacing(
        jobID: ProcessingJobID? = nil,
        preserveJobIDWhenNil: Bool = true,
        state: DurableProcessingState? = nil,
        lastSnapshot: ProcessingSnapshot? = nil,
        preserveSnapshotWhenNil: Bool = true,
        resultArtifacts: [StemArtifact]? = nil,
        preserveArtifactsWhenNil: Bool = true,
        retryable: Bool? = nil,
        stableErrorCode: String? = nil,
        preserveErrorWhenNil: Bool = true,
        updatedAt: Date = Date()
    ) -> DurableProcessingRecord {
        DurableProcessingRecord(
            schemaVersion: schemaVersion,
            projectID: projectID,
            request: request,
            generationID: generationID,
            jobID: jobID ?? (preserveJobIDWhenNil ? self.jobID : nil),
            state: state ?? self.state,
            lastSnapshot: lastSnapshot ?? (preserveSnapshotWhenNil ? self.lastSnapshot : nil),
            resultArtifacts: resultArtifacts ?? (preserveArtifactsWhenNil ? self.resultArtifacts : nil),
            retryCount: retryCount,
            retryable: retryable ?? self.retryable,
            stableErrorCode: stableErrorCode ?? (preserveErrorWhenNil ? self.stableErrorCode : nil),
            updatedAt: updatedAt
        )
    }
}

public protocol ProcessingLifecycleStateStoring: Sendable {
    func load(projectID: ProjectID) async throws -> DurableProcessingRecord?
    func save(_ record: DurableProcessingRecord) async throws
    func remove(projectID: ProjectID) async throws
}

/// File-per-project durable state. `Data.write(.atomic)` prevents a torn JSON file from becoming
/// the canonical processing record after app termination or storage interruption.
public actor FileProcessingLifecycleStateStore: ProcessingLifecycleStateStoring {
    private let rootURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(appDataRoot: URL, fileManager: FileManager = .default) throws {
        let root = appDataRoot.resolvingSymlinksInPath().standardizedFileURL
        self.rootURL = root.appendingPathComponent("processing-state", isDirectory: true)
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    public func load(projectID: ProjectID) async throws -> DurableProcessingRecord? {
        let url = recordURL(projectID: projectID)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let record = try decoder.decode(DurableProcessingRecord.self, from: data)
            guard record.schemaVersion == 1 else {
                throw DomainFailure.processingFailed(code: "PROC_STATE_SCHEMA_UNSUPPORTED", retryable: false)
            }
            guard record.projectID == projectID else {
                throw DomainFailure.processingFailed(code: "PROC_STATE_PROJECT_MISMATCH", retryable: false)
            }
            return record
        } catch let failure as DomainFailure {
            throw failure
        } catch {
            throw DomainFailure.processingFailed(code: "PROC_STATE_CORRUPT", retryable: false)
        }
    }

    public func save(_ record: DurableProcessingRecord) async throws {
        let url = recordURL(projectID: record.projectID)
        do {
            let data = try encoder.encode(record)
            try data.write(to: url, options: [.atomic])
        } catch {
            throw DomainFailure.processingFailed(code: "PROC_STATE_WRITE_FAILED", retryable: true)
        }
    }

    public func remove(projectID: ProjectID) async throws {
        let url = recordURL(projectID: projectID)
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw DomainFailure.processingFailed(code: "PROC_STATE_REMOVE_FAILED", retryable: true)
        }
    }

    private func recordURL(projectID: ProjectID) -> URL {
        rootURL.appendingPathComponent(projectID.rawValue.uuidString + ".json", isDirectory: false)
    }
}

public protocol ProcessingOutputTransacting: Sendable {
    func begin(projectID: ProjectID, generationID: UUID) async throws
    func validateFinalArtifacts(_ artifacts: [StemArtifact], projectID: ProjectID) async throws
    func commit(projectID: ProjectID, generationID: UUID) async throws
    func rollback(projectID: ProjectID, generationID: UUID) async throws
}

/// Protects an existing stem set while a replacement job runs. The current separator finalizes
/// individual files, so the processing layer keeps a rollback copy until the complete result has
/// been persisted. First-run jobs have no backup cost. This can be replaced by job-scoped provider
/// staging once that becomes a shared separator contract.
public actor FileProcessingOutputTransaction: ProcessingOutputTransacting {
    private let appDataRoot: URL
    private let fileManager: FileManager

    public init(appDataRoot: URL, fileManager: FileManager = .default) {
        self.appDataRoot = appDataRoot.resolvingSymlinksInPath().standardizedFileURL
        self.fileManager = fileManager
    }

    public func begin(projectID: ProjectID, generationID: UUID) async throws {
        let transaction = transactionURL(projectID: projectID, generationID: generationID)
        let marker = transaction.appendingPathComponent("state.json")
        if fileManager.fileExists(atPath: marker.path) { return }

        do {
            try fileManager.createDirectory(at: transaction, withIntermediateDirectories: true)
            let final = finalStemDirectory(projectID: projectID)
            let hadExisting = fileManager.fileExists(atPath: final.path)
            if hadExisting {
                let backup = transaction.appendingPathComponent("previous", isDirectory: true)
                try fileManager.copyItem(at: final, to: backup)
            }
            let data = try JSONSerialization.data(withJSONObject: ["had_existing_outputs": hadExisting], options: [.sortedKeys])
            try data.write(to: marker, options: [.atomic])
        } catch {
            try? fileManager.removeItem(at: transaction)
            throw DomainFailure.processingFailed(code: "PROC_OUTPUT_TRANSACTION_BEGIN_FAILED", retryable: false)
        }
    }

    public func validateFinalArtifacts(_ artifacts: [StemArtifact], projectID: ProjectID) async throws {
        guard !artifacts.isEmpty else {
            throw DomainFailure.processingFailed(code: "PROC_RESULT_EMPTY", retryable: false)
        }
        let root = appDataRoot.resolvingSymlinksInPath().standardizedFileURL
        for artifact in artifacts {
            guard artifact.projectID == projectID,
                  !artifact.relativePath.isEmpty,
                  !artifact.relativePath.hasPrefix("/") else {
                throw DomainFailure.processingFailed(code: "PROC_RESULT_ARTIFACT_MISMATCH", retryable: false)
            }
            let candidate = root
                .appendingPathComponent(artifact.relativePath)
                .resolvingSymlinksInPath()
                .standardizedFileURL
            guard candidate.path.hasPrefix(root.path + "/") else {
                throw DomainFailure.processingFailed(code: "PROC_RESULT_OUTSIDE_APP_ROOT", retryable: false)
            }
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
                throw DomainFailure.processingFailed(code: "PROC_RESULT_FILE_MISSING", retryable: true)
            }
            let attributes = try fileManager.attributesOfItem(atPath: candidate.path)
            if let size = attributes[.size] as? NSNumber, size.int64Value <= 0 {
                throw DomainFailure.processingFailed(code: "PROC_RESULT_FILE_EMPTY", retryable: true)
            }
        }
    }

    public func commit(projectID: ProjectID, generationID: UUID) async throws {
        let transaction = transactionURL(projectID: projectID, generationID: generationID)
        guard fileManager.fileExists(atPath: transaction.path) else { return }
        do {
            try fileManager.removeItem(at: transaction)
        } catch {
            throw DomainFailure.processingFailed(code: "PROC_OUTPUT_TRANSACTION_COMMIT_FAILED", retryable: true)
        }
    }

    public func rollback(projectID: ProjectID, generationID: UUID) async throws {
        let transaction = transactionURL(projectID: projectID, generationID: generationID)
        let final = finalStemDirectory(projectID: projectID)

        do {
            if fileManager.fileExists(atPath: final.path) {
                try fileManager.removeItem(at: final)
            }
            let backup = transaction.appendingPathComponent("previous", isDirectory: true)
            if fileManager.fileExists(atPath: backup.path) {
                try fileManager.createDirectory(at: final.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileManager.moveItem(at: backup, to: final)
            }
            if fileManager.fileExists(atPath: transaction.path) {
                try fileManager.removeItem(at: transaction)
            }
        } catch {
            throw DomainFailure.processingFailed(code: "PROC_OUTPUT_TRANSACTION_ROLLBACK_FAILED", retryable: true)
        }
    }

    private func finalStemDirectory(projectID: ProjectID) -> URL {
        appDataRoot
            .appendingPathComponent("separation-stems", isDirectory: true)
            .appendingPathComponent(projectID.rawValue.uuidString, isDirectory: true)
    }

    private func transactionURL(projectID: ProjectID, generationID: UUID) -> URL {
        appDataRoot
            .appendingPathComponent("processing-backups", isDirectory: true)
            .appendingPathComponent(projectID.rawValue.uuidString, isDirectory: true)
            .appendingPathComponent(generationID.uuidString, isDirectory: true)
    }
}
