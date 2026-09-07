import Foundation

public struct AnalysisPhysicalCaptureArtifactStagingRecord: Codable, Equatable, Sendable {
    public let role: AnalysisPhysicalCaptureArtifactRole
    public let relativePath: String
    public let sha256: String
    public let byteLength: UInt64

    public init(role: AnalysisPhysicalCaptureArtifactRole, relativePath: String, sha256: String, byteLength: UInt64) {
        self.role = role
        self.relativePath = relativePath
        self.sha256 = sha256.lowercased()
        self.byteLength = byteLength
    }
}

public enum AnalysisPhysicalCaptureArtifactStagingState: String, Codable, Sendable {
    case staging = "STAGING"
    case readyToPublish = "READY_TO_PUBLISH"
}

public struct AnalysisPhysicalCaptureArtifactStagingManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let state: AnalysisPhysicalCaptureArtifactStagingState
    public let runID: String
    public let workloadExecutionID: String
    public let bundleRootSHA256: String
    public let artifacts: [AnalysisPhysicalCaptureArtifactStagingRecord]

    public init(
        schemaVersion: Int = 1,
        state: AnalysisPhysicalCaptureArtifactStagingState,
        runID: String,
        workloadExecutionID: String,
        bundleRootSHA256: String,
        artifacts: [AnalysisPhysicalCaptureArtifactStagingRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.state = state
        self.runID = runID
        self.workloadExecutionID = workloadExecutionID
        self.bundleRootSHA256 = bundleRootSHA256.lowercased()
        self.artifacts = artifacts.sorted { $0.relativePath < $1.relativePath }
    }
}

public enum AnalysisPhysicalCaptureArtifactPublicationStatus: String, Codable, Sendable {
    case published = "PUBLISHED"
    case recoveredInterruptedStageAndPublished = "RECOVERED_INTERRUPTED_STAGE_AND_PUBLISHED"
}

public struct AnalysisPhysicalCaptureArtifactPublicationReceipt: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let status: AnalysisPhysicalCaptureArtifactPublicationStatus
    public let runID: String
    public let workloadExecutionID: String
    public let bundleRootSHA256: String
    public let finalRelativeDirectory: String
    public let artifactCount: Int

    public init(
        schemaVersion: Int = 1,
        status: AnalysisPhysicalCaptureArtifactPublicationStatus,
        runID: String,
        workloadExecutionID: String,
        bundleRootSHA256: String,
        finalRelativeDirectory: String,
        artifactCount: Int
    ) {
        self.schemaVersion = schemaVersion
        self.status = status
        self.runID = runID
        self.workloadExecutionID = workloadExecutionID
        self.bundleRootSHA256 = bundleRootSHA256.lowercased()
        self.finalRelativeDirectory = finalRelativeDirectory
        self.artifactCount = artifactCount
    }
}

public enum AnalysisPhysicalCaptureArtifactStagingError: Error, Equatable, Sendable {
    case invalidBundle
    case archiveRootNotDirectory
    case existingTargetCollision
    case ambiguousRecoveryState
    case stagingPathCollision
    case unsafeArtifactPath
    case artifactOutsideRunDirectory
    case duplicateArtifactPath
    case stagingWriteFailed
    case stagedArtifactMismatch
    case publicationFailed
    case publishedArtifactMismatch
}

public enum AnalysisPhysicalCaptureArtifactStager {
    public static let stagingManifestFileName = "W39_STAGING_MANIFEST.json"
    public static let publicationManifestFileName = "W39_BUNDLE_MANIFEST.json"

    public static func publish(
        bundle: AnalysisPhysicalCaptureArtifactBundle,
        archiveRootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalCaptureArtifactPublicationReceipt {
        let validation = AnalysisPhysicalCaptureArtifactBundleValidator.validate(bundle)
        guard validation.valid else {
            throw AnalysisPhysicalCaptureArtifactStagingError.invalidBundle
        }

        try ensureArchiveRoot(archiveRootURL, fileManager: fileManager)
        let runsRoot = archiveRootURL.appendingPathComponent("runs", isDirectory: true)
        try ensureDirectory(runsRoot, fileManager: fileManager)

        let finalDirectory = runsRoot.appendingPathComponent(bundle.runID, isDirectory: true)
        if fileManager.fileExists(atPath: finalDirectory.path) {
            throw AnalysisPhysicalCaptureArtifactStagingError.existingTargetCollision
        }

        let stageName = ".w39-staging-\(bundle.runID)-\(String(bundle.bundleRootSHA256.prefix(16)))"
        let stagingDirectory = runsRoot.appendingPathComponent(stageName, isDirectory: true)
        let expectedManifest = manifest(bundle: bundle, state: .staging)
        var recoveredInterruptedStage = false

        if fileManager.fileExists(atPath: stagingDirectory.path) {
            guard let existing = try? decodeManifest(
                Data(contentsOf: stagingDirectory.appendingPathComponent(stagingManifestFileName))
            ), manifestIdentityMatches(existing, expectedManifest) else {
                throw AnalysisPhysicalCaptureArtifactStagingError.ambiguousRecoveryState
            }
            do {
                try fileManager.removeItem(at: stagingDirectory)
                recoveredInterruptedStage = true
            } catch {
                throw AnalysisPhysicalCaptureArtifactStagingError.ambiguousRecoveryState
            }
        }

        do {
            try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: false)
        } catch {
            throw AnalysisPhysicalCaptureArtifactStagingError.stagingPathCollision
        }

        do {
            let stagingManifestURL = stagingDirectory.appendingPathComponent(stagingManifestFileName)
            try encodeManifest(expectedManifest).write(to: stagingManifestURL, options: .atomic)
            try writeArtifacts(bundle, stagingDirectory: stagingDirectory, fileManager: fileManager)
            try verifyArtifacts(bundle, directory: stagingDirectory)

            let readyManifest = manifest(bundle: bundle, state: .readyToPublish)
            let readyBytes = try encodeManifest(readyManifest)
            try readyBytes.write(
                to: stagingDirectory.appendingPathComponent(stagingManifestFileName),
                options: .atomic
            )
            try readyBytes.write(
                to: stagingDirectory.appendingPathComponent(publicationManifestFileName),
                options: .atomic
            )

            let decodedReady = try decodeManifest(Data(contentsOf: stagingDirectory.appendingPathComponent(publicationManifestFileName)))
            guard decodedReady == readyManifest else {
                throw AnalysisPhysicalCaptureArtifactStagingError.stagedArtifactMismatch
            }
        } catch let error as AnalysisPhysicalCaptureArtifactStagingError {
            throw error
        } catch {
            throw AnalysisPhysicalCaptureArtifactStagingError.stagingWriteFailed
        }

        do {
            try fileManager.moveItem(at: stagingDirectory, to: finalDirectory)
        } catch {
            throw AnalysisPhysicalCaptureArtifactStagingError.publicationFailed
        }

        do {
            try verifyArtifacts(bundle, directory: finalDirectory)
            let finalManifest = try decodeManifest(
                Data(contentsOf: finalDirectory.appendingPathComponent(publicationManifestFileName))
            )
            guard finalManifest.state == .readyToPublish,
                  manifestIdentityMatches(finalManifest, expectedManifest) else {
                throw AnalysisPhysicalCaptureArtifactStagingError.publishedArtifactMismatch
            }
        } catch let error as AnalysisPhysicalCaptureArtifactStagingError {
            throw error
        } catch {
            throw AnalysisPhysicalCaptureArtifactStagingError.publishedArtifactMismatch
        }

        return .init(
            status: recoveredInterruptedStage ? .recoveredInterruptedStageAndPublished : .published,
            runID: bundle.runID,
            workloadExecutionID: bundle.workloadExecutionID,
            bundleRootSHA256: bundle.bundleRootSHA256,
            finalRelativeDirectory: "runs/\(bundle.runID)",
            artifactCount: bundle.artifacts.count
        )
    }

    /// Creates only the deterministic staging marker. This is useful for tests
    /// and for hosts that need to checkpoint before an externally interruptible
    /// write sequence. A later `publish` call recognizes this exact marker,
    /// removes the incomplete stage, and starts cleanly.
    public static func createInterruptedStageCheckpoint(
        bundle: AnalysisPhysicalCaptureArtifactBundle,
        archiveRootURL: URL,
        fileManager: FileManager = .default
    ) throws {
        let validation = AnalysisPhysicalCaptureArtifactBundleValidator.validate(bundle)
        guard validation.valid else {
            throw AnalysisPhysicalCaptureArtifactStagingError.invalidBundle
        }
        try ensureArchiveRoot(archiveRootURL, fileManager: fileManager)
        let runsRoot = archiveRootURL.appendingPathComponent("runs", isDirectory: true)
        try ensureDirectory(runsRoot, fileManager: fileManager)
        let finalDirectory = runsRoot.appendingPathComponent(bundle.runID, isDirectory: true)
        guard !fileManager.fileExists(atPath: finalDirectory.path) else {
            throw AnalysisPhysicalCaptureArtifactStagingError.existingTargetCollision
        }
        let stageName = ".w39-staging-\(bundle.runID)-\(String(bundle.bundleRootSHA256.prefix(16)))"
        let stagingDirectory = runsRoot.appendingPathComponent(stageName, isDirectory: true)
        guard !fileManager.fileExists(atPath: stagingDirectory.path) else {
            throw AnalysisPhysicalCaptureArtifactStagingError.stagingPathCollision
        }
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: false)
        let bytes = try encodeManifest(manifest(bundle: bundle, state: .staging))
        try bytes.write(to: stagingDirectory.appendingPathComponent(stagingManifestFileName), options: .atomic)
    }

    public static func stagingDirectoryURL(
        bundle: AnalysisPhysicalCaptureArtifactBundle,
        archiveRootURL: URL
    ) -> URL {
        archiveRootURL
            .appendingPathComponent("runs", isDirectory: true)
            .appendingPathComponent(
                ".w39-staging-\(bundle.runID)-\(String(bundle.bundleRootSHA256.prefix(16)))",
                isDirectory: true
            )
    }

    private static func writeArtifacts(
        _ bundle: AnalysisPhysicalCaptureArtifactBundle,
        stagingDirectory: URL,
        fileManager: FileManager
    ) throws {
        var seen = Set<String>()
        let prefix = "runs/\(bundle.runID)/"
        for artifact in bundle.artifacts.sorted(by: { $0.relativePath < $1.relativePath }) {
            guard safeRelativePath(artifact.relativePath) else {
                throw AnalysisPhysicalCaptureArtifactStagingError.unsafeArtifactPath
            }
            guard artifact.relativePath.hasPrefix(prefix) else {
                throw AnalysisPhysicalCaptureArtifactStagingError.artifactOutsideRunDirectory
            }
            guard seen.insert(artifact.relativePath).inserted else {
                throw AnalysisPhysicalCaptureArtifactStagingError.duplicateArtifactPath
            }
            let suffix = String(artifact.relativePath.dropFirst(prefix.count))
            guard safeRelativePath(suffix) else {
                throw AnalysisPhysicalCaptureArtifactStagingError.unsafeArtifactPath
            }
            let target = stagingDirectory.appendingPathComponent(suffix, isDirectory: false)
            try fileManager.createDirectory(
                at: target.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if fileManager.fileExists(atPath: target.path) {
                throw AnalysisPhysicalCaptureArtifactStagingError.stagingPathCollision
            }
            try artifact.bytes.write(to: target, options: .atomic)
        }
    }

    private static func verifyArtifacts(
        _ bundle: AnalysisPhysicalCaptureArtifactBundle,
        directory: URL
    ) throws {
        let prefix = "runs/\(bundle.runID)/"
        for artifact in bundle.artifacts {
            guard artifact.relativePath.hasPrefix(prefix) else {
                throw AnalysisPhysicalCaptureArtifactStagingError.artifactOutsideRunDirectory
            }
            let suffix = String(artifact.relativePath.dropFirst(prefix.count))
            let url = directory.appendingPathComponent(suffix)
            guard let bytes = try? Data(contentsOf: url),
                  UInt64(bytes.count) == artifact.byteLength,
                  AnalysisDeviceWorkloadSHA256.hexDigest(bytes) == artifact.sha256 else {
                throw AnalysisPhysicalCaptureArtifactStagingError.stagedArtifactMismatch
            }
        }
    }

    private static func manifest(
        bundle: AnalysisPhysicalCaptureArtifactBundle,
        state: AnalysisPhysicalCaptureArtifactStagingState
    ) -> AnalysisPhysicalCaptureArtifactStagingManifest {
        .init(
            state: state,
            runID: bundle.runID,
            workloadExecutionID: bundle.workloadExecutionID,
            bundleRootSHA256: bundle.bundleRootSHA256,
            artifacts: bundle.artifacts.map {
                .init(role: $0.role, relativePath: $0.relativePath, sha256: $0.sha256, byteLength: $0.byteLength)
            }
        )
    }

    private static func manifestIdentityMatches(
        _ lhs: AnalysisPhysicalCaptureArtifactStagingManifest,
        _ rhs: AnalysisPhysicalCaptureArtifactStagingManifest
    ) -> Bool {
        lhs.schemaVersion == 1
            && rhs.schemaVersion == 1
            && lhs.runID == rhs.runID
            && lhs.workloadExecutionID == rhs.workloadExecutionID
            && lhs.bundleRootSHA256 == rhs.bundleRootSHA256
            && lhs.artifacts == rhs.artifacts
    }

    private static func encodeManifest(_ value: AnalysisPhysicalCaptureArtifactStagingManifest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private static func decodeManifest(_ data: Data) throws -> AnalysisPhysicalCaptureArtifactStagingManifest {
        try JSONDecoder().decode(AnalysisPhysicalCaptureArtifactStagingManifest.self, from: data)
    }

    private static func ensureArchiveRoot(_ url: URL, fileManager: FileManager) throws {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw AnalysisPhysicalCaptureArtifactStagingError.archiveRootNotDirectory
            }
        } else {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                throw AnalysisPhysicalCaptureArtifactStagingError.archiveRootNotDirectory
            }
        }
    }

    private static func ensureDirectory(_ url: URL, fileManager: FileManager) throws {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw AnalysisPhysicalCaptureArtifactStagingError.archiveRootNotDirectory
            }
            return
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private static func safeRelativePath(_ value: String) -> Bool {
        guard !value.isEmpty,
              value == value.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.hasPrefix("/"),
              !value.hasPrefix("\\"),
              !value.contains("\\"),
              !value.contains("//") else { return false }
        return value.split(separator: "/", omittingEmptySubsequences: false).allSatisfy {
            !$0.isEmpty && $0 != "." && $0 != ".."
        }
    }
}
