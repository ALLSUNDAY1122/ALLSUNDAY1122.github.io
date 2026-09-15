import Foundation
import SceneKit
import simd

private struct MeshRefineKey: Hashable, Sendable {
    let x: Int
    let y: Int
    let z: Int
}

private struct MeshRefineFaceKey: Hashable, Sendable {
    let a: Int
    let b: Int
    let c: Int

    init(_ x: Int, _ y: Int, _ z: Int) {
        let sorted = [x, y, z].sorted()
        a = sorted[0]; b = sorted[1]; c = sorted[2]
    }
}

private struct MeshRefineMesh: Sendable {
    var vertices: [SIMD3<Float>]
    var faces: [SIMD3<Int>]
}

struct MeshGeometryRefineResult: Sendable {
    let url: URL
    let vertexCount: Int
    let faceCount: Int
    let removedFaces: Int
    let removedComponents: Int
}

private enum MeshGeometryRefinerEngine {
    static func refine(url: URL, weldMeters: Float = 0.0015) throws -> MeshGeometryRefineResult {
        let source = try String(contentsOf: url, encoding: .utf8)
        let parsed = parse(source)
        guard parsed.vertices.count >= 3, !parsed.faces.isEmpty else {
            throw error("有効なOBJ三角形がありません")
        }

        var sums: [MeshRefineKey: SIMD3<Float>] = [:]
        var counts: [MeshRefineKey: Int] = [:]
        var keys: [MeshRefineKey] = []
        keys.reserveCapacity(parsed.vertices.count)
        for p in parsed.vertices {
            let key = MeshRefineKey(
                x: Int((p.x / weldMeters).rounded()),
                y: Int((p.y / weldMeters).rounded()),
                z: Int((p.z / weldMeters).rounded())
            )
            keys.append(key)
            sums[key, default: .zero] += p
            counts[key, default: 0] += 1
        }

        let ordered = sums.keys.sorted {
            if $0.x != $1.x { return $0.x < $1.x }
            if $0.y != $1.y { return $0.y < $1.y }
            return $0.z < $1.z
        }
        var keyToIndex: [MeshRefineKey: Int] = [:]
        var vertices: [SIMD3<Float>] = []
        vertices.reserveCapacity(ordered.count)
        for key in ordered {
            keyToIndex[key] = vertices.count
            vertices.append((sums[key] ?? .zero) / Float(max(1, counts[key] ?? 1)))
        }

        var faces: [SIMD3<Int>] = []
        var faceSet = Set<MeshRefineFaceKey>()
        faces.reserveCapacity(parsed.faces.count)
        for f in parsed.faces {
            guard f.x >= 0, f.y >= 0, f.z >= 0,
                  f.x < keys.count, f.y < keys.count, f.z < keys.count,
                  let a = keyToIndex[keys[f.x]],
                  let b = keyToIndex[keys[f.y]],
                  let c = keyToIndex[keys[f.z]],
                  a != b, b != c, a != c else { continue }
            let cross = simd_cross(vertices[b] - vertices[a], vertices[c] - vertices[a])
            guard simd_length_squared(cross) > 1e-10 else { continue }
            guard faceSet.insert(MeshRefineFaceKey(a, b, c)).inserted else { continue }
            faces.append(SIMD3<Int>(a, b, c))
        }

        guard !faces.isEmpty else { throw error("統合後に有効な面が残りませんでした") }
        let componentResult = filterMicroscopicComponents(vertices: vertices, faces: faces)
        faces = componentResult.faces
        let compacted = compact(vertices: vertices, faces: faces)
        let normals = recomputeNormals(vertices: compacted.vertices, faces: compacted.faces)

        let outputURL = url.deletingLastPathComponent().appendingPathComponent("mesh-refined.obj")
        var output = "# Scan Lab refined metric mesh\n"
        output += "# conservative weld_m \(weldMeters)\n"
        output += "# source_faces \(parsed.faces.count) refined_faces \(compacted.faces.count)\n"
        for p in compacted.vertices { output += "v \(p.x) \(p.y) \(p.z)\n" }
        for n in normals { output += "vn \(n.x) \(n.y) \(n.z)\n" }
        for f in compacted.faces {
            output += "f \(f.x + 1)//\(f.x + 1) \(f.y + 1)//\(f.y + 1) \(f.z + 1)//\(f.z + 1)\n"
        }
        try output.write(to: outputURL, atomically: true, encoding: .utf8)
        return MeshGeometryRefineResult(
            url: outputURL,
            vertexCount: compacted.vertices.count,
            faceCount: compacted.faces.count,
            removedFaces: max(0, parsed.faces.count - compacted.faces.count),
            removedComponents: componentResult.removedComponents
        )
    }

    private static func parse(_ text: String) -> MeshRefineMesh {
        var vertices: [SIMD3<Float>] = []
        var faces: [SIMD3<Int>] = []
        for line in text.split(whereSeparator: \.isNewline) {
            if line.hasPrefix("v ") {
                let p = line.split(separator: " ", omittingEmptySubsequences: true)
                if p.count >= 4, let x = Float(p[1]), let y = Float(p[2]), let z = Float(p[3]) {
                    vertices.append(SIMD3<Float>(x, y, z))
                }
            } else if line.hasPrefix("f ") {
                let p = line.split(separator: " ", omittingEmptySubsequences: true)
                let ids = p.dropFirst().compactMap { token -> Int? in
                    guard let s = token.split(separator: "/", omittingEmptySubsequences: false).first,
                          let raw = Int(s) else { return nil }
                    return raw > 0 ? raw - 1 : vertices.count + raw
                }
                if ids.count >= 3 {
                    for i in 1..<(ids.count - 1) { faces.append(SIMD3<Int>(ids[0], ids[i], ids[i + 1])) }
                }
            }
        }
        return MeshRefineMesh(vertices: vertices, faces: faces)
    }

    private static func filterMicroscopicComponents(vertices: [SIMD3<Float>], faces: [SIMD3<Int>]) -> (faces: [SIMD3<Int>], removedComponents: Int) {
        var parent = Array(0..<vertices.count)
        func find(_ x: Int) -> Int {
            var i = x
            while parent[i] != i { parent[i] = parent[parent[i]]; i = parent[i] }
            return i
        }
        func union(_ a: Int, _ b: Int) {
            let ra = find(a), rb = find(b)
            if ra != rb { parent[rb] = ra }
        }
        for f in faces { union(f.x, f.y); union(f.y, f.z); union(f.z, f.x) }

        var groups: [Int: [Int]] = [:]
        for (index, f) in faces.enumerated() { groups[find(f.x), default: []].append(index) }
        var keep = Set<Int>()
        var removed = 0
        for indices in groups.values {
            var minP = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
            var maxP = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
            for faceIndex in indices {
                let f = faces[faceIndex]
                for id in [f.x, f.y, f.z] { minP = simd_min(minP, vertices[id]); maxP = simd_max(maxP, vertices[id]) }
            }
            let diagonal = simd_length(maxP - minP)
            if indices.count >= 4 || diagonal >= 0.006 {
                keep.formUnion(indices)
            } else {
                removed += 1
            }
        }
        return (faces.enumerated().compactMap { keep.contains($0.offset) ? $0.element : nil }, removed)
    }

    private static func compact(vertices: [SIMD3<Float>], faces: [SIMD3<Int>]) -> MeshRefineMesh {
        var used = Set<Int>()
        for f in faces { used.insert(f.x); used.insert(f.y); used.insert(f.z) }
        let ordered = used.sorted()
        var map: [Int: Int] = [:]
        var outV: [SIMD3<Float>] = []
        for old in ordered { map[old] = outV.count; outV.append(vertices[old]) }
        let outF = faces.compactMap { f -> SIMD3<Int>? in
            guard let a = map[f.x], let b = map[f.y], let c = map[f.z] else { return nil }
            return SIMD3<Int>(a, b, c)
        }
        return MeshRefineMesh(vertices: outV, faces: outF)
    }

    private static func recomputeNormals(vertices: [SIMD3<Float>], faces: [SIMD3<Int>]) -> [SIMD3<Float>] {
        var normals = Array(repeating: SIMD3<Float>.zero, count: vertices.count)
        for f in faces {
            let n = simd_cross(vertices[f.y] - vertices[f.x], vertices[f.z] - vertices[f.x])
            normals[f.x] += n; normals[f.y] += n; normals[f.z] += n
        }
        return normals.map { simd_length_squared($0) > 1e-12 ? simd_normalize($0) : SIMD3<Float>(0, 1, 0) }
    }

    private static func error(_ message: String) -> NSError {
        NSError(domain: "ScanLab.MeshGeometryRefiner", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

extension MeshScanModel {
    func refineMetricGeometry() {
        guard phase == .finished,
              currentMeshHasMetricScale,
              let source = rawOBJURL ?? resultURL,
              source.pathExtension.lowercased() == "obj",
              !source.lastPathComponent.lowercased().contains("refined"),
              !source.lastPathComponent.lowercased().contains("textured") else { return }
        phase = .reconstructing
        reconstructionProgress = 0.35
        statusMessage = "重複頂点を統合し、薄い形状を残したままMeshを精製しています"
        Task { [weak self] in
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try MeshGeometryRefinerEngine.refine(url: source)
                }.value
                guard let self else { return }
                self.rawOBJURL = result.url
                self.resultURL = result.url
                self.previewScene = try? SCNScene(url: result.url, options: nil)
                self.vertexCount = result.vertexCount
                self.faceCount = result.faceCount
                self.reconstructionProgress = 1
                self.phase = .finished
                self.statusMessage = "Mesh精製完了：微小ノイズ\(result.removedComponents)成分を除去、薄い可視部品は保持"
            } catch {
                guard let self else { return }
                self.reconstructionProgress = 1
                self.phase = .finished
                self.statusMessage = "元Meshを保持しました。精製のみ失敗: \(error.localizedDescription)"
            }
        }
    }
}
