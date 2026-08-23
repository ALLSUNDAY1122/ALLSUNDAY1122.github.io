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

    public static let preRegistrationMarkerFilename = ".lane2-registration-pending"
    public static let publicationSessionID = UUID().uuidString.lowercased()

    private let fileStore: IOFileStore
    private let stagingBatchDirectoryName = "ExportBatches"
    private let finalizedBatchDirectoryName = "Batches"

    public init(fileStore: IOFileStore) {
        self.fileStore = fileStore
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
            try fileManager.createDirectory(at: stagingBatchesURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: finalizedBatchesURL, withIntermediateDirectories: true)
        } catch {
            throw BatchError.fileOperationFailed(code: "EXPORT_BATCH_DIRECTORY_CREATE_FAILED")
        }

        let id = UUID().uuidString.lowercased()
        let batchURL = stagingBatchesURL.appendingPathComponent(id, isDirectory: true)
        do {
            try fileManager.createDirectory(at: batchURL, withIntermediateDirectories: false)
        } catch {
            throw BatchError.fileOperationFailed(code: "EXPORT_BATCH_STAGE_CREATE_FAILED")
        }

        var occurrences: [String: Int] = [:]
        let items = suggestedFilenameStems.map { rawStem -> PlannedItem in
            let stem = IOFileStore.sanitizedFilenameStem(rawStem)
            let normalizedKey = stem.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            let occurrence = (occurrences[normalizedKey] ?? 0) + 1
            occurrences[normalizedKey] = occurrence
            let suffix = occurrence == 1 ? "" : " (\(occurrence))"
            let filename = "\(stem)\(suffix).\(fileExtension)"
            return PlannedItem(filename: filename, stagingURL: batchURL.appendingPathComponent(filename))
        }

        return Plan(id: id, stagingDirectoryURL: batchURL, items: items)
    }

    /// Atomically publishes the entire batch using one directory move.
    /// Every output must exist, be a regular file, and contain at least one byte.
    /// The hidden marker is persisted inside staging before the rename, so every
    /// successfully published canonical batch is recoverable until Library registration
    /// durably adopts it.
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

        for item in plan.items {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: item.stagingURL.path, isDirectory: &isDirectory) else {
                throw BatchError.outputMissing(filename: item.filename)
            }
            guard !isDirectory.boolValue else {
                throw BatchError.outputNotRegularFile(filename: item.filename)
            }
            do {
                let attributes = try fileManager.attributesOfItem(atPath: item.stagingURL.path)
                guard attributes[.type] as? FileAttributeType == .typeRegular else {
                    throw BatchError.outputNotRegularFile(filename: item.filename)
                }
                let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
                guard size > 0 else { throw BatchError.outputEmpty(filename: item.filename) }
            } catch let error as BatchError {
                throw error
            } catch {
                throw BatchError.fileOperationFailed(code: "EXPORT_BATCH_OUTPUT_STAT_FAILED")
            }
        }

        let finalDirectoryURL = finalizedBatchesURL.appendingPathComponent(plan.id, isDirectory: true)
        guard !fileManager.fileExists(atPath: finalDirectoryURL.path) else {
            throw BatchError.destinationConflict
        }

        let markerURL = plan.stagingDirectoryURL.appendingPathComponent(Self.preRegistrationMarkerFilename)
        do {
            guard fileManager.createFile(atPath: markerURL.path, contents: Data((Self.publicationSessionID + "\n").utf8)) else {
                throw BatchError.fileOperationFailed(code: "EXPORT_BATCH_MARKER_CREATE_FAILED")
            }
            let markerHandle = try FileHandle(forWritingTo: markerURL)
            try markerHandle.synchronize()
            try markerHandle.close()
        } catch let error as BatchError {
            throw error
        } catch {
            throw BatchError.fileOperationFailed(code: "EXPORT_BATCH_MARKER_CREATE_FAILED")
        }

        do {
            try fileManager.moveItem(at: plan.stagingDirectoryURL, to: finalDirectoryURL)
        } catch {
            throw BatchError.fileOperationFailed(code: "EXPORT_BATCH_COMMIT_MOVE_FAILED")
        }

        do {
            return try plan.items.map { item in
                let finalURL = finalDirectoryURL.appendingPathComponent(item.filename)
                return IOFileStore.FinalizedFile(
                    relativePath: try fileStore.relativePath(for: finalURL),
                    url: finalURL
                )
            }
        } catch {
            try? fileManager.removeItem(at: finalDirectoryURL)
            throw BatchError.fileOperationFailed(code: "EXPORT_BATCH_RELATIVE_PATH_FAILED")
        }
    }

    public func abort(_ plan: Plan, fileManager: FileManager = .default) {
        guard isDirectChild(plan.stagingDirectoryURL, of: stagingBatchesURL) else { return }
        try? fileManager.removeItem(at: plan.stagingDirectoryURL)
    }

    /// Removes only unpublished batch directories. Finalized batches are never touched here;
    /// their pre-registration markers are consumed/recovered by Lane2ExportRegistrationJournal.
    @discardableResult
    public func recoverAbandonedBatches(fileManager: FileManager = .default) throws -> Int {
        guard fileManager.fileExists(atPath: stagingBatchesURL.path) else { return 0 }
        let children: [URL]
        do {
            children = try fileManager.contentsOfDirectory(
                at: stagingBatchesURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw BatchError.fileOperationFailed(code: "EXPORT_BATCH_RECOVERY_ENUMERATE_FAILED")
        }

        var removed = 0
        for child in children where isDirectChild(child, of: stagingBatchesURL) {
            do {
                try fileManager.removeItem(at: child)
                removed += 1
            } catch {
                throw BatchError.fileOperationFailed(code: "EXPORT_BATCH_RECOVERY_REMOVE_FAILED")
            }
        }
        return removed
    }

    private func isDirectChild(_ candidate: URL, of ancestor: URL) -> Bool {
        candidate.standardizedFileURL.deletingLastPathComponent() == ancestor.standardizedFileURL
    }
}
