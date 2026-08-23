import Foundation

public enum IOReferenceMediaDecodeRoute: String, Codable, Sendable {
    case nativeProbe
    case nativeThenCompatibility
}

public struct IOReferenceMediaCompatibilityPolicy: Sendable {
    public static let referenceExtensions: Set<String> = ["mp3", "wav", "flac", "m4a", "mp4", "mov", "wma"]

    public init() {}

    public func route(forPathExtension rawExtension: String) -> IOReferenceMediaDecodeRoute {
        normalizedExtension(rawExtension) == "wma" ? .nativeThenCompatibility : .nativeProbe
    }

    public func isReferenceExtension(_ rawExtension: String) -> Bool {
        Self.referenceExtensions.contains(normalizedExtension(rawExtension))
    }

    public func normalizedExtension(_ rawExtension: String) -> String {
        rawExtension
            .trimmingCharacters(in: CharacterSet(charactersIn: ".").union(.whitespacesAndNewlines))
            .lowercased()
    }
}

public protocol IOCompatibilityAudioDecoding: Sendable {
    /// Decodes a compatibility-only source (currently WMA) to a canonical, app-owned WAV staging file.
    /// The implementation must not delete or mutate sourceURL. It must either complete destinationURL
    /// as a non-empty regular file or throw.
    func decodeToCanonicalWAV(sourceURL: URL, destinationURL: URL) async throws
}

public enum IOCompatibilityDecodeStagingError: Error, Equatable, Sendable {
    case decoderUnavailable
    case decoderFailed
    case outputMissing
    case outputNotRegularFile
    case outputEmpty
}

public struct IOCompatibilityDecodeStaging: Sendable {
    private let fileStore: IOFileStore

    public init(fileStore: IOFileStore) {
        self.fileStore = fileStore
    }

    public func decodeToCanonicalWAV(
        stagedSourceURL: URL,
        decoder: (any IOCompatibilityAudioDecoding)?,
        fileManager: FileManager = .default
    ) async throws -> URL {
        guard let decoder else {
            throw IOCompatibilityDecodeStagingError.decoderUnavailable
        }
        guard fileManager.fileExists(atPath: stagedSourceURL.path),
              try fileStore.relativePath(for: stagedSourceURL).hasPrefix("Staging/") else {
            throw IOCompatibilityDecodeStagingError.outputMissing
        }

        try fileStore.prepareDirectories(fileManager: fileManager)
        let destination = fileStore.stagingURL
            .appendingPathComponent(UUID().uuidString.lowercased())
            .appendingPathExtension("wav")
        fileStore.removeIfExists(destination, fileManager: fileManager)

        do {
            try Task.checkCancellation()
            try await decoder.decodeToCanonicalWAV(sourceURL: stagedSourceURL, destinationURL: destination)
            try Task.checkCancellation()
        } catch is CancellationError {
            fileStore.removeIfExists(destination, fileManager: fileManager)
            throw CancellationError()
        } catch {
            fileStore.removeIfExists(destination, fileManager: fileManager)
            throw IOCompatibilityDecodeStagingError.decoderFailed
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: destination.path, isDirectory: &isDirectory) else {
            throw IOCompatibilityDecodeStagingError.outputMissing
        }
        guard !isDirectory.boolValue else {
            fileStore.removeIfExists(destination, fileManager: fileManager)
            throw IOCompatibilityDecodeStagingError.outputNotRegularFile
        }
        let values = try destination.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile != false, values.isSymbolicLink != true else {
            fileStore.removeIfExists(destination, fileManager: fileManager)
            throw IOCompatibilityDecodeStagingError.outputNotRegularFile
        }
        guard let size = values.fileSize, size > 0 else {
            fileStore.removeIfExists(destination, fileManager: fileManager)
            throw IOCompatibilityDecodeStagingError.outputEmpty
        }
        return destination
    }
}
