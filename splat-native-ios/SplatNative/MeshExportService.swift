import AssimpBinary
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

        var assimpExporterID: String? {
            switch self {
            case .fbx: return "fbx"
            case .obj: return "obj"
            case .glb: return "glb2"
            case .stl: return "stlb"
            case .usdz: return nil
            }
        }
    }

    enum ExportError: LocalizedError {
        case sourceMissing
        case emptySource
        case unsupportedSource(String)
        case unsupportedConversion(source: String, destination: String)
        case assimpImporterFailed(String)
        case assimpExporterUnavailable(String)
        case assimpExportFailed(String)
        case invalidContainer(String)
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
                return ".\(source)から.\(destination)へ正しい3Dデータとして変換できません。"
            case .assimpImporterFailed(let message):
                return "Mesh中間データを読み込めませんでした。\n\(message)"
            case .assimpExporterUnavailable(let format):
                return "このビルドには\(format)の実Exporterが含まれていません。"
            case .assimpExportFailed(let message):
                return "Meshの実ファイル書き出しに失敗しました。\n\(message)"
            case .invalidContainer(let format):
                return "出力された.\(format)が実フォーマットとして検証できませんでした。"
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
        let sourceExtension = sourceURL.pathExtension.lowercased()
        let exporterIDs = assimpExporterIDs()
        let canBridgeToOBJ = sourceExtension == "obj" || (
            MDLAsset.canImportFileExtension(sourceExtension) &&
                MDLAsset.canExportFileExtension("obj")
        )

        return Format.allCases.map { format in
            if sourceExtension == format.rawValue {
                return Capability(format: format, isAvailable: true, reason: nil)
            }

            if format == .usdz {
                let available = MDLAsset.canImportFileExtension(sourceExtension) &&
                    MDLAsset.canExportFileExtension("usdz")
                return Capability(
                    format: format,
                    isAvailable: available,
                    reason: available ? nil : "Model I/OでUSDZへ実変換できません"
                )
            }

            guard canBridgeToOBJ else {
                return Capability(
                    format: format,
                    isAvailable: false,
                    reason: "元の.\(sourceExtension)をOBJ中間データへ変換できません"
                )
            }
            guard let exporterID = format.assimpExporterID,
                  exporterIDs.contains(exporterID) else {
                return Capability(
                    format: format,
                    isAvailable: false,
                    reason: "実\(format.displayName) Exporterがこのビルドにありません"
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
        let bridgeDirectory = directory.appendingPathComponent(".mesh-export-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.removeItem(at: partialURL)
        try? FileManager.default.removeItem(at: bridgeDirectory)

        do {
            let sourceExtension = sourceURL.pathExtension.lowercased()
            if sourceExtension == format.rawValue {
                try FileManager.default.copyItem(at: sourceURL, to: partialURL)
            } else if format == .usdz {
                guard MDLAsset.canImportFileExtension(sourceExtension),
                      MDLAsset.canExportFileExtension("usdz") else {
                    throw ExportError.unsupportedConversion(source: sourceExtension, destination: "usdz")
                }
                let asset = MDLAsset(url: sourceURL)
                try Task.checkCancellation()
                try asset.export(to: partialURL)
            } else {
                guard let exporterID = format.assimpExporterID else {
                    throw ExportError.unsupportedConversion(source: sourceExtension, destination: format.rawValue)
                }
                guard assimpExporterIDs().contains(exporterID) else {
                    throw ExportError.assimpExporterUnavailable(format.displayName)
                }

                try FileManager.default.createDirectory(at: bridgeDirectory, withIntermediateDirectories: true)
                let bridgeURL: URL
                if sourceExtension == "obj" {
                    bridgeURL = sourceURL
                } else {
                    guard MDLAsset.canImportFileExtension(sourceExtension),
                          MDLAsset.canExportFileExtension("obj") else {
                        throw ExportError.unsupportedSource(sourceExtension)
                    }
                    bridgeURL = bridgeDirectory.appendingPathComponent("scene.obj")
                    let asset = MDLAsset(url: sourceURL)
                    try Task.checkCancellation()
                    try asset.export(to: bridgeURL)
                    try validateOutput(bridgeURL)
                }

                try Task.checkCancellation()
                try exportWithAssimp(sourceOBJ: bridgeURL, exporterID: exporterID, outputURL: partialURL)
            }

            try Task.checkCancellation()
            try validateOutput(partialURL)
            try validateContainer(partialURL, as: format)
            if FileManager.default.fileExists(atPath: finalURL.path) {
                try FileManager.default.removeItem(at: finalURL)
            }
            try FileManager.default.moveItem(at: partialURL, to: finalURL)
            try? FileManager.default.removeItem(at: bridgeDirectory)
            return finalURL
        } catch {
            try? FileManager.default.removeItem(at: partialURL)
            try? FileManager.default.removeItem(at: finalURL)
            try? FileManager.default.removeItem(at: bridgeDirectory)
            throw error
        }
    }

    static func assimpExporterIDs() -> Set<String> {
        let count = aiGetExportFormatCount()
        var ids = Set<String>()
        guard count > 0 else { return ids }

        for index in 0..<count {
            guard let description = aiGetExportFormatDescription(index) else { continue }
            defer { aiReleaseExportFormatDescription(description) }
            if let pointer = description.pointee.id {
                ids.insert(String(cString: pointer))
            }
        }
        return ids
    }

    private static func exportWithAssimp(sourceOBJ: URL, exporterID: String, outputURL: URL) throws {
        let scene: UnsafePointer<aiScene>? = sourceOBJ.path.withCString { path in
            aiImportFile(path, 0)
        }
        guard let scene else {
            throw ExportError.assimpImporterFailed(assimpErrorString())
        }
        defer { aiReleaseImport(scene) }

        let result: aiReturn = exporterID.withCString { formatPointer in
            outputURL.path.withCString { outputPointer in
                aiExportScene(scene, formatPointer, outputPointer, 0)
            }
        }
        guard result == aiReturn_SUCCESS else {
            throw ExportError.assimpExportFailed(assimpErrorString())
        }
    }

    private static func assimpErrorString() -> String {
        guard let pointer = aiGetErrorString() else { return "Assimp error detail unavailable" }
        let message = String(cString: pointer)
        return message.isEmpty ? "Assimp returned an unspecified error" : message
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

    /// Prevents extension-only success. Every finalized file must carry a recognizable
    /// signature/structure for the requested interchange format.
    private static func validateContainer(_ url: URL, as format: Format) throws {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard !data.isEmpty else { throw ExportError.outputMissing }

        let valid: Bool
        switch format {
        case .fbx:
            let prefix = String(decoding: data.prefix(32), as: UTF8.self)
            valid = prefix.contains("Kaydara FBX Binary") || prefix.contains("; FBX")
        case .glb:
            valid = data.count >= 12 && Array(data.prefix(4)) == [0x67, 0x6c, 0x54, 0x46]
        case .usdz:
            valid = data.count >= 4 && data[0] == 0x50 && data[1] == 0x4b
        case .stl:
            let asciiPrefix = String(decoding: data.prefix(80), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            valid = data.count >= 84 || asciiPrefix.hasPrefix("solid")
        case .obj:
            guard let text = String(data: data.prefix(min(data.count, 1_000_000)), encoding: .utf8) else {
                valid = false
                break
            }
            valid = text.hasPrefix("v ") || text.contains("\nv ")
        }

        guard valid else { throw ExportError.invalidContainer(format.rawValue) }
    }
}
