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
    static func trim(url: URL, x: ClosedRange<Double>, y: ClosedRange<Double>, z: ClosedRange<Double>) throws -> MeshTrimResult {
        let text = try String(contentsOf: url, encoding: .utf8)
        // Keep line views into the original OBJ text instead of materializing a second full set of
        // per-line Strings. Large textured OBJ scans can be hundreds of megabytes; Substring slices
        // keep parsing semantics identical while avoiding an input-sized duplicate allocation.
        let lines = text.split(whereSeparator: \.isNewline)
        var vertices: [SIMD3<Float>] = []
        var hasMaterialLibrary = false

        for line in lines {
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard let directive = fields.first else { continue }
            if directive.lowercased() == "mtllib" {
                hasMaterialLibrary = true
                continue
            }
            guard directive == "v" else { continue }
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
        let newline = Data([0x0A])
        var completed = false
        defer {
            try? handle.close()
            if !completed { try? FileManager.default.removeItem(at: out) }
        }

        func writeLine(_ line: Substring) throws {
            try handle.write(contentsOf: Data(line.utf8))
            try handle.write(contentsOf: newline)
        }

        var used = Set<Int>()
        var faceCount = 0

        for line in lines {
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard let directive = fields.first, directive == "f" else {
                try writeLine(line)
                continue
            }
            let faceFields = fields.dropFirst().prefix { !$0.hasPrefix("#") }
            guard faceFields.count >= 3 else { throw error("OBJ面定義が不正です") }
            var ids: [Int] = []
            ids.reserveCapacity(faceFields.count)
            for token in faceFields {
                guard let first = token.split(separator: "/", omittingEmptySubsequences: false).first,
                      !first.isEmpty,
                      let raw = Int(first),
                      raw != 0 else {
                    throw error("OBJ面定義が不正です")
                }
                let index = raw > 0 ? raw - 1 : vertices.count + raw
                guard index >= 0, index < vertices.count else {
                    throw error("OBJ面インデックスが範囲外です")
                }
                ids.append(index)
            }

            var centroid = SIMD3<Float>.zero
            for id in ids { centroid += vertices[id] }
            centroid /= Float(ids.count)
            guard centroid.x.isFinite, centroid.y.isFinite, centroid.z.isFinite else {
                throw error("面の位置を計算できません")
            }
            let inside = centroid.x >= low.x && centroid.x <= high.x &&
                centroid.y >= low.y && centroid.y <= high.y &&
                centroid.z >= low.z && centroid.z <= high.z
            if inside {
                try writeLine(line)
                used.formUnion(ids)
                faceCount += ids.count - 2
            }
        }
        guard faceCount > 0 else { throw error("トリミング範囲内に面が残りません") }

        try handle.synchronize()
        completed = true
        return MeshTrimResult(url: out, usedVertexCount: used.count, faceCount: faceCount)
    }

    static func discard(_ result: MeshTrimResult) {
        try? FileManager.default.removeItem(at: result.url)
        let sidecar = result.url.deletingPathExtension().appendingPathExtension("mesh-asset.json")
        try? FileManager.default.removeItem(at: sidecar)
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
