import Foundation
import SceneKit
import SwiftUI
import simd

private struct DetailFace: Sendable {
    let a: Int
    let b: Int
    let c: Int
}

private struct DetailEdge: Hashable, Sendable {
    let a: Int
    let b: Int

    init(_ x: Int, _ y: Int) {
        a = min(x, y)
        b = max(x, y)
    }
}

private struct DetailCluster: Hashable, Sendable {
    let x: Int
    let y: Int
    let z: Int
    let unique: Int
}

private struct DetailSimplifyResult: Sendable {
    let url: URL
    let vertices: Int
    let faces: Int
    let boundaryVertices: Int
    let protectedComponents: Int
}

private enum MeshDetailSimplifierEngine {
    static func simplify(url: URL, retainedFraction: Double) throws -> DetailSimplifyResult {
        let text = try String(contentsOf: url, encoding: .utf8)
        var vertices: [SIMD3<Float>] = []
        var faces: [DetailFace] = []

        for line in text.split(whereSeparator: \.isNewline) {
            if line.hasPrefix("v ") {
                let parts = line.split(separator: " ")
                guard parts.count >= 4,
                      let x = Float(parts[1]),
                      let y = Float(parts[2]),
                      let z = Float(parts[3]) else { continue }
                vertices.append(SIMD3<Float>(x, y, z))
            } else if line.hasPrefix("f ") {
                let tokens = line.split(separator: " ").dropFirst()
                let indices = tokens.compactMap { token -> Int? in
                    guard let first = token.split(separator: "/", omittingEmptySubsequences: false).first,
                          let raw = Int(first) else { return nil }
                    return raw > 0 ? raw - 1 : vertices.count + raw
                }
                guard indices.count >= 3 else { continue }
                for i in 1..<(indices.count - 1) {
                    faces.append(DetailFace(a: indices[0], b: indices[i], c: indices[i + 1]))
                }
            }
        }

        guard vertices.count > 8, !faces.isEmpty else {
            throw error("十分なMeshがありません")
        }

        var edgeCount: [DetailEdge: Int] = [:]
        for face in faces {
            edgeCount[DetailEdge(face.a, face.b), default: 0] += 1
            edgeCount[DetailEdge(face.b, face.c), default: 0] += 1
            edgeCount[DetailEdge(face.c, face.a), default: 0] += 1
        }

        var boundaryVertices = Set<Int>()
        for (edge, count) in edgeCount where count == 1 {
            boundaryVertices.insert(edge.a)
            boundaryVertices.insert(edge.b)
        }

        var parent = Array(0..<vertices.count)
        func find(_ x: Int) -> Int {
            var index = x
            while parent[index] != index {
                parent[index] = parent[parent[index]]
                index = parent[index]
            }
            return index
        }
        func union(_ a: Int, _ b: Int) {
            let rootA = find(a)
            let rootB = find(b)
            if rootA != rootB { parent[rootB] = rootA }
        }

        for face in faces {
            union(face.a, face.b)
            union(face.b, face.c)
            union(face.c, face.a)
        }

        var componentFaceCounts: [Int: Int] = [:]
        for face in faces {
            componentFaceCounts[find(face.a), default: 0] += 1
        }
        let protectedRoots = Set(
            componentFaceCounts
                .filter { $0.value < 600 }
                .map(\.key)
        )
        let protectedVertices = Set(vertices.indices.filter { protectedRoots.contains(find($0)) })

        var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for vertex in vertices {
            minimum = simd_min(minimum, vertex)
            maximum = simd_max(maximum, vertex)
        }
        let extent = simd_max(maximum - minimum, SIMD3<Float>(repeating: 0.0001))
        let target = max(16, Int(Double(vertices.count) * min(0.95, max(0.15, retainedFraction))))
        let resolution = max(2, Int(ceil(pow(Double(target), 1.0 / 3.0))))
        let cell = extent / Float(resolution)

        var sums: [DetailCluster: SIMD3<Float>] = [:]
        var counts: [DetailCluster: Int] = [:]
        var vertexKeys: [DetailCluster] = []
        vertexKeys.reserveCapacity(vertices.count)

        for (index, vertex) in vertices.enumerated() {
            let key: DetailCluster
            if boundaryVertices.contains(index) || protectedVertices.contains(index) {
                key = DetailCluster(x: 0, y: 0, z: 0, unique: index + 1)
            } else {
                let relative = (vertex - minimum) / cell
                key = DetailCluster(
                    x: min(resolution - 1, max(0, Int(floor(relative.x)))),
                    y: min(resolution - 1, max(0, Int(floor(relative.y)))),
                    z: min(resolution - 1, max(0, Int(floor(relative.z)))),
                    unique: 0
                )
            }
            vertexKeys.append(key)
            sums[key, default: .zero] += vertex
            counts[key, default: 0] += 1
        }

        let orderedKeys = sums.keys.sorted { lhs, rhs in
            if lhs.unique != rhs.unique { return lhs.unique < rhs.unique }
            if lhs.x != rhs.x { return lhs.x < rhs.x }
            if lhs.y != rhs.y { return lhs.y < rhs.y }
            return lhs.z < rhs.z
        }

        var clusterToIndex: [DetailCluster: Int] = [:]
        var outputVertices: [SIMD3<Float>] = []
        outputVertices.reserveCapacity(orderedKeys.count)
        for key in orderedKeys {
            clusterToIndex[key] = outputVertices.count
            outputVertices.append((sums[key] ?? .zero) / Float(max(1, counts[key] ?? 1)))
        }

        var outputFaces: [SIMD3<Int>] = []
        var seenFaces = Set<String>()
        for face in faces {
            guard face.a >= 0, face.b >= 0, face.c >= 0,
                  face.a < vertexKeys.count, face.b < vertexKeys.count, face.c < vertexKeys.count,
                  let a = clusterToIndex[vertexKeys[face.a]],
                  let b = clusterToIndex[vertexKeys[face.b]],
                  let c = clusterToIndex[vertexKeys[face.c]],
                  a != b, b != c, a != c else { continue }
            let area = simd_length_squared(simd_cross(outputVertices[b] - outputVertices[a], outputVertices[c] - outputVertices[a]))
            guard area > 1e-10 else { continue }
            let canonical = [a, b, c].sorted().map(String.init).joined(separator: ":")
            if seenFaces.insert(canonical).inserted {
                outputFaces.append(SIMD3<Int>(a, b, c))
            }
        }

        guard !outputFaces.isEmpty else {
            throw error("簡略化後に面が残りません")
        }

        var normals = Array(repeating: SIMD3<Float>.zero, count: outputVertices.count)
        for face in outputFaces {
            let normal = simd_cross(
                outputVertices[face.y] - outputVertices[face.x],
                outputVertices[face.z] - outputVertices[face.x]
            )
            normals[face.x] += normal
            normals[face.y] += normal
            normals[face.z] += normal
        }
        normals = normals.map {
            simd_length_squared($0) > 1e-12 ? simd_normalize($0) : SIMD3<Float>(0, 1, 0)
        }

        let percent = Int((retainedFraction * 100).rounded())
        let outputURL = url.deletingLastPathComponent()
            .appendingPathComponent("mesh-detail-simplified-\(percent).obj")
        var output = "# Scan Lab detail-preserving simplification\n"
        output += "# boundaries \(boundaryVertices.count) protected_components \(protectedRoots.count)\n"
        for vertex in outputVertices {
            output += "v \(vertex.x) \(vertex.y) \(vertex.z)\n"
        }
        for normal in normals {
            output += "vn \(normal.x) \(normal.y) \(normal.z)\n"
        }
        for face in outputFaces {
            output += "f \(face.x + 1)//\(face.x + 1) \(face.y + 1)//\(face.y + 1) \(face.z + 1)//\(face.z + 1)\n"
        }
        try output.write(to: outputURL, atomically: true, encoding: .utf8)

        return DetailSimplifyResult(
            url: outputURL,
            vertices: outputVertices.count,
            faces: outputFaces.count,
            boundaryVertices: boundaryVertices.count,
            protectedComponents: protectedRoots.count
        )
    }

    private static func error(_ message: String) -> NSError {
        NSError(domain: "ScanLab.MeshDetailSimplifier", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

@MainActor
struct MeshDetailSimplifySheet: View {
    @EnvironmentObject var model: MeshScanModel
    @Environment(\.dismiss) private var dismiss
    let sourceURL: URL
    @State private var retained = 0.60
    @State private var working = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("形状を守る軽量化") {
                    HStack {
                        Text("目標密度")
                        Spacer()
                        Text("\(Int(retained * 100))%").monospacedDigit()
                    }
                    Slider(value: $retained, in: 0.25...0.9, step: 0.05)
                    Text("境界線と小さな連結部品を固定し、内部だけをクラスタリングします。花びら・葉・細い包装を単純な頂点削減で消しにくくします。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red) }
                }
                Section {
                    Button(working ? "処理中…" : "ディテール保持OBJを生成") { run() }
                        .disabled(working)
                }
            }
            .navigationTitle("Mesh軽量化")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func run() {
        working = true
        errorText = nil
        let url = sourceURL
        let fraction = retained
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try MeshDetailSimplifierEngine.simplify(url: url, retainedFraction: fraction)
                }.value
                model.rawOBJURL = result.url
                model.resultURL = result.url
                model.previewScene = try? SCNScene(url: result.url, options: nil)
                model.vertexCount = result.vertices
                model.faceCount = result.faces
                model.statusMessage = "境界\(result.boundaryVertices)頂点・小部品\(result.protectedComponents)成分を保護して軽量化しました"
                working = false
                dismiss()
            } catch {
                working = false
                errorText = error.localizedDescription
            }
        }
    }
}
