import AssimpBinary
import Foundation
import ModelIO

/// Export adapter intentionally decoupled from `MeshScanModel` so B can supply its real result
/// while C owns actual interchange conversion and delivery semantics.
enum MeshExportService {
    enum Format: String, CaseIterable, Identifiable, Sendable {
        case fbx
        case obj
        case glb
        case usdz
        case stl
        case ply
        case las

        var id: String { rawValue }
        var displayName: String { rawValue.uppercased() }

        var assimpExporterIDs: [String] {
            switch self {
            // Prefer ASCII FBX because the pinned Assimp binary exporter can emit files that
            // pass the FBX header check but fail the independent Assimp importer. Keep binary
            // as a fallback and require a successful reopen before either result is accepted.
            case .fbx: return ["fbxa", "fbx"]
            case .obj: return ["obj"]
            case .glb: return ["glb2"]
            case .stl: return ["stlb"]
            case .usdz, .ply, .las: return []
            }
        }

        var assimpExporterID: String? { assimpExporterIDs.first }
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
                return "書き出しファイルを完成できませんでした。"
            }
        }
    }

    struct Capability: Equatable, Sendable {
        let format: Format
        let isAvailable: Bool
        let reason: String?
    }

    private static let las12HeaderSize = 227

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

            if format == .ply || format == .las {
                return Capability(format: format, isAvailable: true, reason: nil)
            }

            let candidateIDs = format.assimpExporterIDs
            guard !candidateIDs.isEmpty,
                  candidateIDs.contains(where: { exporterIDs.contains($0) }) else {
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
                try FileManager.default.createDirectory(at: bridgeDirectory, withIntermediateDirectories: true)
                let bridgeURL = try bridgeToOBJ(
                    sourceURL: sourceURL,
                    bridgeDirectory: bridgeDirectory
                )
                try Task.checkCancellation()

                switch format {
                case .ply:
                    try MeshPointCloudExportService.exportPLY(sourceOBJ: bridgeURL, outputURL: partialURL)
                case .las:
                    try MeshPointCloudExportService.exportLAS12(sourceOBJ: bridgeURL, outputURL: partialURL)
                case .fbx:
                    let availableIDs = format.assimpExporterIDs.filter { assimpExporterIDs().contains($0) }
                    guard !availableIDs.isEmpty else {
                        throw ExportError.assimpExporterUnavailable(format.displayName)
                    }
                    try exportFBXWithReadableFallback(
                        sourceOBJ: bridgeURL,
                        exporterIDs: availableIDs,
                        outputURL: partialURL
                    )
                case .obj, .glb, .stl:
                    guard let exporterID = format.assimpExporterID else {
                        throw ExportError.unsupportedConversion(source: sourceExtension, destination: format.rawValue)
                    }
                    guard assimpExporterIDs().contains(exporterID) else {
                        throw ExportError.assimpExporterUnavailable(format.displayName)
                    }
                    try exportWithAssimp(sourceOBJ: bridgeURL, exporterID: exporterID, outputURL: partialURL)
                case .usdz:
                    throw ExportError.unsupportedConversion(source: sourceExtension, destination: format.rawValue)
                }
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

    private static func bridgeToOBJ(sourceURL: URL, bridgeDirectory: URL) throws -> URL {
        let sourceExtension = sourceURL.pathExtension.lowercased()
        if sourceExtension == "obj" {
            return sourceURL
        }
        guard MDLAsset.canImportFileExtension(sourceExtension),
              MDLAsset.canExportFileExtension("obj") else {
            throw ExportError.unsupportedSource(sourceExtension)
        }

        let bridgeURL = bridgeDirectory.appendingPathComponent("scene.obj")
        let asset = MDLAsset(url: sourceURL)
        try Task.checkCancellation()
        try asset.export(to: bridgeURL)
        try validateOutput(bridgeURL)
        return bridgeURL
    }

    private static func exportFBXWithReadableFallback(
        sourceOBJ: URL,
        exporterIDs: [String],
        outputURL: URL
    ) throws {
        var failures: [String] = []

        for exporterID in exporterIDs {
            try Task.checkCancellation()
            try? FileManager.default.removeItem(at: outputURL)

            do {
                try exportWithAssimp(sourceOBJ: sourceOBJ, exporterID: exporterID, outputURL: outputURL)
                try validateOutput(outputURL)
                try validateContainer(outputURL, as: .fbx)
                try validateAssimpReadable(outputURL)
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failures.append("\(exporterID): \(error.localizedDescription)")
            }
        }

        try? FileManager.default.removeItem(at: outputURL)
        let detail = failures.isEmpty
            ? "利用可能なFBX Exporterがありません。"
            : failures.joined(separator: "\n")
        throw ExportError.assimpExportFailed("FBXを第三者reader互換として完成できませんでした。\n\(detail)")
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

    private static func validateAssimpReadable(_ url: URL) throws {
        let scene: UnsafePointer<aiScene>? = url.path.withCString { path in
            aiImportFile(path, 0)
        }
        guard let scene else {
            throw ExportError.assimpImporterFailed(assimpErrorString())
        }
        defer { aiReleaseImport(scene) }

        guard scene.pointee.mNumMeshes > 0 else {
            throw ExportError.assimpImporterFailed("Assimpで再読込できましたがMesh payloadが空です。")
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
        guard try fileByteCount(url) > 0 else {
            throw ExportError.outputMissing
        }
    }

    /// Prevents extension-only success without loading a potentially huge export into memory.
    /// Container recognition needs only bounded header/prefix bytes plus the on-disk byte count.
    private static func validateContainer(_ url: URL, as format: Format) throws {
        let totalBytes = try fileByteCount(url)
        guard totalBytes > 0 else { throw ExportError.outputMissing }

        let valid: Bool
        switch format {
        case .fbx:
            let data = try readPrefix(url, maxBytes: 32)
            let prefix = String(decoding: data, as: UTF8.self)
            valid = prefix.contains("Kaydara FBX Binary") || prefix.contains("; FBX")

        case .glb:
            let data = try readPrefix(url, maxBytes: 12)
            valid = data.count >= 12 && Array(data.prefix(4)) == [0x67, 0x6c, 0x54, 0x46]

        case .usdz:
            let data = try readPrefix(url, maxBytes: 4)
            valid = data.count >= 4 && data[0] == 0x50 && data[1] == 0x4b

        case .stl:
            let data = try readPrefix(url, maxBytes: 84)
            let asciiPrefix = String(decoding: data.prefix(80), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            valid = totalBytes >= 84 || asciiPrefix.hasPrefix("solid")

        case .obj:
            let data = try readPrefix(url, maxBytes: 1_000_000)
            guard let text = String(data: data, encoding: .utf8) else {
                valid = false
                break
            }
            valid = text.hasPrefix("v ") || text.contains("\nv ")

        case .ply:
            let data = try readPrefix(url, maxBytes: 2_048)
            let prefix = String(decoding: data, as: UTF8.self)
            valid = prefix.hasPrefix("ply\n") &&
                prefix.contains("format binary_little_endian 1.0") &&
                prefix.contains("element vertex ") &&
                !prefix.contains("element face ") &&
                prefix.contains("end_header\n")

        case .las:
            let data = try readPrefix(url, maxBytes: las12HeaderSize)
            guard data.count >= las12HeaderSize,
                  Array(data.prefix(4)) == [0x4c, 0x41, 0x53, 0x46] else {
                valid = false
                break
            }
            let headerSize = Int(readUInt16LE(data, offset: 94))
            let pointOffset = Int(readUInt32LE(data, offset: 96))
            let pointFormat = data[104] & 0x3f
            let recordLength = Int(readUInt16LE(data, offset: 105))
            let legacyPointCount = UInt64(readUInt32LE(data, offset: 107))
            let requiredBytes = UInt64(pointOffset) + legacyPointCount * UInt64(recordLength)
            valid = headerSize >= las12HeaderSize &&
                pointOffset >= headerSize &&
                UInt64(pointOffset) <= totalBytes &&
                pointFormat <= 10 &&
                recordLength > 0 &&
                requiredBytes <= totalBytes
        }

        guard valid else { throw ExportError.invalidContainer(format.rawValue) }
    }

    private static func fileByteCount(_ url: URL) throws -> UInt64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber else {
            throw ExportError.outputMissing
        }
        return size.uint64Value
    }

    private static func readPrefix(_ url: URL, maxBytes: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        return try handle.read(upToCount: max(1, maxBytes)) ?? Data()
    }

    private static func readUInt16LE(_ data: Data, offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func readUInt32LE(_ data: Data, offset: Int) -> UInt32 {
        UInt32(data[offset]) |
            (UInt32(data[offset + 1]) << 8) |
            (UInt32(data[offset + 2]) << 16) |
            (UInt32(data[offset + 3]) << 24)
    }
}
