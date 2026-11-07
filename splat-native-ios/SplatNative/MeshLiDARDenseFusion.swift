import Foundation
import SceneKit
import simd

private struct LiDARDepthIndex: Decodable, Sendable {
    let samples: [LiDARDepthSample]
}

private struct LiDARDepthSample: Decodable, Sendable {
    let file: String
    let timestamp: TimeInterval
    let width: Int
    let height: Int
    let cameraWidth: Int?
    let cameraHeight: Int?
    let transform: [[Float]]
    let intrinsics: [[Float]]
}

private struct LiDARFusionVoxel: Hashable, Sendable {
    let x: Int
    let y: Int
    let z: Int
}

private struct LiDARFusionFace: Hashable, Sendable {
    let a: Int
    let b: Int
    let c: Int

    init(_ x: Int, _ y: Int, _ z: Int) {
        let sorted = [x, y, z].sorted()
        a = sorted[0]
        b = sorted[1]
        c = sorted[2]
    }
}

private struct LiDARFusionGrid: Sendable {
    let columns: Int
    let rows: Int
    let keys: [LiDARFusionVoxel?]
    let depths: [Float]
}

private struct LiDARFusionBounds: Sendable {
    var minimum: SIMD3<Float>
    var maximum: SIMD3<Float>

    var extent: SIMD3<Float> { maximum - minimum }
    var maximumExtent: Float { max(extent.x, max(extent.y, extent.z)) }

    func expanded(by amount: Float) -> LiDARFusionBounds {
        LiDARFusionBounds(
            minimum: minimum - SIMD3<Float>(repeating: amount),
            maximum: maximum + SIMD3<Float>(repeating: amount)
        )
    }

    func contains(_ point: SIMD3<Float>) -> Bool {
        point.x >= minimum.x && point.x <= maximum.x &&
        point.y >= minimum.y && point.y <= maximum.y &&
        point.z >= minimum.z && point.z <= maximum.z
    }
}

struct MeshLiDARDenseFusionResult: Sendable {
    let url: URL
    let vertexCount: Int
    let faceCount: Int
    let depthFrames: Int
    let weldMeters: Float
}

private enum MeshLiDARDenseFusionEngine {
    static func fuse(sourceOBJURL: URL) throws -> MeshLiDARDenseFusionResult {
        let projectURL = sourceOBJURL.deletingLastPathComponent()
        let depthDirectory = projectURL.appendingPathComponent("lidar-depth", isDirectory: true)
        let indexURL = depthDirectory.appendingPathComponent("depth-index.json")
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            throw error("LiDAR depth rawがまだ保存されていません")
        }

        let index = try JSONDecoder().decode(LiDARDepthIndex.self, from: Data(contentsOf: indexURL))
        guard index.samples.count >= 3 else {
            throw error("高密度融合に必要なdepthフレームが不足しています")
        }

        let sourceBounds = try bounds(of: sourceOBJURL)
        let expansion = max(0.035, sourceBounds.maximumExtent * 0.06)
        let acceptedBounds = sourceBounds.expanded(by: expansion)
        let weldMeters: Float
        if sourceBounds.maximumExtent <= 1.2 {
            weldMeters = 0.003
        } else if sourceBounds.maximumExtent <= 3.0 {
            weldMeters = 0.006
        } else {
            weldMeters = 0.015
        }

        let selectedSamples = select(index.samples, maximumCount: 18)
        var sums: [LiDARFusionVoxel: SIMD3<Float>] = [:]
        var counts: [LiDARFusionVoxel: Int] = [:]
        var grids: [LiDARFusionGrid] = []
        grids.reserveCapacity(selectedSamples.count)

        for sample in selectedSamples {
            guard let grid = ingest(
                sample: sample,
                depthDirectory: depthDirectory,
                bounds: acceptedBounds,
                weldMeters: weldMeters,
                sums: &sums,
                counts: &counts
            ) else { continue }
            grids.append(grid)
        }

        guard sums.count >= 1_000, grids.count >= 3 else {
            throw error("depth融合に使える有効点が不足しています")
        }

        let orderedKeys = sums.keys.sorted { lhs, rhs in
            if lhs.x != rhs.x { return lhs.x < rhs.x }
            if lhs.y != rhs.y { return lhs.y < rhs.y }
            return lhs.z < rhs.z
        }
        var keyToVertex: [LiDARFusionVoxel: Int] = [:]
        var vertices: [SIMD3<Float>] = []
        vertices.reserveCapacity(orderedKeys.count)
        for key in orderedKeys {
            keyToVertex[key] = vertices.count
            vertices.append((sums[key] ?? .zero) / Float(max(1, counts[key] ?? 1)))
        }

        var faces: [SIMD3<Int>] = []
        var faceSet = Set<LiDARFusionFace>()
        faces.reserveCapacity(min(500_000, vertices.count * 3))

        for grid in grids {
            guard grid.columns > 1, grid.rows > 1 else { continue }
            for y in 0..<(grid.rows - 1) {
                for x in 0..<(grid.columns - 1) {
                    let i = y * grid.columns + x
                    let j = i + 1
                    let k = i + grid.columns
                    let l = k + 1
                    guard let ka = grid.keys[i],
                          let kb = grid.keys[j],
                          let kc = grid.keys[k],
                          let kd = grid.keys[l],
                          let a = keyToVertex[ka],
                          let b = keyToVertex[kb],
                          let c = keyToVertex[kc],
                          let d = keyToVertex[kd] else { continue }
                    let depths = [grid.depths[i], grid.depths[j], grid.depths[k], grid.depths[l]]
                    let minimumDepth = depths.min() ?? 0
                    let maximumDepth = depths.max() ?? 0
                    let averageDepth = depths.reduce(0, +) / 4
                    guard minimumDepth > 0,
                          maximumDepth - minimumDepth <= max(0.025, averageDepth * 0.04) else { continue }

                    appendFace(a, c, b, vertices: vertices, faces: &faces, faceSet: &faceSet)
                    appendFace(b, c, d, vertices: vertices, faces: &faces, faceSet: &faceSet)
                }
            }
        }

        guard faces.count >= 1_000 else {
            throw error("depth点は取得できましたが連続面を十分に構成できませんでした")
        }

        var normals = Array(repeating: SIMD3<Float>.zero, count: vertices.count)
        for face in faces {
            let normal = simd_cross(
                vertices[face.y] - vertices[face.x],
                vertices[face.z] - vertices[face.x]
            )
            normals[face.x] += normal
            normals[face.y] += normal
            normals[face.z] += normal
        }
        normals = normals.map {
            simd_length_squared($0) > 1e-12 ? simd_normalize($0) : SIMD3<Float>(0, 1, 0)
        }

        let outputURL = projectURL.appendingPathComponent("mesh-depth-fused.obj")
        _ = FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: outputURL)
        defer { try? handle.close() }
        var buffer = "# Scan Lab multi-view LiDAR depth fused metric mesh\n"
        buffer += "# depth_frames \(grids.count) weld_m \(weldMeters) vertices \(vertices.count) faces \(faces.count)\n"
        func flush() throws {
            guard !buffer.isEmpty else { return }
            try handle.write(contentsOf: Data(buffer.utf8))
            buffer.removeAll(keepingCapacity: true)
        }
        for vertex in vertices {
            buffer += "v \(vertex.x) \(vertex.y) \(vertex.z)\n"
            if buffer.utf8.count > 1_000_000 { try flush() }
        }
        for normal in normals {
            buffer += "vn \(normal.x) \(normal.y) \(normal.z)\n"
            if buffer.utf8.count > 1_000_000 { try flush() }
        }
        for face in faces {
            buffer += "f \(face.x + 1)//\(face.x + 1) \(face.y + 1)//\(face.y + 1) \(face.z + 1)//\(face.z + 1)\n"
            if buffer.utf8.count > 1_000_000 { try flush() }
        }
        try flush()

        return MeshLiDARDenseFusionResult(
            url: outputURL,
            vertexCount: vertices.count,
            faceCount: faces.count,
            depthFrames: grids.count,
            weldMeters: weldMeters
        )
    }

    private static func ingest(
        sample: LiDARDepthSample,
        depthDirectory: URL,
        bounds: LiDARFusionBounds,
        weldMeters: Float,
        sums: inout [LiDARFusionVoxel: SIMD3<Float>],
        counts: inout [LiDARFusionVoxel: Int]
    ) -> LiDARFusionGrid? {
        guard sample.transform.count == 4,
              sample.transform.allSatisfy({ $0.count == 4 }),
              sample.intrinsics.count == 3,
              sample.intrinsics.allSatisfy({ $0.count == 3 }),
              sample.width > 4,
              sample.height > 4 else { return nil }
        let fileURL = depthDirectory.appendingPathComponent(sample.file)
        guard let data = try? Data(contentsOf: fileURL),
              data.count >= sample.width * sample.height * MemoryLayout<Float>.size else { return nil }

        let cameraToWorld = matrix(sample.transform)
        let sourceWidth = max(1, sample.cameraWidth ?? sample.width)
        let sourceHeight = max(1, sample.cameraHeight ?? sample.height)
        let scaleX = Float(sample.width) / Float(sourceWidth)
        let scaleY = Float(sample.height) / Float(sourceHeight)
        let fx = sample.intrinsics[0][0] * scaleX
        let fy = sample.intrinsics[1][1] * scaleY
        let cx = sample.intrinsics[0][2] * scaleX
        let cy = sample.intrinsics[1][2] * scaleY
        guard fx > 0, fy > 0 else { return nil }

        let pixelStride = 2
        let columns = (sample.width - 2) / pixelStride
        let rows = (sample.height - 2) / pixelStride
        guard columns > 1, rows > 1 else { return nil }
        var keys = [LiDARFusionVoxel?](repeating: nil, count: columns * rows)
        var depths = [Float](repeating: 0, count: columns * rows)

        data.withUnsafeBytes { rawBuffer in
            let values = rawBuffer.bindMemory(to: Float.self)
            for gridY in 0..<rows {
                let pixelY = 1 + gridY * pixelStride
                for gridX in 0..<columns {
                    let pixelX = 1 + gridX * pixelStride
                    let depth = values[pixelY * sample.width + pixelX]
                    guard depth.isFinite, depth >= 0.12, depth <= 5.5 else { continue }
                    let cameraX = (Float(pixelX) - cx) / fx * depth
                    let cameraY = -(Float(pixelY) - cy) / fy * depth
                    let cameraPoint = SIMD4<Float>(cameraX, cameraY, -depth, 1)
                    let transformed = cameraToWorld * cameraPoint
                    let world = SIMD3<Float>(transformed.x, transformed.y, transformed.z)
                    guard bounds.contains(world) else { continue }
                    let key = LiDARFusionVoxel(
                        x: Int((world.x / weldMeters).rounded()),
                        y: Int((world.y / weldMeters).rounded()),
                        z: Int((world.z / weldMeters).rounded())
                    )
                    sums[key, default: .zero] += world
                    counts[key, default: 0] += 1
                    let index = gridY * columns + gridX
                    keys[index] = key
                    depths[index] = depth
                }
            }
        }

        return LiDARFusionGrid(columns: columns, rows: rows, keys: keys, depths: depths)
    }

    private static func appendFace(
        _ a: Int,
        _ b: Int,
        _ c: Int,
        vertices: [SIMD3<Float>],
        faces: inout [SIMD3<Int>],
        faceSet: inout Set<LiDARFusionFace>
    ) {
        guard a != b, b != c, a != c else { return }
        let area = simd_length_squared(simd_cross(vertices[b] - vertices[a], vertices[c] - vertices[a]))
        guard area > 1e-10 else { return }
        let canonical = LiDARFusionFace(a, b, c)
        guard faceSet.insert(canonical).inserted else { return }
        faces.append(SIMD3<Int>(a, b, c))
    }

    private static func bounds(of url: URL) throws -> LiDARFusionBounds {
        let text = try String(contentsOf: url, encoding: .utf8)
        var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        var count = 0
        for line in text.split(whereSeparator: \.isNewline) where line.hasPrefix("v ") {
            let parts = line.split(separator: " ")
            guard parts.count >= 4,
                  let x = Float(parts[1]),
                  let y = Float(parts[2]),
                  let z = Float(parts[3]) else { continue }
            let point = SIMD3<Float>(x, y, z)
            minimum = simd_min(minimum, point)
            maximum = simd_max(maximum, point)
            count += 1
        }
        guard count > 0 else { throw error("元Meshの境界を取得できません") }
        return LiDARFusionBounds(minimum: minimum, maximum: maximum)
    }

    private static func select(_ samples: [LiDARDepthSample], maximumCount: Int) -> [LiDARDepthSample] {
        guard samples.count > maximumCount else { return samples }
        return (0..<maximumCount).map { index in
            let sourceIndex = Int(
                (Double(index) * Double(samples.count - 1) / Double(maximumCount - 1)).rounded()
            )
            return samples[sourceIndex]
        }
    }

    private static func matrix(_ rows: [[Float]]) -> simd_float4x4 {
        simd_float4x4(columns: (
            SIMD4<Float>(rows[0][0], rows[1][0], rows[2][0], rows[3][0]),
            SIMD4<Float>(rows[0][1], rows[1][1], rows[2][1], rows[3][1]),
            SIMD4<Float>(rows[0][2], rows[1][2], rows[2][2], rows[3][2]),
            SIMD4<Float>(rows[0][3], rows[1][3], rows[2][3], rows[3][3])
        ))
    }

    private static func error(_ message: String) -> NSError {
        NSError(domain: "ScanLab.MeshLiDARDenseFusion", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

extension MeshScanModel {
    func fuseLiDARDenseDepth() {
        guard phase == .finished,
              mode == .lidar,
              currentMeshHasMetricScale,
              let source = rawOBJURL ?? resultURL,
              source.pathExtension.lowercased() == "obj",
              !source.lastPathComponent.lowercased().contains("depth-fused") else { return }

        phase = .reconstructing
        reconstructionProgress = 0.18
        statusMessage = "複数視点のLiDAR depthを融合して、scene meshより高密度な形状を再構築しています"

        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try MeshLiDARDenseFusionEngine.fuse(sourceOBJURL: source)
                }.value
                guard let self else { return }
                self.rawOBJURL = result.url
                self.resultURL = result.url
                self.previewScene = try? SCNScene(url: result.url, options: nil)
                self.vertexCount = result.vertexCount
                self.faceCount = result.faceCount
                self.reconstructionProgress = 1
                self.phase = .finished
                self.statusMessage = "LiDAR depth融合完了：\(result.depthFrames)視点・\(result.faceCount.formatted())面・\(String(format: "%.1f", result.weldMeters * 1000))mm融合"
                try? self.persistExporterMeshAssetContract()
            } catch {
                guard let self else { return }
                self.reconstructionProgress = 1
                self.phase = .finished
                self.statusMessage = "ARKit scene meshを保持しました。depth高密度融合のみ未適用: \(error.localizedDescription)"
            }
        }
    }
}
