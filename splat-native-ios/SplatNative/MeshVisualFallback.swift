@preconcurrency import ARKit
import CoreImage
import Foundation
import SceneKit
import SwiftUI
import UIKit
import simd

private struct VisualVoxelKey: Hashable, Codable, Sendable {
    let x: Int
    let y: Int
    let z: Int
}

private struct VisualGridVertex: Hashable, Sendable {
    let x: Int
    let y: Int
    let z: Int
}

private struct VisualMeshFrameRecord: Codable, Sendable {
    let filePath: String
    let timestamp: TimeInterval
    let transform: [[Float]]
    let intrinsics: [[Float]]
    let width: Int
    let height: Int
}

private struct VisualMeshManifest: Codable, Sendable {
    let schemaVersion: Int
    let source: String
    let createdAt: Date
    let voxelSizeMeters: Float
    let maximumRangeMeters: Float
    let stableVoxelCount: Int
    let frames: [VisualMeshFrameRecord]
}

private struct VisualMeshBuildResult: Sendable {
    let url: URL
    let vertexCount: Int
    let faceCount: Int
}

@MainActor
final class MeshVisualFallbackRecorder: ObservableObject {
    private var projectURL: URL?
    private var imagesURL: URL?
    private var voxelSize: Float = 0.035
    private var maximumRange: Float = 2.75
    private var scanOrigin: SIMD3<Float>?
    private var observations: [VisualVoxelKey: Int] = [:]
    private var frames: [VisualMeshFrameRecord] = []
    private var lastSavedImageTimestamp: TimeInterval = -1
    private var lastFeatureTimestamp: TimeInterval = -1
    private let ciContext = CIContext(options: [.cacheIntermediates: false])

    var isRecording: Bool { projectURL != nil }
    var frameCount: Int { frames.count }
    var stableVoxelCount: Int { observations.values.reduce(0) { $0 + ($1 >= 3 ? 1 : 0) } }
    var canFinish: Bool { frameCount >= 16 && stableVoxelCount >= 48 }

    func start(size: MeshScanSize) throws {
        discard()
        switch size {
        case .small:
            voxelSize = 0.018
        case .medium:
            voxelSize = 0.035
        case .large:
            voxelSize = 0.07
        }
        maximumRange = size.maximumRangeMeters

        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let root = documents.appendingPathComponent("SplatLab", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let project = root.appendingPathComponent("\(UUID().uuidString).meshproject", isDirectory: true)
        let images = project.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        projectURL = project
        imagesURL = images
        observations.removeAll(keepingCapacity: true)
        frames.removeAll(keepingCapacity: true)
        scanOrigin = nil
        lastSavedImageTimestamp = -1
        lastFeatureTimestamp = -1
    }

    func record(frame: ARFrame) {
        guard projectURL != nil else { return }
        let cameraPosition = SIMD3<Float>(
            frame.camera.transform.columns.3.x,
            frame.camera.transform.columns.3.y,
            frame.camera.transform.columns.3.z
        )
        if scanOrigin == nil { scanOrigin = cameraPosition }

        if frame.timestamp - lastFeatureTimestamp >= 0.20,
           let origin = scanOrigin,
           let cloud = frame.rawFeaturePoints {
            var frameKeys = Set<VisualVoxelKey>()
            frameKeys.reserveCapacity(cloud.points.count)
            for point in cloud.points {
                guard simd_distance(point, origin) <= maximumRange else { continue }
                frameKeys.insert(VisualVoxelKey(
                    x: Int(floor(point.x / voxelSize)),
                    y: Int(floor(point.y / voxelSize)),
                    z: Int(floor(point.z / voxelSize))
                ))
            }
            for key in frameKeys {
                observations[key, default: 0] = min(255, observations[key, default: 0] + 1)
            }
            lastFeatureTimestamp = frame.timestamp
        }

        guard frame.timestamp - lastSavedImageTimestamp >= 0.70,
              let imagesURL else { return }
        let image = CIImage(cvPixelBuffer: frame.capturedImage)
        guard let cgImage = ciContext.createCGImage(image, from: image.extent),
              let jpeg = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.90) else { return }

        let fileName = String(format: "visual_%05d.jpg", frames.count)
        let fileURL = imagesURL.appendingPathComponent(fileName)
        do {
            try jpeg.write(to: fileURL, options: .atomic)
            let resolution = frame.camera.imageResolution
            frames.append(VisualMeshFrameRecord(
                filePath: "images/\(fileName)",
                timestamp: frame.timestamp,
                transform: Self.rows(frame.camera.transform),
                intrinsics: Self.rows3(frame.camera.intrinsics),
                width: Int(resolution.width),
                height: Int(resolution.height)
            ))
            lastSavedImageTimestamp = frame.timestamp
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    func finish(model: MeshScanModel) async {
        guard let projectURL else {
            model.phase = .failed("非LiDAR Meshのraw保存先がありません。")
            return
        }

        let stable = observations.filter { $0.value >= 3 }.map(\.key)
        guard stable.count >= 48 else {
            model.phase = .failed("複数フレームで追跡できた3D特徴点が不足しています。模様や角のある対象を複数方向から撮影してください。")
            return
        }

        let manifest = VisualMeshManifest(
            schemaVersion: 1,
            source: "ARKit rawFeaturePoints cross-frame voxel surface",
            createdAt: Date(),
            voxelSizeMeters: voxelSize,
            maximumRangeMeters: maximumRange,
            stableVoxelCount: stable.count,
            frames: frames
        )
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(manifest).write(
                to: projectURL.appendingPathComponent("mesh-project.json"),
                options: .atomic
            )
        } catch {
            model.phase = .failed("非LiDAR Meshのraw索引を保存できませんでした: \(error.localizedDescription)")
            return
        }

        let size = voxelSize
        model.phase = .reconstructing
        model.reconstructionProgress = 0.25
        model.statusMessage = "複数フレームで安定した3D特徴点から実寸ボクセル表面を生成しています"

        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try Self.buildSurface(voxels: Set(stable), voxelSize: size, projectURL: projectURL)
            }.value
            model.rawOBJURL = result.url
            model.resultURL = result.url
            model.previewScene = try? SCNScene(url: result.url, options: nil)
            model.vertexCount = result.vertexCount
            model.faceCount = result.faceCount
            model.reconstructionProgress = 1
            model.phase = .finished
            model.statusMessage = "非LiDAR Visual Meshを生成しました。高密度MVSではないため品質監査対象です"
            releaseCompletedProject()
        } catch {
            model.phase = .failed("非LiDAR Visual Meshを生成できませんでした: \(error.localizedDescription)")
        }
    }

    func discard() {
        if let projectURL {
            try? FileManager.default.removeItem(at: projectURL)
        }
        clearInMemoryState()
    }

    private func releaseCompletedProject() {
        clearInMemoryState()
    }

    private func clearInMemoryState() {
        projectURL = nil
        imagesURL = nil
        observations.removeAll()
        frames.removeAll()
        scanOrigin = nil
        lastSavedImageTimestamp = -1
        lastFeatureTimestamp = -1
    }

    nonisolated private static func buildSurface(
        voxels: Set<VisualVoxelKey>,
        voxelSize: Float,
        projectURL: URL
    ) throws -> VisualMeshBuildResult {
        guard !voxels.isEmpty else {
            throw NSError(domain: "ScanLab.VisualMesh", code: 1, userInfo: [NSLocalizedDescriptionKey: "安定ボクセルがありません"])
        }

        var vertexMap: [VisualGridVertex: Int] = [:]
        var vertices: [SIMD3<Float>] = []
        var faces: [SIMD3<Int>] = []

        func vertexIndex(_ key: VisualGridVertex) -> Int {
            if let existing = vertexMap[key] { return existing }
            let index = vertices.count
            vertexMap[key] = index
            vertices.append(SIMD3<Float>(
                Float(key.x) * voxelSize,
                Float(key.y) * voxelSize,
                Float(key.z) * voxelSize
            ))
            return index
        }

        func addQuad(_ a: VisualGridVertex, _ b: VisualGridVertex, _ c: VisualGridVertex, _ d: VisualGridVertex) {
            let ia = vertexIndex(a)
            let ib = vertexIndex(b)
            let ic = vertexIndex(c)
            let id = vertexIndex(d)
            faces.append(SIMD3<Int>(ia, ib, ic))
            faces.append(SIMD3<Int>(ia, ic, id))
        }

        for v in voxels {
            let x = v.x, y = v.y, z = v.z
            if !voxels.contains(VisualVoxelKey(x: x + 1, y: y, z: z)) {
                addQuad(
                    VisualGridVertex(x: x + 1, y: y, z: z),
                    VisualGridVertex(x: x + 1, y: y + 1, z: z),
                    VisualGridVertex(x: x + 1, y: y + 1, z: z + 1),
                    VisualGridVertex(x: x + 1, y: y, z: z + 1)
                )
            }
            if !voxels.contains(VisualVoxelKey(x: x - 1, y: y, z: z)) {
                addQuad(
                    VisualGridVertex(x: x, y: y, z: z),
                    VisualGridVertex(x: x, y: y, z: z + 1),
                    VisualGridVertex(x: x, y: y + 1, z: z + 1),
                    VisualGridVertex(x: x, y: y + 1, z: z)
                )
            }
            if !voxels.contains(VisualVoxelKey(x: x, y: y + 1, z: z)) {
                addQuad(
                    VisualGridVertex(x: x, y: y + 1, z: z),
                    VisualGridVertex(x: x, y: y + 1, z: z + 1),
                    VisualGridVertex(x: x + 1, y: y + 1, z: z + 1),
                    VisualGridVertex(x: x + 1, y: y + 1, z: z)
                )
            }
            if !voxels.contains(VisualVoxelKey(x: x, y: y - 1, z: z)) {
                addQuad(
                    VisualGridVertex(x: x, y: y, z: z),
                    VisualGridVertex(x: x + 1, y: y, z: z),
                    VisualGridVertex(x: x + 1, y: y, z: z + 1),
                    VisualGridVertex(x: x, y: y, z: z + 1)
                )
            }
            if !voxels.contains(VisualVoxelKey(x: x, y: y, z: z + 1)) {
                addQuad(
                    VisualGridVertex(x: x, y: y, z: z + 1),
                    VisualGridVertex(x: x + 1, y: y, z: z + 1),
                    VisualGridVertex(x: x + 1, y: y + 1, z: z + 1),
                    VisualGridVertex(x: x, y: y + 1, z: z + 1)
                )
            }
            if !voxels.contains(VisualVoxelKey(x: x, y: y, z: z - 1)) {
                addQuad(
                    VisualGridVertex(x: x, y: y, z: z),
                    VisualGridVertex(x: x, y: y + 1, z: z),
                    VisualGridVertex(x: x + 1, y: y + 1, z: z),
                    VisualGridVertex(x: x + 1, y: y, z: z)
                )
            }
        }

        guard !faces.isEmpty else {
            throw NSError(domain: "ScanLab.VisualMesh", code: 2, userInfo: [NSLocalizedDescriptionKey: "表面三角形を生成できませんでした"])
        }

        let outputURL = projectURL.appendingPathComponent("visual-mesh.obj")
        var output = "# Scan Lab non-LiDAR visual feature voxel mesh\n"
        output += "# voxel_size_m \(voxelSize)\n"
        output += "# vertices \(vertices.count) faces \(faces.count)\n"
        for p in vertices {
            output += "v \(p.x) \(p.y) \(p.z)\n"
        }
        for f in faces {
            output += "f \(f.x + 1) \(f.y + 1) \(f.z + 1)\n"
        }
        try output.write(to: outputURL, atomically: true, encoding: .utf8)
        return VisualMeshBuildResult(url: outputURL, vertexCount: vertices.count, faceCount: faces.count)
    }

    private static func rows(_ matrix: simd_float4x4) -> [[Float]] {
        (0..<4).map { row in (0..<4).map { column in matrix[column][row] } }
    }

    private static func rows3(_ matrix: simd_float3x3) -> [[Float]] {
        (0..<3).map { row in (0..<3).map { column in matrix[column][row] } }
    }
}

@MainActor
struct MeshVisualFallbackOverlay: View {
    @EnvironmentObject var model: MeshScanModel
    @StateObject private var recorder = MeshVisualFallbackRecorder()

    private var needsFallback: Bool {
        !model.supportsLiDARMesh && !model.supportsPhotogrammetry
    }

    var body: some View {
        ZStack {
            if needsFallback && model.phase == .ready {
                VStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Text("非LiDAR Visual Mesh")
                            .font(.headline)
                        Text("Apple Object Capture非対応端末では、ARKitの実3D特徴点から粗い実寸Meshを生成します。高密度Meshではありません。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Visual Meshを開始") {
                            startFallback()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(16)
                    .background(.black.opacity(0.94), in: RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
            }

            if needsFallback && recorder.isRecording && model.phase == .scanning {
                VStack {
                    Spacer()
                    VStack(spacing: 9) {
                        Text("非LiDAR Visual Mesh撮影中")
                            .font(.subheadline.bold())
                        HStack {
                            metric("写真", "\(recorder.frameCount)")
                            metric("安定3D点", "\(recorder.stableVoxelCount)")
                        }
                        Text(recorder.canFinish
                             ? "生成可能です。欠ける面がある場合はさらに角度を変えて撮影してください。"
                             : "模様・角のある対象を、重なりを保ちながら複数方向から撮影してください。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        if recorder.canFinish {
                            Button("Visual Meshを生成") {
                                model.session?.pause()
                                Task { await recorder.finish(model: model) }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                    }
                    .padding(16)
                    .background(.black.opacity(0.95), in: RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
            }
        }
        .onChange(of: model.phase) { _, newPhase in
            if newPhase == .ready && recorder.isRecording {
                recorder.discard()
            }
        }
        .task(id: model.phase) {
            guard needsFallback, model.phase == .scanning, recorder.isRecording else { return }
            while !Task.isCancelled && model.phase == .scanning && recorder.isRecording {
                if let frame = model.session?.currentFrame {
                    recorder.record(frame: frame)
                    model.frameCount = recorder.frameCount
                    model.vertexCount = recorder.stableVoxelCount
                    model.faceCount = 0
                    model.statusMessage = recorder.canFinish
                        ? "非LiDAR Visual Meshを生成できます"
                        : "非LiDAR Visual Mesh用の3D特徴点を収集中"
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func startFallback() {
        guard ARWorldTrackingConfiguration.isSupported, let session = model.session else {
            model.phase = .failed("この端末ではARKit World Trackingを利用できません。")
            return
        }
        do {
            try recorder.start(size: model.scanSize)
        } catch {
            model.phase = .failed("非LiDAR Mesh保存領域を準備できませんでした: \(error.localizedDescription)")
            return
        }

        model.mode = .photogrammetry
        model.frameCount = 0
        model.vertexCount = 0
        model.faceCount = 0
        model.reconstructionProgress = 0
        model.resultURL = nil
        model.rawOBJURL = nil
        model.previewScene = nil
        model.phase = .scanning
        model.statusMessage = "ARKitの実3D特徴点を収集中"

        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.isLightEstimationEnabled = true
        configuration.environmentTexturing = .automatic
        configuration.planeDetection = [.horizontal, .vertical]
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline.monospacedDigit())
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
