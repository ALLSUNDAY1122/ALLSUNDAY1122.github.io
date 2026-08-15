import Foundation
import ModelIO

/// Export adapter intentionally decoupled from `MeshScanModel` so S0 can merge S4 and S6
/// in either order. S4 supplies its real `resultURL`; S6 owns the format conversion/share step.
enum MeshExportService {
    enum Format: String, CaseIterable, Identifiable, Sendable {
        case fbx
        case obj
        case glb
        case usdz
        case stl

        var id: String { rawValue }
        var displayName: String { rawValue.uppercased() }
    }

    enum ExportError: LocalizedError {
        case sourceMissing
        case emptySource
        case unsupportedSource(String)
        case unsupportedConversion(source: String, destination: String)
        case outputMissing

        var errorDescription: String? {
            switch self {
            case .sourceMissing:
                return "Meshの書き出し元が見つかりません。"
            case .emptySource:
                return "Meshファイルが空です。"
            case .unsupportedSource(let ext):
                return "この端末では.\(ext)をMesh変換元として読み込めません。"
            case .unsupportedConversion(let source, let destination):
                return "この端末の標準3D変換では.\(source)から.\(destination)へ正しく書き出せません。"
            case .outputMissing:
                return "Mesh書き出しファイルを完成できませんでした。"
            }
        }
    }

    struct Capability: Equatable, Sendable {
        let format: Format
        let isAvailable: Bool
        let reason: String?
    }

    /// Reports actual runtime capability. A format is never advertised merely because its
    /// extension exists in the UI. Exact-format passthrough is always permitted after validation.
    static func capabilities(for sourceURL: URL) -> [Capability] {
        Format.allCases.map { format in
            if sourceURL.pathExtension.caseInsensitiveCompare(format.rawValue) == .orderedSame {
                return Capability(format: format, isAvailable: true, reason: nil)
            }

            let sourceExtension = sourceURL.pathExtension.lowercased()
            guard MDLAsset.canImportFileExtension(sourceExtension) else {
                return Capability(
                    format: format,
                    isAvailable: false,
                    reason: "元の.\(sourceExtension)を標準変換器で読み込めません"
                )
            }
            guard MDLAsset.canExportFileExtension(format.rawValue) else {
                return Capability(
                    format: format,
                    isAvailable: false,
                    reason: "このiOSでは\(format.displayName)書き出しが提供されていません"
                )
            }
            return Capability(format: format, isAvailable: true, reason: nil)
        }
    }

    static func export(
        sourceURL: URL,
        format: Format,
        destinationDirectory: URL? = nil
    ) async throws -> URL {
        try Task.checkCancellation()
        try validateSource(sourceURL)

        let directory = destinationDirectory ?? sourceURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let finalURL = directory.appendingPathComponent("scan-mesh-\(UUID().uuidString).\(format.rawValue)")
        let partialURL = directory.appendingPathComponent(".\(finalURL.lastPathComponent).partial.\(format.rawValue)")
        try? FileManager.default.removeItem(at: partialURL)

        do {
            let sourceExtension = sourceURL.pathExtension.lowercased()
            if sourceExtension == format.rawValue {
                try FileManager.default.copyItem(at: sourceURL, to: partialURL)
            } else {
                guard MDLAsset.canImportFileExtension(sourceExtension) else {
                    throw ExportError.unsupportedSource(sourceExtension)
                }
                guard MDLAsset.canExportFileExtension(format.rawValue) else {
                    throw ExportError.unsupportedConversion(
                        source: sourceExtension,
                        destination: format.rawValue
                    )
                }

                let asset = MDLAsset(url: sourceURL)
                try Task.checkCancellation()
                try asset.export(to: partialURL)
            }

            try Task.checkCancellation()
            try validateOutput(partialURL)
            if FileManager.default.fileExists(atPath: finalURL.path) {
                try FileManager.default.removeItem(at: finalURL)
            }
            try FileManager.default.moveItem(at: partialURL, to: finalURL)
            return finalURL
        } catch {
            try? FileManager.default.removeItem(at: partialURL)
            try? FileManager.default.removeItem(at: finalURL)
            throw error
        }
    }

    private static func validateSource(_ url: URL) throws {
        guard url.isFileURL, FileManager.default.fileExists(atPath: url.path) else {
            throw ExportError.sourceMissing
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber, size.intValue > 0 else {
            throw ExportError.emptySource
        }
    }

    private static func validateOutput(_ url: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber, size.intValue > 0 else {
            throw ExportError.outputMissing
        }
    }
}
