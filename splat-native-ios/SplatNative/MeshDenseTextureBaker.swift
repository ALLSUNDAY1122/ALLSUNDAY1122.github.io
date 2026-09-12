import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import SceneKit
import UniformTypeIdentifiers
import simd

private struct DenseTextureManifest: Decodable {
    let frames: [DenseTextureFrame]
}

private struct DenseTextureFrame: Decodable {
    let filePath: String
    let timestamp: TimeInterval
    let transform: [[Float]]
    let intrinsics: [[Float]]
    let width: Int
    let height: Int
}

private struct DenseTextureMesh {
    let vertices: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let triangles: [SIMD3<Int>]
}

private struct DensePreparedFrame {
    let fileURL: URL
    let worldToCamera: simd_float4x4
    let cameraPosition: SIMD3<Float>
    let forward: SIMD3<Float>
    let fx: Float
    let fy: Float
    let cx: Float
    let cy: Float
    let width: Float
    let height: Float
    let tileIndex: Int
    let luminance: Float
}

private struct DenseEdge: Hashable {
    let a: Int
    let b: Int
    init(_ x: Int, _ y: Int) { a = min(x, y); b = max(x, y) }
}

private struct DenseCandidate {
    let frameIndex: Int
    let score: Float
    let uvA: SIMD2<Float>
    let uvB: SIMD2<Float>
    let uvC: SIMD2<Float>
}

struct MeshDenseTextureBakeResult: Sendable {
    let objURL: URL
    let textureURL: URL
    let metadataURL: URL
    let assignedTriangles: Int
    let totalTriangles: Int
    let selectedFrames: Int
    let atlasSize: Int
    let seamSmoothingSwitches: Int
    var coverage: Double { Double(assignedTriangles) / Double(max(1, totalTriangles)) }
}

private struct DenseTextureMetadata: Codable {
    let schemaVersion: Int
    let sourceOBJ: String
    let outputOBJ: String
    let textureFile: String
    let atlasSize: Int
    let selectedFrames: Int
    let totalTriangles: Int
    let assignedTriangles: Int
    let projectionCoverage: Double
    let seamSmoothingSwitches: Int
    let visibilityGrid: String
    let exposureNormalization: Bool
    let coordinateSpace: String
    let linearUnit: String
}

private enum MeshDenseTextureBakerEngine {
    static func bake(sourceOBJURL: URL) throws -> MeshDenseTextureBakeResult {
        let project = sourceOBJURL.deletingLastPathComponent()
        let manifestURL = project.appendingPathComponent("mesh-project.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else { throw error("RGB撮影メタデータがありません") }
        let manifest = try JSONDecoder().decode(DenseTextureManifest.self, from: Data(contentsOf: manifestURL))
        let mesh = try parseOBJ(sourceOBJURL)
        guard !mesh.vertices.isEmpty, !mesh.triangles.isEmpty else { throw error("Meshが空です") }

        let selectedRecords = selectDiverseFrames(manifest.frames, maximumCount: 32)
        var prepared: [DensePreparedFrame] = []
        for (index, record) in selectedRecords.enumerated() {
            if let frame = prepare(record, project: project, tileIndex: index) { prepared.append(frame) }
        }
        guard prepared.count >= 6 else { throw error("有効なRGBキーフレームが不足しています") }

        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let atlasSize: Int
        if mesh.triangles.count >= 100_000 && physicalMemory >= 6_000_000_000 { atlasSize = 8192 }
        else if mesh.triangles.count >= 20_000 { atlasSize = 4096 }
        else { atlasSize = 2048 }
        let grid = min(8, max(3, Int(ceil(sqrt(Double(prepared.count + 1))))))
        let tileSize = atlasSize / grid
        let padding = max(3, tileSize / 220)

        let textureURL = project.appendingPathComponent(sourceOBJURL.lastPathComponent.contains("visual") ? "visual-mesh-textured-atlas.jpg" : "mesh-textured-atlas-v2.jpg")
        try renderAtlas(frames: prepared, atlasSize: atlasSize, grid: grid, tileSize: tileSize, padding: padding, outputURL: textureURL)

        let visibility = buildVisibilityMaps(mesh: mesh, frames: prepared, gridWidth: 72, gridHeight: 54)
        var candidates = buildCandidates(mesh: mesh, frames: prepared, visibility: visibility, gridWidth: 72, gridHeight: 54, atlasSize: atlasSize, grid: grid, tileSize: tileSize, padding: padding)
        let switches = smoothAssignments(mesh: mesh, candidates: &candidates)

        let prefix = sourceOBJURL.lastPathComponent.contains("visual") ? "visual-mesh-textured" : "mesh-textured-v2"
        let objURL = project.appendingPathComponent(prefix + ".obj")
        let mtlURL = project.appendingPathComponent(prefix + ".mtl")
        let assigned = try writeOBJ(mesh: mesh, candidates: candidates, neutralTileIndex: prepared.count, objURL: objURL, mtlURL: mtlURL, textureURL: textureURL, atlasSize: atlasSize, grid: grid, tileSize: tileSize)

        let metadata = DenseTextureMetadata(
            schemaVersion: 2,
            sourceOBJ: sourceOBJURL.lastPathComponent,
            outputOBJ: objURL.lastPathComponent,
            textureFile: textureURL.lastPathComponent,
            atlasSize: atlasSize,
            selectedFrames: prepared.count,
            totalTriangles: mesh.triangles.count,
            assignedTriangles: assigned,
            projectionCoverage: Double(assigned) / Double(max(1, mesh.triangles.count)),
            seamSmoothingSwitches: switches,
            visibilityGrid: "72x54 per keyframe; centroid z-buffer",
            exposureNormalization: true,
            coordinateSpace: "ARKit world space; Y-up; right-handed",
            linearUnit: "meter"
        )
        let metadataURL = project.appendingPathComponent("mesh-texture-bake-v2.json")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(metadata).write(to: metadataURL, options: .atomic)
        return MeshDenseTextureBakeResult(objURL: objURL, textureURL: textureURL, metadataURL: metadataURL, assignedTriangles: assigned, totalTriangles: mesh.triangles.count, selectedFrames: prepared.count, atlasSize: atlasSize, seamSmoothingSwitches: switches)
    }

    private static func selectDiverseFrames(_ frames: [DenseTextureFrame], maximumCount: Int) -> [DenseTextureFrame] {
        guard frames.count > maximumCount else { return frames }
        func pose(_ frame: DenseTextureFrame) -> (SIMD3<Float>, SIMD3<Float>)? {
            guard frame.transform.count == 4, frame.transform.allSatisfy({ $0.count == 4 }) else { return nil }
            let m = matrix4(frame.transform)
            let p = SIMD3<Float>(m.columns.3.x, m.columns.3.y, m.columns.3.z)
            let f0 = SIMD3<Float>(-m.columns.2.x, -m.columns.2.y, -m.columns.2.z)
            let f = simd_length_squared(f0) > 1e-8 ? simd_normalize(f0) : SIMD3<Float>(0, 0, -1)
            return (p, f)
        }
        var selected = [0]
        while selected.count < maximumCount {
            var bestIndex: Int?
            var bestScore: Float = -1
            for i in frames.indices where !selected.contains(i) {
                guard let candidate = pose(frames[i]) else { continue }
                var minimumDiversity = Float.greatestFiniteMagnitude
                for s in selected {
                    guard let chosen = pose(frames[s]) else { continue }
                    let baseline = min(1, simd_distance(candidate.0, chosen.0) / 0.18)
                    let angular = min(1, acos(min(1, max(-1, simd_dot(candidate.1, chosen.1)))) / 0.8)
                    minimumDiversity = min(minimumDiversity, 0.55 * baseline + 0.45 * angular)
                }
                if minimumDiversity > bestScore { bestScore = minimumDiversity; bestIndex = i }
            }
            guard let bestIndex else { break }
            selected.append(bestIndex)
        }
        return selected.sorted().map { frames[$0] }
    }

    private static func prepare(_ frame: DenseTextureFrame, project: URL, tileIndex: Int) -> DensePreparedFrame? {
        guard frame.transform.count == 4, frame.transform.allSatisfy({ $0.count == 4 }), frame.intrinsics.count == 3, frame.intrinsics.allSatisfy({ $0.count == 3 }), frame.width > 0, frame.height > 0 else { return nil }
        let file = project.appendingPathComponent(frame.filePath)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let c2w = matrix4(frame.transform)
        let forwardRaw = SIMD3<Float>(-c2w.columns.2.x, -c2w.columns.2.y, -c2w.columns.2.z)
        return DensePreparedFrame(
            fileURL: file,
            worldToCamera: simd_inverse(c2w),
            cameraPosition: SIMD3<Float>(c2w.columns.3.x, c2w.columns.3.y, c2w.columns.3.z),
            forward: simd_length_squared(forwardRaw) > 1e-8 ? simd_normalize(forwardRaw) : SIMD3<Float>(0, 0, -1),
            fx: frame.intrinsics[0][0], fy: frame.intrinsics[1][1], cx: frame.intrinsics[0][2], cy: frame.intrinsics[1][2], width: Float(frame.width), height: Float(frame.height), tileIndex: tileIndex, luminance: averageLuminance(file)
        )
    }

    private static func parseOBJ(_ url: URL) throws -> DenseTextureMesh {
        let text = try String(contentsOf: url, encoding: .utf8)
        var vertices: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = [], triangles: [SIMD3<Int>] = []
        for line in text.split(whereSeparator: \.isNewline) {
            if line.hasPrefix("v ") {
                let p = line.split(separator: " "); if p.count >= 4, let x = Float(p[1]), let y = Float(p[2]), let z = Float(p[3]) { vertices.append(SIMD3<Float>(x,y,z)) }
            } else if line.hasPrefix("vn ") {
                let p = line.split(separator: " "); if p.count >= 4, let x = Float(p[1]), let y = Float(p[2]), let z = Float(p[3]) { normals.append(SIMD3<Float>(x,y,z)) }
            } else if line.hasPrefix("f ") {
                let p = line.split(separator: " ")
                let ids = p.dropFirst().compactMap { token -> Int? in
                    guard let s = token.split(separator: "/", omittingEmptySubsequences: false).first, let raw = Int(s) else { return nil }
                    return raw > 0 ? raw - 1 : vertices.count + raw
                }
                if ids.count >= 3 { for i in 1..<(ids.count-1) { triangles.append(SIMD3<Int>(ids[0],ids[i],ids[i+1])) } }
            }
        }
        if normals.count < vertices.count { normals = Array(repeating: SIMD3<Float>(0,1,0), count: vertices.count) }
        return DenseTextureMesh(vertices: vertices, normals: normals, triangles: triangles)
    }

    private static func buildVisibilityMaps(mesh: DenseTextureMesh, frames: [DensePreparedFrame], gridWidth: Int, gridHeight: Int) -> [[Float]] {
        var maps = Array(repeating: Array(repeating: Float.greatestFiniteMagnitude, count: gridWidth * gridHeight), count: frames.count)
        for (frameIndex, frame) in frames.enumerated() {
            for tri in mesh.triangles {
                let c = (mesh.vertices[tri.x] + mesh.vertices[tri.y] + mesh.vertices[tri.z]) / 3
                guard let sample = project(c, frame), inside(sample.pixel, frame) else { continue }
                let gx = min(gridWidth - 1, max(0, Int(sample.pixel.x / frame.width * Float(gridWidth))))
                let gy = min(gridHeight - 1, max(0, Int(sample.pixel.y / frame.height * Float(gridHeight))))
                let idx = gy * gridWidth + gx
                if sample.depth < maps[frameIndex][idx] { maps[frameIndex][idx] = sample.depth }
            }
        }
        return maps
    }

    private static func buildCandidates(mesh: DenseTextureMesh, frames: [DensePreparedFrame], visibility: [[Float]], gridWidth: Int, gridHeight: Int, atlasSize: Int, grid: Int, tileSize: Int, padding: Int) -> [[DenseCandidate]] {
        var output = Array(repeating: [DenseCandidate](), count: mesh.triangles.count)
        for (triIndex, tri) in mesh.triangles.enumerated() {
            let a = mesh.vertices[tri.x], b = mesh.vertices[tri.y], c = mesh.vertices[tri.z]
            let centroid = (a+b+c)/3
            var normal = simd_cross(b-a,c-a)
            if simd_length_squared(normal) < 1e-12 { continue }
            normal = simd_normalize(normal)
            if tri.x < mesh.normals.count && tri.y < mesh.normals.count && tri.z < mesh.normals.count {
                let average = mesh.normals[tri.x] + mesh.normals[tri.y] + mesh.normals[tri.z]
                if simd_length_squared(average) > 1e-8 && simd_dot(normal, average) < 0 { normal = -normal }
            }
            var list: [DenseCandidate] = []
            for (fi, frame) in frames.enumerated() {
                let toCamera = frame.cameraPosition - centroid
                let d2 = max(0.01, simd_length_squared(toCamera))
                let facing = simd_dot(normal, simd_normalize(toCamera))
                guard facing > 0.10,
                      let pa = project(a, frame), let pb = project(b, frame), let pc = project(c, frame),
                      inside(pa.pixel, frame), inside(pb.pixel, frame), inside(pc.pixel, frame) else { continue }
                let center = (pa.pixel + pb.pixel + pc.pixel) / 3
                let gx = min(gridWidth - 1, max(0, Int(center.x / frame.width * Float(gridWidth))))
                let gy = min(gridHeight - 1, max(0, Int(center.y / frame.height * Float(gridHeight))))
                let nearest = visibility[fi][gy * gridWidth + gx]
                let depth = (pa.depth + pb.depth + pc.depth) / 3
                guard nearest == Float.greatestFiniteMagnitude || depth <= nearest + max(0.025, depth * 0.035) else { continue }
                let centerPenalty = abs(center.x/frame.width - 0.5) + abs(center.y/frame.height - 0.5)
                let score = facing * max(0.35, 1 - 0.55 * centerPenalty) / d2
                list.append(DenseCandidate(frameIndex: fi, score: score, uvA: atlasUV(pa.pixel, frame, atlasSize, grid, tileSize, padding), uvB: atlasUV(pb.pixel, frame, atlasSize, grid, tileSize, padding), uvC: atlasUV(pc.pixel, frame, atlasSize, grid, tileSize, padding)))
            }
            output[triIndex] = Array(list.sorted { $0.score > $1.score }.prefix(4))
        }
        return output
    }

    private static func smoothAssignments(mesh: DenseTextureMesh, candidates: inout [[DenseCandidate]]) -> Int {
        var edgeOwners: [DenseEdge: [Int]] = [:]
        for (i,f) in mesh.triangles.enumerated() {
            edgeOwners[DenseEdge(f.x,f.y), default: []].append(i); edgeOwners[DenseEdge(f.y,f.z), default: []].append(i); edgeOwners[DenseEdge(f.z,f.x), default: []].append(i)
        }
        var neighbors = Array(repeating: [Int](), count: mesh.triangles.count)
        for owners in edgeOwners.values where owners.count == 2 { neighbors[owners[0]].append(owners[1]); neighbors[owners[1]].append(owners[0]) }
        var chosen = candidates.map { $0.first?.frameIndex }
        var switches = 0
        for _ in 0..<2 {
            var next = chosen
            for i in chosen.indices {
                guard let best = candidates[i].first else { continue }
                var votes: [Int:Int] = [:]
                for n in neighbors[i] { if let f = chosen[n] { votes[f, default: 0] += 1 } }
                guard let majority = votes.max(by: { $0.value < $1.value })?.key, majority != best.frameIndex,
                      let alternate = candidates[i].first(where: { $0.frameIndex == majority }),
                      alternate.score >= best.score * 0.82 else { continue }
                next[i] = majority; switches += 1
                if let idx = candidates[i].firstIndex(where: { $0.frameIndex == majority }) { let item = candidates[i].remove(at: idx); candidates[i].insert(item, at: 0) }
            }
            chosen = next
        }
        return switches
    }

    private static func renderAtlas(frames: [DensePreparedFrame], atlasSize: Int, grid: Int, tileSize: Int, padding: Int, outputURL: URL) throws {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: atlasSize, height: atlasSize, bitsPerComponent: 8, bytesPerRow: atlasSize*4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw error("atlasメモリを確保できません") }
        ctx.translateBy(x: 0, y: CGFloat(atlasSize)); ctx.scaleBy(x: 1, y: -1); ctx.setFillColor(red: 0.42, green: 0.42, blue: 0.42, alpha: 1); ctx.fill(CGRect(x:0,y:0,width:atlasSize,height:atlasSize))
        let target = frames.map(\.luminance).sorted()[frames.count/2]
        let ciContext = CIContext(options: [.cacheIntermediates:false])
        for frame in frames {
            autoreleasepool {
                guard let source = CGImageSourceCreateWithURL(frame.fileURL as CFURL,nil), let thumb = CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:max(256,tileSize),kCGImageSourceCreateThumbnailWithTransform:false] as CFDictionary) else { return }
                let input = CIImage(cgImage: thumb)
                let control = CIFilter(name:"CIColorControls")!; control.setValue(input, forKey:kCIInputImageKey); control.setValue(Double(max(-0.14,min(0.14,(target-frame.luminance)*0.55))), forKey:kCIInputBrightnessKey); control.setValue(1.03, forKey:kCIInputContrastKey); control.setValue(1.0, forKey:kCIInputSaturationKey)
                let filtered = (control.outputImage ?? input)
                let image = ciContext.createCGImage(filtered, from: filtered.extent) ?? thumb
                let col = frame.tileIndex % grid, row = frame.tileIndex / grid
                let rect = CGRect(x:CGFloat(col*tileSize+padding),y:CGFloat(row*tileSize+padding),width:CGFloat(tileSize-2*padding),height:CGFloat(tileSize-2*padding))
                ctx.draw(image,in:rect)
            }
        }
        guard let atlas = ctx.makeImage(), let dst = CGImageDestinationCreateWithURL(outputURL as CFURL,UTType.jpeg.identifier as CFString,1,nil) else { throw error("atlasを書き出せません") }
        CGImageDestinationAddImage(dst,atlas,[kCGImageDestinationLossyCompressionQuality:0.92] as CFDictionary); guard CGImageDestinationFinalize(dst) else { throw error("atlas JPEG確定に失敗しました") }
    }

    private static func writeOBJ(mesh: DenseTextureMesh, candidates: [[DenseCandidate]], neutralTileIndex: Int, objURL: URL, mtlURL: URL, textureURL: URL, atlasSize: Int, grid: Int, tileSize: Int) throws -> Int {
        try "newmtl scanlab_texture\nKa 1 1 1\nKd 1 1 1\nKs 0 0 0\nd 1\nillum 1\nmap_Kd \(textureURL.lastPathComponent)\n".write(to:mtlURL,atomically:true,encoding:.utf8)
        _ = FileManager.default.createFile(atPath: objURL.path, contents: nil); let handle = try FileHandle(forWritingTo:objURL); defer { try? handle.close() }
        func flush(_ s: inout String) throws { if !s.isEmpty { try handle.write(contentsOf:Data(s.utf8)); s.removeAll(keepingCapacity:true) } }
        var b = "# Scan Lab visibility-aware textured metric mesh\nmtllib \(mtlURL.lastPathComponent)\n"
        for v in mesh.vertices { b += "v \(v.x) \(v.y) \(v.z)\n"; if b.utf8.count > 1_000_000 { try flush(&b) } }
        if mesh.normals.count == mesh.vertices.count { for n in mesh.normals { b += "vn \(n.x) \(n.y) \(n.z)\n"; if b.utf8.count > 1_000_000 { try flush(&b) } } }
        b += "usemtl scanlab_texture\n"; try flush(&b)
        let neutral = neutralUV(neutralTileIndex, atlasSize, grid, tileSize)
        var ti = 1, assigned = 0
        for (index,f) in mesh.triangles.enumerated() {
            let c = candidates[index].first
            let u0 = c?.uvA ?? neutral, u1 = c?.uvB ?? neutral, u2 = c?.uvC ?? neutral
            if c != nil { assigned += 1 }
            b += "vt \(u0.x) \(u0.y)\nvt \(u1.x) \(u1.y)\nvt \(u2.x) \(u2.y)\n"
            if mesh.normals.count == mesh.vertices.count { b += "f \(f.x+1)/\(ti)/\(f.x+1) \(f.y+1)/\(ti+1)/\(f.y+1) \(f.z+1)/\(ti+2)/\(f.z+1)\n" }
            else { b += "f \(f.x+1)/\(ti) \(f.y+1)/\(ti+1) \(f.z+1)/\(ti+2)\n" }
            ti += 3; if b.utf8.count > 1_000_000 { try flush(&b) }
        }
        try flush(&b); return assigned
    }

    private static func project(_ p: SIMD3<Float>, _ f: DensePreparedFrame) -> (pixel: SIMD2<Float>, depth: Float)? {
        let c = f.worldToCamera * SIMD4<Float>(p.x,p.y,p.z,1); let d = -c.z; guard d > 0.04 else { return nil }
        let x = f.cx + f.fx*(c.x/d), y = f.cy - f.fy*(c.y/d); guard x.isFinite && y.isFinite else { return nil }
        return (SIMD2<Float>(x,y),d)
    }
    private static func inside(_ p: SIMD2<Float>, _ f: DensePreparedFrame) -> Bool { let mx=f.width*0.015,my=f.height*0.015; return p.x>=mx && p.x<=f.width-mx && p.y>=my && p.y<=f.height-my }
    private static func atlasUV(_ p: SIMD2<Float>, _ f: DensePreparedFrame, _ atlas:Int,_ grid:Int,_ tile:Int,_ pad:Int) -> SIMD2<Float> { let col=f.tileIndex%grid,row=f.tileIndex/grid,inner=Float(tile-2*pad),nx=min(1,max(0,p.x/f.width)),ny=min(1,max(0,p.y/f.height)),x=Float(col*tile+pad)+nx*inner,y=Float(row*tile+pad)+ny*inner; return SIMD2<Float>(x/Float(atlas),1-y/Float(atlas)) }
    private static func neutralUV(_ index:Int,_ atlas:Int,_ grid:Int,_ tile:Int)->SIMD2<Float>{ let col=index%grid,row=index/grid; return SIMD2<Float>(Float(col*tile+tile/2)/Float(atlas),1-Float(row*tile+tile/2)/Float(atlas)) }
    private static func matrix4(_ r:[[Float]])->simd_float4x4{ simd_float4x4(columns:(SIMD4<Float>(r[0][0],r[1][0],r[2][0],r[3][0]),SIMD4<Float>(r[0][1],r[1][1],r[2][1],r[3][1]),SIMD4<Float>(r[0][2],r[1][2],r[2][2],r[3][2]),SIMD4<Float>(r[0][3],r[1][3],r[2][3],r[3][3]))) }
    private static func averageLuminance(_ url:URL)->Float{ guard let src=CGImageSourceCreateWithURL(url as CFURL,nil),let img=CGImageSourceCreateThumbnailAtIndex(src,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:32] as CFDictionary) else{return 0.5}; let w=32,h=32; var px=[UInt8](repeating:0,count:w*h*4); guard let ctx=CGContext(data:&px,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return 0.5}; ctx.draw(img,in:CGRect(x:0,y:0,width:w,height:h)); var sum:Float=0; for i in stride(from:0,to:px.count,by:4){sum += 0.2126*Float(px[i])/255 + 0.7152*Float(px[i+1])/255 + 0.0722*Float(px[i+2])/255}; return sum/Float(w*h) }
    private static func error(_ message:String)->NSError{ NSError(domain:"ScanLab.MeshDenseTexture",code:1,userInfo:[NSLocalizedDescriptionKey:message]) }
}

extension MeshScanModel {
    func bakeDenseRGBTextureAtlas() {
        guard phase == .finished,
              currentMeshHasMetricScale,
              frameCount >= 8,
              let source = rawOBJURL ?? resultURL,
              source.pathExtension.lowercased() == "obj",
              !source.lastPathComponent.lowercased().contains("textured") else { return }
        phase = .reconstructing; reconstructionProgress = 0.12; statusMessage = "遮蔽判定と露出補正を行いながらRGBテクスチャを焼き込んでいます"
        Task { [weak self] in
            do {
                let result = try await Task.detached(priority:.userInitiated){ try MeshDenseTextureBakerEngine.bake(sourceOBJURL:source) }.value
                guard let self else { return }
                self.resultURL = result.objURL; self.previewScene = try? SCNScene(url:result.objURL,options:nil); self.reconstructionProgress=1; self.phase = .finished
                self.statusMessage = String(format:"高品質RGB Mesh：投影%.0f%%・%d枚・%dpx・継ぎ目調整%d面",result.coverage*100,result.selectedFrames,result.atlasSize,result.seamSmoothingSwitches)
                try? self.persistExporterMeshAssetContract()
            } catch {
                guard let self else { return }; self.reconstructionProgress=1; self.phase = .finished; self.statusMessage = "形状Meshを保持しました。高品質テクスチャ処理のみ失敗: \(error.localizedDescription)"
            }
        }
    }
}
