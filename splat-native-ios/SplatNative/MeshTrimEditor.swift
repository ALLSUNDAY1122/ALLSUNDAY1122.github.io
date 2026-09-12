import Foundation
import SceneKit
import SwiftUI
import simd

struct MeshTrimResult: Sendable {
    let url: URL
    let usedVertexCount: Int
    let faceCount: Int
}

enum MeshTrimEngine {
    private static let inputChunkSize = 256 * 1024
    private static let maximumOBJLineBytes = 8 * 1024 * 1024

    static func trim(url: URL, x: ClosedRange<Double>, y: ClosedRange<Double>, z: ClosedRange<Double>) throws -> MeshTrimResult {
        var vertices: [SIMD3<Float>] = []
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
            vertices.append(SIMD3<Float>(a, b, c))
        }
        guard !vertices.isEmpty else { throw error("OBJ頂点がありません") }

        var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for point in vertices {
            minimum = simd_min(minimum, point)
            maximum = simd_max(maximum, point)
        }
        let rawExtent = maximum - minimum
        guard rawExtent.x.isFinite, rawExtent.y.isFinite, rawExtent.z.isFinite else {
            throw error("Meshの座標範囲が大きすぎます")
        }
        let extent = simd_max(rawExtent, SIMD3<Float>(repeating: 0.000001))
        let bounds = [x.lowerBound, x.upperBound, y.lowerBound, y.upperBound, z.lowerBound, z.upperBound]
        guard bounds.allSatisfy(\.isFinite) else { throw error("トリミング範囲が不正です") }
        let low = minimum + extent * SIMD3<Float>(Float(x.lowerBound), Float(y.lowerBound), Float(z.lowerBound))
        let high = minimum + extent * SIMD3<Float>(Float(x.upperBound), Float(y.upperBound), Float(z.upperBound))
        guard low.x.isFinite, low.y.isFinite, low.z.isFinite,
              high.x.isFinite, high.y.isFinite, high.z.isFinite else {
            throw error("トリミング境界を計算できません")
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
            if writeBuffer.count >= writeBufferLimit {
                try flushOutput()
            }
        }

        let bitWordCount = (vertices.count >> 6) + ((vertices.count & 63) == 0 ? 0 : 1)
        var usedVertexBits = [UInt64](repeating: 0, count: bitWordCount)
        var usedVertexCount = 0
        var faceCount = 0
        var faceIndices: [Int] = []
        faceIndices.reserveCapacity(4)

        try forEachOBJLine(at: url) { line in
            guard firstDirective(in: line) == "f" else {
                try writeLine(line)
                return
            }
            let fields = line.split(whereSeparator: \.isWhitespace)
            let faceFields = fields.dropFirst().prefix { !$0.hasPrefix("#") }
            guard faceFields.count >= 3 else { throw error("OBJ面定義が不正です") }
            faceIndices.removeAll(keepingCapacity: true)
            if faceIndices.capacity < faceFields.count {
                faceIndices.reserveCapacity(faceFields.count)
            }
            for token in faceFields {
                let first: Substring
                if let slash = token.firstIndex(of: "/") {
                    first = token[..<slash]
                } else {
                    first = token
                }
                guard !first.isEmpty,
                      let raw = Int(first),
                      raw != 0 else {
                    throw error("OBJ面定義が不正です")
                }
                let index = raw > 0 ? raw - 1 : vertices.count + raw
                guard index >= 0, index < vertices.count else {
                    throw error("OBJ面インデックスが範囲外です")
                }
                faceIndices.append(index)
            }

            var centroid = SIMD3<Float>.zero
            for id in faceIndices { centroid += vertices[id] }
            centroid /= Float(faceIndices.count)
            guard centroid.x.isFinite, centroid.y.isFinite, centroid.z.isFinite else {
                throw error("面の位置を計算できません")
            }
            let inside = centroid.x >= low.x && centroid.x <= high.x &&
                centroid.y >= low.y && centroid.y <= high.y &&
                centroid.z >= low.z && centroid.z <= high.z
            if inside {
                try writeLine(line)
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
        }
        guard faceCount > 0 else { throw error("トリミング範囲内に面が残りません") }

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
