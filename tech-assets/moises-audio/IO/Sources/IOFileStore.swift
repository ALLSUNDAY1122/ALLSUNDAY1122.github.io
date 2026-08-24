import Foundation

public struct IOFileStore: Sendable {
    public enum StoreError: Error, Equatable, Sendable {
        case invalidRelativePath
        case sourceMissing
        case insufficientStorage(requiredBytes: Int64, availableBytes: Int64)
        case fileOperationFailed(code: String)
    }

    public struct FinalizedFile: Equatable, Sendable {
        public let relativePath: String
        public let url: URL

        public init(relativePath: String, url: URL) {
            self.relativePath = relativePath
            self.url = url
        }
    }

    public let rootURL: URL
    private let importsDirectoryName = "Imports"
    private let exportsDirectoryName = "Exports"
    private let stagingDirectoryName = "Staging"

    public init(rootURL: URL) {
        self.rootURL = rootURL.standardizedFileURL
    }

    public func prepareDirectories(fileManager: FileManager = .default) throws {
        for url in [importsURL, exportsURL, stagingURL] {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    public var importsURL: URL { rootURL.appendingPathComponent(importsDirectoryName, isDirectory: true) }
    public var exportsURL: URL { rootURL.appendingPathComponent(exportsDirectoryName, isDirectory: true) }
    public var stagingURL: URL { rootURL.appendingPathComponent(stagingDirectoryName, isDirectory: true) }

    public func resolve(relativePath: String) throws -> URL {
        guard !relativePath.isEmpty, !relativePath.hasPrefix("/") else {
            throw StoreError.invalidRelativePath
        }
        let candidate = rootURL.appendingPathComponent(relativePath).standardizedFileURL
        guard isDescendant(candidate, of: rootURL) else {
            throw StoreError.invalidRelativePath
        }
        return candidate
    }

    public func relativePath(for url: URL) throws -> String {
        let standardized = url.standardizedFileURL
        guard isDescendant(standardized, of: rootURL) else {
            throw StoreError.invalidRelativePath
        }
        let rootPath = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        return String(standardized.path.dropFirst(rootPath.count))
    }

    public func stageCopy(from sourceURL: URL, fileManager: FileManager = .default) throws -> URL {
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw StoreError.sourceMissing
        }
        try prepareDirectories(fileManager: fileManager)
        let ext = sourceURL.pathExtension
        let stagedName = UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)")
        let destination = stagingURL.appendingPathComponent(stagedName)
        do {
            try fileManager.copyItem(at: sourceURL, to: destination)
            return destination
        } catch {
            throw StoreError.fileOperationFailed(code: "STAGE_COPY_FAILED")
        }
    }

    public func moveDownloadedTemporaryFile(_ temporaryURL: URL, preferredExtension: String? = nil, fileManager: FileManager = .default) throws -> URL {
        guard fileManager.fileExists(atPath: temporaryURL.path) else {
            throw StoreError.sourceMissing
        }
        try prepareDirectories(fileManager: fileManager)
        let ext = (preferredExtension ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let stagedName = UUID().uuidString + (ext.isEmpty ? ".download" : ".\(ext)")
        let staged = stagingURL.appendingPathComponent(stagedName)
        do {
            try fileManager.moveItem(at: temporaryURL, to: staged)
            return staged
        } catch {
            // Some URLSession/file-provider temporary locations cannot be renamed across volumes.
            do {
                try fileManager.copyItem(at: temporaryURL, to: staged)
                return staged
            } catch {
                throw StoreError.fileOperationFailed(code: "DOWNLOAD_STAGE_FAILED")
            }
        }
    }

    public func finalizeImport(stagingFile: URL, preferredName: String?, fileManager: FileManager = .default) throws -> FinalizedFile {
        try finalize(stagingFile: stagingFile, directory: importsURL, preferredName: preferredName, fileManager: fileManager)
    }

    public func finalizeExport(stagingFile: URL, preferredName: String?, fileManager: FileManager = .default) throws -> FinalizedFile {
        try finalize(stagingFile: stagingFile, directory: exportsURL, preferredName: preferredName, fileManager: fileManager)
    }

    public func removeIfExists(_ url: URL, fileManager: FileManager = .default) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.removeItem(at: url)
    }

    public func preflight(requiredBytes: Int64, reserveBytes: Int64 = 32 * 1024 * 1024, fileManager: FileManager = .default) throws {
        guard requiredBytes >= 0, reserveBytes >= 0 else { return }
        let attributes = try fileManager.attributesOfFileSystem(forPath: rootURL.path)
        guard let free = (attributes[.systemFreeSize] as? NSNumber)?.int64Value else { return }
        let totalRequired = requiredBytes.addingReportingOverflow(reserveBytes)
        let required = totalRequired.overflow ? Int64.max : totalRequired.partialValue
        if free < required {
            throw StoreError.insufficientStorage(requiredBytes: required, availableBytes: free)
        }
    }

    public static func sanitizedFilenameStem(_ raw: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>\u{0000}")
        let pieces = raw.components(separatedBy: forbidden)
        let joined = pieces.joined(separator: "_")
        let collapsed = joined.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if collapsed.isEmpty || collapsed == "." || collapsed == ".." {
            return "audio"
        }
        return String(collapsed.prefix(96))
    }

    private func finalize(
        stagingFile: URL,
        directory: URL,
        preferredName: String?,
        fileManager: FileManager
    ) throws -> FinalizedFile {
        guard fileManager.fileExists(atPath: stagingFile.path), isDescendant(stagingFile, of: stagingURL) else {
            throw StoreError.sourceMissing
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let ext = stagingFile.pathExtension
        let stem = Self.sanitizedFilenameStem(preferredName ?? stagingFile.deletingPathExtension().lastPathComponent)
        let unique = UUID().uuidString.lowercased()
        let filename = "\(stem)-\(unique)" + (ext.isEmpty ? "" : ".\(ext)")
        let destination = directory.appendingPathComponent(filename)
        let finalRelativePath = try relativePath(for: destination)
        let publicationJournal = Lane2ManagedArtifactPublicationJournal(
            rootURL: rootURL,
            fileManager: fileManager
        )

        do {
            _ = try publicationJournal.begin(relativePath: finalRelativePath)
        } catch {
            throw StoreError.fileOperationFailed(code: "PUBLICATION_INTENT_FAILED")
        }

        do {
            try fileManager.moveItem(at: stagingFile, to: destination)
            // The publication intent deliberately remains durable here. Library's readiness boundary
            // registers the final path in the managed-artifact inventory and only then retires it.
            return FinalizedFile(relativePath: finalRelativePath, url: destination)
        } catch let error as StoreError {
            try? publicationJournal.cancelCurrentSessionIfPresent(relativePath: finalRelativePath)
            throw error
        } catch {
            try? publicationJournal.cancelCurrentSessionIfPresent(relativePath: finalRelativePath)
            throw StoreError.fileOperationFailed(code: "FINALIZE_MOVE_FAILED")
        }
    }

    private func isDescendant(_ candidate: URL, of ancestor: URL) -> Bool {
        let parent = ancestor.standardizedFileURL.path.hasSuffix("/")
            ? ancestor.standardizedFileURL.path
            : ancestor.standardizedFileURL.path + "/"
        let child = candidate.standardizedFileURL.path
        return child.hasPrefix(parent) && child.count > parent.count
    }
}
