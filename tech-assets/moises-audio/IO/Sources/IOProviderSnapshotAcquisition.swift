import Foundation

public struct IOProviderContentFingerprint: Equatable, Sendable {
    public let byteCount: Int64
    public let hashA: UInt64
    public let hashB: UInt64

    public init(byteCount: Int64, hashA: UInt64, hashB: UInt64) {
        self.byteCount = byteCount
        self.hashA = hashA
        self.hashB = hashB
    }
}

public enum IOProviderSnapshotAcquisitionError: Error, Equatable, Sendable {
    case invalidConfiguration
    case invalidSourceURL
    case sourceInsideAppRoot
    case sourceMissing
    case sourceNotRegularFile
    case sourceEmpty
    case sourceTooLarge(limitBytes: Int64, actualBytes: Int64)
    case securityScopeDenied
    case providerCoordinationFailed
    case sourceChangedDuringAcquisition
    case partialPublishFailed
}

/// Snapshot-safe File Provider / picker acquisition boundary.
///
/// Bytes are copied into a non-authoritative `.provider-partial` staging file first. The copied
/// content fingerprint must match a fresh post-copy fingerprint of the coordinated source before
/// the partial file is atomically renamed into a ready staging file. This is a consistency check,
/// not a cryptographic authenticity primitive.
public struct IOProviderSnapshotAcquirer: Sendable {
    private let fileStore: IOFileStore
    private let maximumFileBytes: Int64
    private let storageReserveBytes: Int64
    private let chunkBytes: Int

    public init(
        fileStore: IOFileStore,
        maximumFileBytes: Int64,
        storageReserveBytes: Int64,
        chunkBytes: Int = 1024 * 1024
    ) {
        self.fileStore = fileStore
        self.maximumFileBytes = maximumFileBytes
        self.storageReserveBytes = storageReserveBytes
        self.chunkBytes = chunkBytes
    }

    public func stageProviderFile(
        at sourceURL: URL,
        accessMode: IOExternalFileAccessMode,
        fileManager: FileManager = .default
    ) throws -> IOStagedExternalFile {
        guard maximumFileBytes > 0, storageReserveBytes >= 0, chunkBytes > 0 else {
            throw IOProviderSnapshotAcquisitionError.invalidConfiguration
        }
        guard sourceURL.isFileURL else {
            throw IOProviderSnapshotAcquisitionError.invalidSourceURL
        }

        switch accessMode {
        case .direct:
            return try inspectCopyVerifyAndPublish(sourceURL, fileManager: fileManager)
        case .securityScoped:
            #if os(iOS) || os(macOS) || os(tvOS) || os(visionOS)
            guard sourceURL.startAccessingSecurityScopedResource() else {
                throw IOProviderSnapshotAcquisitionError.securityScopeDenied
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
                    try inspectCopyVerifyAndPublish(coordinatedURL, fileManager: fileManager)
                }
            }
            if coordinationError != nil {
                throw IOProviderSnapshotAcquisitionError.providerCoordinationFailed
            }
            guard let result else {
                throw IOProviderSnapshotAcquisitionError.providerCoordinationFailed
            }
            return try result.get()
            #else
            throw IOProviderSnapshotAcquisitionError.securityScopeDenied
            #endif
        }
    }

    private func inspectCopyVerifyAndPublish(
        _ sourceURL: URL,
        fileManager: FileManager
    ) throws -> IOStagedExternalFile {
        let source = sourceURL.standardizedFileURL
        guard !isDescendant(source, of: fileStore.rootURL) else {
            throw IOProviderSnapshotAcquisitionError.sourceInsideAppRoot
        }

        let initialBytes = try inspectSource(source, fileManager: fileManager)
        try fileStore.preflight(
            requiredBytes: initialBytes,
            reserveBytes: storageReserveBytes,
            fileManager: fileManager
        )
        try fileStore.prepareDirectories(fileManager: fileManager)

        let token = UUID().uuidString.lowercased()
        let partial = fileStore.stagingURL.appendingPathComponent(token + ".provider-partial")
        let ext = safeExtension(source.pathExtension)
        let ready = fileStore.stagingURL.appendingPathComponent(
            token + (ext.isEmpty ? ".provider-ready" : "." + ext)
        )

        do {
            let copied = try copyAndFingerprint(
                from: source,
                to: partial,
                fileManager: fileManager
            )
            let sourceAfter = try fingerprint(
                source,
                maximumBytes: maximumFileBytes,
                fileManager: fileManager
            )
            try Self.requireCoherentSnapshot(
                initialBytes: initialBytes,
                copied: copied,
                sourceAfter: sourceAfter
            )

            do {
                try fileManager.moveItem(at: partial, to: ready)
            } catch {
                throw IOProviderSnapshotAcquisitionError.partialPublishFailed
            }

            let descriptor = IOExternalFileDescriptor(
                byteCount: copied.byteCount,
                preferredName: source.deletingPathExtension().lastPathComponent,
                pathExtension: ext
            )
            return IOStagedExternalFile(stagingURL: ready, descriptor: descriptor)
        } catch {
            fileStore.removeIfExists(partial, fileManager: fileManager)
            fileStore.removeIfExists(ready, fileManager: fileManager)
            throw error
        }
    }

    public static func requireCoherentSnapshot(
        initialBytes: Int64,
        copied: IOProviderContentFingerprint,
        sourceAfter: IOProviderContentFingerprint
    ) throws {
        guard initialBytes > 0, copied.byteCount == initialBytes, sourceAfter == copied else {
            throw IOProviderSnapshotAcquisitionError.sourceChangedDuringAcquisition
        }
    }

    private func inspectSource(_ source: URL, fileManager: FileManager) throws -> Int64 {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory) else {
            throw IOProviderSnapshotAcquisitionError.sourceMissing
        }
        guard !isDirectory.boolValue else {
            throw IOProviderSnapshotAcquisitionError.sourceNotRegularFile
        }
        let values = try source.resourceValues(forKeys: [
            .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey
        ])
        guard values.isSymbolicLink != true, values.isRegularFile != false else {
            throw IOProviderSnapshotAcquisitionError.sourceNotRegularFile
        }
        let bytes: Int64
        if let size = values.fileSize {
            bytes = Int64(size)
        } else {
            let attributes = try fileManager.attributesOfItem(atPath: source.path)
            guard let number = attributes[.size] as? NSNumber else {
                throw IOProviderSnapshotAcquisitionError.sourceNotRegularFile
            }
            bytes = number.int64Value
        }
        guard bytes > 0 else { throw IOProviderSnapshotAcquisitionError.sourceEmpty }
        guard bytes <= maximumFileBytes else {
            throw IOProviderSnapshotAcquisitionError.sourceTooLarge(
                limitBytes: maximumFileBytes,
                actualBytes: bytes
            )
        }
        return bytes
    }

    private func copyAndFingerprint(
        from source: URL,
        to destination: URL,
        fileManager: FileManager
    ) throws -> IOProviderContentFingerprint {
        guard fileManager.createFile(atPath: destination.path, contents: nil) else {
            throw IOProviderSnapshotAcquisitionError.partialPublishFailed
        }
        let input = try FileHandle(forReadingFrom: source)
        let output = try FileHandle(forWritingTo: destination)
        defer {
            try? input.close()
            try? output.close()
        }

        var builder = FingerprintBuilder()
        while true {
            if Task<Never, Never>.isCancelled { throw CancellationError() }
            guard let data = try input.read(upToCount: chunkBytes), !data.isEmpty else { break }
            builder.update(data)
            if builder.byteCount > maximumFileBytes {
                throw IOProviderSnapshotAcquisitionError.sourceTooLarge(
                    limitBytes: maximumFileBytes,
                    actualBytes: builder.byteCount
                )
            }
            try output.write(contentsOf: data)
        }
        try output.synchronize()
        guard builder.byteCount > 0 else { throw IOProviderSnapshotAcquisitionError.sourceEmpty }
        return builder.finalize()
    }

    public func fingerprint(
        _ source: URL,
        maximumBytes: Int64,
        fileManager: FileManager = .default
    ) throws -> IOProviderContentFingerprint {
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        var builder = FingerprintBuilder()
        while true {
            if Task<Never, Never>.isCancelled { throw CancellationError() }
            guard let data = try input.read(upToCount: chunkBytes), !data.isEmpty else { break }
            builder.update(data)
            if builder.byteCount > maximumBytes {
                throw IOProviderSnapshotAcquisitionError.sourceTooLarge(
                    limitBytes: maximumBytes,
                    actualBytes: builder.byteCount
                )
            }
        }
        guard builder.byteCount > 0 else { throw IOProviderSnapshotAcquisitionError.sourceEmpty }
        return builder.finalize()
    }

    private func safeExtension(_ raw: String) -> String {
        let value = raw.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !value.isEmpty, value.count <= 12,
              value.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }) else {
            return ""
        }
        return value
    }

    private func isDescendant(_ candidate: URL, of ancestor: URL) -> Bool {
        let parent = ancestor.standardizedFileURL.path.hasSuffix("/")
            ? ancestor.standardizedFileURL.path
            : ancestor.standardizedFileURL.path + "/"
        let child = candidate.standardizedFileURL.path
        return child.hasPrefix(parent) && child.count > parent.count
    }

    private struct FingerprintBuilder {
        private(set) var byteCount: Int64 = 0
        private var hashA: UInt64 = 14_695_981_039_346_656_037
        private var hashB: UInt64 = 7_809_847_782_465_536_322

        mutating func update(_ data: Data) {
            byteCount += Int64(data.count)
            for byte in data {
                hashA ^= UInt64(byte)
                hashA &*= 1_099_511_628_211
                hashB ^= UInt64(byte) &+ 0x9e
                hashB &*= 14_029_467_366_897_019_727
            }
        }

        func finalize() -> IOProviderContentFingerprint {
            IOProviderContentFingerprint(byteCount: byteCount, hashA: hashA, hashB: hashB)
        }
    }
}
