import Foundation
import SceneKit
import SwiftUI
import simd

private struct DetailFace: Sendable { let a:Int; let b:Int; let c:Int }
private struct DetailEdge: Hashable, Sendable { let a:Int; let b:Int; init(_ x:Int,_ y:Int){a=min(x,y);b=max(x,y)} }
private struct DetailCluster: Hashable, Sendable { let x:Int;let y:Int;let z:Int;let unique:Int }
private struct DetailSimplifyResult: Sendable { let url:URL;let vertices:Int;let faces:Int;let boundaryVertices:Int;let protectedComponents:Int }

private enum MeshDetailSimplifierEngine {
    static func simplify(url:URL, retainedFraction:Double)throws->DetailSimplifyResult{
        let text=try String(contentsOf:url,encoding:.utf8);var v:[SIMD3<Float>]=[];var f:[DetailFace]=[]
        for l in text.split(whereSeparator:\.isNewline){if l.hasPrefix("v "){let p=l.split(separator:" ");if p.count>=4,let x=Float(p[1]),let y=Float(p[2]),let z=Float(p[3]){v.append(.init(x,y,z))}}else if l.hasPrefix("f "){let p=l.split(separator:" ").dropFirst();let ids=p.compactMap{t->Int? in guard let s=t.split(separator:"/",omittingEmptySubsequences:false).first,let r=Int(s) else{return nil};return r>0 ? r-1 : v.count+r};if ids.count>=3{for i in 1..<(ids.count-1){f.append(.init(a:ids[0],b:ids[i],c:ids[i+1]))}}}}
        guard v.count>8 && !f.isEmpty else{throw err("十分なMeshがありません")}
        var edgeCount:[DetailEdge:Int]=[:];for q in f{edgeCount[.init(q.a,q.b),default:0]+=1;edgeCount[.init(q.b,q.c),default:0]+=1;edgeCount[.init(q.c,q.a),default:0]+=1}
        var boundary=Set<Int>();for(e,n)in edgeCount where n==1{boundary.insert(e.a);boundary.insert(e.b)}
        var parent=Array(0..<v.count);func find(_ x:Int)->Int{var i=x;while parent[i] != i{parent[i]=parent[parent[i]];i=parent[i]};return i};func union(_ a:Int,_ b:Int){let ra=find(a),rb=find(b);if ra != rb{parent[rb]=ra}}
        for q in f{union(q.a,q.b);union(q.b,q.c)}
        var compFaces:[Int:Int]=[:];for q in f{compFaces[find(q.a),default:0]+=1};let protectedRoots=Set(compFaces.filter{$0.value<600}.map(\.key));let protectedVertices=Set(v.indices.filter{protectedRoots.contains(find($0))})
        var minP=SIMD3<Float>(repeating:.greatestFiniteMagnitude),maxP=SIMD3<Float>(repeating:-.greatestFiniteMagnitude);for p in v{minP=simd_min(minP,p);maxP=simd_max(maxP,p)};let extent=simd_max(maxP-minP,SIMD3<Float>(repeating:0.0001));let target=max(16,Int(Double(v.count)*min(0.95,max(0.15,retainedFraction))));let res=max(2,Int(ceil(pow(Double(target),1.0/3.0))));let cell=extent/Float(res)
        var sums:[DetailCluster:SIMD3<Float>]=[:],counts:[DetailCluster:Int]=[:],keys:[DetailCluster]=[];keys.reserveCapacity(v.count)
        for(i,p)in v.enumerated(){let k:DetailCluster;if boundary.contains(i)||protectedVertices.contains(i){k=.init(x:0,y:0,z:0,unique:i+1)}else{let r=(p-minP)/cell;k=.init(x:min(res-1,max(0,Int(floor(r.x)))),y:min(res-1,max(0,Int(floor(r.y)))),z:min(res-1,max(0,Int(floor(r.z)))),unique:0)};keys.append(k);sums[k,default:.zero]+=p;counts[k,default:0]+=1}
        let ordered=sums.keys.sorted{($0.unique,$0.x,$0.y,$0.z)<($1.unique,$1.x,$1.y,$1.z)};var map:[DetailCluster:Int]=[:],outV:[SIMD3<Float>]=[];for k in ordered{map[k]=outV.count;outV.append((sums[k] ?? .zero)/Float(max(1,counts[k] ?? 1)))}
        var outF:[SIMD3<Int>]=[],seen=Set<String>();for q in f{guard let a=map[keys[q.a]],let b=map[keys[q.b]],let c=map[keys[q.c]],a != b && b != c && a != c else{continue};let area=simd_length_squared(simd_cross(outV[b]-outV[a],outV[c]-outV[a]));guard area>1e-10 else{continue};let canon=[a,b,c].sorted().map(String.init).joined(separator:":");if seen.insert(canon).inserted{outF.append(.init(a,b,c))}}
        guard !outF.isEmpty else{throw err("簡略化後に面が残りません")};var normals=Array(repeating:SIMD3<Float>.zero,count:outV.count);for q in outF{let n=simd_cross(outV[q.y]-outV[q.x],outV[q.z]-outV[q.x]);normals[q.x]+=n;normals[q.y]+=n;normals[q.z]+=n};normals=normals.map{simd_length_squared($0)>1e-12 ? simd_normalize($0):SIMD3<Float>(0,1,0)}
        let pct=Int((retainedFraction*100).rounded()),out=url.deletingLastPathComponent().appendingPathComponent("mesh-detail-simplified-\(pct).obj");var s="# Scan Lab detail-preserving simplification\n# boundaries \(boundary.count) protected_components \(protectedRoots.count)\n";for p in outV{s+="v \(p.x) \(p.y) \(p.z)\n"};for n in normals{s+="vn \(n.x) \(n.y) \(n.z)\n"};for q in outF{s+="f \(q.x+1)//\(q.x+1) \(q.y+1)//\(q.y+1) \(q.z+1)//\(q.z+1)\n"};try s.write(to:out,atomically:true,encoding:.utf8);return .init(url:out,vertices:outV.count,faces:outF.count,boundaryVertices:boundary.count,protectedComponents:protectedRoots.count)
    }
    private static func err(_ s:String)->NSError{NSError(domain:"ScanLab.MeshDetailSimplifier",code:1,userInfo:[NSLocalizedDescriptionKey:s])}
}

@MainActor
struct MeshDetailSimplifySheet:View{
    @EnvironmentObject var model:MeshScanModel;@Environment(\.dismiss)private var dismiss;let sourceURL:URL;@State private var retained=0.60;@State private var working=false;@State private var errorText:String?
    var body:some View{NavigationStack{Form{Section("形状を守る軽量化"){HStack{Text("目標密度");Spacer();Text("\(Int(retained*100))%").monospacedDigit()};Slider(value:$retained,in:0.25...0.9,step:0.05);Text("境界線と小さな連結部品を固定し、内部だけをクラスタリングします。花びら・葉・細い包装を単純な頂点削減で消しにくくします。").font(.caption).foregroundStyle(.secondary)};if let errorText{Section{Text(errorText).foregroundStyle(.red)}};Section{Button(working ? "処理中…":"ディテール保持OBJを生成"){run()}.disabled(working)}}.navigationTitle("Mesh軽量化").toolbar{ToolbarItem(placement:.topBarTrailing){Button("閉じる"){dismiss()}}}}}
    private func run(){working=true;errorText=nil;let u=sourceURL,r=retained;Task{do{let x=try await Task.detached(priority:.userInitiated){try MeshDetailSimplifierEngine.simplify(url:u,retainedFraction:r)}.value;model.rawOBJURL=x.url;model.resultURL=x.url;model.previewScene=try? SCNScene(url:x.url,options:nil);model.vertexCount=x.vertices;model.faceCount=x.faces;model.statusMessage="境界\(x.boundaryVertices)頂点・小部品\(x.protectedComponents)成分を保護して軽量化しました";working=false;dismiss()}catch{working=false;errorText=error.localizedDescription}}}
}
