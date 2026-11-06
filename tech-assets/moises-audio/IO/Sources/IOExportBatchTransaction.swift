import Foundation

/// Crash-safe all-or-nothing publication for a group of exported stems.
///
/// All encoded outputs are written into one staging directory. Commit is a
/// same-volume directory rename into Exports/Batches, so readers never observe
/// a partially published batch. A hidden pre-registration marker crosses the
/// rename with the batch so a crash before Library registration is detectable.
public struct IOExportBatchTransaction: Sendable {
    public enum BatchError: Error, Equatable, Sendable {
        case emptyBatch
        case invalidExtension
        case invalidPlan
        case outputMissing(filename: String)
        case outputNotRegularFile(filename: String)
        case outputEmpty(filename: String)
        case destinationConflict
        case integrityManifestInvalid
        case integrityMismatch(filename: String)
        case fileOperationFailed(code: String)
    }

    public struct PlannedItem: Equatable, Sendable {
        public let filename: String
        public let stagingURL: URL

        public init(filename: String, stagingURL: URL) {
            self.filename = filename
            self.stagingURL = stagingURL
        }
    }

    public struct Plan: Equatable, Sendable {
        public let id: String
        public let stagingDirectoryURL: URL
        public let items: [PlannedItem]

        public init(id: String, stagingDirectoryURL: URL, items: [PlannedItem]) {
            self.id = id
            self.stagingDirectoryURL = stagingDirectoryURL
            self.items = items
        }
    }

    private struct IntegrityItem: Codable, Equatable, Sendable {
        let filename: String
        let byteCount: UInt64
        let contentDigest: UInt64
    }

    private struct IntegrityManifest: Codable, Equatable, Sendable {
        static let schemaVersion = 1
        let schemaVersion: Int
        let batchID: String
        let items: [IntegrityItem]
    }

    public static let preRegistrationMarkerFilename = ".lane2-registration-pending"
    public static let integrityManifestFilename = ".lane2-batch-integrity-v1.json"
    public static let publicationSessionID = UUID().uuidString.lowercased()

    private let fileStore: IOFileStore
    private let stagingBatchDirectoryName = "ExportBatches"
    private let finalizedBatchDirectoryName = "Batches"

    public init(fileStore: IOFileStore) {
        self.fileStore = fileStore
    }

    private var pathBoundary: IOManagedPathBoundary {
        IOManagedPathBoundary(rootURL: fileStore.rootURL)
    }

    public var stagingBatchesURL: URL {
        fileStore.stagingURL.appendingPathComponent(stagingBatchDirectoryName, isDirectory: true)
    }

    public var finalizedBatchesURL: URL {
        fileStore.exportsURL.appendingPathComponent(finalizedBatchDirectoryName, isDirectory: true)
    }

    public func prepare(
        suggestedFilenameStems: [String],
        fileExtension rawExtension: String,
        fileManager: FileManager = .default
    ) throws -> Plan {
        guard !suggestedFilenameStems.isEmpty else { throw BatchError.emptyBatch }

        let fileExtension = rawExtension
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
            .lowercased()
        guard !fileExtension.isEmpty,
              !fileExtension.contains("/"),
              !fileExtension.contains("\\") else {
            throw BatchError.invalidExtension
        }

        do {
            try fileStore.prepareDirectories(fileManager: fileManager)
            try pathBoundary.ensureDirectory(stagingBatchesURL, fileManager: fileManager)
            try pathBoundary.ensureDirectory(finalizedBatchesURL, fileManager: fileManager)
        } catch {
            throw BatchError.fileOperationFailed(code: "EXPORT_BATCH_DIRECTORY_CREATE_FAILED")
        }

        let id = UUID().uuidString.lowercased()
        let batchURL = stagingBatchesURL.appendingPathComponent(id, isDirectory: true)
        do {
            try pathBoundary.requireSafeDestination(
                batchURL,
                within: stagingBatchesURL,
                fileManager: fileManager
            )
            try fileManager.createDirectory(at: batchURL, withIntermediateDirectories: false)
            try pathBoundary.requireDirectory(batchURL, fileManager: fileManager)
        } catch {
            throw BatchError.fileOperationFailed(code: "EXPORT_BATCH_STAGE_CREATE_FAILED")
        }

        var occurrences: [String: Int] = [:]
        let items = suggestedFilenameStems.map { rawStem -> PlannedItem in
            let stem = IOFileStore.sanitizedFilenameStem(rawStem)
            let normalizedKey = stem.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            let occurrence = (occurrences[normalizedKey] ?? 0) + 1
            occurrences[normalizedKey] = occurrence
            let suffix = occurrence == 1 ? "" : " (\(occurrence))"
            let filename = "\(stem)\(suffix).\(fileExtension)"
            return PlannedItem(filename: filename, stagingURL: batchURL.appendingPathComponent(filename))
        }

        return Plan(id: id, stagingDirectoryURL: batchURL, items: items)
    }

    /// Atomically publishes the entire batch using one directory move. A durable integrity manifest
    /// is written before the rename and read back against the published files after the rename.
    public func commit(
        _ plan: Plan,
        fileManager: FileManager = .default
    ) throws -> [IOFileStore.FinalizedFile] {
        guard isDirectChild(plan.stagingDirectoryURL, of: stagingBatchesURL),
              plan.stagingDirectoryURL.lastPathComponent == plan.id,
              !plan.items.isEmpty,
              plan.items.allSatisfy({ isDirectChild($0.stagingURL, of: plan.stagingDirectoryURL) }) else {
            throw BatchError.invalidPlan
        }

        do {
            try pathBoundary.requireDirectory(stagingBatchesURL, fileManager: fileManager)
            try pathBoundary.requireDirectory(finalizedBatchesURL, fileManager: fileManager)
            try pathBoundary.requireDirectory(plan.stagingDirectoryURL, fileManager: fileManager)
        } catch {
            throw BatchError.invalidPlan
        }

        var fingerprints: [IntegrityItem] = []
        fingerprints.reserveCapacity(plan.items.count)
        for item in plan.items {
            fingerprints.append(
                try fingerprint(
                    itemURL: item.stagingURL,
                    filename: item.filename,
                    fileManager: fileManager
                )
            )
        }
        let manifest = IntegrityManifest(
            schemaVersion: IntegrityManifest.schemaVersion,
            batchID: plan.id,
            items: fingerprints.sorted { $0.filename < $1.filename }
        )
        try persistManifest(manifest, directory: plan.stagingDirectoryURL, fileManager: fileManager)

        let finalDirectoryURL = finalizedBatchesURL.appendingPathComponent(plan.id, isDirectory: true)
        do {
            try pathBoundary.requireSafeDestination(
                finalDirectoryURL,
                within: finalizedBatchesURL,
                fileManager: fileManager
            )
        } catch IOManagedPathBoundaryFailure.destinationExists {
            throw BatchError.destinationConflict
        } catch {
            throw BatchError.fileOperationFailed(code: "EXPORT_BATCH_FINAL_DESTINATION_UNSAFE")
        }

        let markerURL = plan.stagingDirectoryURL.appendingPathComponent(Self.preRegistrationMarkerFilename)
        do {
            try pathBoundary.requireSafeDestination(
                markerURL,
                within: plan.stagingDirectoryURL,
                fileManager: fileManager
            )
            guard fileManager.createFile(
                atPath: markerURL.path,
                contents: Data((Self.publicationSessionID + "\n").utf8)
            ) else {
                throw BatchError.fileOperationFailed(code: "EXPORT_BATCH_MARKER_CREATE_FAILED")
            }
            try pathBoundary.requireExistingRegularFile(
                markerURL,
                within: plan.stagingDirectoryURL,
                fileManager: fileManager
            )
            let markerHandle = try FileHandle(forWritingTo: markerURL)
            try markerHandle.synchronize()
            try markerHandle.close()
        } catch let error as BatchError {
            throw error
        } catch {
            throw BatchError.fileOperationFailed(code: "EXPORT_BATCH_MARKER_CREATE_FAILED")
        }

        do {
            // Narrow the validation-to-rename race: both source and destination parents are checked
            // immediately before the same-volume publication rename.
            try pathBoundary.requireDirectory(plan.stagingDirectoryURL, fileManager: fileManager)
            try pathBoundary.requireSafeDestination(
                finalDirectoryURL,
                within: finalizedBatchesURL,
                fileManager: fileManager
            )
            try fileManager.moveItem(at: plan.stagingDirectoryURL, to: finalDirectoryURL)
            try pathBoundary.requireDirectory(finalDirectoryURL, fileManager: fileManager)
        } catch {
            throw BatchError.fileOperationFailed(code: "EXPORT_BATCH_COMMIT_MOVE_FAILED")
        }

        do {
            return try verifyPublishedBatch(batchID: plan.id, fileManager: fileManager)
        } catch {
            // Never traverse a replacement symlink while compensating a failed verification.
            if (try? pathBoundary.requireDirectory(finalDirectoryURL, fileManager: fileManager)) != nil {
                try? fileManager.removeItem(at: finalDirectoryURL)
            }
            throw error
        }
    }

    /// Verifies a previously published batch against its durable manifest. This can be used by
    /// registration/share recovery before exposing files after a relaunch.
    public func verifyPublishedBatch(
        batchID: String,
        fileManager: FileManager = .default
    ) throws -> [IOFileStore.FinalizedFile] {
        guard !batchID.isEmpty,
              !batchID.contains("/"),
              !batchID.contains("\\") else {
            throw BatchError.integrityManifestInvalid
        }
        let directory = finalizedBatchesURL.appendingPathComponent(batchID, isDirectory: true)
        guard isDirectChild(directory, of: finalizedBatchesURL) else {
            throw BatchError.integrityManifestInvalid
        }
        do {
            try pathBoundary.requireDirectory(finalizedBatchesURL, fileManager: fileManager)
            try pathBoundary.requireDirectory(directory, fileManager: fileManager)
        } catch {
            throw BatchError.integrityManifestInvalid
        }

        let manifest = try loadManifest(directory: directory, fileManager: fileManager)
        guard manifest.schemaVersion == IntegrityManifest.schemaVersion,
              manifest.batchID == batchID,
              !manifest.items.isEmpty else {
            throw BatchError.integrityManifestInvalid
        }

        var seen = Set<String>()
        var expectedNames = Set<String>()
        var finalized: [IOFileStore.FinalizedFile] = []
        for expected in manifest.items.sorted(by: { $0.filename < $1.filename }) {
            guard isSafeLeafFilename(expected.filename), seen.insert(expected.filename).inserted else {
                throw BatchError.integrityManifestInvalid
            }
            expectedNames.insert(expected.filename)
            let url = directory.appendingPathComponent(expected.filename, isDirectory: false)
            let actual = try fingerprint(itemURL: url, filename: expected.filename, fileManager: fileManager)
            guard actual == expected else {
                throw BatchError.integrityMismatch(filename: expected.filename)
            }
            finalized.append(
                IOFileStore.FinalizedFile(
                    relativePath: try fileStore.relativePath(for: url),
                    url: url
                )
            )
        }

        let children = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: []
        )
        let allowedHidden = Set([Self.preRegistrationMarkerFilename, Self.integrityManifestFilename])
        for child in children {
            let name = child.lastPathComponent
            guard expectedNames.contains(name) || allowedHidden.contains(name) else {
                throw BatchError.integrityMismatch(filename: name)
            }
            do {
                try pathBoundary.requireExistingRegularFile(
                    child,
                    within: directory,
                    fileManager: fileManager
                )
            } catch {
                throw BatchError.integrityMismatch(filename: name)
            }
        }
        return finalized
    }

    public func abort(_ plan: Plan, fileManager: FileManager = .default) {
        guard isDirectChild(plan.stagingDirectoryURL, of: stagingBatchesURL) else { return }
        guard (try? pathBoundary.requireDirectory(
            plan.stagingDirectoryURL,
            fileManager: fileManager
        )) != nil else {
            return
        }
        try? fileManager.removeItem(at: plan.stagingDirectoryURL)
    }

    /// Removes only unpublished batch directories. Finalized batches are never touched here;
    /// their pre-registration markers are consumed/recovered by Lane2ExportRegistrationJournal.
    @discardableResult
    public func recoverAbandonedBatches(fileManager: FileManager = .default) throws -> Int {
        let exists: Bool
        do {
            exists = try pathBoundary.nodeExists(stagingBatchesURL, fileManager: fileManager)
            if exists {
                try pathBoundary.requireDirectory(stagingBatchesURL, fileManager: fileManager)
            }
        } catch {
            throw BatchError.fileOperationFailed(code: "EXPORT_BATCH_RECOVERY_ROOT_UNSAFE")
        }
        guard exists else { return 0 }

        let children: [URL]
        do {
            children = try fileManager.contentsOfDirectory(
                at: stagingBatchesURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw BatchError.fileOperationFailed(code: "EXPORT_BATCH_RECOVERY_ENUMERATE_FAILED")
        }

        var removed = 0
        for child in children where isDirectChild(child, of: stagingBatchesURL) {
            do {
                try pathBoundary.requireDirectory(child, fileManager: fileManager)
                try fileManager.removeItem(at: child)
                removed += 1
            } catch {
                throw BatchError.fileOperationFailed(code: "EXPORT_BATCH_RECOVERY_UNSAFE_ENTRY")
            }
        }
        return removed
    }

    private func fingerprint(
        itemURL: URL,
        filename: String,
        fileManager: FileManager
    ) throws -> IntegrityItem {
        do {
            try pathBoundary.requireExistingRegularFile(
                itemURL,
                within: fileStore.rootURL,
                fileManager: fileManager
            )
        } catch {
            let exists = (try? pathBoundary.nodeExists(itemURL, fileManager: fileManager)) == true
            if !exists { throw BatchError.outputMissing(filename: filename) }
            throw BatchError.outputNotRegularFile(filename: filename)
        }

        let values = try itemURL.resourceValues(forKeys: [.fileSizeKey])
        let size = UInt64(max(values.fileSize ?? 0, 0))
        guard size > 0 else { throw BatchError.outputEmpty(filename: filename) }

        do {
            let handle = try FileHandle(forReadingFrom: itemURL)
            defer { try? handle.close() }
            var digest: UInt64 = 14_695_981_039_346_656_037
            while true {
                let chunk = try handle.read(upToCount: 1024 * 1024) ?? Data()
                if chunk.isEmpty { break }
                for byte in chunk {
                    digest ^= UInt64(byte)
                    digest &*= 1_099_511_628_211
                }
            }
            return IntegrityItem(filename: filename, byteCount: size, contentDigest: digest)
        } catch let error as BatchError {
            throw error
        } catch {
            throw BatchError.fileOperationFailed(code: "EXPORT_BATCH_FINGERPRINT_FAILED")
        }
    }

    private func persistManifest(
        _ manifest: IntegrityManifest,
        directory: URL,
        fileManager: FileManager
    ) throws {
        let url = directory.appendingPathComponent(Self.integrityManifestFilename, isDirectory: false)
        do {
            try pathBoundary.requireDirectory(directory, fileManager: fileManager)
            _ = try pathBoundary.requireRegularFileOrMissing(
                url,
                within: directory,
                fileManager: fileManager
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(manifest)
            try data.write(to: url, options: [.atomic])
            try pathBoundary.requireExistingRegularFile(url, within: directory, fileManager: fileManager)
            let handle = try FileHandle(forWritingTo: url)
            try handle.synchronize()
            try handle.close()
        } catch {
            throw BatchError.fileOperationFailed(code: "EXPORT_BATCH_MANIFEST_WRITE_FAILED")
        }
    }

    private func loadManifest(
        directory: URL,
        fileManager: FileManager
    ) throws -> IntegrityManifest {
        let url = directory.appendingPathComponent(Self.integrityManifestFilename, isDirectory: false)
        do {
            try pathBoundary.requireExistingRegularFile(url, within: directory, fileManager: fileManager)
            return try JSONDecoder().decode(IntegrityManifest.self, from: Data(contentsOf: url))
        } catch let error as BatchError {
            throw error
        } catch {
            throw BatchError.integrityManifestInvalid
        }
    }

    private func isSafeLeafFilename(_ filename: String) -> Bool {
        !filename.isEmpty
            && !filename.hasPrefix(".")
            && !filename.contains("/")
            && !filename.contains("\\")
            && filename != "."
            && filename != ".."
    }

    private func isDirectChild(_ candidate: URL, of ancestor: URL) -> Bool {
        candidate.standardizedFileURL.deletingLastPathComponent() == ancestor.standardizedFileURL
    }
}
