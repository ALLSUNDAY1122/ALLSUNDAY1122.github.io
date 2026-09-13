import Foundation
import SceneKit
import simd

private struct MeshRefineKey: Hashable, Sendable {
    let x: Int
    let y: Int
    let z: Int
}

private struct MeshRefineAccumulator: Sendable {
    var sum = SIMD3<Double>.zero
    var count = 0
}

private struct MeshRefineComponentSummary: Sendable {
    var faceCount = 0
    var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
    var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
}

private struct MeshRefineFaceKey: Hashable, Sendable {
    let a: Int
    let b: Int
    let c: Int

    init(_ x: Int, _ y: Int, _ z: Int) {
        if x <= y {
            if y <= z {
                a = x; b = y; c = z
            } else if x <= z {
                a = x; b = z; c = y
            } else {
                a = z; b = x; c = y
            }
        } else if x <= z {
            a = y; b = x; c = z
        } else if y <= z {
            a = y; b = z; c = x
        } else {
            a = z; b = y; c = x
        }
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
    private static let outputFlushThresholdBytes = 256 * 1024
    private static let objInputChunkSize = 256 * 1024
    private static let maximumOBJLineBytes = 8 * 1024 * 1024

    static func refine(url: URL, weldMeters: Float = 0.0015) throws -> MeshGeometryRefineResult {
        guard weldMeters.isFinite, weldMeters >= 0.000001, weldMeters <= 0.1 else {
            throw error("Mesh精製の統合距離が不正です")
        }
        var parsed = try parse(url)
        guard parsed.vertices.count >= 3, !parsed.faces.isEmpty else {
            throw error("有効なOBJ三角形がありません")
        }
        let sourceFaceCount = parsed.faces.count

        var accumulators: [MeshRefineKey: MeshRefineAccumulator] = [:]
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
            var accumulator = accumulators[key] ?? MeshRefineAccumulator()
            accumulator.sum += SIMD3<Double>(Double(point.x), Double(point.y), Double(point.z))
            accumulator.count += 1
            accumulators[key] = accumulator
        }
        // Keys retain the complete source-to-weld mapping needed by faces. The original float
        // vertices are no longer needed after accumulation, so release that large allocation before
        // building the welded vertex table and face set.
        parsed.vertices.removeAll(keepingCapacity: false)

        var ordered = accumulators.keys.sorted {
            if $0.x != $1.x { return $0.x < $1.x }
            if $0.y != $1.y { return $0.y < $1.y }
            return $0.z < $1.z
        }
        var keyToIndex: [MeshRefineKey: Int] = [:]
        var vertices: [SIMD3<Float>] = []
        vertices.reserveCapacity(ordered.count)
        for key in ordered {
            keyToIndex[key] = vertices.count
            let accumulator = accumulators[key] ?? MeshRefineAccumulator()
            let divisor = Double(max(1, accumulator.count))
            let mean = accumulator.sum / divisor
            guard mean.x.isFinite, mean.y.isFinite, mean.z.isFinite,
                  abs(mean.x) <= Double(Float.greatestFiniteMagnitude),
                  abs(mean.y) <= Double(Float.greatestFiniteMagnitude),
                  abs(mean.z) <= Double(Float.greatestFiniteMagnitude) else {
                throw error("Meshの統合座標を確定できません")
            }
            vertices.append(SIMD3<Float>(Float(mean.x), Float(mean.y), Float(mean.z)))
        }

        // Faces only need a compact source-vertex -> welded-vertex index after the deterministic
        // welded table is built. Collapse the 24-byte source keys into Int indices, then release the
        // key arrays/dictionaries before allocating the deduplicated face set.
        var sourceToWelded: [Int] = []
        sourceToWelded.reserveCapacity(keys.count)
        for key in keys {
            guard let index = keyToIndex[key] else {
                throw error("Mesh頂点の統合対応を確定できません")
            }
            sourceToWelded.append(index)
        }
        keys.removeAll(keepingCapacity: false)
        ordered.removeAll(keepingCapacity: false)
        accumulators.removeAll(keepingCapacity: false)
        keyToIndex.removeAll(keepingCapacity: false)

        var faces: [SIMD3<Int>] = []
        var faceSet = Set<MeshRefineFaceKey>()
        faces.reserveCapacity(parsed.faces.count)
        for face in parsed.faces {
            guard face.x >= 0, face.y >= 0, face.z >= 0,
                  face.x < sourceToWelded.count,
                  face.y < sourceToWelded.count,
                  face.z < sourceToWelded.count else { continue }
            let a = sourceToWelded[face.x]
            let b = sourceToWelded[face.y]
            let c = sourceToWelded[face.z]
            guard a != b, b != c, a != c else { continue }
            let cross = simd_cross(vertices[b] - vertices[a], vertices[c] - vertices[a])
            let area = simd_length_squared(cross)
            guard area.isFinite, area > 1e-10 else { continue }
            guard faceSet.insert(MeshRefineFaceKey(a, b, c)).inserted else { continue }
            faces.append(SIMD3<Int>(a, b, c))
        }
        sourceToWelded.removeAll(keepingCapacity: false)
        faceSet.removeAll(keepingCapacity: false)
        parsed.faces.removeAll(keepingCapacity: false)

        guard !faces.isEmpty else { throw error("統合後に有効な面が残りませんでした") }
        let removedComponents = filterMicroscopicComponents(vertices: vertices, faces: &faces)
        guard !faces.isEmpty else { throw error("ノイズ除去後に有効な面が残りませんでした") }
        let compacted = compact(vertices: vertices, faces: faces)
        let normals = recomputeNormals(vertices: compacted.vertices, faces: compacted.faces)

        let outputURL = url.deletingLastPathComponent()
            .appendingPathComponent("mesh-refined-\(UUID().uuidString.lowercased()).obj")
        try writeOBJ(
            to: outputURL,
            weldMeters: weldMeters,
            sourceFaceCount: sourceFaceCount,
            vertices: compacted.vertices,
            normals: normals,
            faces: compacted.faces
        )
        return MeshGeometryRefineResult(
            url: outputURL,
            vertexCount: compacted.vertices.count,
            faceCount: compacted.faces.count,
            removedFaces: max(0, sourceFaceCount - compacted.faces.count),
            removedComponents: removedComponents
        )
    }

    static func discard(_ result: MeshGeometryRefineResult) {
        try? FileManager.default.removeItem(at: result.url)
        let sidecar = result.url.deletingPathExtension().appendingPathExtension("mesh-asset.json")
        try? FileManager.default.removeItem(at: sidecar)
    }

    private static func writeOBJ(
        to outputURL: URL,
        weldMeters: Float,
        sourceFaceCount: Int,
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        faces: [SIMD3<Int>]
    ) throws {
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil) else {
            throw error("精製後OBJの出力ファイルを作成できません")
        }
        let handle: FileHandle
        do {
            handle = try FileHandle(forWritingTo: outputURL)
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }

        do {
            var buffer = ""
            buffer.reserveCapacity(outputFlushThresholdBytes)
            var bufferedBytes = 0

            func append(_ line: String) throws {
                buffer.append(line)
                bufferedBytes += line.utf8.count
                if bufferedBytes >= outputFlushThresholdBytes {
                    try handle.write(contentsOf: Data(buffer.utf8))
                    buffer.removeAll(keepingCapacity: true)
                    bufferedBytes = 0
                }
            }

            try append("# Scan Lab refined metric mesh\n")
            try append("# conservative weld_m \(weldMeters)\n")
            try append("# source_faces \(sourceFaceCount) refined_faces \(faces.count)\n")
            for (index, point) in vertices.enumerated() {
                if index & 0xFFF == 0 { try Task.checkCancellation() }
                try append("v \(point.x) \(point.y) \(point.z)\n")
            }
            for (index, normal) in normals.enumerated() {
                if index & 0xFFF == 0 { try Task.checkCancellation() }
                try append("vn \(normal.x) \(normal.y) \(normal.z)\n")
            }
            for (index, face) in faces.enumerated() {
                if index & 0xFFF == 0 { try Task.checkCancellation() }
                try append("f \(face.x + 1)//\(face.x + 1) \(face.y + 1)//\(face.y + 1) \(face.z + 1)//\(face.z + 1)\n")
            }
            if !buffer.isEmpty {
                try handle.write(contentsOf: Data(buffer.utf8))
            }
            try handle.synchronize()
            try handle.close()
        } catch {
            try? handle.close()
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }
    }

    private static func parse(_ url: URL) throws -> MeshRefineMesh {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard (attributes[.type] as? FileAttributeType) == .typeRegular,
              let size = attributes[.size] as? NSNumber,
              size.uint64Value > 0 else {
            throw error("OBJファイルを読み込めません")
        }
        let sourceByteCount = Int(clamping: size.uint64Value)
        var vertices: [SIMD3<Float>] = []
        var faces: [SIMD3<Int>] = []
        vertices.reserveCapacity(max(128, sourceByteCount / 80))

        try forEachOBJLine(at: url) { line in
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard let directive = fields.first else { return }
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

    private static func forEachOBJLine(
        at url: URL,
        body: (Substring) throws -> Void
    ) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var buffer = Data()
        buffer.reserveCapacity(objInputChunkSize * 2)

        while let chunk = try handle.read(upToCount: objInputChunkSize), !chunk.isEmpty {
            try Task.checkCancellation()
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
                    throw error("OBJの1行が安全な上限を超えています")
                }
                let lineString = String(decoding: buffer[start..<end], as: UTF8.self)
                try body(lineString[...])
                start = buffer.index(after: newline)
            }
            if start > buffer.startIndex {
                buffer.removeSubrange(buffer.startIndex..<start)
            }
            guard buffer.count <= maximumOBJLineBytes else {
                throw error("OBJの1行が安全な上限を超えています")
            }
        }

        if !buffer.isEmpty {
            try Task.checkCancellation()
            var end = buffer.endIndex
            if end > buffer.startIndex {
                let previous = buffer.index(before: end)
                if buffer[previous] == 0x0D { end = previous }
            }
            guard buffer.distance(from: buffer.startIndex, to: end) <= maximumOBJLineBytes else {
                throw error("OBJの1行が安全な上限を超えています")
            }
            let lineString = String(decoding: buffer[buffer.startIndex..<end], as: UTF8.self)
            try body(lineString[...])
        }
    }

    private static func filterMicroscopicComponents(vertices: [SIMD3<Float>], faces: inout [SIMD3<Int>]) -> Int {
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

        // Keep one compact summary per component instead of retaining an array of every face index
        // and then a second Set of every kept face index. On large connected meshes the old shape
        // duplicated O(faceCount) Int storage exactly when refinement is already memory intensive.
        var summaries: [Int: MeshRefineComponentSummary] = [:]
        for face in faces {
            let root = find(face.x)
            var summary = summaries[root] ?? MeshRefineComponentSummary()
            summary.faceCount += 1
            for id in [face.x, face.y, face.z] {
                summary.minimum = simd_min(summary.minimum, vertices[id])
                summary.maximum = simd_max(summary.maximum, vertices[id])
            }
            summaries[root] = summary
        }

        var keptRoots = Set<Int>()
        var removed = 0
        for (root, summary) in summaries {
            let diagonal = simd_length(summary.maximum - summary.minimum)
            if diagonal.isFinite, summary.faceCount >= 4 || diagonal >= 0.006 {
                keptRoots.insert(root)
            } else {
                removed += 1
            }
        }
        faces.removeAll { !keptRoots.contains(find($0.x)) }
        return removed
    }

    private static func compact(vertices: [SIMD3<Float>], faces: [SIMD3<Int>]) -> MeshRefineMesh {
        // A dense remap replaces the Set -> sorted Array -> Dictionary chain. Because compacted
        // vertices were already emitted in ascending original index order, this preserves output
        // ordering while keeping one O(vertexCount) Int table and direct O(1) face remaps.
        var remap = Array(repeating: -1, count: vertices.count)
        for face in faces {
            remap[face.x] = 0
            remap[face.y] = 0
            remap[face.z] = 0
        }
        var outputVertices: [SIMD3<Float>] = []
        for oldIndex in remap.indices where remap[oldIndex] == 0 {
            remap[oldIndex] = outputVertices.count
            outputVertices.append(vertices[oldIndex])
        }
        var outputFaces: [SIMD3<Int>] = []
        outputFaces.reserveCapacity(faces.count)
        for face in faces {
            let a = remap[face.x]
            let b = remap[face.y]
            let c = remap[face.z]
            guard a >= 0, b >= 0, c >= 0 else { continue }
            outputFaces.append(SIMD3<Int>(a, b, c))
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
        for index in normals.indices {
            let lengthSquared = simd_length_squared(normals[index])
            normals[index] = lengthSquared.isFinite && lengthSquared > 1e-12
                ? simd_normalize(normals[index])
                : SIMD3<Float>(0, 1, 0)
        }
        return normals
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
