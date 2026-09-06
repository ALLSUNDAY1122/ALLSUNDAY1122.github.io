import Foundation

/// Path-free, process-local identity snapshot for a file-backed PCM source.
///
/// The snapshot intentionally stores no URL/path and no raw file bytes. Device/inode catch atomic
/// replacement, size/mtime catch ordinary in-place mutation, and Foundation resource/generation
/// identifiers are folded to process-local hashes when the backing filesystem exposes them.
struct Lane3FileSourceIdentitySnapshot: Equatable, Sendable {
    let systemNumber: UInt64
    let systemFileNumber: UInt64
    let fileSize: UInt64
    let creationDateBitPattern: UInt64?
    let modificationDateBitPattern: UInt64
    let resourceIdentifierHash: Int?
    let generationIdentifierHash: Int?
}

enum Lane3FileSourceIdentityFenceError: Error, Equatable, Sendable {
    case unavailable
    case notRegularFile
    case changed
}

enum Lane3FileSourceIdentityFence {
    static func capture(fileURL: URL) throws -> Lane3FileSourceIdentitySnapshot {
        guard fileURL.isFileURL else {
            throw Lane3FileSourceIdentityFenceError.unavailable
        }

        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        } catch {
            throw Lane3FileSourceIdentityFenceError.unavailable
        }

        guard let type = attributes[.type] as? FileAttributeType,
              type == .typeRegular else {
            throw Lane3FileSourceIdentityFenceError.notRegularFile
        }
        guard let systemNumber = (attributes[.systemNumber] as? NSNumber)?.uint64Value,
              let systemFileNumber = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value,
              let fileSize = (attributes[.size] as? NSNumber)?.uint64Value,
              let modificationDate = attributes[.modificationDate] as? Date else {
            throw Lane3FileSourceIdentityFenceError.unavailable
        }

        let creationDateBitPattern = (attributes[.creationDate] as? Date)?
            .timeIntervalSinceReferenceDate.bitPattern

        // These keys are supplemental. Some filesystems do not expose either value, so absence must
        // not make a valid local regular file unusable. NSObject.hash follows Foundation equality for
        // opaque identifiers and avoids relying on pointer-bearing debug descriptions. Hashes are only
        // compared inside this process; they are never persisted or exposed as cross-run identifiers.
        let resourceValues = try? fileURL.resourceValues(
            forKeys: [.fileResourceIdentifierKey, .generationIdentifierKey]
        )
        let resourceIdentifierHash = opaqueFoundationIdentifierHash(
            resourceValues?.fileResourceIdentifier
        )
        let generationIdentifierHash = opaqueFoundationIdentifierHash(
            resourceValues?.generationIdentifier
        )

        return Lane3FileSourceIdentitySnapshot(
            systemNumber: systemNumber,
            systemFileNumber: systemFileNumber,
            fileSize: fileSize,
            creationDateBitPattern: creationDateBitPattern,
            modificationDateBitPattern: modificationDate.timeIntervalSinceReferenceDate.bitPattern,
            resourceIdentifierHash: resourceIdentifierHash,
            generationIdentifierHash: generationIdentifierHash
        )
    }

    static func requireUnchanged(
        fileURL: URL,
        expected: Lane3FileSourceIdentitySnapshot
    ) throws {
        guard try capture(fileURL: fileURL) == expected else {
            throw Lane3FileSourceIdentityFenceError.changed
        }
    }

    private static func opaqueFoundationIdentifierHash(_ value: Any?) -> Int? {
        guard let object = value as? NSObject else { return nil }
        return object.hash
    }
}
