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

        var assimpExporterID: String? {
            switch self {
            case .fbx: return "fbx"
            case .obj: return "obj"
            case .glb: return "glb2"
            case .stl: return "stlb"
            case .usdz, .ply, .las: return nil
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
    private static let zipEndOfCentralDirectorySearchBytes = 65_557
    private static let plyHeaderSearchBytes = 64 * 1024

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
                case .fbx, .obj, .glb, .stl:
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
        guard (attributes[.type] as? FileAttributeType) == .typeRegular,
              let size = attributes[.size] as? NSNumber,
              size.intValue > 0 else {
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
            let data = try readPrefix(url, maxBytes: 20)
            if data.count >= 12,
               Array(data.prefix(4)) == [0x67, 0x6c, 0x54, 0x46] {
                let version = readUInt32LE(data, offset: 4)
                let declaredLength = UInt64(readUInt32LE(data, offset: 8))
                switch version {
                case 1:
                    valid = data.count >= 20 && declaredLength == totalBytes && declaredLength >= 20
                case 2:
                    if data.count >= 20 {
                        let jsonChunkLength = UInt64(readUInt32LE(data, offset: 12))
                        let firstChunkType = readUInt32LE(data, offset: 16)
                        valid = declaredLength == totalBytes &&
                            declaredLength >= 20 &&
                            jsonChunkLength > 0 &&
                            jsonChunkLength % 4 == 0 &&
                            jsonChunkLength <= declaredLength - 20 &&
                            firstChunkType == 0x4E4F534A
                    } else {
                        valid = false
                    }
                default:
                    valid = false
                }
            } else {
                valid = false
            }

        case .usdz:
            let prefix = try readPrefix(url, maxBytes: 4)
            let suffix = try readSuffix(url, maxBytes: zipEndOfCentralDirectorySearchBytes)
            valid = totalBytes >= 22 &&
                Array(prefix) == [0x50, 0x4b, 0x03, 0x04] &&
                hasValidZipEndOfCentralDirectory(suffix, url: url, totalBytes: totalBytes)

        case .stl:
            let data = try readPrefix(url, maxBytes: 1_000_000)
            let asciiPrefix = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if asciiPrefix.hasPrefix("solid"), asciiPrefix.contains("facet"), asciiPrefix.contains("endsolid") {
                valid = true
            } else if data.count >= 84, totalBytes >= 84 {
                let triangleCount = UInt64(readUInt32LE(data, offset: 80))
                if triangleCount == 0 || triangleCount > (UInt64.max - 84) / 50 {
                    valid = false
                } else {
                    let requiredBytes = 84 + triangleCount * 50
                    valid = requiredBytes == totalBytes
                }
            } else {
                valid = false
            }

        case .obj:
            let data = try readPrefix(url, maxBytes: 1_000_000)
            guard let text = String(data: data, encoding: .utf8) else {
                valid = false
                break
            }
            valid = text.hasPrefix("v ") || text.contains("\nv ")

        case .ply:
            let data = try readPrefix(url, maxBytes: plyHeaderSearchBytes)
            valid = validBinaryPointCloudPLY(data, totalBytes: totalBytes)

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

    private static func validBinaryPointCloudPLY(_ data: Data, totalBytes: UInt64) -> Bool {
        let marker = Data("end_header\n".utf8)
        guard let markerRange = data.range(of: marker) else { return false }
        let headerEnd = markerRange.upperBound
        guard let header = String(data: data.prefix(upTo: headerEnd), encoding: .utf8),
              header.hasPrefix("ply\n"),
              header.contains("format binary_little_endian 1.0\n") else {
            return false
        }

        var vertexCount: UInt64?
        var vertexStride: UInt64 = 0
        var parsingVertexProperties = false
        var sawX = false
        var sawY = false
        var sawZ = false

        for line in header.split(separator: "\n", omittingEmptySubsequences: false) {
            let parts = line.split(separator: " ")
            guard !parts.isEmpty else { continue }

            if parts[0] == "element" {
                guard parts.count == 3 else { return false }
                let name = String(parts[1])
                guard name == "vertex", vertexCount == nil,
                      let count = UInt64(parts[2]), count > 0 else {
                    return false
                }
                vertexCount = count
                parsingVertexProperties = true
                continue
            }

            guard parts[0] == "property", parsingVertexProperties else { continue }
            guard parts.count == 3,
                  let width = plyScalarByteWidth(String(parts[1])) else {
                return false
            }
            let propertyName = String(parts[2])
            sawX = sawX || propertyName == "x"
            sawY = sawY || propertyName == "y"
            sawZ = sawZ || propertyName == "z"
            let (nextStride, overflow) = vertexStride.addingReportingOverflow(width)
            guard !overflow else { return false }
            vertexStride = nextStride
        }

        guard let vertexCount,
              vertexStride > 0,
              sawX, sawY, sawZ else {
            return false
        }
        let (payloadBytes, overflow) = vertexCount.multipliedReportingOverflow(by: vertexStride)
        guard !overflow else { return false }
        let (requiredBytes, totalOverflow) = UInt64(headerEnd).addingReportingOverflow(payloadBytes)
        return !totalOverflow && requiredBytes == totalBytes
    }

    private static func plyScalarByteWidth(_ type: String) -> UInt64? {
        switch type.lowercased() {
        case "char", "uchar", "int8", "uint8": return 1
        case "short", "ushort", "int16", "uint16": return 2
        case "int", "uint", "int32", "uint32", "float", "float32": return 4
        case "double", "float64": return 8
        default: return nil
        }
    }

    private static func hasValidZipEndOfCentralDirectory(
        _ data: Data,
        url: URL,
        totalBytes: UInt64
    ) -> Bool {
        guard data.count >= 22 else { return false }
        let suffixStart = totalBytes - UInt64(data.count)

        for offset in stride(from: data.count - 22, through: 0, by: -1) {
            guard data[offset] == 0x50,
                  data[offset + 1] == 0x4b,
                  data[offset + 2] == 0x05,
                  data[offset + 3] == 0x06 else { continue }

            let commentLength = Int(readUInt16LE(data, offset: offset + 20))
            guard offset + 22 + commentLength == data.count else { continue }

            let diskNumber = readUInt16LE(data, offset: offset + 4)
            let centralDirectoryDisk = readUInt16LE(data, offset: offset + 6)
            let entriesOnDisk = UInt64(readUInt16LE(data, offset: offset + 8))
            let totalEntries = UInt64(readUInt16LE(data, offset: offset + 10))
            let centralDirectorySize = UInt64(readUInt32LE(data, offset: offset + 12))
            let centralDirectoryOffset = UInt64(readUInt32LE(data, offset: offset + 16))
            let endOfCentralDirectoryOffset = suffixStart + UInt64(offset)

            guard diskNumber == 0,
                  centralDirectoryDisk == 0,
                  entriesOnDisk > 0,
                  entriesOnDisk == totalEntries,
                  centralDirectorySize >= totalEntries * 46,
                  centralDirectoryOffset < endOfCentralDirectoryOffset,
                  centralDirectoryOffset + centralDirectorySize <= endOfCentralDirectoryOffset,
                  let centralSignature = try? readRange(url, offset: centralDirectoryOffset, maxBytes: 4),
                  Array(centralSignature) == [0x50, 0x4b, 0x01, 0x02] else {
                continue
            }
            return true
        }
        return false
    }

    private static func fileByteCount(_ url: URL) throws -> UInt64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard (attributes[.type] as? FileAttributeType) == .typeRegular,
              let size = attributes[.size] as? NSNumber else {
            throw ExportError.outputMissing
        }
        return size.uint64Value
    }

    private static func readPrefix(_ url: URL, maxBytes: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        return try handle.read(upToCount: max(1, maxBytes)) ?? Data()
    }

    private static func readSuffix(_ url: URL, maxBytes: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let size = try handle.seekToEnd()
        let count = min(UInt64(max(1, maxBytes)), size)
        try handle.seek(toOffset: size - count)
        return try handle.readToEnd() ?? Data()
    }

    private static func readRange(_ url: URL, offset: UInt64, maxBytes: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: offset)
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
