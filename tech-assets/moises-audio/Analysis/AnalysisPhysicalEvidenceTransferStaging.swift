import Foundation

public struct AnalysisPhysicalEvidenceTransferStagingMarker: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let transferID: String
    public let publicationID: String
    public let transferRootSHA256: String
    public let itemCount: Int
    public let runCount: Int

    public init(
        schemaVersion: Int = 1,
        transferID: String,
        publicationID: String,
        transferRootSHA256: String,
        itemCount: Int,
        runCount: Int
    ) {
        self.schemaVersion = schemaVersion
        self.transferID = transferID
        self.publicationID = publicationID
        self.transferRootSHA256 = transferRootSHA256.lowercased()
        self.itemCount = itemCount
        self.runCount = runCount
    }
}

public enum AnalysisPhysicalEvidenceTransferExporter {
    public static let stagingMarkerFileName = "W41_STAGING_MANIFEST.json"

    public static func publish(
        transferID: String,
        publicationID: String,
        archiveRootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalEvidenceTransferPublicationReceipt {
        guard AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(transferID) else {
            throw AnalysisPhysicalEvidenceTransferError.unsafeTransferID
        }
        let reopened = try AnalysisPhysicalEvidencePublishedBatchReopener.reopen(
            publicationID: publicationID,
            archiveRootURL: archiveRootURL,
            fileManager: fileManager
        )
        let snapshot = try AnalysisPhysicalEvidenceTransferManifestBuilder.build(
            transferID: transferID,
            reopened: reopened
        )

        let transfersRoot = archiveRootURL.appendingPathComponent("transfers", isDirectory: true)
        try ensureDirectory(transfersRoot, fileManager: fileManager)
        let finalDirectory = transfersRoot.appendingPathComponent(transferID, isDirectory: true)
        if fileManager.fileExists(atPath: finalDirectory.path) {
            throw AnalysisPhysicalEvidenceTransferError.existingTargetCollision
        }
        let stage = stagingDirectoryURL(snapshot: snapshot, archiveRootURL: archiveRootURL)
        try guardNoForeignStages(
            transferID: transferID,
            expectedStage: stage,
            transfersRoot: transfersRoot,
            fileManager: fileManager
        )
        let marker = stagingMarker(snapshot.manifest)
        var recovered = false

        if fileManager.fileExists(atPath: stage.path) {
            let markerURL = stage.appendingPathComponent(stagingMarkerFileName)
            guard let bytes = try? Data(contentsOf: markerURL),
                  let observed = try? JSONDecoder().decode(AnalysisPhysicalEvidenceTransferStagingMarker.self, from: bytes),
                  observed == marker else {
                throw AnalysisPhysicalEvidenceTransferError.ambiguousRecoveryState
            }
            do {
                try fileManager.removeItem(at: stage)
                recovered = true
            } catch {
                throw AnalysisPhysicalEvidenceTransferError.ambiguousRecoveryState
            }
        }

        do {
            try fileManager.createDirectory(at: stage, withIntermediateDirectories: false)
        } catch {
            throw AnalysisPhysicalEvidenceTransferError.stagingPathCollision
        }

        do {
            try encode(marker).write(to: stage.appendingPathComponent(stagingMarkerFileName), options: .atomic)
            try writeSnapshot(snapshot, to: stage, fileManager: fileManager)
            _ = try AnalysisPhysicalEvidenceTransferVerifier.verify(
                transferDirectoryURL: stage,
                allowedExtraRelativePath: stagingMarkerFileName,
                fileManager: fileManager
            )

            let fresh = try AnalysisPhysicalEvidencePublishedBatchReopener.reopen(
                publicationID: publicationID,
                archiveRootURL: archiveRootURL,
                fileManager: fileManager
            )
            let freshSnapshot = try AnalysisPhysicalEvidenceTransferManifestBuilder.build(
                transferID: transferID,
                reopened: fresh
            )
            guard freshSnapshot.manifest == snapshot.manifest else {
                throw AnalysisPhysicalEvidenceTransferError.sourceChangedDuringPublication
            }

            try fileManager.removeItem(at: stage.appendingPathComponent(stagingMarkerFileName))
            _ = try AnalysisPhysicalEvidenceTransferVerifier.verify(
                transferDirectoryURL: stage,
                fileManager: fileManager
            )
        } catch let error as AnalysisPhysicalEvidenceTransferError {
            throw error
        } catch {
            throw AnalysisPhysicalEvidenceTransferError.stagingWriteFailed
        }

        do {
            try fileManager.moveItem(at: stage, to: finalDirectory)
        } catch {
            throw AnalysisPhysicalEvidenceTransferError.publicationFailed
        }

        do {
            let verified = try AnalysisPhysicalEvidenceTransferVerifier.verify(
                transferDirectoryURL: finalDirectory,
                fileManager: fileManager
            )
            guard verified == snapshot.manifest else {
                throw AnalysisPhysicalEvidenceTransferError.publishedVerificationFailed
            }
            let fresh = try AnalysisPhysicalEvidencePublishedBatchReopener.reopen(
                publicationID: publicationID,
                archiveRootURL: archiveRootURL,
                fileManager: fileManager
            )
            let freshSnapshot = try AnalysisPhysicalEvidenceTransferManifestBuilder.build(
                transferID: transferID,
                reopened: fresh
            )
            guard freshSnapshot.manifest == snapshot.manifest else {
                throw AnalysisPhysicalEvidenceTransferError.sourceChangedDuringPublication
            }
        } catch let error as AnalysisPhysicalEvidenceTransferError {
            throw error
        } catch {
            throw AnalysisPhysicalEvidenceTransferError.publishedVerificationFailed
        }

        return .init(
            status: recovered ? .recoveredInterruptedStageAndPublished : .published,
            transferID: transferID,
            publicationID: publicationID,
            transferRootSHA256: snapshot.manifest.declaredTransferRootSHA256,
            finalRelativeDirectory: "transfers/\(transferID)",
            itemCount: snapshot.manifest.items.count,
            runCount: snapshot.manifest.runs.count
        )
    }

    public static func createInterruptedStageCheckpoint(
        transferID: String,
        publicationID: String,
        archiveRootURL: URL,
        fileManager: FileManager = .default
    ) throws {
        guard AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(transferID) else {
            throw AnalysisPhysicalEvidenceTransferError.unsafeTransferID
        }
        let reopened = try AnalysisPhysicalEvidencePublishedBatchReopener.reopen(
            publicationID: publicationID,
            archiveRootURL: archiveRootURL,
            fileManager: fileManager
        )
        let snapshot = try AnalysisPhysicalEvidenceTransferManifestBuilder.build(
            transferID: transferID,
            reopened: reopened
        )
        let transfersRoot = archiveRootURL.appendingPathComponent("transfers", isDirectory: true)
        try ensureDirectory(transfersRoot, fileManager: fileManager)
        let finalDirectory = transfersRoot.appendingPathComponent(transferID, isDirectory: true)
        guard !fileManager.fileExists(atPath: finalDirectory.path) else {
            throw AnalysisPhysicalEvidenceTransferError.existingTargetCollision
        }
        let stage = stagingDirectoryURL(snapshot: snapshot, archiveRootURL: archiveRootURL)
        try guardNoForeignStages(
            transferID: transferID,
            expectedStage: stage,
            transfersRoot: transfersRoot,
            fileManager: fileManager
        )
        guard !fileManager.fileExists(atPath: stage.path) else {
            throw AnalysisPhysicalEvidenceTransferError.stagingPathCollision
        }
        try fileManager.createDirectory(at: stage, withIntermediateDirectories: false)
        try encode(stagingMarker(snapshot.manifest)).write(
            to: stage.appendingPathComponent(stagingMarkerFileName),
            options: .atomic
        )
    }

    public static func stagingDirectoryURL(
        transferID: String,
        publicationID: String,
        archiveRootURL: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        let reopened = try AnalysisPhysicalEvidencePublishedBatchReopener.reopen(
            publicationID: publicationID,
            archiveRootURL: archiveRootURL,
            fileManager: fileManager
        )
        let snapshot = try AnalysisPhysicalEvidenceTransferManifestBuilder.build(
            transferID: transferID,
            reopened: reopened
        )
        return stagingDirectoryURL(snapshot: snapshot, archiveRootURL: archiveRootURL)
    }

    private static func stagingDirectoryURL(
        snapshot: AnalysisPhysicalEvidenceTransferSnapshot,
        archiveRootURL: URL
    ) -> URL {
        archiveRootURL
            .appendingPathComponent("transfers", isDirectory: true)
            .appendingPathComponent(
                ".w41-staging-\(snapshot.manifest.transferID)-\(String(snapshot.manifest.declaredTransferRootSHA256.prefix(16)))",
                isDirectory: true
            )
    }

    private static func guardNoForeignStages(
        transferID: String,
        expectedStage: URL,
        transfersRoot: URL,
        fileManager: FileManager
    ) throws {
        let prefix = ".w41-staging-\(transferID)-"
        let names: [String]
        do {
            names = try fileManager.contentsOfDirectory(atPath: transfersRoot.path)
        } catch {
            throw AnalysisPhysicalEvidenceTransferError.ambiguousRecoveryState
        }
        for name in names where name.hasPrefix(prefix) && name != expectedStage.lastPathComponent {
            throw AnalysisPhysicalEvidenceTransferError.ambiguousRecoveryState
        }
    }

    private static func writeSnapshot(
        _ snapshot: AnalysisPhysicalEvidenceTransferSnapshot,
        to directory: URL,
        fileManager: FileManager
    ) throws {
        guard snapshot.payloadBytesByPath.count == snapshot.manifest.items.count else {
            throw AnalysisPhysicalEvidenceTransferError.payloadInventoryMismatch
        }
        for item in snapshot.manifest.items {
            guard let bytes = snapshot.payloadBytesByPath[item.payloadRelativePath],
                  UInt64(bytes.count) == item.byteLength,
                  AnalysisDeviceWorkloadSHA256.hexDigest(bytes) == item.sha256.lowercased() else {
                throw AnalysisPhysicalEvidenceTransferError.missingOrInvalidPayload(item.payloadRelativePath)
            }
            let url = directory.appendingPathComponent(item.payloadRelativePath, isDirectory: false)
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard !fileManager.fileExists(atPath: url.path) else {
                throw AnalysisPhysicalEvidenceTransferError.stagingPathCollision
            }
            try bytes.write(to: url, options: .atomic)
        }
        try AnalysisPhysicalEvidenceTransferCodec.encodeManifest(snapshot.manifest).write(
            to: directory.appendingPathComponent(AnalysisPhysicalEvidenceTransferVerifier.manifestFileName),
            options: .atomic
        )
    }

    private static func stagingMarker(
        _ manifest: AnalysisPhysicalEvidenceTransferManifest
    ) -> AnalysisPhysicalEvidenceTransferStagingMarker {
        .init(
            transferID: manifest.transferID,
            publicationID: manifest.publicationID,
            transferRootSHA256: manifest.declaredTransferRootSHA256,
            itemCount: manifest.items.count,
            runCount: manifest.runs.count
        )
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private static func ensureDirectory(_ url: URL, fileManager: FileManager) throws {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else { throw AnalysisPhysicalEvidenceTransferError.stagingPathCollision }
            return
        }
        do { try fileManager.createDirectory(at: url, withIntermediateDirectories: true) }
        catch { throw AnalysisPhysicalEvidenceTransferError.stagingPathCollision }
    }
}
