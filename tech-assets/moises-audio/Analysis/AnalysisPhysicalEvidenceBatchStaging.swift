import Foundation

public enum AnalysisPhysicalEvidenceBatchStagingState: String, Codable, Sendable {
    case staging = "STAGING"
    case readyToPublish = "READY_TO_PUBLISH"
}

public struct AnalysisPhysicalEvidenceBatchSingletonRecord: Codable, Equatable, Sendable {
    public let role: AnalysisPhysicalEvidenceArtifactRole
    public let relativePath: String
    public let sha256: String
    public let byteLength: UInt64

    public init(role: AnalysisPhysicalEvidenceArtifactRole, relativePath: String, sha256: String, byteLength: UInt64) {
        self.role = role
        self.relativePath = relativePath
        self.sha256 = sha256.lowercased()
        self.byteLength = byteLength
    }
}

public struct AnalysisPhysicalEvidenceBatchStagingManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let state: AnalysisPhysicalEvidenceBatchStagingState
    public let publicationID: String
    public let batchRootSHA256: String
    public let w27ArchiveID: String
    public let w27RootSHA256: String
    public let w38ArchiveID: String
    public let w38RootSHA256: String
    public let runs: [AnalysisPhysicalEvidenceBatchRunSummary]
    public let singletons: [AnalysisPhysicalEvidenceBatchSingletonRecord]

    public init(
        schemaVersion: Int = 1,
        state: AnalysisPhysicalEvidenceBatchStagingState,
        publicationID: String,
        batchRootSHA256: String,
        w27ArchiveID: String,
        w27RootSHA256: String,
        w38ArchiveID: String,
        w38RootSHA256: String,
        runs: [AnalysisPhysicalEvidenceBatchRunSummary],
        singletons: [AnalysisPhysicalEvidenceBatchSingletonRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.state = state
        self.publicationID = publicationID
        self.batchRootSHA256 = batchRootSHA256.lowercased()
        self.w27ArchiveID = w27ArchiveID
        self.w27RootSHA256 = w27RootSHA256.lowercased()
        self.w38ArchiveID = w38ArchiveID
        self.w38RootSHA256 = w38RootSHA256.lowercased()
        self.runs = runs.sorted { $0.runID < $1.runID }
        self.singletons = singletons.sorted { $0.relativePath < $1.relativePath }
    }
}

public enum AnalysisPhysicalEvidenceBatchPublicationStatus: String, Codable, Sendable {
    case published = "PUBLISHED"
    case recoveredInterruptedStageAndPublished = "RECOVERED_INTERRUPTED_STAGE_AND_PUBLISHED"
}

public struct AnalysisPhysicalEvidenceBatchPublicationReceipt: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let status: AnalysisPhysicalEvidenceBatchPublicationStatus
    public let publicationID: String
    public let batchRootSHA256: String
    public let finalRelativeDirectory: String
    public let runCount: Int

    public init(
        schemaVersion: Int = 1,
        status: AnalysisPhysicalEvidenceBatchPublicationStatus,
        publicationID: String,
        batchRootSHA256: String,
        finalRelativeDirectory: String,
        runCount: Int
    ) {
        self.schemaVersion = schemaVersion
        self.status = status
        self.publicationID = publicationID
        self.batchRootSHA256 = batchRootSHA256.lowercased()
        self.finalRelativeDirectory = finalRelativeDirectory
        self.runCount = runCount
    }
}

public enum AnalysisPhysicalEvidenceBatchStagingError: Error, Equatable, Sendable {
    case invalidAssembly
    case archiveRootNotDirectory
    case existingTargetCollision
    case stagingPathCollision
    case ambiguousRecoveryState
    case stagingWriteFailed
    case stagedContentMismatch
    case publicationFailed
    case publishedContentMismatch
}

public enum AnalysisPhysicalEvidenceBatchStager {
    public static let stagingManifestFileName = "W40_STAGING_MANIFEST.json"
    public static let publicationManifestFileName = "W40_BATCH_MANIFEST.json"

    public static func publish(
        assembly: AnalysisPhysicalEvidenceBatchAssembly,
        archiveRootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalEvidenceBatchPublicationReceipt {
        guard AnalysisPhysicalEvidenceBatchAssemblyValidator.validate(assembly),
              revalidateW39RunInputs(assembly, archiveRootURL: archiveRootURL, fileManager: fileManager) else {
            throw AnalysisPhysicalEvidenceBatchStagingError.invalidAssembly
        }
        try ensureDirectory(archiveRootURL, allowCreate: true, fileManager: fileManager)
        let batchesRoot = archiveRootURL.appendingPathComponent("batches", isDirectory: true)
        try ensureDirectory(batchesRoot, allowCreate: true, fileManager: fileManager)

        let finalDirectory = batchesRoot.appendingPathComponent(assembly.publicationID, isDirectory: true)
        if fileManager.fileExists(atPath: finalDirectory.path) {
            throw AnalysisPhysicalEvidenceBatchStagingError.existingTargetCollision
        }

        let stageName = ".w40-staging-\(assembly.publicationID)-\(String(assembly.batchRootSHA256.prefix(16)))"
        let stagingDirectory = batchesRoot.appendingPathComponent(stageName, isDirectory: true)
        let expected = manifest(assembly, state: .staging)
        var recovered = false

        if fileManager.fileExists(atPath: stagingDirectory.path) {
            guard let observed = try? decodeManifest(Data(contentsOf: stagingDirectory.appendingPathComponent(stagingManifestFileName))),
                  identityMatches(observed, expected) else {
                throw AnalysisPhysicalEvidenceBatchStagingError.ambiguousRecoveryState
            }
            do {
                try fileManager.removeItem(at: stagingDirectory)
                recovered = true
            } catch {
                throw AnalysisPhysicalEvidenceBatchStagingError.ambiguousRecoveryState
            }
        }

        do {
            try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: false)
            try encodeManifest(expected).write(
                to: stagingDirectory.appendingPathComponent(stagingManifestFileName),
                options: .atomic
            )
            try writeSingletons(assembly, to: stagingDirectory, fileManager: fileManager)
            try writeArchiveDocuments(assembly, to: stagingDirectory)
            try verify(assembly, at: stagingDirectory)

            let ready = manifest(assembly, state: .readyToPublish)
            let readyBytes = try encodeManifest(ready)
            try readyBytes.write(to: stagingDirectory.appendingPathComponent(stagingManifestFileName), options: .atomic)
            try readyBytes.write(to: stagingDirectory.appendingPathComponent(publicationManifestFileName), options: .atomic)
            guard try decodeManifest(Data(contentsOf: stagingDirectory.appendingPathComponent(publicationManifestFileName))) == ready else {
                throw AnalysisPhysicalEvidenceBatchStagingError.stagedContentMismatch
            }
        } catch let error as AnalysisPhysicalEvidenceBatchStagingError {
            throw error
        } catch {
            throw AnalysisPhysicalEvidenceBatchStagingError.stagingWriteFailed
        }

        do {
            try fileManager.moveItem(at: stagingDirectory, to: finalDirectory)
        } catch {
            throw AnalysisPhysicalEvidenceBatchStagingError.publicationFailed
        }

        do {
            try verify(assembly, at: finalDirectory)
            let finalControl = try decodeManifest(
                Data(contentsOf: finalDirectory.appendingPathComponent(publicationManifestFileName))
            )
            guard finalControl.state == .readyToPublish,
                  identityMatches(finalControl, expected),
                  revalidateW39RunInputs(assembly, archiveRootURL: archiveRootURL, fileManager: fileManager) else {
                throw AnalysisPhysicalEvidenceBatchStagingError.publishedContentMismatch
            }
        } catch let error as AnalysisPhysicalEvidenceBatchStagingError {
            throw error
        } catch {
            throw AnalysisPhysicalEvidenceBatchStagingError.publishedContentMismatch
        }

        return .init(
            status: recovered ? .recoveredInterruptedStageAndPublished : .published,
            publicationID: assembly.publicationID,
            batchRootSHA256: assembly.batchRootSHA256,
            finalRelativeDirectory: "batches/\(assembly.publicationID)",
            runCount: assembly.runSummaries.count
        )
    }

    public static func createInterruptedStageCheckpoint(
        assembly: AnalysisPhysicalEvidenceBatchAssembly,
        archiveRootURL: URL,
        fileManager: FileManager = .default
    ) throws {
        guard AnalysisPhysicalEvidenceBatchAssemblyValidator.validate(assembly),
              revalidateW39RunInputs(assembly, archiveRootURL: archiveRootURL, fileManager: fileManager) else {
            throw AnalysisPhysicalEvidenceBatchStagingError.invalidAssembly
        }
        try ensureDirectory(archiveRootURL, allowCreate: true, fileManager: fileManager)
        let batchesRoot = archiveRootURL.appendingPathComponent("batches", isDirectory: true)
        try ensureDirectory(batchesRoot, allowCreate: true, fileManager: fileManager)
        let finalDirectory = batchesRoot.appendingPathComponent(assembly.publicationID, isDirectory: true)
        guard !fileManager.fileExists(atPath: finalDirectory.path) else {
            throw AnalysisPhysicalEvidenceBatchStagingError.existingTargetCollision
        }
        let stagingDirectory = stagingDirectoryURL(assembly: assembly, archiveRootURL: archiveRootURL)
        guard !fileManager.fileExists(atPath: stagingDirectory.path) else {
            throw AnalysisPhysicalEvidenceBatchStagingError.stagingPathCollision
        }
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: false)
        try encodeManifest(manifest(assembly, state: .staging)).write(
            to: stagingDirectory.appendingPathComponent(stagingManifestFileName),
            options: .atomic
        )
    }

    public static func stagingDirectoryURL(
        assembly: AnalysisPhysicalEvidenceBatchAssembly,
        archiveRootURL: URL
    ) -> URL {
        archiveRootURL
            .appendingPathComponent("batches", isDirectory: true)
            .appendingPathComponent(
                ".w40-staging-\(assembly.publicationID)-\(String(assembly.batchRootSHA256.prefix(16)))",
                isDirectory: true
            )
    }

    private static func revalidateW39RunInputs(
        _ assembly: AnalysisPhysicalEvidenceBatchAssembly,
        archiveRootURL: URL,
        fileManager: FileManager
    ) -> Bool {
        for summary in assembly.runSummaries {
            guard let bundle = try? AnalysisPhysicalEvidenceW39BatchLoader.load(
                runID: summary.runID,
                archiveRootURL: archiveRootURL,
                fileManager: fileManager
            ), bundle.runID == summary.runID,
               bundle.workloadExecutionID == summary.workloadExecutionID,
               bundle.bundleRootSHA256 == summary.w39BundleRootSHA256.lowercased() else {
                return false
            }
        }
        return true
    }

    private static func writeSingletons(
        _ assembly: AnalysisPhysicalEvidenceBatchAssembly,
        to stagingDirectory: URL,
        fileManager: FileManager
    ) throws {
        let prefix = "batches/\(assembly.publicationID)/"
        for singleton in assembly.singletons {
            guard singleton.relativePath.hasPrefix(prefix) else {
                throw AnalysisPhysicalEvidenceBatchStagingError.stagedContentMismatch
            }
            let suffix = String(singleton.relativePath.dropFirst(prefix.count))
            guard AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(suffix) else {
                throw AnalysisPhysicalEvidenceBatchStagingError.stagedContentMismatch
            }
            let target = stagingDirectory.appendingPathComponent(suffix, isDirectory: false)
            try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard !fileManager.fileExists(atPath: target.path) else {
                throw AnalysisPhysicalEvidenceBatchStagingError.stagedContentMismatch
            }
            try singleton.bytes.write(to: target, options: .atomic)
        }
    }

    private static func writeArchiveDocuments(
        _ assembly: AnalysisPhysicalEvidenceBatchAssembly,
        to directory: URL
    ) throws {
        try AnalysisPhysicalEvidenceArchiveCodec.encodePolicy(assembly.w27Policy).write(to: directory.appendingPathComponent("w27-policy.json"), options: .atomic)
        try AnalysisPhysicalEvidenceArchiveCodec.encodeManifest(assembly.w27Manifest).write(to: directory.appendingPathComponent("w27-manifest.json"), options: .atomic)
        try AnalysisPhysicalEvidenceArchiveCodec.encodeReport(assembly.w27Report).write(to: directory.appendingPathComponent("w27-report.json"), options: .atomic)
        try AnalysisPhysicalEvidenceArchiveChainCodec.encodePolicy(assembly.w38Policy).write(to: directory.appendingPathComponent("w38-policy.json"), options: .atomic)
        try AnalysisPhysicalEvidenceArchiveChainCodec.encodeManifest(assembly.w38Manifest).write(to: directory.appendingPathComponent("w38-manifest.json"), options: .atomic)
        try AnalysisPhysicalEvidenceArchiveChainCodec.encodeReport(assembly.w38Report).write(to: directory.appendingPathComponent("w38-report.json"), options: .atomic)
    }

    private static func verify(
        _ assembly: AnalysisPhysicalEvidenceBatchAssembly,
        at directory: URL
    ) throws {
        let prefix = "batches/\(assembly.publicationID)/"
        for singleton in assembly.singletons {
            let suffix = String(singleton.relativePath.dropFirst(prefix.count))
            let url = directory.appendingPathComponent(suffix, isDirectory: false)
            guard let bytes = try? Data(contentsOf: url),
                  UInt64(bytes.count) == singleton.byteLength,
                  AnalysisDeviceWorkloadSHA256.hexDigest(bytes) == singleton.sha256 else {
                throw AnalysisPhysicalEvidenceBatchStagingError.stagedContentMismatch
            }
        }
        guard try AnalysisPhysicalEvidenceArchiveCodec.decodePolicy(Data(contentsOf: directory.appendingPathComponent("w27-policy.json"))) == assembly.w27Policy,
              try AnalysisPhysicalEvidenceArchiveCodec.decodeManifest(Data(contentsOf: directory.appendingPathComponent("w27-manifest.json"))) == assembly.w27Manifest,
              try AnalysisPhysicalEvidenceArchiveCodec.decodeReport(Data(contentsOf: directory.appendingPathComponent("w27-report.json"))) == assembly.w27Report,
              try AnalysisPhysicalEvidenceArchiveChainCodec.decodePolicy(Data(contentsOf: directory.appendingPathComponent("w38-policy.json"))) == assembly.w38Policy,
              try AnalysisPhysicalEvidenceArchiveChainCodec.decodeManifest(Data(contentsOf: directory.appendingPathComponent("w38-manifest.json"))) == assembly.w38Manifest,
              try AnalysisPhysicalEvidenceArchiveChainCodec.decodeReport(Data(contentsOf: directory.appendingPathComponent("w38-report.json"))) == assembly.w38Report else {
            throw AnalysisPhysicalEvidenceBatchStagingError.stagedContentMismatch
        }
    }

    private static func manifest(
        _ assembly: AnalysisPhysicalEvidenceBatchAssembly,
        state: AnalysisPhysicalEvidenceBatchStagingState
    ) -> AnalysisPhysicalEvidenceBatchStagingManifest {
        .init(
            state: state,
            publicationID: assembly.publicationID,
            batchRootSHA256: assembly.batchRootSHA256,
            w27ArchiveID: assembly.w27Manifest.archiveID,
            w27RootSHA256: assembly.w27Manifest.declaredRootSHA256,
            w38ArchiveID: assembly.w38Manifest.archiveID,
            w38RootSHA256: assembly.w38Manifest.declaredRootSHA256,
            runs: assembly.runSummaries,
            singletons: assembly.singletons.map {
                .init(role: $0.role, relativePath: $0.relativePath, sha256: $0.sha256, byteLength: $0.byteLength)
            }
        )
    }

    private static func identityMatches(
        _ lhs: AnalysisPhysicalEvidenceBatchStagingManifest,
        _ rhs: AnalysisPhysicalEvidenceBatchStagingManifest
    ) -> Bool {
        lhs.schemaVersion == 1
            && rhs.schemaVersion == 1
            && lhs.publicationID == rhs.publicationID
            && lhs.batchRootSHA256 == rhs.batchRootSHA256
            && lhs.w27ArchiveID == rhs.w27ArchiveID
            && lhs.w27RootSHA256 == rhs.w27RootSHA256
            && lhs.w38ArchiveID == rhs.w38ArchiveID
            && lhs.w38RootSHA256 == rhs.w38RootSHA256
            && lhs.runs == rhs.runs
            && lhs.singletons == rhs.singletons
    }

    private static func encodeManifest(_ value: AnalysisPhysicalEvidenceBatchStagingManifest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private static func decodeManifest(_ data: Data) throws -> AnalysisPhysicalEvidenceBatchStagingManifest {
        try JSONDecoder().decode(AnalysisPhysicalEvidenceBatchStagingManifest.self, from: data)
    }

    private static func ensureDirectory(
        _ url: URL,
        allowCreate: Bool,
        fileManager: FileManager
    ) throws {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else { throw AnalysisPhysicalEvidenceBatchStagingError.archiveRootNotDirectory }
            return
        }
        guard allowCreate else { throw AnalysisPhysicalEvidenceBatchStagingError.archiveRootNotDirectory }
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw AnalysisPhysicalEvidenceBatchStagingError.archiveRootNotDirectory
        }
    }
}
