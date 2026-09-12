@preconcurrency import ARKit
import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import SceneKit
import SwiftUI
import UIKit
import simd

private struct DenseMVSRecord: Codable, Sendable {
    let filePath: String
    let timestamp: TimeInterval
    let transform: [[Float]]
    let intrinsics: [[Float]]
    let width: Int
    let height: Int
}

private struct DenseMVSManifest: Codable, Sendable {
    let schemaVersion: Int
    let source: String
    let createdAt: Date
    let maximumRangeMeters: Float
    let frames: [DenseMVSRecord]
}

private struct DenseGray: Sendable {
    let pixels: [UInt8]
    let width: Int
    let height: Int

    func sample(_ x: Float, _ y: Float) -> Float? {
        let ix = Int(x.rounded())
        let iy = Int(y.rounded())
        guard ix >= 0, iy >= 0, ix < width, iy < height else { return nil }
        return Float(pixels[iy * width + ix])
    }
}

private struct DenseMVSFrame: Sendable {
    let gray: DenseGray
    let cameraToWorld: simd_float4x4
    let worldToCamera: simd_float4x4
    let fx: Float
    let fy: Float
    let cx: Float
    let cy: Float
    let position: SIMD3<Float>
    let forward: SIMD3<Float>
}

private struct DenseMVSResult: Sendable {
    let url: URL
    let vertices: Int
    let faces: Int
    let keyframes: Int
}

private enum MeshPlaneSweepMVS {
    static func reconstruct(project: URL, manifest: DenseMVSManifest) throws -> DenseMVSResult {
        let records = selectFrames(manifest.frames, maximumCount: 14)
        let maximumPixel = ProcessInfo.processInfo.physicalMemory >= 6_000_000_000 ? 224 : 176
        var frames: [DenseMVSFrame] = []
        for record in records {
            if let frame = load(record, project: project, maximumPixel: maximumPixel) {
                frames.append(frame)
            }
        }
        guard frames.count >= 5 else {
            throw error("MVSに必要な有効画像が5枚未満です")
        }

        let references = referenceIndices(frames.count, maximumCount: 6)
        var vertices: [SIMD3<Float>] = []
        var faces: [SIMD3<Int>] = []

        for referenceIndex in references {
            let reference = frames[referenceIndex]
            let neighbors = neighborIndices(referenceIndex: referenceIndex, frames: frames)
            guard neighbors.count >= 2 else { continue }

            let pixelStride = 2
            let border = 5
            let columns = max(0, (reference.gray.width - border * 2) / pixelStride)
            let rows = max(0, (reference.gray.height - border * 2) / pixelStride)
            guard columns > 2, rows > 2 else { continue }

            var grid = [Int?](repeating: nil, count: columns * rows)
            let nearDepth: Float = 0.12
            let farDepth = min(max(0.45, manifest.maximumRangeMeters), 2.8)
            let hypothesisCount = 30

            for gridY in 0..<rows {
                for gridX in 0..<columns {
                    let u = Float(border + gridX * pixelStride)
                    let v = Float(border + gridY * pixelStride)
                    var bestCost = Float.greatestFiniteMagnitude
                    var secondCost = Float.greatestFiniteMagnitude
                    var bestDepth: Float = 0

                    for hypothesis in 0..<hypothesisCount {
                        let t = Float(hypothesis) / Float(hypothesisCount - 1)
                        let inverseDepth = (1 / nearDepth) * (1 - t) + (1 / farDepth) * t
                        let depth = 1 / inverseDepth
                        guard let cost = patchCost(
                            u: u,
                            v: v,
                            depth: depth,
                            reference: reference,
                            neighborIndices: neighbors,
                            frames: frames
                        ) else { continue }

                        if cost < bestCost {
                            secondCost = bestCost
                            bestCost = cost
                            bestDepth = depth
                        } else if cost < secondCost {
                            secondCost = cost
                        }
                    }

                    guard bestDepth > 0,
                          bestCost < 34,
                          secondCost.isFinite,
                          secondCost - bestCost > 3.5 else { continue }

                    let world = backproject(u: u, v: v, depth: bestDepth, frame: reference)
                    let index = vertices.count
                    vertices.append(world)
                    grid[gridY * columns + gridX] = index
                }
            }

            func edgeIsConsistent(_ a: Int, _ b: Int) -> Bool {
                let pa = vertices[a]
                let pb = vertices[b]
                let averageDepth = max(
                    0.1,
                    (simd_distance(pa, reference.position) + simd_distance(pb, reference.position)) / 2
                )
                return simd_distance(pa, pb) < max(0.045, averageDepth * 0.085)
            }

            for y in 0..<(rows - 1) {
                for x in 0..<(columns - 1) {
                    let i = y * columns + x
                    guard let a = grid[i],
                          let b = grid[i + 1],
                          let c = grid[i + columns],
                          let d = grid[i + columns + 1] else { continue }
                    if edgeIsConsistent(a, b),
                       edgeIsConsistent(a, c),
                       edgeIsConsistent(b, d),
                       edgeIsConsistent(c, d) {
                        faces.append(SIMD3<Int>(a, b, c))
                        faces.append(SIMD3<Int>(b, d, c))
                    }
                }
            }
        }

        guard vertices.count >= 500, faces.count >= 500 else {
            throw error("MVS対応点が不足しました。模様のある対象をゆっくり全周撮影してください")
        }

        let outputURL = project.appendingPathComponent("visual-dense-mvs.obj")
        var output = "# Scan Lab ARKit-pose plane-sweep dense MVS\n"
        output += "# keyframes \(references.count) vertices \(vertices.count) faces \(faces.count)\n"
        for point in vertices {
            output += "v \(point.x) \(point.y) \(point.z)\n"
        }
        for face in faces {
            output += "f \(face.x + 1) \(face.y + 1) \(face.z + 1)\n"
        }
        try output.write(to: outputURL, atomically: true, encoding: .utf8)
        return DenseMVSResult(url: outputURL, vertices: vertices.count, faces: faces.count, keyframes: references.count)
    }

    private static func patchCost(
        u: Float,
        v: Float,
        depth: Float,
        reference: DenseMVSFrame,
        neighborIndices: [Int],
        frames: [DenseMVSFrame]
    ) -> Float? {
        let offsets: [Float] = [-2, 0, 2]
        var total: Float = 0
        var samples = 0
        for dy in offsets {
            for dx in offsets {
                guard let referenceValue = reference.gray.sample(u + dx, v + dy) else { continue }
                let world = backproject(u: u + dx, v: v + dy, depth: depth, frame: reference)
                for neighborIndex in neighborIndices {
                    let neighbor = frames[neighborIndex]
                    guard let pixel = project(world, frame: neighbor),
                          let neighborValue = neighbor.gray.sample(pixel.x, pixel.y) else { continue }
                    total += abs(neighborValue - referenceValue)
                    samples += 1
                }
            }
        }
        guard samples >= max(12, neighborIndices.count * 5) else { return nil }
        return total / Float(samples)
    }

    private static func load(_ record: DenseMVSRecord, project: URL, maximumPixel: Int) -> DenseMVSFrame? {
        guard record.transform.count == 4,
              record.transform.allSatisfy({ $0.count == 4 }),
              record.intrinsics.count == 3,
              record.intrinsics.allSatisfy({ $0.count == 3 }) else { return nil }
        let fileURL = project.appendingPathComponent(record.filePath)
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: maximumPixel,
                    kCGImageSourceCreateThumbnailWithTransform: false
                ] as CFDictionary
              ) else { return nil }

        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let cameraToWorld = matrix(record.transform)
        let position = SIMD3<Float>(
            cameraToWorld.columns.3.x,
            cameraToWorld.columns.3.y,
            cameraToWorld.columns.3.z
        )
        let forwardRaw = SIMD3<Float>(
            -cameraToWorld.columns.2.x,
            -cameraToWorld.columns.2.y,
            -cameraToWorld.columns.2.z
        )
        let forward = simd_length_squared(forwardRaw) > 1e-8
            ? simd_normalize(forwardRaw)
            : SIMD3<Float>(0, 0, -1)
        let scaleX = Float(width) / Float(max(1, record.width))
        let scaleY = Float(height) / Float(max(1, record.height))

        return DenseMVSFrame(
            gray: DenseGray(pixels: pixels, width: width, height: height),
            cameraToWorld: cameraToWorld,
            worldToCamera: simd_inverse(cameraToWorld),
            fx: record.intrinsics[0][0] * scaleX,
            fy: record.intrinsics[1][1] * scaleY,
            cx: record.intrinsics[0][2] * scaleX,
            cy: record.intrinsics[1][2] * scaleY,
            position: position,
            forward: forward
        )
    }

    private static func selectFrames(_ frames: [DenseMVSRecord], maximumCount: Int) -> [DenseMVSRecord] {
        guard frames.count > maximumCount else { return frames }
        return (0..<maximumCount).map { index in
            let sourceIndex = Int(
                (Double(index) * Double(frames.count - 1) / Double(maximumCount - 1)).rounded()
            )
            return frames[sourceIndex]
        }
    }

    private static func referenceIndices(_ count: Int, maximumCount: Int) -> [Int] {
        let selectedCount = min(maximumCount, count)
        guard selectedCount > 1 else { return count > 0 ? [0] : [] }
        return (0..<selectedCount).map { index in
            Int((Double(index) * Double(count - 1) / Double(selectedCount - 1)).rounded())
        }
    }

    private static func neighborIndices(referenceIndex: Int, frames: [DenseMVSFrame]) -> [Int] {
        let reference = frames[referenceIndex]
        let candidates: [(index: Int, score: Float)] = frames.indices.compactMap { index in
            guard index != referenceIndex else { return nil }
            let baseline = simd_distance(reference.position, frames[index].position)
            let directionDot = simd_dot(reference.forward, frames[index].forward)
            guard baseline >= 0.025, baseline <= 0.75, directionDot > 0.50 else { return nil }
            let score = abs(baseline - 0.16) + (1 - directionDot) * 0.12
            return (index, score)
        }
        return candidates.sorted { $0.score < $1.score }.prefix(4).map(\.index)
    }

    private static func backproject(u: Float, v: Float, depth: Float, frame: DenseMVSFrame) -> SIMD3<Float> {
        let x = (u - frame.cx) / frame.fx * depth
        let y = -(v - frame.cy) / frame.fy * depth
        let cameraPoint = SIMD4<Float>(x, y, -depth, 1)
        let world = frame.cameraToWorld * cameraPoint
        return SIMD3<Float>(world.x, world.y, world.z)
    }

    private static func project(_ point: SIMD3<Float>, frame: DenseMVSFrame) -> SIMD2<Float>? {
        let camera = frame.worldToCamera * SIMD4<Float>(point.x, point.y, point.z, 1)
        let depth = -camera.z
        guard depth > 0.05 else { return nil }
        let x = frame.cx + frame.fx * camera.x / depth
        let y = frame.cy - frame.fy * camera.y / depth
        guard x >= 2,
              y >= 2,
              x < Float(frame.gray.width - 2),
              y < Float(frame.gray.height - 2) else { return nil }
        return SIMD2<Float>(x, y)
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
        NSError(domain: "ScanLab.DenseMVS", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

@MainActor
final class MeshDenseVisualRecorder: ObservableObject {
    private var projectURL: URL?
    private var imagesURL: URL?
    private var frames: [DenseMVSRecord] = []
    private var lastSavedTimestamp: TimeInterval = -.greatestFiniteMagnitude
    private let ciContext = CIContext(options: [.cacheIntermediates: false])
    private var maximumRange: Float = 2.75

    var isRecording: Bool { projectURL != nil }
    var frameCount: Int { frames.count }
    var canFinish: Bool { frames.count >= 32 }

    func start(size: MeshScanSize) throws {
        discard()
        maximumRange = size.maximumRangeMeters
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let root = documents.appendingPathComponent("SplatLab", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let project = root.appendingPathComponent(UUID().uuidString + ".meshproject", isDirectory: true)
        let images = project.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        projectURL = project
        imagesURL = images
        frames.removeAll(keepingCapacity: true)
        lastSavedTimestamp = -.greatestFiniteMagnitude
    }

    func record(_ frame: ARFrame) {
        guard case .normal = frame.camera.trackingState,
              frame.timestamp - lastSavedTimestamp >= 0.42,
              let imagesURL else { return }
        let image = CIImage(cvPixelBuffer: frame.capturedImage)
        guard let cgImage = ciContext.createCGImage(image, from: image.extent),
              let jpeg = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.92) else { return }
        let fileName = String(format: "mvs_%05d.jpg", frames.count)
        let fileURL = imagesURL.appendingPathComponent(fileName)
        do {
            try jpeg.write(to: fileURL, options: .atomic)
            let resolution = frame.camera.imageResolution
            frames.append(DenseMVSRecord(
                filePath: "images/\(fileName)",
                timestamp: frame.timestamp,
                transform: Self.rows(frame.camera.transform),
                intrinsics: Self.rows3(frame.camera.intrinsics),
                width: Int(resolution.width),
                height: Int(resolution.height)
            ))
            lastSavedTimestamp = frame.timestamp
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    func finish(model: MeshScanModel) async {
        guard let projectURL else {
            model.phase = .failed("MVS保存先がありません")
            return
        }
        let manifest = DenseMVSManifest(
            schemaVersion: 2,
            source: "ARKit pose-guided plane-sweep MVS",
            createdAt: Date(),
            maximumRangeMeters: maximumRange,
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
            model.phase = .failed("MVS raw索引保存失敗: \(error.localizedDescription)")
            return
        }

        model.phase = .reconstructing
        model.reconstructionProgress = 0.18
        model.statusMessage = "既知のARKit姿勢を使って画像間対応を探索し、高密度Depthを再構築しています"
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try MeshPlaneSweepMVS.reconstruct(project: projectURL, manifest: manifest)
            }.value
            model.rawOBJURL = result.url
            model.resultURL = result.url
            model.previewScene = try? SCNScene(url: result.url, options: nil)
            model.vertexCount = result.vertices
            model.faceCount = result.faces
            model.reconstructionProgress = 1
            model.phase = .finished
            model.statusMessage = "非LiDAR dense MVS：\(result.keyframes)視点から\(result.faces.formatted())面を生成"
            releaseCompletedProject()
        } catch {
            model.phase = .failed("非LiDAR dense MVSに失敗: \(error.localizedDescription)")
        }
    }

    func discard() {
        if let projectURL { try? FileManager.default.removeItem(at: projectURL) }
        releaseCompletedProject()
    }

    private func releaseCompletedProject() {
        projectURL = nil
        imagesURL = nil
        frames.removeAll()
        lastSavedTimestamp = -.greatestFiniteMagnitude
    }

    nonisolated private static func rows(_ matrix: simd_float4x4) -> [[Float]] {
        (0..<4).map { row in (0..<4).map { column in matrix[column][row] } }
    }

    nonisolated private static func rows3(_ matrix: simd_float3x3) -> [[Float]] {
        (0..<3).map { row in (0..<3).map { column in matrix[column][row] } }
    }
}

@MainActor
struct MeshDenseVisualFallbackOverlay: View {
    @EnvironmentObject var model: MeshScanModel
    @StateObject private var recorder = MeshDenseVisualRecorder()

    private var needed: Bool {
        !model.supportsLiDARMesh && !model.supportsPhotogrammetry
    }

    var body: some View {
        ZStack {
            if needed && model.phase == .ready {
                VStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Text("非LiDAR Dense Mesh").font(.headline)
                        Text("ARKitの実カメラ姿勢を固定し、複数画像のplane-sweep stereoでDepthを推定します。特徴点ボクセルだけの旧経路より高密度です。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Dense Meshを開始") { start() }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(16)
                    .background(.black.opacity(0.95), in: RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
            }

            if needed && recorder.isRecording && model.phase == .scanning {
                VStack {
                    Spacer()
                    VStack(spacing: 9) {
                        Text("非LiDAR Dense撮影中").font(.subheadline.bold())
                        Text("写真 \(recorder.frameCount) / 32+").monospacedDigit()
                        Text(recorder.canFinish
                             ? "生成可能。細部用に上下・斜めも追加すると有利です"
                             : "対象の全周を、重なりを保ちながらゆっくり撮影してください")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        if recorder.canFinish {
                            Button("Dense Meshを生成") {
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
        .task(id: model.phase) {
            guard needed, model.phase == .scanning, recorder.isRecording else { return }
            while !Task.isCancelled && model.phase == .scanning && recorder.isRecording {
                if let frame = model.session?.currentFrame {
                    recorder.record(frame)
                    model.frameCount = recorder.frameCount
                    model.statusMessage = recorder.canFinish ? "Dense MVS生成可能" : "Dense MVS用RGB＋pose収集中"
                }
                try? await Task.sleep(for: .milliseconds(220))
            }
        }
        .onChange(of: model.phase) { _, phase in
            if phase == .ready && recorder.isRecording { recorder.discard() }
        }
    }

    private func start() {
        guard ARWorldTrackingConfiguration.isSupported, let session = model.session else {
            model.phase = .failed("ARKit World Tracking非対応です")
            return
        }
        do {
            try recorder.start(size: model.scanSize)
        } catch {
            model.phase = .failed("Dense MVS保存準備失敗: \(error.localizedDescription)")
            return
        }
        model.mode = .photogrammetry
        model.frameCount = 0
        model.vertexCount = 0
        model.faceCount = 0
        model.resultURL = nil
        model.rawOBJURL = nil
        model.previewScene = nil
        model.phase = .scanning

        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.isLightEstimationEnabled = true
        configuration.environmentTexturing = .automatic
        configuration.planeDetection = [.horizontal, .vertical]
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
}
