import Foundation

public enum IOExternalFileAccessMode: String, Codable, Sendable {
    case direct
    case securityScoped
}

public enum IOExternalFileAcquisitionError: Error, Equatable, Sendable {
    case invalidSourceURL
    case sourceInsideAppRoot
    case sourceMissing
    case sourceNotRegularFile
    case sourceEmpty
    case sourceTooLarge(limitBytes: Int64, actualBytes: Int64)
    case securityScopeDenied
    case providerCoordinationFailed
    case stagedSizeMismatch(expectedBytes: Int64, actualBytes: Int64)
}

public struct IOExternalFileDescriptor: Equatable, Sendable {
    public let byteCount: Int64
    public let preferredName: String
    public let pathExtension: String

    public init(byteCount: Int64, preferredName: String, pathExtension: String) {
        self.byteCount = byteCount
        self.preferredName = preferredName
        self.pathExtension = pathExtension
    }
}

public struct IOStagedExternalFile: Equatable, Sendable {
    public let stagingURL: URL
    public let descriptor: IOExternalFileDescriptor

    public init(stagingURL: URL, descriptor: IOExternalFileDescriptor) {
        self.stagingURL = stagingURL
        self.descriptor = descriptor
    }
}

/// Copies picker / File Provider / camera-roll-exported files into app-owned staging while
/// the external access lease is still valid. Only complete, non-empty regular files cross
/// this boundary. Media decoding/validation remains IOSAudioIOService's responsibility.
public struct IOExternalFileAcquirer: Sendable {
    private let fileStore: IOFileStore
    private let maximumFileBytes: Int64
    private let storageReserveBytes: Int64

    public init(
        fileStore: IOFileStore,
        maximumFileBytes: Int64,
        storageReserveBytes: Int64
    ) {
        self.fileStore = fileStore
        self.maximumFileBytes = maximumFileBytes
        self.storageReserveBytes = storageReserveBytes
    }

    public func stageExternalFile(
        at sourceURL: URL,
        accessMode: IOExternalFileAccessMode,
        fileManager: FileManager = .default
    ) throws -> IOStagedExternalFile {
        guard maximumFileBytes > 0, storageReserveBytes >= 0 else {
            throw IOExternalFileAcquisitionError.sourceTooLarge(
                limitBytes: max(maximumFileBytes, 0),
                actualBytes: 0
            )
        }
        guard sourceURL.isFileURL else {
            throw IOExternalFileAcquisitionError.invalidSourceURL
        }

        switch accessMode {
        case .direct:
            return try inspectAndStage(sourceURL, fileManager: fileManager)
        case .securityScoped:
            #if os(iOS) || os(macOS) || os(tvOS) || os(visionOS)
            guard sourceURL.startAccessingSecurityScopedResource() else {
                throw IOExternalFileAcquisitionError.securityScopeDenied
            }
            defer { sourceURL.stopAccessingSecurityScopedResource() }

            var coordinationError: NSError?
            var result: Result<IOStagedExternalFile, Error>?
            NSFileCoordinator(filePresenter: nil).coordinate(
                readingItemAt: sourceURL,
                options: [],
                error: &coordinationError
            ) { coordinatedURL in
                result = Result {
                    try inspectAndStage(coordinatedURL, fileManager: fileManager)
                }
            }
            if coordinationError != nil {
                throw IOExternalFileAcquisitionError.providerCoordinationFailed
            }
            guard let result else {
                throw IOExternalFileAcquisitionError.providerCoordinationFailed
            }
            return try result.get()
            #else
            throw IOExternalFileAcquisitionError.securityScopeDenied
            #endif
        }
    }

    private func inspectAndStage(
        _ sourceURL: URL,
        fileManager: FileManager
    ) throws -> IOStagedExternalFile {
        let source = sourceURL.standardizedFileURL
        guard !isDescendant(source, of: fileStore.rootURL) else {
            throw IOExternalFileAcquisitionError.sourceInsideAppRoot
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory) else {
            throw IOExternalFileAcquisitionError.sourceMissing
        }
        guard !isDirectory.boolValue else {
            throw IOExternalFileAcquisitionError.sourceNotRegularFile
        }

        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        if values.isSymbolicLink == true || values.isRegularFile == false {
            throw IOExternalFileAcquisitionError.sourceNotRegularFile
        }

        let byteCount: Int64
        if let fileSize = values.fileSize {
            byteCount = Int64(fileSize)
        } else {
            let attributes = try fileManager.attributesOfItem(atPath: source.path)
            guard let size = (attributes[.size] as? NSNumber)?.int64Value else {
                throw IOExternalFileAcquisitionError.sourceNotRegularFile
            }
            byteCount = size
        }

        guard byteCount > 0 else {
            throw IOExternalFileAcquisitionError.sourceEmpty
        }
        guard byteCount <= maximumFileBytes else {
            throw IOExternalFileAcquisitionError.sourceTooLarge(
                limitBytes: maximumFileBytes,
                actualBytes: byteCount
            )
        }

        try fileStore.preflight(
            requiredBytes: byteCount,
            reserveBytes: storageReserveBytes,
            fileManager: fileManager
        )

        let staged = try fileStore.stageCopy(from: source, fileManager: fileManager)
        do {
            let stagedValues = try staged.resourceValues(forKeys: [.fileSizeKey])
            let stagedBytes: Int64
            if let fileSize = stagedValues.fileSize {
                stagedBytes = Int64(fileSize)
            } else {
                let attributes = try fileManager.attributesOfItem(atPath: staged.path)
                stagedBytes = (attributes[.size] as? NSNumber)?.int64Value ?? -1
            }
            guard stagedBytes == byteCount else {
                throw IOExternalFileAcquisitionError.stagedSizeMismatch(
                    expectedBytes: byteCount,
                    actualBytes: stagedBytes
                )
            }

            let descriptor = IOExternalFileDescriptor(
                byteCount: byteCount,
                preferredName: source.deletingPathExtension().lastPathComponent,
                pathExtension: source.pathExtension.lowercased()
            )
            return IOStagedExternalFile(stagingURL: staged, descriptor: descriptor)
        } catch {
            fileStore.removeIfExists(staged, fileManager: fileManager)
            throw error
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
