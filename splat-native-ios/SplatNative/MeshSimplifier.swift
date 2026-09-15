import Foundation
import SceneKit
import SwiftUI
import simd

private struct MeshSimplifyResult: Sendable {
    let url: URL
    let vertexCount: Int
    let faceCount: Int
}

private struct MeshClusterKey: Hashable, Sendable {
    let x: Int
    let y: Int
    let z: Int
}

private enum MeshOBJSimplifier {
    static func simplify(url: URL, retainedFraction: Double) throws -> MeshSimplifyResult {
        let source = try String(contentsOf: url, encoding: .utf8)
        var vertices: [SIMD3<Float>] = []
        var faces: [SIMD3<Int>] = []

        for line in source.split(whereSeparator: \.isNewline) {
            if line.hasPrefix("v ") {
                let parts = line.split(separator: " ")
                guard parts.count >= 4,
                      let x = Float(parts[1]),
                      let y = Float(parts[2]),
                      let z = Float(parts[3]) else { continue }
                vertices.append(SIMD3<Float>(x, y, z))
            } else if line.hasPrefix("f ") {
                let parts = line.split(separator: " ")
                guard parts.count >= 4 else { continue }
                let parsed = parts[1...3].compactMap { token -> Int? in
                    guard let first = token.split(separator: "/").first,
                          let oneBased = Int(first), oneBased > 0 else { return nil }
                    return oneBased - 1
                }
                guard parsed.count == 3 else { continue }
                faces.append(SIMD3<Int>(parsed[0], parsed[1], parsed[2]))
            }
        }

        guard vertices.count >= 8, !faces.isEmpty else {
            throw NSError(
                domain: "ScanLab.MeshSimplifier",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "OBJに十分な三角形Meshがありません"]
            )
        }

        var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for vertex in vertices {
            minimum = simd_min(minimum, vertex)
            maximum = simd_max(maximum, vertex)
        }
        let extent = simd_max(maximum - minimum, SIMD3<Float>(repeating: 0.0001))
        let targetVertexCount = max(8, Int(Double(vertices.count) * min(0.95, max(0.1, retainedFraction))))
        let resolution = max(2, Int(ceil(pow(Double(targetVertexCount), 1.0 / 3.0))))
        let cell = extent / Float(resolution)

        var sums: [MeshClusterKey: SIMD3<Float>] = [:]
        var counts: [MeshClusterKey: Int] = [:]
        var vertexKeys: [MeshClusterKey] = []
        vertexKeys.reserveCapacity(vertices.count)

        for vertex in vertices {
            let relative = (vertex - minimum) / cell
            let key = MeshClusterKey(
                x: min(resolution - 1, max(0, Int(floor(relative.x)))),
                y: min(resolution - 1, max(0, Int(floor(relative.y)))),
                z: min(resolution - 1, max(0, Int(floor(relative.z))))
            )
            vertexKeys.append(key)
            sums[key, default: .zero] += vertex
            counts[key, default: 0] += 1
        }

        let orderedKeys = sums.keys.sorted {
            if $0.x != $1.x { return $0.x < $1.x }
            if $0.y != $1.y { return $0.y < $1.y }
            return $0.z < $1.z
        }
        var remap: [MeshClusterKey: Int] = [:]
        var simplifiedVertices: [SIMD3<Float>] = []
        simplifiedVertices.reserveCapacity(orderedKeys.count)
        for key in orderedKeys {
            remap[key] = simplifiedVertices.count
            simplifiedVertices.append((sums[key] ?? .zero) / Float(max(1, counts[key] ?? 1)))
        }

        var simplifiedFaces: [SIMD3<Int>] = []
        var faceSet = Set<String>()
        for face in faces {
            guard face.x >= 0, face.y >= 0, face.z >= 0,
                  face.x < vertexKeys.count, face.y < vertexKeys.count, face.z < vertexKeys.count,
                  let a = remap[vertexKeys[face.x]],
                  let b = remap[vertexKeys[face.y]],
                  let c = remap[vertexKeys[face.z]],
                  a != b, b != c, a != c else { continue }
            let key = "\(a):\(b):\(c)"
            guard faceSet.insert(key).inserted else { continue }
            simplifiedFaces.append(SIMD3<Int>(a, b, c))
        }

        guard !simplifiedFaces.isEmpty else {
            throw NSError(
                domain: "ScanLab.MeshSimplifier",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "簡略化後に有効な三角形が残りませんでした"]
            )
        }

        let percent = Int((retainedFraction * 100).rounded())
        let outputURL = url.deletingLastPathComponent().appendingPathComponent("mesh-simplified-\(percent).obj")
        var output = "# Scan Lab vertex-cluster simplified mesh\n"
        output += "# source vertices \(vertices.count) faces \(faces.count)\n"
        output += "# simplified vertices \(simplifiedVertices.count) faces \(simplifiedFaces.count)\n"
        for vertex in simplifiedVertices {
            output += "v \(vertex.x) \(vertex.y) \(vertex.z)\n"
        }
        for face in simplifiedFaces {
            output += "f \(face.x + 1) \(face.y + 1) \(face.z + 1)\n"
        }
        try output.write(to: outputURL, atomically: true, encoding: .utf8)
        return MeshSimplifyResult(
            url: outputURL,
            vertexCount: simplifiedVertices.count,
            faceCount: simplifiedFaces.count
        )
    }
}

@MainActor
struct MeshSimplifySheet: View {
    @EnvironmentObject var model: MeshScanModel
    @Environment(\.dismiss) private var dismiss
    let sourceURL: URL
    @State private var retainedFraction = 0.55
    @State private var isWorking = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Mesh簡略化") {
                    HStack {
                        Text("目標密度")
                        Spacer()
                        Text("\(Int(retainedFraction * 100))%")
                            .monospacedDigit()
                    }
                    Slider(value: $retainedFraction, in: 0.2...0.9, step: 0.05)
                    Text("頂点クラスタリングで実ジオメトリを削減します。元OBJは保持されます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let errorText {
                    Section {
                        Text(errorText).foregroundStyle(.red)
                    }
                }
                Section {
                    Button(isWorking ? "簡略化中…" : "簡略化OBJを生成") {
                        isWorking = true
                        errorText = nil
                        let url = sourceURL
                        let fraction = retainedFraction
                        Task {
                            do {
                                let result = try await Task.detached(priority: .userInitiated) {
                                    try MeshOBJSimplifier.simplify(url: url, retainedFraction: fraction)
                                }.value
                                model.rawOBJURL = result.url
                                model.resultURL = result.url
                                model.previewScene = try? SCNScene(url: result.url, options: nil)
                                model.vertexCount = result.vertexCount
                                model.faceCount = result.faceCount
                                model.statusMessage = "簡略化した実Meshを生成しました"
                                isWorking = false
                                dismiss()
                            } catch {
                                isWorking = false
                                errorText = error.localizedDescription
                            }
                        }
                    }
                    .disabled(isWorking)
                }
            }
            .navigationTitle("Meshを軽量化")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
