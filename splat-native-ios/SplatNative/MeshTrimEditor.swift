import Foundation
import SceneKit
import SwiftUI

struct MeshTrimResult: Sendable {
    let url: URL
    let usedVertexCount: Int
    let faceCount: Int
}

enum MeshTrimEngine {
    private struct Vertex {
        let x: Float
        let y: Float
        let z: Float
    }

    private static let inputChunkSize = 256 * 1024
    private static let maximumOBJLineBytes = 8 * 1024 * 1024

    static func trim(url: URL, x: ClosedRange<Double>, y: ClosedRange<Double>, z: ClosedRange<Double>) throws -> MeshTrimResult {
        let sourceValues = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard sourceValues.isRegularFile == true, sourceValues.isSymbolicLink != true else {
            throw error("トリミング元Meshが安全な通常ファイルではありません")
        }

        var vertices: [Vertex] = []
        var hasMaterialLibrary = false

        try forEachOBJLine(at: url) { line in
            guard let directive = firstDirective(in: line) else { return }
            if directive.lowercased() == "mtllib" {
                hasMaterialLibrary = true
                return
            }
            guard directive == "v" else { return }
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count >= 4,
                  let a = Float(fields[1]),
                  let b = Float(fields[2]),
                  let c = Float(fields[3]),
                  a.isFinite, b.isFinite, c.isFinite else {
                throw error("OBJ頂点定義が不正です")
            }
            vertices.append(Vertex(x: a, y: b, z: c))
        }
        guard !vertices.isEmpty else { throw error("OBJ頂点がありません") }

        var minimumX = Float.greatestFiniteMagnitude
        var minimumY = Float.greatestFiniteMagnitude
        var minimumZ = Float.greatestFiniteMagnitude
        var maximumX = -Float.greatestFiniteMagnitude
        var maximumY = -Float.greatestFiniteMagnitude
        var maximumZ = -Float.greatestFiniteMagnitude
        for point in vertices {
            minimumX = min(minimumX, point.x)
            minimumY = min(minimumY, point.y)
            minimumZ = min(minimumZ, point.z)
            maximumX = max(maximumX, point.x)
            maximumY = max(maximumY, point.y)
            maximumZ = max(maximumZ, point.z)
        }
        let extentX = max(maximumX - minimumX, 0.000001)
        let extentY = max(maximumY - minimumY, 0.000001)
        let extentZ = max(maximumZ - minimumZ, 0.000001)
        guard extentX.isFinite, extentY.isFinite, extentZ.isFinite else {
            throw error("Meshの座標範囲が大きすぎます")
        }
        let bounds = [x.lowerBound, x.upperBound, y.lowerBound, y.upperBound, z.lowerBound, z.upperBound]
        guard bounds.allSatisfy(\.isFinite) else { throw error("トリミング範囲が不正です") }
        let lowX = minimumX + extentX * Float(x.lowerBound)
        let lowY = minimumY + extentY * Float(y.lowerBound)
        let lowZ = minimumZ + extentZ * Float(z.lowerBound)
        let highX = minimumX + extentX * Float(x.upperBound)
        let highY = minimumY + extentY * Float(y.upperBound)
        let highZ = minimumZ + extentZ * Float(z.upperBound)
        guard lowX.isFinite, lowY.isFinite, lowZ.isFinite,
              highX.isFinite, highY.isFinite, highZ.isFinite else {
            throw error("トリミング境界を計算できません")
        }

        let bitWordCount = (vertices.count >> 6) + ((vertices.count & 63) == 0 ? 0 : 1)
        var usedVertexBits = [UInt64](repeating: 0, count: bitWordCount)
        var usedVertexCount = 0
        var faceCount = 0
        var faceIndices: [Int] = []
        faceIndices.reserveCapacity(4)
        var verticesSeen = 0
        var faceRecordIndex = 0
        var selectedFaceBits: [UInt64] = []

        try forEachOBJLine(at: url) { line in
            let directive = firstDirective(in: line)
            if directive == "v" {
                verticesSeen += 1
                return
            }
            guard directive == "f" else { return }

            let fields = line.split(whereSeparator: \.isWhitespace)
            let faceFields = fields.dropFirst().prefix { !$0.hasPrefix("#") }
            guard faceFields.count >= 3 else { throw error("OBJ面定義が不正です") }
            faceIndices.removeAll(keepingCapacity: true)
            if faceIndices.capacity < faceFields.count {
                faceIndices.reserveCapacity(faceFields.count)
            }
            for token in faceFields {
                let index = try resolveVertexIndex(token: token, verticesDefined: verticesSeen, totalVertices: vertices.count)
                faceIndices.append(index)
            }

            var centroidX: Float = 0
            var centroidY: Float = 0
            var centroidZ: Float = 0
            for id in faceIndices {
                let point = vertices[id]
                centroidX += point.x
                centroidY += point.y
                centroidZ += point.z
            }
            let inverseCount = 1 / Float(faceIndices.count)
            centroidX *= inverseCount
            centroidY *= inverseCount
            centroidZ *= inverseCount
            guard centroidX.isFinite, centroidY.isFinite, centroidZ.isFinite else {
                throw error("面の位置を計算できません")
            }
            let inside = centroidX >= lowX && centroidX <= highX &&
                centroidY >= lowY && centroidY <= highY &&
                centroidZ >= lowZ && centroidZ <= highZ
            if inside {
                markBit(faceRecordIndex, in: &selectedFaceBits)
                for id in faceIndices {
                    let word = id >> 6
                    let mask = UInt64(1) << UInt64(id & 63)
                    if usedVertexBits[word] & mask == 0 {
                        usedVertexBits[word] |= mask
                        usedVertexCount += 1
                    }
                }
                faceCount += faceIndices.count - 2
            }
            faceRecordIndex += 1
        }
        guard faceCount > 0 else { throw error("トリミング範囲内に面が残りません") }

        var usedVertexPrefix = [Int](repeating: 0, count: usedVertexBits.count + 1)
        if !usedVertexBits.isEmpty {
            for word in 0..<usedVertexBits.count {
                usedVertexPrefix[word + 1] = usedVertexPrefix[word] + usedVertexBits[word].nonzeroBitCount
            }
        }

        let sourceName = url.lastPathComponent.lowercased()
        let visual = sourceName.contains("visual")
        let textured = sourceName.contains("textured") || hasMaterialLibrary
        let stem: String
        switch (visual, textured) {
        case (true, true): stem = "visual-mesh-textured-trimmed"
        case (true, false): stem = "visual-mesh-trimmed"
        case (false, true): stem = "mesh-textured-trimmed"
        case (false, false): stem = "mesh-trimmed"
        }
        let out = url.deletingLastPathComponent()
            .appendingPathComponent("\(stem)-\(UUID().uuidString.lowercased()).obj")
        guard FileManager.default.createFile(atPath: out.path, contents: nil) else {
            throw error("トリミング結果を作成できません")
        }
        let handle: FileHandle
        do {
            handle = try FileHandle(forWritingTo: out)
        } catch {
            try? FileManager.default.removeItem(at: out)
            throw error
        }
        let writeBufferLimit = 256 * 1024
        var writeBuffer = Data()
        writeBuffer.reserveCapacity(writeBufferLimit)
        var completed = false
        defer {
            try? handle.close()
            if !completed { try? FileManager.default.removeItem(at: out) }
        }

        func flushOutput() throws {
            guard !writeBuffer.isEmpty else { return }
            try handle.write(contentsOf: writeBuffer)
            writeBuffer.removeAll(keepingCapacity: true)
        }

        func writeLine(_ line: Substring) throws {
            writeBuffer.append(contentsOf: line.utf8)
            writeBuffer.append(0x0A)
            if writeBuffer.count >= writeBufferLimit { try flushOutput() }
        }

        func writeString(_ line: String) throws {
            writeBuffer.append(contentsOf: line.utf8)
            writeBuffer.append(0x0A)
            if writeBuffer.count >= writeBufferLimit { try flushOutput() }
        }

        verticesSeen = 0
        faceRecordIndex = 0
        try forEachOBJLine(at: url) { line in
            let directive = firstDirective(in: line)
            if directive == "v" {
                let sourceIndex = verticesSeen
                verticesSeen += 1
                if isBitSet(sourceIndex, in: usedVertexBits) {
                    try writeLine(line)
                }
                return
            }
            guard directive == "f" else {
                try writeLine(line)
                return
            }

            let selected = isBitSet(faceRecordIndex, in: selectedFaceBits)
            faceRecordIndex += 1
            guard selected else { return }

            let fields = line.split(whereSeparator: \.isWhitespace)
            let faceFields = fields.dropFirst().prefix { !$0.hasPrefix("#") }
            guard faceFields.count >= 3 else { throw error("OBJ面定義が不正です") }
            var rewritten = "f"
            rewritten.reserveCapacity(line.utf8.count)
            for token in faceFields {
                let sourceIndex = try resolveVertexIndex(token: token, verticesDefined: verticesSeen, totalVertices: vertices.count)
                guard isBitSet(sourceIndex, in: usedVertexBits) else {
                    throw error("OBJ面の頂点対応が壊れています")
                }
                let compactIndex = compactVertexIndex(sourceIndex, bits: usedVertexBits, prefix: usedVertexPrefix)
                rewritten.append(" ")
                rewritten.append(contentsOf: String(compactIndex))
                if let slash = token.firstIndex(of: "/") {
                    rewritten.append(contentsOf: token[slash...])
                }
            }
            if let commentField = fields.firstIndex(where: { $0.hasPrefix("#") }) {
                rewritten.append(" ")
                rewritten.append(contentsOf: fields[commentField...].joined(separator: " "))
            }
            try writeString(rewritten)
        }

        try flushOutput()
        try handle.synchronize()
        completed = true
        return MeshTrimResult(url: out, usedVertexCount: usedVertexCount, faceCount: faceCount)
    }

    static func discard(_ result: MeshTrimResult) {
        try? FileManager.default.removeItem(at: result.url)
        let sidecar = result.url.deletingPathExtension().appendingPathExtension("mesh-asset.json")
        try? FileManager.default.removeItem(at: sidecar)
    }

    private static func resolveVertexIndex(token: Substring, verticesDefined: Int, totalVertices: Int) throws -> Int {
        let first: Substring
        if let slash = token.firstIndex(of: "/") {
            first = token[..<slash]
        } else {
            first = token
        }
        guard !first.isEmpty, let raw = Int(first), raw != 0 else {
            throw error("OBJ面定義が不正です")
        }
        let index = raw > 0 ? raw - 1 : verticesDefined + raw
        guard index >= 0, index < totalVertices else {
            throw error("OBJ面インデックスが範囲外です")
        }
        return index
    }

    private static func compactVertexIndex(_ sourceIndex: Int, bits: [UInt64], prefix: [Int]) -> Int {
        let word = sourceIndex >> 6
        let bit = sourceIndex & 63
        let lowerMask: UInt64 = bit == 0 ? 0 : (UInt64(1) << UInt64(bit)) - 1
        return prefix[word] + (bits[word] & lowerMask).nonzeroBitCount + 1
    }

    private static func markBit(_ index: Int, in bits: inout [UInt64]) {
        let word = index >> 6
        if word >= bits.count {
            bits.append(contentsOf: repeatElement(0, count: word - bits.count + 1))
        }
        bits[word] |= UInt64(1) << UInt64(index & 63)
    }

    private static func isBitSet(_ index: Int, in bits: [UInt64]) -> Bool {
        guard index >= 0 else { return false }
        let word = index >> 6
        guard word < bits.count else { return false }
        return bits[word] & (UInt64(1) << UInt64(index & 63)) != 0
    }

    private static func firstDirective(in line: Substring) -> Substring? {
        var start = line.startIndex
        while start < line.endIndex, line[start].isWhitespace {
            line.formIndex(after: &start)
        }
        guard start < line.endIndex else { return nil }
        var end = start
        while end < line.endIndex, !line[end].isWhitespace {
            line.formIndex(after: &end)
        }
        return line[start..<end]
    }

    private static func forEachOBJLine(at url: URL, _ body: (Substring) throws -> Void) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var buffer = Data()
        buffer.reserveCapacity(inputChunkSize * 2)

        while let chunk = try handle.read(upToCount: inputChunkSize), !chunk.isEmpty {
            buffer.append(chunk)
            var start = buffer.startIndex
            while start < buffer.endIndex,
                  let newline = buffer[start...].firstIndex(of: 0x0A) {
                var end = newline
                if end > start {
                    let previous = buffer.index(before: end)
                    if buffer[previous] == 0x0D { end = previous }
                }
                guard buffer.distance(from: start, to: end) <= maximumOBJLineBytes else {
                    throw error("OBJの1行が大きすぎます")
                }
                guard let lineString = String(bytes: buffer[start..<end], encoding: .utf8) else {
                    throw error("OBJがUTF-8として読み込めません")
                }
                try body(lineString[...])
                start = buffer.index(after: newline)
            }
            if start > buffer.startIndex {
                buffer.removeSubrange(buffer.startIndex..<start)
            }
            guard buffer.count <= maximumOBJLineBytes else {
                throw error("OBJの1行が大きすぎます")
            }
        }

        if !buffer.isEmpty {
            var end = buffer.endIndex
            if end > buffer.startIndex {
                let previous = buffer.index(before: end)
                if buffer[previous] == 0x0D { end = previous }
            }
            guard buffer.distance(from: buffer.startIndex, to: end) <= maximumOBJLineBytes else {
                throw error("OBJの1行が大きすぎます")
            }
            guard let lineString = String(bytes: buffer[buffer.startIndex..<end], encoding: .utf8) else {
                throw error("OBJがUTF-8として読み込めません")
            }
            try body(lineString[...])
        }
    }

    private static func error(_ message: String) -> NSError {
        NSError(domain: "ScanLab.MeshTrim", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

@MainActor
struct MeshTrimEditorSheet: View {
    @EnvironmentObject var model: MeshScanModel
    @Environment(\.dismiss) private var dismiss
    let sourceURL: URL
    @State private var x0 = 0.0
    @State private var x1 = 1.0
    @State private var y0 = 0.0
    @State private var y1 = 1.0
    @State private var z0 = 0.0
    @State private var z1 = 1.0
    @State private var working = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                axis("左右 X", low: $x0, high: $x1)
                axis("上下 Y", low: $y0, high: $y1)
                axis("前後 Z", low: $z0, high: $z1)
                Section { Text("6方向の実ジオメトリ平面で切り取ります。テクスチャOBJではUV/MTLを保持します。").font(.caption).foregroundStyle(.secondary) }
                if let errorText { Section { Text(errorText).foregroundStyle(.red) } }
                Section { Button(working ? "適用中…" : "トリミングを実Meshへ適用") { apply() }.disabled(working || x1 - x0 < 0.05 || y1 - y0 < 0.05 || z1 - z0 < 0.05) }
            }
            .navigationTitle("トリミング")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() }.disabled(working) } }
        }
        .interactiveDismissDisabled(working)
    }

    private func axis(_ title: String, low: Binding<Double>, high: Binding<Double>) -> some View {
        Section(title) {
            HStack { Text("開始"); Spacer(); Text("\(Int(low.wrappedValue * 100))%").monospacedDigit() }
            Slider(value: low, in: 0...max(0, high.wrappedValue - 0.05), step: 0.01)
            HStack { Text("終了"); Spacer(); Text("\(Int(high.wrappedValue * 100))%").monospacedDigit() }
            Slider(value: high, in: min(1, low.wrappedValue + 0.05)...1, step: 0.01)
        }
    }

    private func apply() {
        working = true
        errorText = nil
        let source = sourceURL, xLow = x0, xHigh = x1, yLow = y0, yHigh = y1, zLow = z0, zHigh = z1
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try MeshTrimEngine.trim(url: source, x: xLow...xHigh, y: yLow...yHigh, z: zLow...zHigh)
                }.value

                guard let candidateScene = try? SCNScene(url: result.url, options: nil),
                      MeshRawSceneValidator.containsGeometry(candidateScene) else {
                    MeshTrimEngine.discard(result)
                    throw NSError(domain:"ScanLab.MeshTrim", code:2, userInfo:[NSLocalizedDescriptionKey:"トリミング後のMeshを検証できませんでした。直前の結果を保持します。"])
                }

                let previousURL = model.resultURL
                let previousScene = model.previewScene
                let previousVertexCount = model.vertexCount
                let previousFaceCount = model.faceCount
                let previousStatus = model.statusMessage

                model.resultURL = result.url
                model.previewScene = candidateScene
                model.vertexCount = result.usedVertexCount
                model.faceCount = result.faceCount
                do {
                    try model.persistExporterMeshAssetContract()
                } catch {
                    model.resultURL = previousURL
                    model.previewScene = previousScene
                    model.vertexCount = previousVertexCount
                    model.faceCount = previousFaceCount
                    model.statusMessage = previousStatus
                    MeshTrimEngine.discard(result)
                    throw error
                }

                model.statusMessage = "6方向トリミングを実Meshへ反映しました"
                working = false
                dismiss()
            } catch {
                working = false
                errorText = error.localizedDescription
            }
        }
    }
}
