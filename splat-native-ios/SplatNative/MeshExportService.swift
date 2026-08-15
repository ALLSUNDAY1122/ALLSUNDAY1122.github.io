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
        case meshGeometryMissing
        case tooManyVertices(Int)
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
            case .meshGeometryMissing:
                return "Mesh中間データに頂点がありません。"
            case .tooManyVertices(let count):
                return "LAS 1.2で扱える点数を超えています（\(count)点）。"
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

    private struct VertexColor {
        let red: UInt16
        let green: UInt16
        let blue: UInt16
    }

    private struct OBJVertex {
        let x: Double
        let y: Double
        let z: Double
        let color: VertexColor?
    }

    private struct OBJTriangle {
        let a: UInt32
        let b: UInt32
        let c: UInt32
    }

    private struct OBJGeometry {
        let vertices: [OBJVertex]
        let triangles: [OBJTriangle]
    }

    private struct LASAxis {
        let scale: Double
        let offset: Double
    }

    private static let las12HeaderSize = 227
    private static let streamFlushThreshold = 64 * 1024

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
                    try exportBinaryPLY(sourceOBJ: bridgeURL, outputURL: partialURL)
                case .las:
                    try exportLAS12(sourceOBJ: bridgeURL, outputURL: partialURL)
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

    /// Scaniverse exposes PLY as a Mesh export. We write a real binary little-endian PLY
    /// containing geometry (and vertex RGB when the OBJ carries the common vertex-color extension)
    /// instead of renaming another container.
    private static func exportBinaryPLY(sourceOBJ: URL, outputURL: URL) throws {
        let geometry = try parseOBJ(sourceOBJ)
        guard !geometry.vertices.isEmpty else { throw ExportError.meshGeometryMissing }
        let hasColor = geometry.vertices.contains { $0.color != nil }

        var header = """
        ply
        format binary_little_endian 1.0
        comment Generated by Scan Lab Native
        element vertex \(geometry.vertices.count)
        property float x
        property float y
        property float z
        """
        if hasColor {
            header += "\nproperty uchar red\nproperty uchar green\nproperty uchar blue"
        }
        header += "\nelement face \(geometry.triangles.count)\nproperty list uchar uint vertex_indices\nend_header\n"

        try? FileManager.default.removeItem(at: outputURL)
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil) else {
            throw ExportError.outputMissing
        }
        let handle = try FileHandle(forWritingTo: outputURL)
        do {
            try handle.write(contentsOf: Data(header.utf8))
            var buffer = Data()
            buffer.reserveCapacity(streamFlushThreshold + 64)

            for (index, vertex) in geometry.vertices.enumerated() {
                if index % 4_096 == 0 { try Task.checkCancellation() }
                appendFloat32(Float(vertex.x), to: &buffer)
                appendFloat32(Float(vertex.y), to: &buffer)
                appendFloat32(Float(vertex.z), to: &buffer)
                if hasColor {
                    let color = vertex.color ?? VertexColor(red: 0, green: 0, blue: 0)
                    buffer.append(UInt8(color.red / 257))
                    buffer.append(UInt8(color.green / 257))
                    buffer.append(UInt8(color.blue / 257))
                }
                try flushIfNeeded(&buffer, to: handle)
            }

            for (index, triangle) in geometry.triangles.enumerated() {
                if index % 4_096 == 0 { try Task.checkCancellation() }
                buffer.append(3)
                appendLittleEndian(triangle.a, to: &buffer)
                appendLittleEndian(triangle.b, to: &buffer)
                appendLittleEndian(triangle.c, to: &buffer)
                try flushIfNeeded(&buffer, to: handle)
            }
            if !buffer.isEmpty { try handle.write(contentsOf: buffer) }
            try handle.close()
        } catch {
            try? handle.close()
            throw error
        }
    }

    /// LAS is a point-cloud container, so the Mesh vertices become the exported points.
    /// LAS 1.2 is used for broad interchange compatibility. Point format 2 is selected only
    /// when real per-vertex RGB exists; otherwise point format 0 avoids inventing color.
    private static func exportLAS12(sourceOBJ: URL, outputURL: URL) throws {
        let geometry = try parseOBJ(sourceOBJ)
        guard !geometry.vertices.isEmpty else { throw ExportError.meshGeometryMissing }
        guard geometry.vertices.count <= Int(UInt32.max) else {
            throw ExportError.tooManyVertices(geometry.vertices.count)
        }

        let hasColor = geometry.vertices.contains { $0.color != nil }
        let recordFormat: UInt8 = hasColor ? 2 : 0
        let recordLength: UInt16 = hasColor ? 26 : 20
        let pointCount = UInt32(geometry.vertices.count)

        let minX = geometry.vertices.map(\.x).min() ?? 0
        let maxX = geometry.vertices.map(\.x).max() ?? 0
        let minY = geometry.vertices.map(\.y).min() ?? 0
        let maxY = geometry.vertices.map(\.y).max() ?? 0
        let minZ = geometry.vertices.map(\.z).min() ?? 0
        let maxZ = geometry.vertices.map(\.z).max() ?? 0
        let xAxis = lasAxis(minimum: minX, maximum: maxX)
        let yAxis = lasAxis(minimum: minY, maximum: maxY)
        let zAxis = lasAxis(minimum: minZ, maximum: maxZ)

        var header = Data()
        header.reserveCapacity(las12HeaderSize)
        header.append(contentsOf: [0x4c, 0x41, 0x53, 0x46]) // LASF
        appendLittleEndian(UInt16(0), to: &header) // File Source ID
        appendLittleEndian(UInt16(0), to: &header) // Global Encoding
        header.append(Data(repeating: 0, count: 16)) // Project ID GUID
        header.append(1) // Version major
        header.append(2) // Version minor
        appendFixedASCII("Scan Lab Mesh", width: 32, to: &header)
        appendFixedASCII("Scan Lab Native", width: 32, to: &header)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let now = Date()
        appendLittleEndian(UInt16(calendar.ordinality(of: .day, in: .year, for: now) ?? 0), to: &header)
        appendLittleEndian(UInt16(calendar.component(.year, from: now)), to: &header)
        appendLittleEndian(UInt16(las12HeaderSize), to: &header)
        appendLittleEndian(UInt32(las12HeaderSize), to: &header)
        appendLittleEndian(UInt32(0), to: &header) // VLR count
        header.append(recordFormat)
        appendLittleEndian(recordLength, to: &header)
        appendLittleEndian(pointCount, to: &header)
        appendLittleEndian(pointCount, to: &header) // points by return 1
        for _ in 0..<4 { appendLittleEndian(UInt32(0), to: &header) }
        appendFloat64(xAxis.scale, to: &header)
        appendFloat64(yAxis.scale, to: &header)
        appendFloat64(zAxis.scale, to: &header)
        appendFloat64(xAxis.offset, to: &header)
        appendFloat64(yAxis.offset, to: &header)
        appendFloat64(zAxis.offset, to: &header)
        appendFloat64(maxX, to: &header)
        appendFloat64(minX, to: &header)
        appendFloat64(maxY, to: &header)
        appendFloat64(minY, to: &header)
        appendFloat64(maxZ, to: &header)
        appendFloat64(minZ, to: &header)
        guard header.count == las12HeaderSize else {
            throw ExportError.invalidContainer("las")
        }

        try? FileManager.default.removeItem(at: outputURL)
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil) else {
            throw ExportError.outputMissing
        }
        let handle = try FileHandle(forWritingTo: outputURL)
        do {
            try handle.write(contentsOf: header)
            var buffer = Data()
            buffer.reserveCapacity(streamFlushThreshold + 64)
            for (index, vertex) in geometry.vertices.enumerated() {
                if index % 4_096 == 0 { try Task.checkCancellation() }
                appendLittleEndian(quantize(vertex.x, axis: xAxis), to: &buffer)
                appendLittleEndian(quantize(vertex.y, axis: yAxis), to: &buffer)
                appendLittleEndian(quantize(vertex.z, axis: zAxis), to: &buffer)
                appendLittleEndian(UInt16(0), to: &buffer) // intensity
                buffer.append(0x09) // return 1 of 1
                buffer.append(0) // classification
                buffer.append(0) // scan angle rank
                buffer.append(0) // user data
                appendLittleEndian(UInt16(0), to: &buffer) // point source ID
                if hasColor {
                    let color = vertex.color ?? VertexColor(red: 0, green: 0, blue: 0)
                    appendLittleEndian(color.red, to: &buffer)
                    appendLittleEndian(color.green, to: &buffer)
                    appendLittleEndian(color.blue, to: &buffer)
                }
                try flushIfNeeded(&buffer, to: handle)
            }
            if !buffer.isEmpty { try handle.write(contentsOf: buffer) }
            try handle.close()
        } catch {
            try? handle.close()
            throw error
        }
    }

    private static func parseOBJ(_ url: URL) throws -> OBJGeometry {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let text = String(decoding: data, as: UTF8.self)
        var vertices: [OBJVertex] = []
        var triangles: [OBJTriangle] = []
        vertices.reserveCapacity(max(128, data.count / 80))

        text.enumerateLines { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return }
            let fields = trimmed.split(whereSeparator: { $0.isWhitespace })
            guard let kind = fields.first else { return }

            if kind == "v", fields.count >= 4,
               let x = Double(fields[1]), let y = Double(fields[2]), let z = Double(fields[3]),
               x.isFinite, y.isFinite, z.isFinite {
                var color: VertexColor?
                if fields.count >= 7,
                   let red = Double(fields[4]), let green = Double(fields[5]), let blue = Double(fields[6]),
                   red.isFinite, green.isFinite, blue.isFinite {
                    color = normalizedVertexColor(red: red, green: green, blue: blue)
                }
                vertices.append(OBJVertex(x: x, y: y, z: z, color: color))
                return
            }

            guard kind == "f", fields.count >= 4 else { return }
            var indices: [UInt32] = []
            indices.reserveCapacity(fields.count - 1)
            for token in fields.dropFirst() {
                let pieces = token.split(separator: "/", omittingEmptySubsequences: false)
                guard let raw = pieces.first, let objIndex = Int(raw), objIndex != 0 else {
                    indices.removeAll()
                    break
                }
                let resolved = objIndex > 0 ? objIndex - 1 : vertices.count + objIndex
                guard resolved >= 0, resolved < vertices.count, resolved <= Int(UInt32.max) else {
                    indices.removeAll()
                    break
                }
                indices.append(UInt32(resolved))
            }
            guard indices.count >= 3 else { return }
            for index in 1..<(indices.count - 1) {
                triangles.append(OBJTriangle(a: indices[0], b: indices[index], c: indices[index + 1]))
            }
        }

        return OBJGeometry(vertices: vertices, triangles: triangles)
    }

    private static func normalizedVertexColor(red: Double, green: Double, blue: Double) -> VertexColor {
        let values = [red, green, blue]
        let unitRange = values.allSatisfy { $0 >= 0 && $0 <= 1 }
        let byteRange = values.allSatisfy { $0 >= 0 && $0 <= 255 }
        let multiplier: Double = unitRange ? 65_535 : (byteRange ? 257 : 1)
        func convert(_ value: Double) -> UInt16 {
            UInt16(clamping: Int((value * multiplier).rounded()))
        }
        return VertexColor(red: convert(red), green: convert(green), blue: convert(blue))
    }

    private static func lasAxis(minimum: Double, maximum: Double) -> LASAxis {
        let offset = (minimum + maximum) / 2
        let halfSpan = max(abs(maximum - offset), abs(minimum - offset))
        let safeIntegerRange = Double(Int32.max) - 4_096
        let scale = max(0.000_001, halfSpan / max(1, safeIntegerRange))
        return LASAxis(scale: scale, offset: offset)
    }

    private static func quantize(_ value: Double, axis: LASAxis) -> Int32 {
        let raw = ((value - axis.offset) / axis.scale).rounded()
        if raw <= Double(Int32.min) { return Int32.min }
        if raw >= Double(Int32.max) { return Int32.max }
        return Int32(raw)
    }

    private static func flushIfNeeded(_ buffer: inout Data, to handle: FileHandle) throws {
        guard buffer.count >= streamFlushThreshold else { return }
        try handle.write(contentsOf: buffer)
        buffer.removeAll(keepingCapacity: true)
    }

    private static func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }

    private static func appendFloat32(_ value: Float, to data: inout Data) {
        appendLittleEndian(value.bitPattern, to: &data)
    }

    private static func appendFloat64(_ value: Double, to data: inout Data) {
        appendLittleEndian(value.bitPattern, to: &data)
    }

    private static func appendFixedASCII(_ value: String, width: Int, to data: inout Data) {
        let bytes = Array(value.utf8.prefix(width))
        data.append(contentsOf: bytes)
        if bytes.count < width {
            data.append(Data(repeating: 0, count: width - bytes.count))
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
        case .ply:
            let prefix = String(decoding: data.prefix(min(data.count, 2_048)), as: UTF8.self)
            valid = prefix.hasPrefix("ply\n") &&
                prefix.contains("format ") &&
                prefix.contains("element vertex ") &&
                prefix.contains("end_header\n")
        case .las:
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
                pointOffset <= data.count &&
                pointFormat <= 10 &&
                recordLength > 0 &&
                requiredBytes <= UInt64(data.count)
        }

        guard valid else { throw ExportError.invalidContainer(format.rawValue) }
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
