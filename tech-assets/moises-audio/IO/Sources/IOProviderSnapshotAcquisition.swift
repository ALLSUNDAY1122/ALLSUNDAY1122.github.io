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
    case insufficientStorage
    case securityScopeDenied
    case providerCoordinationFailed
    case sourceChangedDuringAcquisition
    case partialPublishFailed
}

public struct IOProviderStagedSnapshot: Sendable {
    public let stagedFile: IOStagedExternalFile
    public let ownership: IOStagingOwnershipLease

    public init(stagedFile: IOStagedExternalFile, ownership: IOStagingOwnershipLease) {
        self.stagedFile = stagedFile
        self.ownership = ownership
    }
}

/// Snapshot-safe File Provider / picker acquisition boundary with durable staging ownership.
///
/// Each import obtains a durable reservation/ownership lease before writing. Bytes are copied into a
/// token-owned `.provider-partial` file, fingerprinted, verified against a fresh coordinated-source
/// fingerprint, then atomically renamed to ready Staging while the same lease remains active.
public struct IOProviderSnapshotAcquirer: Sendable {
    private let fileStore: IOFileStore
    private let maximumFileBytes: Int64
    private let chunkBytes: Int
    private let ownershipHeartbeatBytes: Int64
    private let ownershipRegistry: IOStagingOwnershipRegistry

    public init(
        fileStore: IOFileStore,
        maximumFileBytes: Int64,
        storageReserveBytes: Int64,
        chunkBytes: Int = 1024 * 1024,
        ownershipHeartbeatBytes: Int64 = 8 * 1024 * 1024,
        ownershipLeaseDuration: TimeInterval = 2 * 60 * 60,
        fileManager: FileManager = .default
    ) {
        self.fileStore = fileStore
        self.maximumFileBytes = maximumFileBytes
        self.chunkBytes = chunkBytes
        self.ownershipHeartbeatBytes = ownershipHeartbeatBytes
        self.ownershipRegistry = IOStagingOwnershipRegistry(
            fileStore: fileStore,
            storageReserveBytes: storageReserveBytes,
            leaseDuration: ownershipLeaseDuration,
            fileManager: fileManager
        )
    }

    /// Production seam: caller retains the ownership lease until downstream validation/import ends.
    public func stageProviderSnapshot(
        at sourceURL: URL,
        accessMode: IOExternalFileAccessMode,
        fileManager: FileManager = .default
    ) throws -> IOProviderStagedSnapshot {
        guard maximumFileBytes > 0,
              chunkBytes > 0,
              ownershipHeartbeatBytes > 0 else {
            throw IOProviderSnapshotAcquisitionError.invalidConfiguration
        }
        guard sourceURL.isFileURL else {
            throw IOProviderSnapshotAcquisitionError.invalidSourceURL
        }
        if Task<Never, Never>.isCancelled { throw CancellationError() }

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
            var result: Result<IOProviderStagedSnapshot, Error>?
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

    /// Compatibility seam for older lane-local tests/callers. Production composition should use
    /// `stageProviderSnapshot` through IOProviderSnapshotAudioImporter so ownership survives handoff.
    public func stageProviderFile(
        at sourceURL: URL,
        accessMode: IOExternalFileAccessMode,
        fileManager: FileManager = .default
    ) throws -> IOStagedExternalFile {
        let snapshot = try stageProviderSnapshot(
            at: sourceURL,
            accessMode: accessMode,
            fileManager: fileManager
        )
        snapshot.ownership.release()
        return snapshot.stagedFile
    }

    private func inspectCopyVerifyAndPublish(
        _ sourceURL: URL,
        fileManager: FileManager
    ) throws -> IOProviderStagedSnapshot {
        let source = sourceURL.standardizedFileURL
        guard !isDescendant(source, of: fileStore.rootURL) else {
            throw IOProviderSnapshotAcquisitionError.sourceInsideAppRoot
        }

        let initialBytes = try inspectSource(source, fileManager: fileManager)
        try fileStore.prepareDirectories(fileManager: fileManager)

        let token = UUID().uuidString.lowercased()
        let partialName = token + ".provider-partial"
        let partial = fileStore.stagingURL.appendingPathComponent(partialName)
        let ext = safeExtension(source.pathExtension)
        let readyName = token + (ext.isEmpty ? ".provider-ready" : "." + ext)
        let ready = fileStore.stagingURL.appendingPathComponent(readyName)

        let lease = try ownershipRegistry.acquire(
            token: token,
            stagingFilename: partialName,
            reservedBytes: initialBytes
        )
        var published = false
        defer {
            if !published { lease.release() }
        }

        do {
            let copied = try copyAndFingerprint(
                from: source,
                to: partial,
                lease: lease,
                fileManager: fileManager
            )
            try lease.heartbeat(writtenBytes: copied.byteCount)
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
            if Task<Never, Never>.isCancelled { throw CancellationError() }

            do {
                try fileManager.moveItem(at: partial, to: ready)
            } catch {
                throw IOProviderSnapshotAcquisitionError.partialPublishFailed
            }
            try lease.retarget(
                stagingFilename: readyName,
                writtenBytes: copied.byteCount
            )
            if Task<Never, Never>.isCancelled { throw CancellationError() }

            let descriptor = IOExternalFileDescriptor(
                byteCount: copied.byteCount,
                preferredName: source.deletingPathExtension().lastPathComponent,
                pathExtension: ext
            )
            published = true
            return IOProviderStagedSnapshot(
                stagedFile: IOStagedExternalFile(stagingURL: ready, descriptor: descriptor),
                ownership: lease
            )
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
        lease: IOStagingOwnershipLease,
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
        var nextHeartbeat = ownershipHeartbeatBytes
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
            do {
                try output.write(contentsOf: data)
            } catch {
                if Self.isOutOfSpace(error) {
                    throw IOProviderSnapshotAcquisitionError.insufficientStorage
                }
                throw error
            }
            if builder.byteCount >= nextHeartbeat {
                try lease.heartbeat(writtenBytes: builder.byteCount)
                let next = nextHeartbeat.addingReportingOverflow(ownershipHeartbeatBytes)
                nextHeartbeat = next.overflow ? Int64.max : next.partialValue
            }
        }
        do {
            try output.synchronize()
        } catch {
            if Self.isOutOfSpace(error) {
                throw IOProviderSnapshotAcquisitionError.insufficientStorage
            }
            throw error
        }
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

    private static func isOutOfSpace(_ error: Error) -> Bool {
        let ns = error as NSError
        return ns.domain == NSCocoaErrorDomain && ns.code == NSFileWriteOutOfSpaceError
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
