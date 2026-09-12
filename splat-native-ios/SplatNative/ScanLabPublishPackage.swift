import CryptoKit
import Foundation
import SplatIO

struct ScanLabPublishManifest: Codable, Equatable {
    static let currentSchemaVersion = 1
    let schemaVersion: Int
    let sceneFile: String
    let sceneByteCount: Int64
    let sceneSHA256: String
    let mediaType: String
    let createdAt: String
    enum CodingKeys: String, CodingKey { case schemaVersion = "schema_version"; case sceneFile = "scene_file"; case sceneByteCount = "scene_byte_count"; case sceneSHA256 = "scene_sha256"; case mediaType = "media_type"; case createdAt = "created_at" }
}

struct ScanLabPublishPackage {
    static let sceneFilename = "scene.spz"
    static let manifestFilename = "manifest.json"
    static let sceneMediaType = "application/octet-stream"
    static let manifestSceneMediaType = "application/vnd.scanlab.spz"
    let directoryURL: URL
    let sceneURL: URL
    let manifestURL: URL
    let manifest: ScanLabPublishManifest
}

enum ScanLabPublishPackageError: LocalizedError, Equatable {
    case invalidSource, sourceTooLarge, invalidSPZ, packageWriteFailed, packageVerificationFailed
    var errorDescription: String? {
        switch self {
        case .invalidSource: "公開用3Dデータを読み込めませんでした。"
        case .sourceTooLarge: "公開用3Dデータが128MBを超えています。"
        case .invalidSPZ: "公開用3DデータをSPZとして検証できませんでした。"
        case .packageWriteFailed: "公開パッケージを作成できませんでした。"
        case .packageVerificationFailed: "公開パッケージの整合性を確認できませんでした。"
        }
    }
}

enum ScanLabPublishPackageBuilder {
    private static let directoryPrefix = "scanlab-publish-"
    private static let ownershipMarker = ".scanlab-publish-package"
    private static let maximumManifestBytes: Int64 = 64 * 1024
    private static let stalePackageAge: TimeInterval = 24 * 60 * 60

    static func build(from sourceURL: URL, maximumBytes: Int = 128 * 1024 * 1024, fileManager: FileManager = .default) throws -> ScanLabPublishPackage {
        guard maximumBytes > 0, sourceURL.isFileURL else { throw ScanLabPublishPackageError.invalidSource }
        cleanupStalePackages(
            in: fileManager.temporaryDirectory,
            olderThan: stalePackageAge,
            now: Date(),
            fileManager: fileManager
        )
        let attributes: [FileAttributeKey: Any]
        do { attributes = try fileManager.attributesOfItem(atPath: sourceURL.path) } catch { throw ScanLabPublishPackageError.invalidSource }
        guard (attributes[.type] as? FileAttributeType) == .typeRegular,
              let number = attributes[.size] as? NSNumber,
              number.int64Value > 0 else { throw ScanLabPublishPackageError.invalidSource }
        guard number.int64Value <= Int64(maximumBytes) else { throw ScanLabPublishPackageError.sourceTooLarge }
        let source: Data
        do { source = try Data(contentsOf: sourceURL, options: [.mappedIfSafe]) } catch { throw ScanLabPublishPackageError.invalidSource }
        guard source.count == number.intValue, isDecodableSPZ(source) else { throw ScanLabPublishPackageError.invalidSPZ }
        let trustedSourceHash = sha256(source)
        let directory = fileManager.temporaryDirectory.appendingPathComponent("\(directoryPrefix)\(UUID().uuidString.lowercased())", isDirectory: true)
        let sceneURL = directory.appendingPathComponent(ScanLabPublishPackage.sceneFilename)
        let manifestURL = directory.appendingPathComponent(ScanLabPublishPackage.manifestFilename)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data().write(to: markerURL(for: directory), options: .atomic)
            try source.write(to: sceneURL, options: [.atomic])
            let manifest = ScanLabPublishManifest(schemaVersion: ScanLabPublishManifest.currentSchemaVersion, sceneFile: ScanLabPublishPackage.sceneFilename, sceneByteCount: Int64(source.count), sceneSHA256: trustedSourceHash, mediaType: ScanLabPublishPackage.manifestSceneMediaType, createdAt: ISO8601DateFormatter().string(from: Date()))
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(manifest).write(to: manifestURL, options: [.atomic])
            let package = ScanLabPublishPackage(directoryURL: directory, sceneURL: sceneURL, manifestURL: manifestURL, manifest: manifest)
            // The source bytes were fully decoded as SPZ immediately above. During this same build,
            // proving the copied bytes have the exact same SHA-256 is sufficient to preserve that
            // semantic guarantee. Avoid decoding the 128 MB-class scene a second time while the
            // source mapping is still alive; public verify() retains the full standalone decode for
            // packages that do not carry this in-process trusted-source proof.
            guard try verifyWrittenCopy(package, trustedSourceHash: trustedSourceHash, fileManager: fileManager) else {
                throw ScanLabPublishPackageError.packageVerificationFailed
            }
            return package
        } catch {
            if isOwnedPackageDirectory(directory, fileManager: fileManager) { try? fileManager.removeItem(at: directory) }
            if error is ScanLabPublishPackageError { throw error }
            throw ScanLabPublishPackageError.packageWriteFailed
        }
    }

    static func verify(_ package: ScanLabPublishPackage, fileManager: FileManager = .default) throws -> Bool {
        guard basicPackageStructureIsValid(package, fileManager: fileManager) else { return false }
        let scene = try Data(contentsOf: package.sceneURL, options: [.mappedIfSafe])
        guard isDecodableSPZ(scene),
              Int64(scene.count) == package.manifest.sceneByteCount,
              sha256(scene) == package.manifest.sceneSHA256 else { return false }
        return try manifestOnDiskMatches(package)
    }

    static func cleanup(_ package: ScanLabPublishPackage, fileManager: FileManager = .default) {
        guard isOwnedPackageDirectory(package.directoryURL, fileManager: fileManager) else { return }
        try? fileManager.removeItem(at: package.directoryURL)
    }

    /// Removes only package directories created by this helper and carrying its ownership marker.
    /// A killed app cannot run the normal upload/share completion cleanup, so a later publish prunes
    /// abandoned packages after a day without risking unrelated temporary folders or active work.
    static func cleanupStalePackages(
        in rootDirectory: URL,
        olderThan age: TimeInterval,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) {
        guard age.isFinite, age >= 0,
              let entries = try? fileManager.contentsOfDirectory(
                at: rootDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
              ) else { return }
        let cutoff = now.addingTimeInterval(-age)
        for entry in entries where entry.lastPathComponent.hasPrefix(directoryPrefix) {
            guard isOwnedPackageDirectory(entry, fileManager: fileManager),
                  let values = try? entry.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = values.contentModificationDate,
                  modified <= cutoff else { continue }
            try? fileManager.removeItem(at: entry)
        }
    }

    private static func verifyWrittenCopy(
        _ package: ScanLabPublishPackage,
        trustedSourceHash: String,
        fileManager: FileManager
    ) throws -> Bool {
        guard package.manifest.sceneSHA256 == trustedSourceHash,
              basicPackageStructureIsValid(package, fileManager: fileManager) else { return false }
        let scene = try Data(contentsOf: package.sceneURL, options: [.mappedIfSafe])
        guard Int64(scene.count) == package.manifest.sceneByteCount,
              sha256(scene) == trustedSourceHash else { return false }
        return try manifestOnDiskMatches(package)
    }

    private static func basicPackageStructureIsValid(
        _ package: ScanLabPublishPackage,
        fileManager: FileManager
    ) -> Bool {
        guard package.manifest.schemaVersion == ScanLabPublishManifest.currentSchemaVersion,
              package.manifest.sceneFile == ScanLabPublishPackage.sceneFilename,
              package.manifest.mediaType == ScanLabPublishPackage.manifestSceneMediaType,
              package.manifest.sceneByteCount > 0,
              !package.manifest.sceneSHA256.isEmpty,
              isOwnedPackageDirectory(package.directoryURL, fileManager: fileManager),
              package.sceneURL.deletingLastPathComponent().standardizedFileURL == package.directoryURL.standardizedFileURL,
              package.manifestURL.deletingLastPathComponent().standardizedFileURL == package.directoryURL.standardizedFileURL,
              isRegularNonSymlinkFile(package.sceneURL),
              isRegularNonSymlinkFile(package.manifestURL),
              let manifestAttributes = try? fileManager.attributesOfItem(atPath: package.manifestURL.path),
              let manifestSize = manifestAttributes[.size] as? NSNumber,
              manifestSize.int64Value > 0,
              manifestSize.int64Value <= maximumManifestBytes else { return false }
        return true
    }

    private static func manifestOnDiskMatches(_ package: ScanLabPublishPackage) throws -> Bool {
        let data = try Data(contentsOf: package.manifestURL, options: [.mappedIfSafe])
        let decoded = try JSONDecoder().decode(ScanLabPublishManifest.self, from: data)
        return decoded == package.manifest
    }

    private static func markerURL(for directory: URL) -> URL {
        directory.appendingPathComponent(ownershipMarker, isDirectory: false)
    }

    private static func isOwnedPackageDirectory(_ directory: URL, fileManager: FileManager) -> Bool {
        guard directory.isFileURL,
              directory.lastPathComponent.hasPrefix(directoryPrefix),
              let directoryValues = try? directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              directoryValues.isDirectory == true,
              directoryValues.isSymbolicLink != true else { return false }
        let marker = markerURL(for: directory)
        guard let markerValues = try? marker.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              markerValues.isRegularFile == true,
              markerValues.isSymbolicLink != true else { return false }
        return fileManager.fileExists(atPath: marker.path)
    }

    private static func isRegularNonSymlinkFile(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else { return false }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    private static func isDecodableSPZ(_ data: Data) -> Bool { do { _ = try SPZSceneReader(data).read(); return true } catch { return false } }
    private static func sha256(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}
