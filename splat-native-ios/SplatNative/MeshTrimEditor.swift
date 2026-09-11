import Foundation
import SceneKit
import SwiftUI
import simd

private struct MeshTrimResult: Sendable {
    let url: URL
    let usedVertexCount: Int
    let faceCount: Int
}

private enum MeshTrimEngine {
    static func trim(url: URL, x: ClosedRange<Double>, y: ClosedRange<Double>, z: ClosedRange<Double>) throws -> MeshTrimResult {
        let text = try String(contentsOf: url, encoding: .utf8)
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        var vertices: [SIMD3<Float>] = []
        for line in lines where line.hasPrefix("v ") {
            let p = line.split(separator: " ", omittingEmptySubsequences: true)
            if p.count >= 4, let a = Float(p[1]), let b = Float(p[2]), let c = Float(p[3]) { vertices.append(SIMD3<Float>(a,b,c)) }
        }
        guard !vertices.isEmpty else { throw error("OBJ頂点がありません") }
        var minimum = SIMD3<Float>(repeating:.greatestFiniteMagnitude), maximum = SIMD3<Float>(repeating:-.greatestFiniteMagnitude)
        for p in vertices { minimum=simd_min(minimum,p); maximum=simd_max(maximum,p) }
        let extent = simd_max(maximum-minimum,SIMD3<Float>(repeating:0.000001))
        let low = minimum + extent * SIMD3<Float>(Float(x.lowerBound),Float(y.lowerBound),Float(z.lowerBound))
        let high = minimum + extent * SIMD3<Float>(Float(x.upperBound),Float(y.upperBound),Float(z.upperBound))

        var output:[String]=[]; output.reserveCapacity(lines.count)
        var used = Set<Int>(); var faceCount=0
        for line in lines {
            guard line.hasPrefix("f ") else { output.append(line); continue }
            let tokens=line.split(separator:" ",omittingEmptySubsequences:true).dropFirst()
            let ids=tokens.compactMap { token -> Int? in
                guard let s=token.split(separator:"/",omittingEmptySubsequences:false).first,let raw=Int(s) else{return nil}
                return raw>0 ? raw-1 : vertices.count+raw
            }
            guard ids.count>=3, ids.allSatisfy({$0>=0 && $0<vertices.count}) else { continue }
            var centroid=SIMD3<Float>.zero; for id in ids { centroid += vertices[id] }; centroid /= Float(ids.count)
            let inside = centroid.x>=low.x && centroid.x<=high.x && centroid.y>=low.y && centroid.y<=high.y && centroid.z>=low.z && centroid.z<=high.z
            if inside { output.append(line); used.formUnion(ids); faceCount += max(1,ids.count-2) }
        }
        guard faceCount>0 else { throw error("トリミング範囲内に面が残りません") }
        let visual=url.lastPathComponent.lowercased().contains("visual")
        // Every successful edit is a new immutable generation. Reusing a fixed filename made a
        // second trim overwrite the last known-good edited mesh before SceneKit/metadata validation
        // had completed, so a failed edit could destroy the user's previous result.
        let stem = visual ? "visual-mesh-trimmed" : "mesh-trimmed"
        let out=url.deletingLastPathComponent().appendingPathComponent("\(stem)-\(UUID().uuidString.lowercased()).obj")
        try (output.joined(separator:"\n")+"\n").write(to:out,atomically:true,encoding:.utf8)
        return MeshTrimResult(url:out,usedVertexCount:used.count,faceCount:faceCount)
    }

    static func discard(_ result: MeshTrimResult) {
        try? FileManager.default.removeItem(at: result.url)
        let sidecar = result.url.deletingPathExtension().appendingPathExtension("mesh-asset.json")
        try? FileManager.default.removeItem(at: sidecar)
    }

    private static func error(_ s:String)->NSError{NSError(domain:"ScanLab.MeshTrim",code:1,userInfo:[NSLocalizedDescriptionKey:s])}
}

@MainActor
struct MeshTrimEditorSheet: View {
    @EnvironmentObject var model: MeshScanModel
    @Environment(\.dismiss) private var dismiss
    let sourceURL: URL
    @State private var x0=0.0; @State private var x1=1.0
    @State private var y0=0.0; @State private var y1=1.0
    @State private var z0=0.0; @State private var z1=1.0
    @State private var working=false; @State private var errorText:String?

    var body: some View {
        NavigationStack {
            Form {
                axis("左右 X", low:$x0, high:$x1)
                axis("上下 Y", low:$y0, high:$y1)
                axis("前後 Z", low:$z0, high:$z1)
                Section { Text("6方向の実ジオメトリ平面で切り取ります。テクスチャOBJではUV/MTLを保持します。").font(.caption).foregroundStyle(.secondary) }
                if let errorText { Section { Text(errorText).foregroundStyle(.red) } }
                Section { Button(working ? "適用中…" : "トリミングを実Meshへ適用") { apply() }.disabled(working || x1-x0<0.05 || y1-y0<0.05 || z1-z0<0.05) }
            }
            .navigationTitle("トリミング")
            .toolbar { ToolbarItem(placement:.topBarTrailing){Button("閉じる"){dismiss()}.disabled(working)} }
        }
        .interactiveDismissDisabled(working)
    }

    private func axis(_ title:String, low:Binding<Double>, high:Binding<Double>)->some View {
        Section(title) {
            HStack{Text("開始");Spacer();Text("\(Int(low.wrappedValue*100))%").monospacedDigit()}; Slider(value:low,in:0...max(0,high.wrappedValue-0.05),step:0.01)
            HStack{Text("終了");Spacer();Text("\(Int(high.wrappedValue*100))%").monospacedDigit()}; Slider(value:high,in:min(1,low.wrappedValue+0.05)...1,step:0.01)
        }
    }

    private func apply() {
        working = true
        errorText = nil
        let source = sourceURL, xLow = x0, xHigh = x1, yLow = y0, yHigh = y1, zLow = z0, zHigh = z1
        Task {
            do {
                let result = try await Task.detached(priority:.userInitiated) {
                    try MeshTrimEngine.trim(url:source, x:xLow...xHigh, y:yLow...yHigh, z:zLow...zHigh)
                }.value

                guard let candidateScene = try? SCNScene(url: result.url, options: nil) else {
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

                model.statusMessage="6方向トリミングを実Meshへ反映しました"
                working=false
                dismiss()
            } catch {
                working=false
                errorText=error.localizedDescription
            }
        }
    }
}
