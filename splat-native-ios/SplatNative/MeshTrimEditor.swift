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
        let out=url.deletingLastPathComponent().appendingPathComponent(visual ? "visual-mesh-trimmed.obj" : "mesh-trimmed.obj")
        try (output.joined(separator:"\n")+"\n").write(to:out,atomically:true,encoding:.utf8)
        return MeshTrimResult(url:out,usedVertexCount:used.count,faceCount:faceCount)
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
            .toolbar { ToolbarItem(placement:.topBarTrailing){Button("閉じる"){dismiss()}} }
        }
    }

    private func axis(_ title:String, low:Binding<Double>, high:Binding<Double>)->some View {
        Section(title) {
            HStack{Text("開始");Spacer();Text("\(Int(low.wrappedValue*100))%").monospacedDigit()}; Slider(value:low,in:0...max(0,high.wrappedValue-0.05),step:0.01)
            HStack{Text("終了");Spacer();Text("\(Int(high.wrappedValue*100))%").monospacedDigit()}; Slider(value:high,in:min(1,low.wrappedValue+0.05)...1,step:0.01)
        }
    }

    private func apply(){working=true;errorText=nil;let u=sourceURL,a=x0,b=x1,c=y0,d=y1,e=z0,f=z1;Task{do{let r=try await Task.detached(priority:.userInitiated){try MeshTrimEngine.trim(url:u,x:a...b,y:c...d,z:e...f)}.value;model.resultURL=r.url;model.previewScene=try? SCNScene(url:r.url,options:nil);model.vertexCount=r.usedVertexCount;model.faceCount=r.faceCount;model.statusMessage="6方向トリミングを実Meshへ反映しました";try? model.persistExporterMeshAssetContract();working=false;dismiss()}catch{working=false;errorText=error.localizedDescription}}}
}
