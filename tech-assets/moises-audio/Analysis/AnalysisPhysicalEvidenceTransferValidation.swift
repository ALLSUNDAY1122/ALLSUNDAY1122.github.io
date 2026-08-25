import Foundation

public enum AnalysisPhysicalEvidenceTransferManifestBuilder {
    public static func build(
        transferID: String,
        reopened: AnalysisPhysicalEvidenceReopenedBatch
    ) throws -> AnalysisPhysicalEvidenceTransferSnapshot {
        guard AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(transferID) else {
            throw AnalysisPhysicalEvidenceTransferError.unsafeTransferID
        }
        guard AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(reopened.publicationID),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(reopened.w40RootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(reopened.w27RootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(reopened.w38RootSHA256),
              !reopened.runSummaries.isEmpty else {
            throw AnalysisPhysicalEvidenceTransferError.invalidReopenedBatch
        }

        var transferItems: [AnalysisPhysicalEvidenceTransferItem] = []
        var payloadBytes: [String: Data] = [:]
        var sourcePaths = Set<String>()
        var payloadPaths = Set<String>()
        for item in reopened.items {
            guard AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(item.sourceRelativePath),
                  sourcePaths.insert(item.sourceRelativePath).inserted,
                  !item.bytes.isEmpty,
                  item.byteLength == UInt64(item.bytes.count),
                  AnalysisDeviceWorkloadSHA256.hexDigest(item.bytes) == item.sha256 else {
                throw AnalysisPhysicalEvidenceTransferError.invalidReopenedBatch
            }
            let payloadPath = "payload/\(item.sourceRelativePath)"
            guard AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(payloadPath),
                  payloadPaths.insert(payloadPath).inserted else {
                throw AnalysisPhysicalEvidenceTransferError.invalidReopenedBatch
            }
            let record = AnalysisPhysicalEvidenceTransferItem(
                kind: item.kind,
                sourceRelativePath: item.sourceRelativePath,
                payloadRelativePath: payloadPath,
                runID: item.runID,
                role: item.role,
                sha256: item.sha256,
                byteLength: item.byteLength
            )
            transferItems.append(record)
            payloadBytes[payloadPath] = item.bytes
        }

        let provisional = AnalysisPhysicalEvidenceTransferManifest(
            transferID: transferID,
            publicationID: reopened.publicationID,
            w40RootSHA256: reopened.w40RootSHA256,
            w27RootSHA256: reopened.w27RootSHA256,
            w38RootSHA256: reopened.w38RootSHA256,
            runs: reopened.runSummaries,
            items: transferItems,
            declaredTransferRootSHA256: String(repeating: "0", count: 64)
        )
        let root = try AnalysisPhysicalEvidenceTransferRoot.compute(provisional)
        let manifest = AnalysisPhysicalEvidenceTransferManifest(
            transferID: transferID,
            publicationID: reopened.publicationID,
            w40RootSHA256: reopened.w40RootSHA256,
            w27RootSHA256: reopened.w27RootSHA256,
            w38RootSHA256: reopened.w38RootSHA256,
            runs: reopened.runSummaries,
            items: transferItems,
            declaredTransferRootSHA256: root
        )
        return .init(manifest: manifest, payloadBytesByPath: payloadBytes)
    }
}

public enum AnalysisPhysicalEvidenceTransferRoot {
    private struct Payload: Codable {
        let schemaVersion: Int
        let transferID: String
        let publicationID: String
        let w40RootSHA256: String
        let w27RootSHA256: String
        let w38RootSHA256: String
        let runs: [AnalysisPhysicalEvidenceBatchRunSummary]
        let items: [AnalysisPhysicalEvidenceTransferItem]
    }

    public static func compute(_ manifest: AnalysisPhysicalEvidenceTransferManifest) throws -> String {
        let payload = Payload(
            schemaVersion: manifest.schemaVersion,
            transferID: manifest.transferID,
            publicationID: manifest.publicationID,
            w40RootSHA256: manifest.w40RootSHA256.lowercased(),
            w27RootSHA256: manifest.w27RootSHA256.lowercased(),
            w38RootSHA256: manifest.w38RootSHA256.lowercased(),
            runs: manifest.runs.sorted { $0.runID < $1.runID },
            items: manifest.items.sorted {
                let lhs = "\($0.kind.rawValue)|\($0.runID ?? "")|\($0.role ?? "")|\($0.sourceRelativePath)|\($0.payloadRelativePath)|\($0.sha256)|\($0.byteLength)"
                let rhs = "\($1.kind.rawValue)|\($1.runID ?? "")|\($1.role ?? "")|\($1.sourceRelativePath)|\($1.payloadRelativePath)|\($1.sha256)|\($1.byteLength)"
                return lhs < rhs
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return AnalysisDeviceWorkloadSHA256.hexDigest(try encoder.encode(payload))
    }
}

public enum AnalysisPhysicalEvidenceTransferCodec {
    public static func encodeManifest(_ value: AnalysisPhysicalEvidenceTransferManifest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    public static func decodeManifest(_ data: Data) throws -> AnalysisPhysicalEvidenceTransferManifest {
        try JSONDecoder().decode(AnalysisPhysicalEvidenceTransferManifest.self, from: data)
    }
}

public enum AnalysisPhysicalEvidenceTransferVerifier {
    public static let manifestFileName = "W41_TRANSFER_MANIFEST.json"

    @discardableResult
    public static func verify(
        transferDirectoryURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalEvidenceTransferManifest {
        try verify(transferDirectoryURL: transferDirectoryURL, allowedExtraRelativePath: nil, fileManager: fileManager)
    }

    static func verify(
        transferDirectoryURL: URL,
        allowedExtraRelativePath: String?,
        fileManager: FileManager
    ) throws -> AnalysisPhysicalEvidenceTransferManifest {
        let manifestURL = transferDirectoryURL.appendingPathComponent(manifestFileName, isDirectory: false)
        let manifest: AnalysisPhysicalEvidenceTransferManifest
        do { manifest = try AnalysisPhysicalEvidenceTransferCodec.decodeManifest(Data(contentsOf: manifestURL)) }
        catch { throw AnalysisPhysicalEvidenceTransferError.invalidTransferManifest }

        let runIDs = manifest.runs.map(\.runID)
        let executionIDs = manifest.runs.map(\.workloadExecutionID)
        guard manifest.schemaVersion == 1,
              AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(manifest.transferID),
              AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(manifest.publicationID),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(manifest.w40RootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(manifest.w27RootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(manifest.w38RootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(manifest.declaredTransferRootSHA256),
              !runIDs.isEmpty,
              Set(runIDs).count == runIDs.count,
              Set(executionIDs).count == executionIDs.count else {
            throw AnalysisPhysicalEvidenceTransferError.invalidTransferManifest
        }

        let expectedCount = 18 + (10 * runIDs.count)
        var sourcePaths = Set<String>()
        var payloadPaths = Set<String>()
        guard manifest.items.count == expectedCount else {
            throw AnalysisPhysicalEvidenceTransferError.payloadInventoryMismatch
        }
        for item in manifest.items {
            guard AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(item.sourceRelativePath),
                  item.payloadRelativePath == "payload/\(item.sourceRelativePath)",
                  AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(item.payloadRelativePath),
                  sourcePaths.insert(item.sourceRelativePath).inserted,
                  payloadPaths.insert(item.payloadRelativePath).inserted,
                  AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(item.sha256),
                  item.byteLength > 0 else {
                throw AnalysisPhysicalEvidenceTransferError.invalidTransferManifest
            }
            let bytes: Data
            do {
                bytes = try AnalysisPhysicalEvidencePublishedBatchReopener.readStrict(
                    item.payloadRelativePath,
                    root: transferDirectoryURL,
                    fileManager: fileManager
                )
            } catch {
                throw AnalysisPhysicalEvidenceTransferError.missingOrInvalidPayload(item.payloadRelativePath)
            }
            guard UInt64(bytes.count) == item.byteLength,
                  AnalysisDeviceWorkloadSHA256.hexDigest(bytes) == item.sha256.lowercased() else {
                throw AnalysisPhysicalEvidenceTransferError.missingOrInvalidPayload(item.payloadRelativePath)
            }
        }

        let computedRoot = try AnalysisPhysicalEvidenceTransferRoot.compute(manifest)
        guard computedRoot == manifest.declaredTransferRootSHA256.lowercased() else {
            throw AnalysisPhysicalEvidenceTransferError.transferRootMismatch
        }

        try validatePhysicalFileInventory(
            transferDirectoryURL: transferDirectoryURL,
            manifest: manifest,
            allowedExtraRelativePath: allowedExtraRelativePath,
            fileManager: fileManager
        )

        let payloadRoot = transferDirectoryURL.appendingPathComponent("payload", isDirectory: true)
        let reopened: AnalysisPhysicalEvidenceReopenedBatch
        do {
            reopened = try AnalysisPhysicalEvidencePublishedBatchReopener.reopen(
                publicationID: manifest.publicationID,
                archiveRootURL: payloadRoot,
                fileManager: fileManager
            )
        } catch {
            throw AnalysisPhysicalEvidenceTransferError.destinationReopenFailed
        }
        guard reopened.w40RootSHA256 == manifest.w40RootSHA256.lowercased(),
              reopened.w27RootSHA256 == manifest.w27RootSHA256.lowercased(),
              reopened.w38RootSHA256 == manifest.w38RootSHA256.lowercased(),
              reopened.runSummaries == manifest.runs else {
            throw AnalysisPhysicalEvidenceTransferError.destinationRootDrift
        }

        let expected = try AnalysisPhysicalEvidenceTransferManifestBuilder.build(
            transferID: manifest.transferID,
            reopened: reopened
        ).manifest
        guard expected == manifest else {
            throw AnalysisPhysicalEvidenceTransferError.payloadInventoryMismatch
        }
        return manifest
    }

    private static func validatePhysicalFileInventory(
        transferDirectoryURL: URL,
        manifest: AnalysisPhysicalEvidenceTransferManifest,
        allowedExtraRelativePath: String?,
        fileManager: FileManager
    ) throws {
        var expected = Set(manifest.items.map(\.payloadRelativePath))
        expected.insert(manifestFileName)
        if let allowedExtraRelativePath { expected.insert(allowedExtraRelativePath) }

        guard let enumerator = fileManager.enumerator(
            at: transferDirectoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [],
            errorHandler: { _, _ in false }
        ) else {
            throw AnalysisPhysicalEvidenceTransferError.payloadInventoryMismatch
        }
        let rootPath = transferDirectoryURL.standardizedFileURL.path
        var observed = Set<String>()
        for case let url as URL in enumerator {
            let values: URLResourceValues
            do { values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) }
            catch { throw AnalysisPhysicalEvidenceTransferError.payloadInventoryMismatch }
            if values.isSymbolicLink == true {
                throw AnalysisPhysicalEvidenceTransferError.unexpectedPayload(relativePath(url, rootPath: rootPath))
            }
            guard values.isRegularFile == true else { continue }
            let path = relativePath(url, rootPath: rootPath)
            guard AnalysisPhysicalEvidenceW39BatchLoader.safeRelativePath(path) else {
                throw AnalysisPhysicalEvidenceTransferError.unexpectedPayload(path)
            }
            observed.insert(path)
        }
        for path in observed.subtracting(expected).sorted() {
            throw AnalysisPhysicalEvidenceTransferError.unexpectedPayload(path)
        }
        guard expected == observed else {
            let missing = expected.subtracting(observed).sorted().first ?? "unknown"
            throw AnalysisPhysicalEvidenceTransferError.missingOrInvalidPayload(missing)
        }
    }

    private static func relativePath(_ url: URL, rootPath: String) -> String {
        let path = url.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        return path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : path
    }
}
