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
    /// as a non-empty regular PCM/IEEE-float RIFF/WAVE file or throw.
    func decodeToCanonicalWAV(sourceURL: URL, destinationURL: URL) async throws
}

public enum IOCompatibilityDecodeStagingError: Error, Equatable, Sendable {
    case decoderUnavailable
    case decoderFailed
    case outputMissing
    case outputNotRegularFile
    case outputEmpty
}

public enum IOCanonicalWAVValidationError: Error, Equatable, Sendable {
    case truncated
    case invalidContainer
    case invalidChunk
    case missingFormat
    case unsupportedFormat
    case missingAudioData
}

/// Bounded structural validation for decoder-produced canonical WAV. It parses only RIFF/WAVE chunk
/// headers plus the small `fmt ` payload; audio payload bytes are never materialized in memory.
public enum IOCanonicalWAVValidator {
    public static func validate(url: URL, fileManager: FileManager = .default) throws {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw IOCanonicalWAVValidationError.invalidContainer
        }
        guard let fileSize = values.fileSize, fileSize >= 44 else {
            throw IOCanonicalWAVValidationError.truncated
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let header = try readExactly(handle: handle, count: 12)
        guard ascii(header, 0..<4) == "RIFF", ascii(header, 8..<12) == "WAVE" else {
            throw IOCanonicalWAVValidationError.invalidContainer
        }
        let declaredRIFFSize = Int(littleEndianUInt32(header, at: 4)) + 8
        guard declaredRIFFSize <= fileSize, declaredRIFFSize >= 44 else {
            throw IOCanonicalWAVValidationError.invalidContainer
        }

        var offset = 12
        var sawFormat = false
        var sawData = false
        var chunks = 0
        while offset + 8 <= declaredRIFFSize, chunks < 256 {
            try handle.seek(toOffset: UInt64(offset))
            let chunkHeader = try readExactly(handle: handle, count: 8)
            let chunkID = ascii(chunkHeader, 0..<4)
            let chunkSize = Int(littleEndianUInt32(chunkHeader, at: 4))
            let dataStart = offset + 8
            let padded = chunkSize + (chunkSize & 1)
            guard chunkSize >= 0, dataStart <= declaredRIFFSize, padded <= declaredRIFFSize - dataStart else {
                throw IOCanonicalWAVValidationError.invalidChunk
            }

            if chunkID == "fmt " {
                guard chunkSize >= 16 else { throw IOCanonicalWAVValidationError.invalidChunk }
                try handle.seek(toOffset: UInt64(dataStart))
                let format = try readExactly(handle: handle, count: 16)
                let audioFormat = littleEndianUInt16(format, at: 0)
                let channels = littleEndianUInt16(format, at: 2)
                let sampleRate = littleEndianUInt32(format, at: 4)
                let byteRate = littleEndianUInt32(format, at: 8)
                let blockAlign = littleEndianUInt16(format, at: 12)
                let bitsPerSample = littleEndianUInt16(format, at: 14)
                guard audioFormat == 1 || audioFormat == 3,
                      (1...64).contains(Int(channels)),
                      (8_000...768_000).contains(Int(sampleRate)),
                      byteRate > 0,
                      blockAlign > 0,
                      bitsPerSample > 0,
                      bitsPerSample <= 64 else {
                    throw IOCanonicalWAVValidationError.unsupportedFormat
                }
                sawFormat = true
            } else if chunkID == "data" {
                guard chunkSize > 0 else { throw IOCanonicalWAVValidationError.missingAudioData }
                sawData = true
            }

            offset = dataStart + padded
            chunks += 1
            if sawFormat && sawData { return }
        }

        guard sawFormat else { throw IOCanonicalWAVValidationError.missingFormat }
        guard sawData else { throw IOCanonicalWAVValidationError.missingAudioData }
    }

    private static func readExactly(handle: FileHandle, count: Int) throws -> Data {
        let data = try handle.read(upToCount: count) ?? Data()
        guard data.count == count else { throw IOCanonicalWAVValidationError.truncated }
        return data
    }

    private static func ascii(_ data: Data, _ range: Range<Int>) -> String {
        String(bytes: data[range], encoding: .ascii) ?? ""
    }

    private static func littleEndianUInt16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func littleEndianUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }
}

private struct IOCompatibilitySourceFingerprint: Equatable, Sendable {
    let fileSize: Int
    let modificationTime: TimeInterval
    let contentDigest: UInt64

    static func capture(url: URL) throws -> Self {
        let values = try url.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .contentModificationDateKey
        ])
        guard values.isRegularFile == true,
              values.isSymbolicLink != true,
              let fileSize = values.fileSize,
              fileSize > 0 else {
            throw IOCompatibilityDecodeStagingError.decoderFailed
        }

        let handle = try FileHandle(forReadingFrom: url)
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
        return Self(
            fileSize: fileSize,
            modificationTime: (values.contentModificationDate ?? .distantPast).timeIntervalSince1970,
            contentDigest: digest
        )
    }
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
        let sourceFingerprintBefore = try IOCompatibilitySourceFingerprint.capture(url: stagedSourceURL)

        try fileStore.prepareDirectories(fileManager: fileManager)
        let destination = fileStore.stagingURL
            .appendingPathComponent(UUID().uuidString.lowercased())
            .appendingPathExtension("wav")
        fileStore.removeIfExists(destination, fileManager: fileManager)

        do {
            try Task.checkCancellation()
            try await decoder.decodeToCanonicalWAV(sourceURL: stagedSourceURL, destinationURL: destination)
            try Task.checkCancellation()
            let sourceFingerprintAfter = try IOCompatibilitySourceFingerprint.capture(url: stagedSourceURL)
            guard sourceFingerprintAfter == sourceFingerprintBefore else {
                throw IOCompatibilityDecodeStagingError.decoderFailed
            }
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
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            fileStore.removeIfExists(destination, fileManager: fileManager)
            throw IOCompatibilityDecodeStagingError.outputNotRegularFile
        }
        guard let size = values.fileSize, size > 0 else {
            fileStore.removeIfExists(destination, fileManager: fileManager)
            throw IOCompatibilityDecodeStagingError.outputEmpty
        }
        do {
            try IOCanonicalWAVValidator.validate(url: destination, fileManager: fileManager)
        } catch {
            fileStore.removeIfExists(destination, fileManager: fileManager)
            throw IOCompatibilityDecodeStagingError.decoderFailed
        }
        return destination
    }
}
