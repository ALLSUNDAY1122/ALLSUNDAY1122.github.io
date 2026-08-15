import CryptoKit
import Foundation
import SplatIO

/// S6 export pipeline for Gaussian Splat assets.
///
/// The reconstruction output is the 32-byte-per-point `.splat` format emitted by Msplat.
/// We intentionally decode it through SplatIO and re-encode through SplatIO's PLY/SPZ writers
/// instead of duplicating coordinate, scale, opacity, rotation, or color conversions here.
enum SplatExportService {
    enum Format: String, CaseIterable, Identifiable, Sendable {
        case ply
        case spz

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .ply: return "PLY"
            case .spz: return "SPZ"
            }
        }
    }

    enum ExportError: LocalizedError {
        case sourceMissing
        case unsupportedSource
        case corruptSource
        case emptySource
        case incompleteWrite(expected: Int, actual: Int)
        case outputMissing

        var errorDescription: String? {
            switch self {
            case .sourceMissing:
                return "書き出し元の3Dデータが見つかりません。"
            case .unsupportedSource:
                return "この3Dデータ形式は現在の書き出し処理では扱えません。"
            case .corruptSource:
                return "3Dデータが途中で欠けています。再生成してから書き出してください。"
            case .emptySource:
                return "3DデータにGaussianが含まれていません。"
            case .incompleteWrite(let expected, let actual):
                return "書き出し件数が一致しません（期待: \(expected)、実際: \(actual)）。"
            case .outputMissing:
                return "書き出しファイルを作成できませんでした。"
            }
        }
    }

    struct BrowserShareManifest: Codable, Equatable, Sendable {
        static let currentSchemaVersion = 1

        struct Asset: Codable, Equatable, Sendable {
            let fileName: String
            let mediaType: String
            let byteLength: Int
            let sha256: String
        }

        let schemaVersion: Int
        let representation: String
        let primaryAsset: Asset
        let previewFileName: String?
        let createdAt: Date
        let containsLocation: Bool

        init(primaryAsset: Asset, previewFileName: String?, createdAt: Date = Date()) {
            self.schemaVersion = Self.currentSchemaVersion
            self.representation = "gaussian-splat"
            self.primaryAsset = primaryAsset
            self.previewFileName = previewFileName
            self.createdAt = createdAt
            // D may add an explicitly approved geotag later. C never infers or embeds location.
            self.containsLocation = false
        }
    }

    struct BrowserSharePackage: Sendable {
        let directoryURL: URL
        let assetURL: URL
        let manifestURL: URL
        let previewURL: URL?
    }

    private static let dotSplatRecordByteWidth = 32

    /// Convert Msplat's `.splat` result into a standards-oriented export file.
    /// The destination is written through a temporary file and only replaces the final output
    /// after the writer has closed and the output has been validated.
    static func export(sourceURL: URL, format: Format) async throws -> URL {
        let pointCount = try sourcePointCount(sourceURL)
        let outputURL = sourceURL.deletingPathExtension().appendingPathExtension(format.rawValue)
        let temporaryURL = outputURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(outputURL.lastPathComponent).\(UUID().uuidString).partial")

        try? FileManager.default.removeItem(at: temporaryURL)

        do {
            let reader = try DotSplatSceneReader(sourceURL)
            let stream = try reader.read()
            var pointsWritten = 0

            switch format {
            case .ply:
                let writer = try SplatPLYSceneWriter(toFileAtPath: temporaryURL.path)
                // `.splat` stores only direct color, so SH0 is the lossless degree for this source.
                try await writer.start(sphericalHarmonicDegree: 0, binary: true, pointCount: pointCount)
                for try await points in stream {
                    try Task.checkCancellation()
                    try await writer.write(points)
                    pointsWritten += points.count
                }
                try await writer.close()

            case .spz:
                let writer = try SPZSceneWriter(toFileAtPath: temporaryURL.path)
                try await writer.start(numPoints: pointCount)
                for try await points in stream {
                    try Task.checkCancellation()
                    try await writer.write(points)
                    pointsWritten += points.count
                }
                try await writer.close()
            }

            guard pointsWritten == pointCount else {
                throw ExportError.incompleteWrite(expected: pointCount, actual: pointsWritten)
            }
            try validateNonEmptyFile(temporaryURL)

            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }
            try FileManager.default.moveItem(at: temporaryURL, to: outputURL)
            return outputURL
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }
    }

    /// Creates the only local asset contract D should consume for explicit browser/cloud sharing.
    /// It accepts only an atomically committed completed Splat, applies the same low-storage gate as
    /// local SPZ export, and never performs networking or embeds location on C's behalf.
    static func makeBrowserSharePackage(
        sourceURL: URL,
        previewJPEG: Data? = nil,
        rootDirectory: URL = FileManager.default.temporaryDirectory
    ) async throws -> BrowserSharePackage {
        let trustedURL = try SplatExportAdmission.preflight(sourceURL: sourceURL, kind: .spz)
        let exportedSPZ = try await export(sourceURL: trustedURL, format: .spz)
        try Task.checkCancellation()

        let packageURL = rootDirectory
            .appendingPathComponent("scanlab-share-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)

        do {
            let assetURL = packageURL.appendingPathComponent("scene.spz")
            try FileManager.default.copyItem(at: exportedSPZ, to: assetURL)
            let assetData = try Data(contentsOf: assetURL, options: [.mappedIfSafe])
            guard !assetData.isEmpty else { throw ExportError.outputMissing }

            var previewURL: URL?
            if let previewJPEG, !previewJPEG.isEmpty {
                let url = packageURL.appendingPathComponent("preview.jpg")
                try previewJPEG.write(to: url, options: .atomic)
                previewURL = url
            }

            let asset = BrowserShareManifest.Asset(
                fileName: assetURL.lastPathComponent,
                mediaType: "application/octet-stream",
                byteLength: assetData.count,
                sha256: sha256Hex(assetData)
            )
            let manifest = BrowserShareManifest(
                primaryAsset: asset,
                previewFileName: previewURL?.lastPathComponent
            )
            let manifestURL = packageURL.appendingPathComponent("manifest.json")
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(manifest).write(to: manifestURL, options: .atomic)

            return BrowserSharePackage(
                directoryURL: packageURL,
                assetURL: assetURL,
                manifestURL: manifestURL,
                previewURL: previewURL
            )
        } catch {
            try? FileManager.default.removeItem(at: packageURL)
            throw error
        }
    }

    static func sourcePointCount(_ sourceURL: URL) throws -> Int {
        guard sourceURL.isFileURL,
              FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw ExportError.sourceMissing
        }
        guard sourceURL.pathExtension.lowercased() == "splat" else {
            throw ExportError.unsupportedSource
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        guard let number = attributes[.size] as? NSNumber else {
            throw ExportError.corruptSource
        }
        let bytes = number.intValue
        guard bytes > 0 else { throw ExportError.emptySource }
        guard bytes % dotSplatRecordByteWidth == 0 else { throw ExportError.corruptSource }
        return bytes / dotSplatRecordByteWidth
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func validateNonEmptyFile(_ url: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber, size.intValue > 0 else {
            throw ExportError.outputMissing
        }
    }
}
