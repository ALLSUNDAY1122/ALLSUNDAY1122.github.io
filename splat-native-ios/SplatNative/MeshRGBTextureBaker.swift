import Foundation
import SceneKit
import UIKit
import simd

private struct MeshTextureManifest: Decodable, Sendable {
    let frames: [MeshTextureFrame]
}

private struct MeshTextureFrame: Decodable, Sendable {
    let filePath: String
    let timestamp: TimeInterval
    let transform: [[Float]]
    let intrinsics: [[Float]]
    let width: Int
    let height: Int
}

private struct MeshTextureOBJ: Sendable {
    let vertices: [SIMD3<Float>]
    let triangles: [SIMD3<Int>]
}

private struct MeshTexturePreparedFrame: Sendable {
    let fileURL: URL
    let worldToCamera: simd_float4x4
    let cameraPosition: SIMD3<Float>
    let fx: Float
    let fy: Float
    let cx: Float
    let cy: Float
    let width: Float
    let height: Float
    let tileIndex: Int
}

struct MeshTextureBakeResult: Sendable {
    let objURL: URL
    let mtlURL: URL
    let textureURL: URL
    let metadataURL: URL
    let assignedTriangles: Int
    let totalTriangles: Int
    let selectedFrameCount: Int
    let atlasSize: Int

    var coverage: Double {
        guard totalTriangles > 0 else { return 0 }
        return Double(assignedTriangles) / Double(totalTriangles)
    }
}

private struct MeshTextureBakeMetadata: Codable, Sendable {
    let schemaVersion: Int
    let sourceOBJ: String
    let outputOBJ: String
    let textureFile: String
    let atlasWidth: Int
    let atlasHeight: Int
    let selectedFrames: Int
    let totalTriangles: Int
    let assignedTriangles: Int
    let projectionCoverage: Double
    let coordinateSpace: String
    let linearUnit: String
}

enum MeshRGBTextureBaker {
    static func bake(sourceOBJURL: URL) throws -> MeshTextureBakeResult {
        let projectURL = sourceOBJURL.deletingLastPathComponent()
        let manifestURL = projectURL.appendingPathComponent("mesh-project.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw bakeError("RGB撮影メタデータがありません")
        }

        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(MeshTextureManifest.self, from: manifestData)
        guard manifest.frames.count >= 8 else {
            throw bakeError("RGBテクスチャ生成には8枚以上の撮影フレームが必要です")
        }

        let mesh = try parseOBJ(sourceOBJURL)
        guard !mesh.vertices.isEmpty, !mesh.triangles.isEmpty else {
            throw bakeError("テクスチャ対象のMeshが空です")
        }

        let selected = selectFrames(manifest.frames, maximumCount: 63)
        guard !selected.isEmpty else {
            throw bakeError("利用できるRGBフレームがありません")
        }

        let atlasSize: Int
        if mesh.triangles.count >= 100_000 {
            atlasSize = 8192
        } else if mesh.triangles.count >= 25_000 {
            atlasSize = 4096
        } else {
            atlasSize = 2048
        }

        let grid = min(8, max(2, Int(ceil(sqrt(Double(selected.count + 1))))))
        let tileSize = atlasSize / grid
        let padding = max(2, tileSize / 256)
        let prepared = selected.enumerated().compactMap { index, frame in
            prepareFrame(frame, projectURL: projectURL, tileIndex: index)
        }
        guard !prepared.isEmpty else {
            throw bakeError("RGBフレームの姿勢情報を復元できません")
        }

        let textureURL = projectURL.appendingPathComponent("mesh-textured-atlas.jpg")
        try renderAtlas(
            frames: prepared,
            atlasSize: atlasSize,
            grid: grid,
            tileSize: tileSize,
            padding: padding,
            outputURL: textureURL
        )

        let mtlURL = projectURL.appendingPathComponent("mesh-textured.mtl")
        let objURL = projectURL.appendingPathComponent("mesh-textured.obj")
        let assigned = try writeTexturedOBJ(
            mesh: mesh,
            frames: prepared,
            atlasSize: atlasSize,
            grid: grid,
            tileSize: tileSize,
            padding: padding,
            neutralTileIndex: prepared.count,
            objURL: objURL,
            mtlURL: mtlURL,
            textureURL: textureURL
        )

        let metadata = MeshTextureBakeMetadata(
            schemaVersion: 1,
            sourceOBJ: sourceOBJURL.lastPathComponent,
            outputOBJ: objURL.lastPathComponent,
            textureFile: textureURL.lastPathComponent,
            atlasWidth: atlasSize,
            atlasHeight: atlasSize,
            selectedFrames: prepared.count,
            totalTriangles: mesh.triangles.count,
            assignedTriangles: assigned,
            projectionCoverage: Double(assigned) / Double(max(1, mesh.triangles.count)),
            coordinateSpace: "ARKit world space; Y-up; right-handed",
            linearUnit: "meter"
        )
        let metadataURL = projectURL.appendingPathComponent("mesh-texture-bake.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(metadata).write(to: metadataURL, options: .atomic)

        return MeshTextureBakeResult(
            objURL: objURL,
            mtlURL: mtlURL,
            textureURL: textureURL,
            metadataURL: metadataURL,
            assignedTriangles: assigned,
            totalTriangles: mesh.triangles.count,
            selectedFrameCount: prepared.count,
            atlasSize: atlasSize
        )
    }

    private static func selectFrames(_ frames: [MeshTextureFrame], maximumCount: Int) -> [MeshTextureFrame] {
        guard frames.count > maximumCount else { return frames }
        let denominator = Double(maximumCount - 1)
        let span = Double(frames.count - 1)
        var indices: [Int] = []
        indices.reserveCapacity(maximumCount)
        for i in 0..<maximumCount {
            let index = Int((Double(i) * span / denominator).rounded())
            if indices.last != index { indices.append(index) }
        }
        return indices.map { frames[$0] }
    }

    private static func prepareFrame(
        _ frame: MeshTextureFrame,
        projectURL: URL,
        tileIndex: Int
    ) -> MeshTexturePreparedFrame? {
        guard frame.transform.count == 4,
              frame.transform.allSatisfy({ $0.count == 4 }),
              frame.intrinsics.count == 3,
              frame.intrinsics.allSatisfy({ $0.count == 3 }),
              frame.width > 0,
              frame.height > 0 else { return nil }

        let cameraToWorld = matrix4(fromRows: frame.transform)
        let worldToCamera = simd_inverse(cameraToWorld)
        let cameraPosition = SIMD3<Float>(
            cameraToWorld.columns.3.x,
            cameraToWorld.columns.3.y,
            cameraToWorld.columns.3.z
        )
        let fileURL = projectURL.appendingPathComponent(frame.filePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        return MeshTexturePreparedFrame(
            fileURL: fileURL,
            worldToCamera: worldToCamera,
            cameraPosition: cameraPosition,
            fx: frame.intrinsics[0][0],
            fy: frame.intrinsics[1][1],
            cx: frame.intrinsics[0][2],
            cy: frame.intrinsics[1][2],
            width: Float(frame.width),
            height: Float(frame.height),
            tileIndex: tileIndex
        )
    }

    private static func matrix4(fromRows rows: [[Float]]) -> simd_float4x4 {
        simd_float4x4(columns: (
            SIMD4<Float>(rows[0][0], rows[1][0], rows[2][0], rows[3][0]),
            SIMD4<Float>(rows[0][1], rows[1][1], rows[2][1], rows[3][1]),
            SIMD4<Float>(rows[0][2], rows[1][2], rows[2][2], rows[3][2]),
            SIMD4<Float>(rows[0][3], rows[1][3], rows[2][3], rows[3][3])
        ))
    }

    private static func parseOBJ(_ url: URL) throws -> MeshTextureOBJ {
        let text = try String(contentsOf: url, encoding: .utf8)
        var vertices: [SIMD3<Float>] = []
        var triangles: [SIMD3<Int>] = []
        vertices.reserveCapacity(100_000)
        triangles.reserveCapacity(150_000)

        for lineSlice in text.split(whereSeparator: \ .isNewline) {
            if lineSlice.hasPrefix("v ") {
                let values = lineSlice.split(separator: " ", omittingEmptySubsequences: true)
                guard values.count >= 4,
                      let x = Float(values[1]),
                      let y = Float(values[2]),
                      let z = Float(values[3]) else { continue }
                vertices.append(SIMD3<Float>(x, y, z))
            } else if lineSlice.hasPrefix("f ") {
                let values = lineSlice.split(separator: " ", omittingEmptySubsequences: true)
                guard values.count >= 4 else { continue }
                let indices = values.dropFirst().compactMap { token -> Int? in
                    guard let first = token.split(separator: "/", omittingEmptySubsequences: false).first,
                          let raw = Int(first) else { return nil }
                    return raw > 0 ? raw - 1 : vertices.count + raw
                }
                guard indices.count >= 3 else { continue }
                for i in 1..<(indices.count - 1) {
                    let a = indices[0]
                    let b = indices[i]
                    let c = indices[i + 1]
                    guard a >= 0, b >= 0, c >= 0,
                          a < vertices.count, b < vertices.count, c < vertices.count else { continue }
                    triangles.append(SIMD3<Int>(a, b, c))
                }
            }
        }
        return MeshTextureOBJ(vertices: vertices, triangles: triangles)
    }

    private static func renderAtlas(
        frames: [MeshTexturePreparedFrame],
        atlasSize: Int,
        grid: Int,
        tileSize: Int,
        padding: Int,
        outputURL: URL
    ) throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: atlasSize, height: atlasSize),
            format: format
        )
        let inner = CGFloat(tileSize - 2 * padding)
        let jpeg = renderer.jpegData(withCompressionQuality: 0.9) { context in
            context.cgContext.setFillColor(UIColor(white: 0.42, alpha: 1).cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: atlasSize, height: atlasSize))

            for frame in frames {
                autoreleasepool {
                    guard let image = UIImage(contentsOfFile: frame.fileURL.path) else { return }
                    let column = frame.tileIndex % grid
                    let row = frame.tileIndex / grid
                    let rect = CGRect(
                        x: CGFloat(column * tileSize + padding),
                        y: CGFloat(row * tileSize + padding),
                        width: inner,
                        height: inner
                    )
                    image.draw(in: rect)
                }
            }
        }
        try jpeg.write(to: outputURL, options: .atomic)
    }

    private static func writeTexturedOBJ(
        mesh: MeshTextureOBJ,
        frames: [MeshTexturePreparedFrame],
        atlasSize: Int,
        grid: Int,
        tileSize: Int,
        padding: Int,
        neutralTileIndex: Int,
        objURL: URL,
        mtlURL: URL,
        textureURL: URL
    ) throws -> Int {
        let mtl = """
        newmtl scanlab_texture
        Ka 1.000000 1.000000 1.000000
        Kd 1.000000 1.000000 1.000000
        Ks 0.000000 0.000000 0.000000
        d 1.0
        illum 1
        map_Kd \(textureURL.lastPathComponent)
        """
        try mtl.write(to: mtlURL, atomically: true, encoding: .utf8)

        FileManager.default.createFile(atPath: objURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: objURL)
        defer { try? handle.close() }

        func flush(_ text: inout String) throws {
            guard !text.isEmpty else { return }
            try handle.write(contentsOf: Data(text.utf8))
            text.removeAll(keepingCapacity: true)
        }

        var buffer = "# Scan Lab RGB-projected metric mesh\n"
        buffer += "mtllib \(mtlURL.lastPathComponent)\n"
        buffer += "# vertices \(mesh.vertices.count) faces \(mesh.triangles.count)\n"
        for vertex in mesh.vertices {
            buffer += "v \(vertex.x) \(vertex.y) \(vertex.z)\n"
            if buffer.utf8.count > 1_000_000 { try flush(&buffer) }
        }
        buffer += "usemtl scanlab_texture\n"
        try flush(&buffer)

        let neutralUV = uvForNeutralTile(
            tileIndex: neutralTileIndex,
            atlasSize: atlasSize,
            grid: grid,
            tileSize: tileSize
        )
        var textureIndex = 1
        var assignedTriangles = 0

        for triangle in mesh.triangles {
            let a = mesh.vertices[triangle.x]
            let b = mesh.vertices[triangle.y]
            let c = mesh.vertices[triangle.z]
            let centroid = (a + b + c) / 3
            let cross = simd_cross(b - a, c - a)
            let faceNormal = simd_length_squared(cross) > 1e-12
                ? simd_normalize(cross)
                : SIMD3<Float>(0, 1, 0)

            var uvA = neutralUV
            var uvB = neutralUV
            var uvC = neutralUV
            if let best = bestFrame(for: centroid, normal: faceNormal, frames: frames),
               let projectedA = project(a, with: best),
               let projectedB = project(b, with: best),
               let projectedC = project(c, with: best),
               insideImage(projectedA, frame: best),
               insideImage(projectedB, frame: best),
               insideImage(projectedC, frame: best) {
                uvA = atlasUV(projectedA, frame: best, atlasSize: atlasSize, grid: grid, tileSize: tileSize, padding: padding)
                uvB = atlasUV(projectedB, frame: best, atlasSize: atlasSize, grid: grid, tileSize: tileSize, padding: padding)
                uvC = atlasUV(projectedC, frame: best, atlasSize: atlasSize, grid: grid, tileSize: tileSize, padding: padding)
                assignedTriangles += 1
            }

            let ta = textureIndex
            let tb = textureIndex + 1
            let tc = textureIndex + 2
            textureIndex += 3
            buffer += "vt \(uvA.x) \(uvA.y)\n"
            buffer += "vt \(uvB.x) \(uvB.y)\n"
            buffer += "vt \(uvC.x) \(uvC.y)\n"
            buffer += "f \(triangle.x + 1)/\(ta) \(triangle.y + 1)/\(tb) \(triangle.z + 1)/\(tc)\n"
            if buffer.utf8.count > 1_000_000 { try flush(&buffer) }
        }
        try flush(&buffer)
        return assignedTriangles
    }

    private static func bestFrame(
        for point: SIMD3<Float>,
        normal: SIMD3<Float>,
        frames: [MeshTexturePreparedFrame]
    ) -> MeshTexturePreparedFrame? {
        var best: MeshTexturePreparedFrame?
        var bestScore: Float = -.greatestFiniteMagnitude
        for frame in frames {
            guard let pixel = project(point, with: frame), insideImage(pixel, frame: frame) else { continue }
            let cameraVector = frame.cameraPosition - point
            let distanceSquared = max(0.01, simd_length_squared(cameraVector))
            let viewDirection = simd_normalize(cameraVector)
            let facing = abs(simd_dot(normal, viewDirection))
            guard facing >= 0.12 else { continue }
            let centeredX = abs(pixel.x / frame.width - 0.5)
            let centeredY = abs(pixel.y / frame.height - 0.5)
            let centerWeight = max(0.25, 1 - 0.65 * (centeredX + centeredY))
            let score = facing * centerWeight / distanceSquared
            if score > bestScore {
                bestScore = score
                best = frame
            }
        }
        return best
    }

    private static func project(
        _ point: SIMD3<Float>,
        with frame: MeshTexturePreparedFrame
    ) -> SIMD2<Float>? {
        let camera = frame.worldToCamera * SIMD4<Float>(point.x, point.y, point.z, 1)
        let depth = -camera.z
        guard depth > 0.04 else { return nil }
        let x = frame.cx + frame.fx * (camera.x / depth)
        let y = frame.cy - frame.fy * (camera.y / depth)
        guard x.isFinite, y.isFinite else { return nil }
        return SIMD2<Float>(x, y)
    }

    private static func insideImage(
        _ pixel: SIMD2<Float>,
        frame: MeshTexturePreparedFrame
    ) -> Bool {
        let marginX = frame.width * 0.01
        let marginY = frame.height * 0.01
        return pixel.x >= marginX && pixel.x <= frame.width - marginX &&
            pixel.y >= marginY && pixel.y <= frame.height - marginY
    }

    private static func atlasUV(
        _ pixel: SIMD2<Float>,
        frame: MeshTexturePreparedFrame,
        atlasSize: Int,
        grid: Int,
        tileSize: Int,
        padding: Int
    ) -> SIMD2<Float> {
        let column = frame.tileIndex % grid
        let row = frame.tileIndex / grid
        let inner = Float(tileSize - 2 * padding)
        let normalizedX = min(1, max(0, pixel.x / frame.width))
        let normalizedY = min(1, max(0, pixel.y / frame.height))
        let atlasX = Float(column * tileSize + padding) + normalizedX * inner
        let atlasYFromTop = Float(row * tileSize + padding) + normalizedY * inner
        return SIMD2<Float>(
            atlasX / Float(atlasSize),
            1 - atlasYFromTop / Float(atlasSize)
        )
    }

    private static func uvForNeutralTile(
        tileIndex: Int,
        atlasSize: Int,
        grid: Int,
        tileSize: Int
    ) -> SIMD2<Float> {
        let column = tileIndex % grid
        let row = tileIndex / grid
        let x = Float(column * tileSize + tileSize / 2) / Float(atlasSize)
        let yFromTop = Float(row * tileSize + tileSize / 2) / Float(atlasSize)
        return SIMD2<Float>(x, 1 - yFromTop)
    }

    private static func bakeError(_ message: String) -> NSError {
        NSError(domain: "MeshRGBTextureBaker", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

extension MeshScanModel {
    func bakeRGBTextureAtlas() {
        guard phase == .finished,
              mode == .lidar,
              frameCount >= 8,
              let sourceURL = rawOBJURL ?? resultURL,
              sourceURL.pathExtension.lowercased() == "obj" else {
            statusMessage = "RGBテクスチャ生成にはLiDAR OBJと撮影フレームが必要です"
            return
        }
        guard !sourceURL.lastPathComponent.contains("textured") else { return }

        phase = .reconstructing
        reconstructionProgress = 0.08
        statusMessage = "撮影したRGB画像を実寸Meshへ投影しています"

        Task { [weak self] in
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try MeshRGBTextureBaker.bake(sourceOBJURL: sourceURL)
                }.value
                guard let self else { return }
                self.resultURL = result.objURL
                self.previewScene = try? SCNScene(url: result.objURL, options: nil)
                self.reconstructionProgress = 1
                self.phase = .finished
                self.statusMessage = String(
                    format: "RGBテクスチャMesh生成完了：%.0f%%の面を%d枚の画像から投影（%dpx atlas）",
                    result.coverage * 100,
                    result.selectedFrameCount,
                    result.atlasSize
                )
                try? self.persistExporterMeshAssetContract()
            } catch {
                guard let self else { return }
                self.reconstructionProgress = 1
                self.phase = .finished
                self.statusMessage = "形状Meshは保持しました。RGBテクスチャ処理のみ失敗: \(error.localizedDescription)"
            }
        }
    }
}
