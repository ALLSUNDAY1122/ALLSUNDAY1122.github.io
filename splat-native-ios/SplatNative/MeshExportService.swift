import AssimpBinary
import Foundation
import ModelIO

enum MeshExportService {
    enum Format: String, CaseIterable, Identifiable, Sendable {
        case fbx, obj, glb, usdz, stl, ply, las
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
        case sourceMissing, emptySource
        case unsupportedSource(String)
        case unsupportedConversion(source: String, destination: String)
        case assimpImporterFailed(String), assimpExporterUnavailable(String), assimpExportFailed(String)
        case invalidContainer(String), outputMissing
        var errorDescription: String? {
            switch self {
            case .sourceMissing: return "Meshの書き出し元が見つかりません。"
            case .emptySource: return "Meshファイルが空です。"
            case .unsupportedSource(let ext): return "この端末では.\(ext)をMesh変換元として読み込めません。"
            case .unsupportedConversion(let source, let destination): return ".\(source)から.\(destination)へ正しい3Dデータとして変換できません。"
            case .assimpImporterFailed(let message): return "Mesh中間データを読み込めませんでした。\n\(message)"
            case .assimpExporterUnavailable(let format): return "このビルドには\(format)の実Exporterが含まれていません。"
            case .assimpExportFailed(let message): return "Meshの実ファイル書き出しに失敗しました。\n\(message)"
            case .invalidContainer(let format): return "出力された.\(format)が実フォーマットとして検証できませんでした。"
            case .outputMissing: return "書き出しファイルを完成できませんでした。"
            }
        }
    }

    struct Capability: Equatable, Sendable { let format: Format; let isAvailable: Bool; let reason: String? }
    private static let las12HeaderSize = 227
    private static let zipEndOfCentralDirectorySearchBytes = 65_557

    static func capabilities(for sourceURL: URL) -> [Capability] {
        let ext = sourceURL.pathExtension.lowercased()
        let exporters = assimpExporterIDs()
        let canBridge = ext == "obj" || (MDLAsset.canImportFileExtension(ext) && MDLAsset.canExportFileExtension("obj"))
        return Format.allCases.map { format in
            if ext == format.rawValue { return Capability(format: format, isAvailable: true, reason: nil) }
            if format == .usdz {
                let ok = MDLAsset.canImportFileExtension(ext) && MDLAsset.canExportFileExtension("usdz")
                return Capability(format: format, isAvailable: ok, reason: ok ? nil : "Model I/OでUSDZへ実変換できません")
            }
            guard canBridge else { return Capability(format: format, isAvailable: false, reason: "元の.\(ext)をOBJ中間データへ変換できません") }
            if format == .ply || format == .las { return Capability(format: format, isAvailable: true, reason: nil) }
            guard let id = format.assimpExporterID, exporters.contains(id) else { return Capability(format: format, isAvailable: false, reason: "実\(format.displayName) Exporterがこのビルドにありません") }
            return Capability(format: format, isAvailable: true, reason: nil)
        }
    }

    static func export(sourceURL: URL, format: Format, destinationDirectory: URL? = nil) async throws -> URL {
        try Task.checkCancellation(); try validateSource(sourceURL)
        let directory = destinationDirectory ?? sourceURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let finalURL = directory.appendingPathComponent("scan-mesh-\(UUID().uuidString).\(format.rawValue)")
        let partialURL = directory.appendingPathComponent(".\(finalURL.lastPathComponent).partial.\(format.rawValue)")
        let bridgeDirectory = directory.appendingPathComponent(".mesh-export-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.removeItem(at: partialURL); try? FileManager.default.removeItem(at: bridgeDirectory)
        do {
            let ext = sourceURL.pathExtension.lowercased()
            if ext == format.rawValue { try FileManager.default.copyItem(at: sourceURL, to: partialURL) }
            else if format == .usdz {
                guard MDLAsset.canImportFileExtension(ext), MDLAsset.canExportFileExtension("usdz") else { throw ExportError.unsupportedConversion(source: ext, destination: "usdz") }
                let asset = MDLAsset(url: sourceURL); try Task.checkCancellation(); try asset.export(to: partialURL)
            } else {
                try FileManager.default.createDirectory(at: bridgeDirectory, withIntermediateDirectories: true)
                let bridge = try bridgeToOBJ(sourceURL: sourceURL, bridgeDirectory: bridgeDirectory); try Task.checkCancellation()
                switch format {
                case .ply: try MeshPointCloudExportService.exportPLY(sourceOBJ: bridge, outputURL: partialURL)
                case .las: try MeshPointCloudExportService.exportLAS12(sourceOBJ: bridge, outputURL: partialURL)
                case .fbx, .obj, .glb, .stl:
                    guard let id = format.assimpExporterID else { throw ExportError.unsupportedConversion(source: ext, destination: format.rawValue) }
                    guard assimpExporterIDs().contains(id) else { throw ExportError.assimpExporterUnavailable(format.displayName) }
                    try exportWithAssimp(sourceOBJ: bridge, exporterID: id, outputURL: partialURL)
                case .usdz: throw ExportError.unsupportedConversion(source: ext, destination: format.rawValue)
                }
            }
            try Task.checkCancellation(); try validateOutput(partialURL); try validateContainer(partialURL, as: format)
            if FileManager.default.fileExists(atPath: finalURL.path) { try FileManager.default.removeItem(at: finalURL) }
            try FileManager.default.moveItem(at: partialURL, to: finalURL); try? FileManager.default.removeItem(at: bridgeDirectory); return finalURL
        } catch {
            try? FileManager.default.removeItem(at: partialURL); try? FileManager.default.removeItem(at: finalURL); try? FileManager.default.removeItem(at: bridgeDirectory); throw error
        }
    }

    static func assimpExporterIDs() -> Set<String> {
        var ids = Set<String>(); for index in 0..<aiGetExportFormatCount() { guard let d = aiGetExportFormatDescription(index) else { continue }; defer { aiReleaseExportFormatDescription(d) }; if let p = d.pointee.id { ids.insert(String(cString: p)) } }; return ids
    }

    private static func bridgeToOBJ(sourceURL: URL, bridgeDirectory: URL) throws -> URL {
        let ext = sourceURL.pathExtension.lowercased(); if ext == "obj" { return sourceURL }
        guard MDLAsset.canImportFileExtension(ext), MDLAsset.canExportFileExtension("obj") else { throw ExportError.unsupportedSource(ext) }
        let url = bridgeDirectory.appendingPathComponent("scene.obj"); let asset = MDLAsset(url: sourceURL); try Task.checkCancellation(); try asset.export(to: url); try validateOutput(url); return url
    }

    private static func exportWithAssimp(sourceOBJ: URL, exporterID: String, outputURL: URL) throws {
        let scene: UnsafePointer<aiScene>? = sourceOBJ.path.withCString { aiImportFile($0, 0) }; guard let scene else { throw ExportError.assimpImporterFailed(assimpErrorString()) }; defer { aiReleaseImport(scene) }
        let result: aiReturn = exporterID.withCString { f in outputURL.path.withCString { o in aiExportScene(scene, f, o, 0) } }; guard result == aiReturn_SUCCESS else { throw ExportError.assimpExportFailed(assimpErrorString()) }
    }
    private static func assimpErrorString() -> String { guard let p = aiGetErrorString() else { return "Assimp error detail unavailable" }; let s = String(cString: p); return s.isEmpty ? "Assimp returned an unspecified error" : s }
    private static func validateSource(_ url: URL) throws { guard url.isFileURL, FileManager.default.fileExists(atPath: url.path) else { throw ExportError.sourceMissing }; let a = try FileManager.default.attributesOfItem(atPath: url.path); guard (a[.type] as? FileAttributeType) == .typeRegular, let n = a[.size] as? NSNumber, n.intValue > 0 else { throw ExportError.emptySource } }
    private static func validateOutput(_ url: URL) throws { guard try fileByteCount(url) > 0 else { throw ExportError.outputMissing } }

    private static func validateContainer(_ url: URL, as format: Format) throws {
        let total = try fileByteCount(url); guard total > 0 else { throw ExportError.outputMissing }; let valid: Bool
        switch format {
        case .fbx:
            let s = String(decoding: try readPrefix(url, maxBytes: 32), as: UTF8.self); valid = s.contains("Kaydara FBX Binary") || s.contains("; FBX")
        case .glb:
            let d = try readPrefix(url, maxBytes: 20)
            if d.count >= 12, Array(d.prefix(4)) == [0x67,0x6c,0x54,0x46] { let v = readUInt32LE(d, offset: 4), l = UInt64(readUInt32LE(d, offset: 8)); valid = v == 1 ? (d.count >= 20 && l == total && l >= 20) : (v == 2 && l == total && l >= 12) } else { valid = false }
        case .usdz:
            let p = try readPrefix(url, maxBytes: 4), s = try readSuffix(url, maxBytes: zipEndOfCentralDirectorySearchBytes)
            valid = total >= 22 && Array(p) == [0x50,0x4b,0x03,0x04] && hasValidZipEndOfCentralDirectory(s)
        case .stl:
            let d = try readPrefix(url, maxBytes: 1_000_000), s = String(decoding: d, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if s.hasPrefix("solid"), s.contains("facet"), s.contains("endsolid") { valid = true } else if d.count >= 84, total >= 84 { let c = UInt64(readUInt32LE(d, offset: 80)); valid = c > 0 && c <= (UInt64.max - 84) / 50 && 84 + c * 50 == total } else { valid = false }
        case .obj:
            let d = try readPrefix(url, maxBytes: 1_000_000); if let s = String(data: d, encoding: .utf8) { valid = s.hasPrefix("v ") || s.contains("\nv ") } else { valid = false }
        case .ply:
            let s = String(decoding: try readPrefix(url, maxBytes: 2_048), as: UTF8.self); valid = s.hasPrefix("ply\n") && s.contains("format binary_little_endian 1.0") && s.contains("element vertex ") && !s.contains("element face ") && s.contains("end_header\n")
        case .las:
            let d = try readPrefix(url, maxBytes: las12HeaderSize)
            if d.count >= las12HeaderSize, Array(d.prefix(4)) == [0x4c,0x41,0x53,0x46] { let h=Int(readUInt16LE(d,offset:94)), o=Int(readUInt32LE(d,offset:96)), f=d[104]&0x3f, r=Int(readUInt16LE(d,offset:105)), c=UInt64(readUInt32LE(d,offset:107)); valid = h >= las12HeaderSize && o >= h && UInt64(o) <= total && f <= 10 && r > 0 && UInt64(o)+c*UInt64(r) <= total } else { valid=false }
        }
        guard valid else { throw ExportError.invalidContainer(format.rawValue) }
    }

    private static func hasValidZipEndOfCentralDirectory(_ data: Data) -> Bool {
        guard data.count >= 22 else { return false }
        for offset in stride(from: data.count - 22, through: 0, by: -1) {
            guard data[offset] == 0x50, data[offset+1] == 0x4b, data[offset+2] == 0x05, data[offset+3] == 0x06 else { continue }
            let commentLength = Int(readUInt16LE(data, offset: offset + 20))
            if offset + 22 + commentLength == data.count { return true }
        }
        return false
    }
    private static func fileByteCount(_ url: URL) throws -> UInt64 { let a=try FileManager.default.attributesOfItem(atPath:url.path); guard (a[.type] as? FileAttributeType) == .typeRegular, let n=a[.size] as? NSNumber else { throw ExportError.outputMissing }; return n.uint64Value }
    private static func readPrefix(_ url: URL, maxBytes: Int) throws -> Data { let h=try FileHandle(forReadingFrom:url); defer{try? h.close()}; return try h.read(upToCount:max(1,maxBytes)) ?? Data() }
    private static func readSuffix(_ url: URL, maxBytes: Int) throws -> Data { let h=try FileHandle(forReadingFrom:url); defer{try? h.close()}; let size=try h.seekToEnd(), count=min(UInt64(max(1,maxBytes)),size); try h.seek(toOffset:size-count); return try h.readToEnd() ?? Data() }
    private static func readUInt16LE(_ d: Data, offset: Int) -> UInt16 { UInt16(d[offset]) | (UInt16(d[offset+1]) << 8) }
    private static func readUInt32LE(_ d: Data, offset: Int) -> UInt32 { UInt32(d[offset]) | (UInt32(d[offset+1])<<8) | (UInt32(d[offset+2])<<16) | (UInt32(d[offset+3])<<24) }
}
