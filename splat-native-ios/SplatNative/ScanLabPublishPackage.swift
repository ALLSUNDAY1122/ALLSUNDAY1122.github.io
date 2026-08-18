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
    static func build(from sourceURL: URL, maximumBytes: Int = 128 * 1024 * 1024, fileManager: FileManager = .default) throws -> ScanLabPublishPackage {
        let attributes: [FileAttributeKey: Any]
        do { attributes = try fileManager.attributesOfItem(atPath: sourceURL.path) } catch { throw ScanLabPublishPackageError.invalidSource }
        guard let number = attributes[.size] as? NSNumber, number.int64Value > 0 else { throw ScanLabPublishPackageError.invalidSource }
        guard number.int64Value <= Int64(maximumBytes) else { throw ScanLabPublishPackageError.sourceTooLarge }
        let source: Data
        do { source = try Data(contentsOf: sourceURL, options: [.mappedIfSafe]) } catch { throw ScanLabPublishPackageError.invalidSource }
        guard source.count == number.intValue, isDecodableSPZ(source) else { throw ScanLabPublishPackageError.invalidSPZ }
        let directory = fileManager.temporaryDirectory.appendingPathComponent("scanlab-publish-\(UUID().uuidString.lowercased())", isDirectory: true)
        let sceneURL = directory.appendingPathComponent(ScanLabPublishPackage.sceneFilename)
        let manifestURL = directory.appendingPathComponent(ScanLabPublishPackage.manifestFilename)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try source.write(to: sceneURL, options: [.atomic])
            let manifest = ScanLabPublishManifest(schemaVersion: ScanLabPublishManifest.currentSchemaVersion, sceneFile: ScanLabPublishPackage.sceneFilename, sceneByteCount: Int64(source.count), sceneSHA256: sha256(source), mediaType: ScanLabPublishPackage.manifestSceneMediaType, createdAt: ISO8601DateFormatter().string(from: Date()))
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(manifest).write(to: manifestURL, options: [.atomic])
            let package = ScanLabPublishPackage(directoryURL: directory, sceneURL: sceneURL, manifestURL: manifestURL, manifest: manifest)
            guard try verify(package, fileManager: fileManager) else { throw ScanLabPublishPackageError.packageVerificationFailed }
            return package
        } catch {
            try? fileManager.removeItem(at: directory)
            if error is ScanLabPublishPackageError { throw error }
            throw ScanLabPublishPackageError.packageWriteFailed
        }
    }

    static func verify(_ package: ScanLabPublishPackage, fileManager: FileManager = .default) throws -> Bool {
        guard package.manifest.schemaVersion == ScanLabPublishManifest.currentSchemaVersion,
              package.manifest.sceneFile == ScanLabPublishPackage.sceneFilename,
              package.manifest.mediaType == ScanLabPublishPackage.manifestSceneMediaType,
              fileManager.fileExists(atPath: package.sceneURL.path), fileManager.fileExists(atPath: package.manifestURL.path) else { return false }
        let scene = try Data(contentsOf: package.sceneURL, options: [.mappedIfSafe])
        guard isDecodableSPZ(scene), Int64(scene.count) == package.manifest.sceneByteCount, sha256(scene) == package.manifest.sceneSHA256 else { return false }
        let decoded = try JSONDecoder().decode(ScanLabPublishManifest.self, from: Data(contentsOf: package.manifestURL))
        return decoded == package.manifest
    }
    static func cleanup(_ package: ScanLabPublishPackage, fileManager: FileManager = .default) { try? fileManager.removeItem(at: package.directoryURL) }
    private static func isDecodableSPZ(_ data: Data) -> Bool { do { _ = try SPZSceneReader(data).read(); return true } catch { return false } }
    private static func sha256(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}
