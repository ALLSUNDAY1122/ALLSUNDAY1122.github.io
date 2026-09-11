@preconcurrency import ARKit
import Combine
import Foundation
@preconcurrency import Metal
import RealityKit
import SceneKit
import SwiftUI
import UIKit

private struct MeshChunk: Sendable {
    let id: UUID
    let vertices: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let triangles: [SIMD3<UInt32>]
}

private struct MergedMesh: Sendable {
    var vertices: [SIMD3<Float>]
    var normals: [SIMD3<Float>]
    var triangles: [SIMD3<UInt32>]

    var isEmpty: Bool { vertices.isEmpty || triangles.isEmpty }
}

private struct MeshCapturedFrame: Codable, Sendable {
    let imageFile: String
    let timestamp: TimeInterval
    let transform: [[Float]]
    let intrinsics: [[Float]]
    let width: Int
    let height: Int
}

private struct MeshCaptureManifest: Codable, Sendable {
    let schemaVersion: Int
    let mode: String
    let scanSize: String
    let capturedAt: Date
    let frames: [MeshCapturedFrame]
    let texturedModelAvailable: Bool
}

enum MeshCaptureMode: String, CaseIterable, Identifiable {
    case lidar
    case photogrammetry

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lidar: return "LiDARメッシュ"
        case .photogrammetry: return "写真からメッシュ"
        }
    }

    var subtitle: String {
        switch self {
        case .lidar: return "部屋・家具・実寸計測向け"
        case .photogrammetry: return "対象物・高精細テクスチャ向け"
        }
    }
}

enum MeshScanSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: return "小物"
        case .medium: return "家具"
        case .large: return "空間"
        }
    }

    var maximumRangeMeters: Float {
        switch self {
        case .small: return 0.9
        case .medium: return 2.4
        case .large: return 6.0
        }
    }
}

@MainActor
final class MeshScanModel: NSObject, ObservableObject, ARSessionDelegate {
    enum Phase: Equatable {
        case ready
        case scanning
        case captured
        case reconstructing
        case finished
        case failed(String)
    }

    @Published var phase: Phase = .ready
    @Published var mode: MeshCaptureMode = .lidar
    @Published var scanSize: MeshScanSize = .medium
    @Published var statusMessage = "Meshモードを選んでください"
    @Published var frameCount = 0
    @Published var vertexCount = 0
    @Published var faceCount = 0
    @Published var reconstructionProgress: Double = 0
    @Published var resultURL: URL?
    @Published var rawOBJURL: URL?
    @Published var previewScene: SCNScene?
    @Published var cropInset: Double = 0
    @Published var measuredDistanceMeters: Float?
    @Published var invalidPhotogrammetrySamples = 0
    @Published private(set) var destructiveResetBlockedReason: String?

    let supportsLiDARMesh = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    let supportsPhotogrammetry = PhotogrammetrySession.isSupported

    private(set) var session: ARSession?
    private var projectURL: URL?
    private var imagesURL: URL?
    private var frames: [MeshCapturedFrame] = []
    private var meshChunks: [UUID: MeshChunk] = [:]
    private var sourceMesh: MergedMesh?
    private var scanOrigin: SIMD3<Float>?
    private var lastSavedFrameTimestamp: TimeInterval = 0
    private var isWritingFrame = false
    private let frameEncoder = MeshFrameJPEGEncoder()
    private let captureQueue = DispatchQueue(label: "jp.allsunday1122.splatlab.mesh.capture", qos: .userInitiated)
    private var reconstructionTask: Task<Void, Never>?
    private var photogrammetrySession: PhotogrammetrySession?

    var canFinish: Bool {
        switch mode {
        case .lidar:
            return phase == .scanning && faceCount >= 300 && frameCount >= 12 && !isWritingFrame
        case .photogrammetry:
            return phase == .scanning && frameCount >= 24 && !isWritingFrame
        }
    }

    var capabilitySummary: String {
        if supportsLiDARMesh && supportsPhotogrammetry {
            return "LiDAR実メッシュと端末内テクスチャ再構築に対応"
        }
        if supportsLiDARMesh {
            return "LiDAR実メッシュに対応"
        }
        if supportsPhotogrammetry {
            return "端末内フォトグラメトリに対応"
        }
        return "Apple標準のMesh再構築対象外端末"
    }

    func attach(session: ARSession) {
        guard self.session !== session else { return }
        self.session = session
        session.delegate = self
    }

    func select(mode: MeshCaptureMode) {
        guard phase == .ready else { return }
        self.mode = mode
    }

    func start() {
        guard let session else { return }

        switch mode {
        case .lidar:
            guard supportsLiDARMesh else {
                phase = .failed("この端末はARKitのLiDARシーンメッシュに対応していません。写真ベースのMesh経路を使用してください。")
                return
            }
        case .photogrammetry:
            guard supportsPhotogrammetry else {
                phase = .failed("この端末ではAppleの端末内PhotogrammetrySessionを使用できません。非LiDAR端末向け独自再構築経路が必要です。")
                return
            }
        }

        do {
            try prepareProject()
        } catch {
            phase = .failed("Mesh保存領域を準備できませんでした: \(error.localizedDescription)")
            return
        }

        resetCaptureStateKeepingProject()
        phase = .scanning
        UIApplication.shared.isIdleTimerDisabled = true

        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.isLightEstimationEnabled = true
        configuration.environmentTexturing = .automatic
        configuration.planeDetection = [.horizontal, .vertical]

        if mode == .lidar {
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
                configuration.sceneReconstruction = .meshWithClassification
            } else {
                configuration.sceneReconstruction = .mesh
            }
            statusMessage = "ゆっくり移動し、面が埋まるまで対象を複数方向から撮影してください"
        } else {
            statusMessage = "対象の周囲を1周し、高さを変えて重なる写真を十分に撮影してください"
        }

        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    func finish() {
        guard canFinish else { return }
        session?.pause()
        UIApplication.shared.isIdleTimerDisabled = false
        phase = .captured

        do {
            try writeManifest(texturedModelAvailable: false)
        } catch {
            phase = .failed("Mesh撮影データの索引を保存できませんでした: \(error.localizedDescription)")
            return
        }

        switch mode {
        case .lidar:
            finishLiDARMesh()
        case .photogrammetry:
            reconstructPhotogrammetry()
        }
    }

    func reconstructTexturedModel() {
        guard supportsPhotogrammetry, frameCount >= 20 else {
            statusMessage = "テクスチャ再構築には対応端末と十分な写真が必要です"
            return
        }
        reconstructPhotogrammetry()
    }

    func applyCropInset(_ value: Double) {
        cropInset = min(0.42, max(0, value))
        guard let sourceMesh else { return }
        let cropped = crop(sourceMesh, inset: Float(cropInset))
        guard !cropped.isEmpty else {
            statusMessage = "切り抜き範囲が小さすぎます"
            return
        }
        do {
            let objURL = try exportOBJ(cropped, suffix: cropInset > 0 ? "-cropped" : "")
            rawOBJURL = objURL
            if mode == .lidar || resultURL?.pathExtension.lowercased() == "obj" {
                resultURL = objURL
                previewScene = makeScene(from: cropped)
            }
            vertexCount = cropped.vertices.count
            faceCount = cropped.triangles.count
            statusMessage = cropInset > 0 ? "実ジオメトリへ切り抜きを適用しました" : "切り抜きを解除しました"
        } catch {
            statusMessage = "切り抜き後のMeshを書き出せませんでした: \(error.localizedDescription)"
        }
    }

    func setMeasuredDistance(_ meters: Float?) {
        measuredDistanceMeters = meters
    }

    func blockDestructiveReset(_ reason: String) {
        destructiveResetBlockedReason = reason
        statusMessage = reason
    }

    func allowDestructiveReset() {
        destructiveResetBlockedReason = nil
    }

    @discardableResult
    func reset() -> Bool {
        if let reason = destructiveResetBlockedReason {
            statusMessage = reason
            return false
        }

        reconstructionTask?.cancel()
        reconstructionTask = nil
        photogrammetrySession?.cancel()
        photogrammetrySession = nil
        session?.pause()

        if let projectURL,
           FileManager.default.fileExists(atPath: projectURL.path) {
            do {
                try FileManager.default.removeItem(at: projectURL)
            } catch {
                let message = "Mesh撮影データを削除できませんでした。空き容量とファイル状態を確認して、破棄を再試行してください。"
                phase = .failed(message)
                statusMessage = "\(message) (\(error.localizedDescription))"
                UIApplication.shared.isIdleTimerDisabled = false
                return false
            }
        }

        projectURL = nil
        imagesURL = nil
        phase = .ready
        statusMessage = "Meshモードを選んでください"
        frameCount = 0
        vertexCount = 0
        faceCount = 0
        reconstructionProgress = 0
        resultURL = nil
        rawOBJURL = nil
        previewScene = nil
        cropInset = 0
        measuredDistanceMeters = nil
        invalidPhotogrammetrySamples = 0
        frames.removeAll()
        meshChunks.removeAll()
        sourceMesh = nil
        scanOrigin = nil
        lastSavedFrameTimestamp = 0
        isWritingFrame = false
        UIApplication.shared.isIdleTimerDisabled = false
        return true
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor [weak self] in
            self?.handleFrame(frame)
        }
    }

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        Task { @MainActor [weak self] in
            self?.absorbMeshAnchors(anchors)
        }
    }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        Task { @MainActor [weak self] in
            self?.absorbMeshAnchors(anchors)
        }
    }

    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        let ids = anchors.compactMap { ($0 as? ARMeshAnchor)?.identifier }
        Task { @MainActor [weak self] in
            guard let self else { return }
            for id in ids { self.meshChunks.removeValue(forKey: id) }
            self.refreshMeshCounters()
        }
    }

    private func prepareProject() throws {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SplatLab", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let project = root.appendingPathComponent(UUID().uuidString + ".meshproject", isDirectory: true)
        let images = project.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        projectURL = project
        imagesURL = images
    }

    private func resetCaptureStateKeepingProject() {
        frames.removeAll(keepingCapacity: true)
        meshChunks.removeAll(keepingCapacity: true)
        sourceMesh = nil
        scanOrigin = nil
        frameCount = 0
        vertexCount = 0
        faceCount = 0
        reconstructionProgress = 0
        resultURL = nil
        rawOBJURL = nil
        previewScene = nil
        cropInset = 0
        measuredDistanceMeters = nil
        invalidPhotogrammetrySamples = 0
        lastSavedFrameTimestamp = 0
        isWritingFrame = false
    }

    private func handleFrame(_ frame: ARFrame) {
        guard phase == .scanning else { return }

        switch frame.camera.trackingState {
        case .normal:
            break
        case .notAvailable:
            statusMessage = "カメラ位置を追跡できません"
            return
        case .limited(let reason):
            statusMessage = limitedReason(reason)
            return
        }

        if scanOrigin == nil {
            scanOrigin = SIMD3<Float>(
                frame.camera.transform.columns.3.x,
                frame.camera.transform.columns.3.y,
                frame.camera.transform.columns.3.z
            )
        }

        guard frame.timestamp - lastSavedFrameTimestamp >= 0.42,
              !isWritingFrame,
              let imagesURL else { return }

        let frameImage = MeshFrameImage(pixelBuffer: frame.capturedImage)
        let index = frames.count
        let fileName = String(format: "mesh_%05d.jpg", index)
        let fileURL = imagesURL.appendingPathComponent(fileName)
        let timestamp = frame.timestamp
        let transform = Self.rows(frame.camera.transform)
        let intrinsics = Self.rows3(frame.camera.intrinsics)
        let resolution = frame.camera.imageResolution
        let frameEncoder = self.frameEncoder
        isWritingFrame = true

        captureQueue.async { [weak self, frameEncoder, frameImage] in
            let success: Bool
            if let jpeg = frameEncoder.encode(frameImage) {
                do {
                    try jpeg.write(to: fileURL, options: .atomic)
                    success = true
                } catch {
                    success = false
                }
            } else {
                success = false
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isWritingFrame = false
                guard self.phase == .scanning else { return }
                guard success else {
                    let message = "撮影データを保存できませんでした。iPhoneの空き容量を確認してください。"
                    self.phase = .failed(message)
                    self.statusMessage = message
                    return
                }
                let sample = MeshCapturedFrame(
                    imageFile: fileName,
                    timestamp: timestamp,
                    transform: transform,
                    intrinsics: intrinsics,
                    width: Int(resolution.width),
                    height: Int(resolution.height)
                )
                self.frames.append(sample)
                self.frameCount = self.frames.count
                self.lastSavedFrameTimestamp = timestamp
                self.statusMessage = self.captureGuidance(for: sample)
            }
        }
    }

    private func absorbMeshAnchors(_ anchors: [ARAnchor]) {
        guard phase == .scanning, mode == .lidar else { return }
        let origin = scanOrigin
        let maximumRange = scanSize.maximumRangeMeters

        for anchor in anchors.compactMap({ $0 as? ARMeshAnchor }) {
            let chunk = Self.makeChunk(from: anchor, origin: origin, maximumRange: maximumRange)
            meshChunks[anchor.identifier] = chunk
        }
        refreshMeshCounters()
    }

    private func refreshMeshCounters() {
        faceCount = meshChunks.values.reduce(into: 0) { $0 += $1.triangles.count }
        vertexCount = meshChunks.values.reduce(into: 0) { $0 += $1.vertices.count }
    }

    private func captureGuidance(for sample: MeshCapturedFrame) -> String {
        let requiredFrames: Int
        switch scanSize {
        case .small: requiredFrames = 36
        case .medium: requiredFrames = 48
        case .large: requiredFrames = 80
        }
        let progress = min(1, Double(frameCount) / Double(requiredFrames))
        if progress < 0.35 { return "対象の正面だけでなく左右へ移動してください" }
        if progress < 0.7 { return "高さを変え、見えていない面を追加してください" }
        return "重なりを保ちながら未撮影の側面・背面を埋めてください"
    }

    private func writeManifest(texturedModelAvailable: Bool) throws {
        guard let projectURL else { return }
        let manifest = MeshCaptureManifest(
            schemaVersion: 1,
            mode: mode.rawValue,
            scanSize: scanSize.rawValue,
            capturedAt: Date(),
            frames: frames,
            texturedModelAvailable: texturedModelAvailable
        )
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: projectURL.appendingPathComponent("manifest.json"), options: .atomic)
    }

    private func finishLiDARMesh() {
        phase = .reconstructing
        reconstructionProgress = 0.1
        let chunks = Array(meshChunks.values)
        reconstructionTask = Task.detached(priority: .userInitiated) { [weak self] in
            let merged = Self.mergeAndClean(chunks)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                guard !merged.isEmpty else {
                    self.phase = .failed("有効な三角形メッシュを生成できませんでした。対象へ近づき、ゆっくり再撮影してください。")
                    return
                }
                self.sourceMesh = merged
                self.reconstructionProgress = 0.8
                do {
                    let url = try self.exportOBJ(merged, suffix: "-lidar")
                    self.resultURL = url
                    self.rawOBJURL = url
                    self.previewScene = self.makeScene(from: merged)
                    self.vertexCount = merged.vertices.count
                    self.faceCount = merged.triangles.count
                    try self.writeManifest(texturedModelAvailable: false)
                    self.reconstructionProgress = 1
                    self.phase = .finished
                    self.statusMessage = "LiDAR三角形Meshを生成しました。必要なら切り抜き・計測・書き出しを行えます。"
                } catch {
                    self.phase = .failed("LiDAR Meshを書き出せませんでした: \(error.localizedDescription)")
                }
            }
        }
    }

    private func reconstructPhotogrammetry() {
        guard supportsPhotogrammetry, let projectURL, let imagesURL else {
            phase = .failed("Photogrammetryの実行条件を満たしていません。")
            return
        }
        guard frameCount >= 20 else {
            phase = .failed("Photogrammetryには少なくとも20枚の有効な写真が必要です。")
            return
        }

        phase = .reconstructing
        reconstructionProgress = 0
        statusMessage = "端末内でテクスチャ付きMeshを再構築しています"

        let output = projectURL.appendingPathComponent("textured.usdz")
        photogrammetrySession?.cancel()
        photogrammetrySession = nil

        do {
            let configuration = PhotogrammetrySession.Configuration()
            configuration.isObjectMaskingEnabled = true
            configuration.sampleOrdering = .unordered
            let session = try PhotogrammetrySession(input: imagesURL, configuration: configuration)
            photogrammetrySession = session

            reconstructionTask = Task { [weak self] in
                guard let self else { return }
                do {
                    for try await outputState in session.outputs {
                        guard !Task.isCancelled else {
                            session.cancel()
                            return
                        }
                        switch outputState {
                        case .requestProgress(_, let fraction):
                            await MainActor.run { self.reconstructionProgress = fraction }
                        case .requestComplete(_, let result):
                            if case .modelFile(let url) = result {
                                await MainActor.run {
                                    do {
                                        if FileManager.default.fileExists(atPath: output.path) {
                                            try FileManager.default.removeItem(at: output)
                                        }
                                        try FileManager.default.copyItem(at: url, to: output)
                                        self.resultURL = output
                                        self.rawOBJURL = nil
                                        self.previewScene = try SCNScene(url: output, options: nil)
                                        self.reconstructionProgress = 1
                                        try self.writeManifest(texturedModelAvailable: true)
                                        self.phase = .finished
                                        self.statusMessage = "テクスチャ付きMeshを生成しました。3Dツール向けに書き出せます。"
                                    } catch {
                                        self.phase = .failed("再構築結果を保存できませんでした: \(error.localizedDescription)")
                                    }
                                }
                            }
                        case .requestError(_, let error):
                            await MainActor.run {
                                self.phase = .failed("Photogrammetryに失敗しました: \(error.localizedDescription)")
                            }
                        case .processingComplete:
                            break
                        case .processingCancelled:
                            await MainActor.run {
                                if case .reconstructing = self.phase {
                                    self.phase = .failed("Photogrammetry処理が中断されました")
                                }
                            }
                        case .invalidSample(let id, _):
                            await MainActor.run {
                                self.invalidPhotogrammetrySamples += 1
                                self.statusMessage = "品質不足の写真を除外しました (\(self.invalidPhotogrammetrySamples)枚)"
                            }
                        case .inputComplete:
                            break
                        @unknown default:
                            break
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.phase = .failed("Photogrammetryを完了できませんでした: \(error.localizedDescription)")
                    }
                }
            }

            try session.process(requests: [
                .modelFile(url: output, detail: .reduced)
            ])
        } catch {
            phase = .failed("Photogrammetryを開始できませんでした: \(error.localizedDescription)")
        }
    }

    private func exportOBJ(_ mesh: MergedMesh, suffix: String) throws -> URL {
        guard let projectURL else { throw meshError("Mesh保存先がありません") }
        let file = projectURL.appendingPathComponent("mesh\(suffix).obj")
        var text = "# Splat Lab generated metric mesh\n"
        for v in mesh.vertices { text += "v \(v.x) \(v.y) \(v.z)\n" }
        for n in mesh.normals { text += "vn \(n.x) \(n.y) \(n.z)\n" }
        for t in mesh.triangles {
            let a = t.x + 1, b = t.y + 1, c = t.z + 1
            text += "f \(a)//\(a) \(b)//\(b) \(c)//\(c)\n"
        }
        try text.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    private func crop(_ mesh: MergedMesh, inset: Float) -> MergedMesh {
        guard inset > 0 else { return mesh }
        let box = Self.bounds(of: mesh.vertices)
        let size = box.max - box.min
        let lower = box.min + size * inset
        let upper = box.max - size * inset
        let kept = mesh.triangles.filter { triangle in
            let center = (mesh.vertices[Int(triangle.x)] + mesh.vertices[Int(triangle.y)] + mesh.vertices[Int(triangle.z)]) / 3
            return Self.inside(center, min: lower, max: upper)
        }
        return Self.compact(vertices: mesh.vertices, normals: mesh.normals, triangles: kept)
    }

    private func makeScene(from mesh: MergedMesh) -> SCNScene {
        let scene = SCNScene()
        let source = SCNGeometrySource(vertices: mesh.vertices.map { SCNVector3($0.x, $0.y, $0.z) })
        let normalSource = SCNGeometrySource(normals: mesh.normals.map { SCNVector3($0.x, $0.y, $0.z) })
        let indices = mesh.triangles.flatMap { [$0.x, $0.y, $0.z] }
        let data = indices.withUnsafeBytes { Data($0) }
        let element = SCNGeometryElement(data: data, primitiveType: .triangles, primitiveCount: mesh.triangles.count, bytesPerIndex: MemoryLayout<UInt32>.size)
        let geometry = SCNGeometry(sources: [source, normalSource], elements: [element])
        geometry.firstMaterial?.diffuse.contents = UIColor(white: 0.78, alpha: 1)
        geometry.firstMaterial?.roughness.contents = 0.72
        geometry.firstMaterial?.metalness.contents = 0.04
        geometry.firstMaterial?.isDoubleSided = true
        scene.rootNode.addChildNode(SCNNode(geometry: geometry))
        return scene
    }

    private func limitedReason(_ reason: ARCamera.TrackingState.Reason) -> String {
        switch reason {
        case .initializing: return "位置を合わせています。ゆっくり動かしてください"
        case .excessiveMotion: return "動きが速すぎます。ゆっくり移動してください"
        case .insufficientFeatures: return "追跡の手がかりが少ないため、明るさや角度を変えてください"
        case .relocalizing: return "位置を復旧しています。撮影済みの場所へゆっくり戻ってください"
        @unknown default: return "追跡が安定するまでゆっくり動かしてください"
        }
    }

    private func meshError(_ message: String) -> NSError {
        NSError(domain: "ScanLab.Mesh", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    nonisolated private static func makeChunk(from anchor: ARMeshAnchor, origin: SIMD3<Float>?, maximumRange: Float) -> MeshChunk {
        let geometry = anchor.geometry
        let transform = anchor.transform
        let normalMatrix = simd_float3x3(
            SIMD3<Float>(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z),
            SIMD3<Float>(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z),
            SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        )

        var vertices: [SIMD3<Float>] = []
        vertices.reserveCapacity(geometry.vertices.count)
        var normals: [SIMD3<Float>] = []
        normals.reserveCapacity(geometry.normals.count)

        for index in 0..<geometry.vertices.count {
            let local = geometry.vertex(at: UInt32(index))
            let world4 = transform * SIMD4<Float>(local.x, local.y, local.z, 1)
            vertices.append(SIMD3<Float>(world4.x, world4.y, world4.z))
        }

        for index in 0..<geometry.normals.count {
            let local = geometry.normal(at: UInt32(index))
            let transformed = normalMatrix * local
            normals.append(simd_length_squared(transformed) > 0 ? simd_normalize(transformed) : SIMD3<Float>(0, 1, 0))
        }
        if normals.count < vertices.count {
            normals.append(contentsOf: repeatElement(SIMD3<Float>(0, 1, 0), count: vertices.count - normals.count))
        }

        let faces = geometry.faces
        let indexCount = faces.indexCountPerPrimitive
        let pointer = faces.buffer.contents()
        var triangles: [SIMD3<UInt32>] = []
        triangles.reserveCapacity(faces.count)

        for faceIndex in 0..<faces.count where indexCount >= 3 {
            let a = readIndex(pointer: pointer, linearIndex: faceIndex * indexCount, bytesPerIndex: faces.bytesPerIndex)
            let b = readIndex(pointer: pointer, linearIndex: faceIndex * indexCount + 1, bytesPerIndex: faces.bytesPerIndex)
            let c = readIndex(pointer: pointer, linearIndex: faceIndex * indexCount + 2, bytesPerIndex: faces.bytesPerIndex)
            guard Int(a) < vertices.count, Int(b) < vertices.count, Int(c) < vertices.count else { continue }
            if let origin {
                let centroid = (vertices[Int(a)] + vertices[Int(b)] + vertices[Int(c)]) / 3
                guard simd_distance(centroid, origin) <= maximumRange else { continue }
            }
            triangles.append(SIMD3<UInt32>(a, b, c))
        }

        return MeshChunk(id: anchor.identifier, vertices: vertices, normals: normals, triangles: triangles)
    }

    nonisolated private static func mergeAndClean(_ chunks: [MeshChunk]) -> MergedMesh {
        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var triangles: [SIMD3<UInt32>] = []
        var base: UInt32 = 0

        for chunk in chunks {
            vertices.append(contentsOf: chunk.vertices)
            normals.append(contentsOf: chunk.normals)
            for triangle in chunk.triangles {
                let shifted = SIMD3<UInt32>(triangle.x + base, triangle.y + base, triangle.z + base)
                let a = vertices[Int(shifted.x)]
                let b = vertices[Int(shifted.y)]
                let c = vertices[Int(shifted.z)]
                let areaVector = simd_cross(b - a, c - a)
                if simd_length_squared(areaVector) > 0.00000025 {
                    triangles.append(shifted)
                }
            }
            base += UInt32(chunk.vertices.count)
        }

        guard !triangles.isEmpty else { return MergedMesh(vertices: [], normals: [], triangles: []) }
        return compact(vertices: vertices, normals: normals, triangles: triangles)
    }

    nonisolated private static func compact(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        triangles: [SIMD3<UInt32>]
    ) -> MergedMesh {
        var used = Set<UInt32>()
        used.reserveCapacity(triangles.count * 2)
        for t in triangles {
            used.insert(t.x); used.insert(t.y); used.insert(t.z)
        }
        let ordered = used.sorted()
        var remap: [UInt32: UInt32] = [:]
        remap.reserveCapacity(ordered.count)
        var compactVertices: [SIMD3<Float>] = []
        var compactNormals: [SIMD3<Float>] = []
        compactVertices.reserveCapacity(ordered.count)
        compactNormals.reserveCapacity(ordered.count)

        for (newIndex, oldIndex) in ordered.enumerated() {
            remap[oldIndex] = UInt32(newIndex)
            compactVertices.append(vertices[Int(oldIndex)])
            compactNormals.append(Int(oldIndex) < normals.count ? normals[Int(oldIndex)] : SIMD3<Float>(0, 1, 0))
        }

        let compactTriangles = triangles.compactMap { t -> SIMD3<UInt32>? in
            guard let a = remap[t.x], let b = remap[t.y], let c = remap[t.z] else { return nil }
            return SIMD3<UInt32>(a, b, c)
        }
        return MergedMesh(vertices: compactVertices, normals: compactNormals, triangles: compactTriangles)
    }

    nonisolated private static func readIndex(pointer: UnsafeMutableRawPointer, linearIndex: Int, bytesPerIndex: Int) -> UInt32 {
        let address = pointer.advanced(by: linearIndex * bytesPerIndex)
        switch bytesPerIndex {
        case 2:
            return UInt32(address.assumingMemoryBound(to: UInt16.self).pointee)
        default:
            return address.assumingMemoryBound(to: UInt32.self).pointee
        }
    }

    nonisolated private static func bounds(of vertices: [SIMD3<Float>]) -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for v in vertices {
            minimum = simd_min(minimum, v)
            maximum = simd_max(maximum, v)
        }
        return (minimum, maximum)
    }

    nonisolated private static func inside(_ p: SIMD3<Float>, min: SIMD3<Float>, max: SIMD3<Float>) -> Bool {
        p.x >= min.x && p.x <= max.x &&
        p.y >= min.y && p.y <= max.y &&
        p.z >= min.z && p.z <= max.z
    }

    nonisolated private static func rows(_ matrix: simd_float4x4) -> [[Float]] {
        (0..<4).map { row in (0..<4).map { column in matrix[column][row] } }
    }

    nonisolated private static func rows3(_ matrix: simd_float3x3) -> [[Float]] {
        (0..<3).map { row in (0..<3).map { column in matrix[column][row] } }
    }
}

private extension ARMeshGeometry {
    func vertex(at index: UInt32) -> SIMD3<Float> {
        let pointer = vertices.buffer.contents().advanced(by: vertices.offset + vertices.stride * Int(index))
        return pointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
    }

    func normal(at index: UInt32) -> SIMD3<Float> {
        let pointer = normals.buffer.contents().advanced(by: normals.offset + normals.stride * Int(index))
        return pointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
    }
}
