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
        guard weldMeters.isFinite, weldMeters >= 0.000001, weldMeters <= 0.1 else {
            throw error("Mesh精製の統合距離が不正です")
        }
        let source = try String(contentsOf: url, encoding: .utf8)
        let parsed = try parse(source)
        guard parsed.vertices.count >= 3, !parsed.faces.isEmpty else {
            throw error("有効なOBJ三角形がありません")
        }

        var sums: [MeshRefineKey: SIMD3<Double>] = [:]
        var counts: [MeshRefineKey: Int] = [:]
        var keys: [MeshRefineKey] = []
        keys.reserveCapacity(parsed.vertices.count)
        for point in parsed.vertices {
            let scaled = point / weldMeters
            guard scaled.x.isFinite, scaled.y.isFinite, scaled.z.isFinite,
                  abs(Double(scaled.x)) <= Double(Int.max) - 1,
                  abs(Double(scaled.y)) <= Double(Int.max) - 1,
                  abs(Double(scaled.z)) <= Double(Int.max) - 1 else {
                throw error("Mesh座標が精製可能な範囲を超えています")
            }
            let key = MeshRefineKey(
                x: Int(scaled.x.rounded()),
                y: Int(scaled.y.rounded()),
                z: Int(scaled.z.rounded())
            )
            keys.append(key)
            sums[key, default: .zero] += SIMD3<Double>(Double(point.x), Double(point.y), Double(point.z))
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
            let divisor = Double(max(1, counts[key] ?? 1))
            let mean = (sums[key] ?? .zero) / divisor
            guard mean.x.isFinite, mean.y.isFinite, mean.z.isFinite,
                  abs(mean.x) <= Double(Float.greatestFiniteMagnitude),
                  abs(mean.y) <= Double(Float.greatestFiniteMagnitude),
                  abs(mean.z) <= Double(Float.greatestFiniteMagnitude) else {
                throw error("Meshの統合座標を確定できません")
            }
            vertices.append(SIMD3<Float>(Float(mean.x), Float(mean.y), Float(mean.z)))
        }

        var faces: [SIMD3<Int>] = []
        var faceSet = Set<MeshRefineFaceKey>()
        faces.reserveCapacity(parsed.faces.count)
        for face in parsed.faces {
            guard face.x >= 0, face.y >= 0, face.z >= 0,
                  face.x < keys.count, face.y < keys.count, face.z < keys.count,
                  let a = keyToIndex[keys[face.x]],
                  let b = keyToIndex[keys[face.y]],
                  let c = keyToIndex[keys[face.z]],
                  a != b, b != c, a != c else { continue }
            let cross = simd_cross(vertices[b] - vertices[a], vertices[c] - vertices[a])
            let area = simd_length_squared(cross)
            guard area.isFinite, area > 1e-10 else { continue }
            guard faceSet.insert(MeshRefineFaceKey(a, b, c)).inserted else { continue }
            faces.append(SIMD3<Int>(a, b, c))
        }

        guard !faces.isEmpty else { throw error("統合後に有効な面が残りませんでした") }
        let componentResult = filterMicroscopicComponents(vertices: vertices, faces: faces)
        faces = componentResult.faces
        guard !faces.isEmpty else { throw error("ノイズ除去後に有効な面が残りませんでした") }
        let compacted = compact(vertices: vertices, faces: faces)
        let normals = recomputeNormals(vertices: compacted.vertices, faces: compacted.faces)

        let outputURL = url.deletingLastPathComponent()
            .appendingPathComponent("mesh-refined-\(UUID().uuidString.lowercased()).obj")
        var output = "# Scan Lab refined metric mesh\n"
        output += "# conservative weld_m \(weldMeters)\n"
        output += "# source_faces \(parsed.faces.count) refined_faces \(compacted.faces.count)\n"
        for point in compacted.vertices { output += "v \(point.x) \(point.y) \(point.z)\n" }
        for normal in normals { output += "vn \(normal.x) \(normal.y) \(normal.z)\n" }
        for face in compacted.faces {
            output += "f \(face.x + 1)//\(face.x + 1) \(face.y + 1)//\(face.y + 1) \(face.z + 1)//\(face.z + 1)\n"
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

    static func discard(_ result: MeshGeometryRefineResult) {
        try? FileManager.default.removeItem(at: result.url)
        let sidecar = result.url.deletingPathExtension().appendingPathExtension("mesh-asset.json")
        try? FileManager.default.removeItem(at: sidecar)
    }

    private static func parse(_ text: String) throws -> MeshRefineMesh {
        var vertices: [SIMD3<Float>] = []
        var faces: [SIMD3<Int>] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard let directive = fields.first else { continue }
            if directive == "mtllib" || directive == "usemtl" || directive == "vt" {
                throw error("テクスチャ付きMeshは色を失うため精製しません")
            }
            if directive == "v" {
                guard fields.count >= 4,
                      let x = Float(fields[1]), let y = Float(fields[2]), let z = Float(fields[3]),
                      x.isFinite, y.isFinite, z.isFinite else {
                    throw error("OBJ頂点定義が不正です")
                }
                if fields.count >= 7 {
                    throw error("頂点色付きMeshは色を失うため精製しません")
                }
                vertices.append(SIMD3<Float>(x, y, z))
            } else if directive == "f" {
                let tokens = Array(fields.dropFirst().prefix { !$0.hasPrefix("#") })
                guard tokens.count >= 3 else { throw error("OBJ面定義が不正です") }
                var ids: [Int] = []
                ids.reserveCapacity(tokens.count)
                for token in tokens {
                    guard let first = token.split(separator: "/", omittingEmptySubsequences: false).first,
                          !first.isEmpty,
                          let raw = Int(first), raw != 0 else {
                        throw error("OBJ面定義が不正です")
                    }
                    let index = raw > 0 ? raw - 1 : vertices.count + raw
                    guard index >= 0, index < vertices.count else {
                        throw error("OBJ面インデックスが範囲外です")
                    }
                    ids.append(index)
                }
                for i in 1..<(ids.count - 1) {
                    faces.append(SIMD3<Int>(ids[0], ids[i], ids[i + 1]))
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
        for face in faces { union(face.x, face.y); union(face.y, face.z); union(face.z, face.x) }

        var groups: [Int: [Int]] = [:]
        for (index, face) in faces.enumerated() { groups[find(face.x), default: []].append(index) }
        var keep = Set<Int>()
        var removed = 0
        for indices in groups.values {
            var minPoint = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
            var maxPoint = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
            for faceIndex in indices {
                let face = faces[faceIndex]
                for id in [face.x, face.y, face.z] {
                    minPoint = simd_min(minPoint, vertices[id])
                    maxPoint = simd_max(maxPoint, vertices[id])
                }
            }
            let diagonal = simd_length(maxPoint - minPoint)
            if diagonal.isFinite, indices.count >= 4 || diagonal >= 0.006 {
                keep.formUnion(indices)
            } else {
                removed += 1
            }
        }
        return (faces.enumerated().compactMap { keep.contains($0.offset) ? $0.element : nil }, removed)
    }

    private static func compact(vertices: [SIMD3<Float>], faces: [SIMD3<Int>]) -> MeshRefineMesh {
        var used = Set<Int>()
        for face in faces { used.insert(face.x); used.insert(face.y); used.insert(face.z) }
        let ordered = used.sorted()
        var map: [Int: Int] = [:]
        var outputVertices: [SIMD3<Float>] = []
        for old in ordered { map[old] = outputVertices.count; outputVertices.append(vertices[old]) }
        let outputFaces = faces.compactMap { face -> SIMD3<Int>? in
            guard let a = map[face.x], let b = map[face.y], let c = map[face.z] else { return nil }
            return SIMD3<Int>(a, b, c)
        }
        return MeshRefineMesh(vertices: outputVertices, faces: outputFaces)
    }

    private static func recomputeNormals(vertices: [SIMD3<Float>], faces: [SIMD3<Int>]) -> [SIMD3<Float>] {
        var normals = Array(repeating: SIMD3<Float>.zero, count: vertices.count)
        for face in faces {
            let normal = simd_cross(vertices[face.y] - vertices[face.x], vertices[face.z] - vertices[face.x])
            guard normal.x.isFinite, normal.y.isFinite, normal.z.isFinite else { continue }
            normals[face.x] += normal; normals[face.y] += normal; normals[face.z] += normal
        }
        return normals.map {
            let lengthSquared = simd_length_squared($0)
            return lengthSquared.isFinite && lengthSquared > 1e-12 ? simd_normalize($0) : SIMD3<Float>(0, 1, 0)
        }
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
                guard let self else {
                    MeshGeometryRefinerEngine.discard(result)
                    return
                }
                guard let candidateScene = try? SCNScene(url: result.url, options: nil) else {
                    MeshGeometryRefinerEngine.discard(result)
                    throw NSError(domain:"ScanLab.MeshGeometryRefiner", code:2, userInfo:[NSLocalizedDescriptionKey:"精製後のMeshを検証できませんでした。元Meshを保持します。"])
                }

                let previousRawURL = self.rawOBJURL
                let previousResultURL = self.resultURL
                let previousScene = self.previewScene
                let previousVertexCount = self.vertexCount
                let previousFaceCount = self.faceCount

                self.rawOBJURL = result.url
                self.resultURL = result.url
                self.previewScene = candidateScene
                self.vertexCount = result.vertexCount
                self.faceCount = result.faceCount
                do {
                    try self.persistExporterMeshAssetContract()
                } catch {
                    self.rawOBJURL = previousRawURL
                    self.resultURL = previousResultURL
                    self.previewScene = previousScene
                    self.vertexCount = previousVertexCount
                    self.faceCount = previousFaceCount
                    MeshGeometryRefinerEngine.discard(result)
                    throw error
                }

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
