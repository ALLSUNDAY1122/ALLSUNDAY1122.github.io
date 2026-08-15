@preconcurrency import ARKit
import CoreImage
import Foundation
import Msplat
import SceneKit
import SwiftUI
import UIKit
import simd

struct CapturedView: Codable, Identifiable {
    let id: Int
    let filePath: String
    let transformMatrix: [[Float]]
    let flX: Float
    let flY: Float
    let cx: Float
    let cy: Float
    let w: Int
    let h: Int
}

struct NerfstudioDataset: Codable {
    let cameraModel: String
    let plyFilePath: String
    let frames: [NerfstudioFrame]

    enum CodingKeys: String, CodingKey {
        case cameraModel = "camera_model"
        case plyFilePath = "ply_file_path"
        case frames
    }
}

struct NerfstudioFrame: Codable {
    let filePath: String
    let transformMatrix: [[Float]]
    let flX: Float
    let flY: Float
    let cx: Float
    let cy: Float
    let w: Int
    let h: Int

    enum CodingKeys: String, CodingKey {
        case filePath = "file_path"
        case transformMatrix = "transform_matrix"
        case flX = "fl_x"
        case flY = "fl_y"
        case cx, cy, w, h
    }
}

@MainActor
final class ScanModel: NSObject, ObservableObject, ARSessionDelegate {
    enum Phase: Equatable {
        case ready
        case capturing
        case captured
        case training
        case finished
        case failed(String)
    }

    @Published var phase: Phase = .ready
    @Published var acceptedFrames = 0
    @Published var targetFrames = 48
    @Published var featurePointCount = 0
    @Published var coverageSectorCount = 0
    @Published var trackingMessage = "対象を中央に置いて開始してください"
    @Published var trainingProgress: Double = 0
    @Published var trainingIteration = 0
    @Published var splatCount = 0
    @Published var resultURL: URL?
    @Published var previewImage: UIImage?

    let coverageSectorTotal = 12
    let minimumCoverageSectors = 8
    private let maxFrames = 72

    private(set) var session: ARSession?
    private var projectURL: URL?
    private var imagesURL: URL?
    private var captured: [CapturedView] = []
    private var featurePoints: [UInt64: SIMD3<Float>] = [:]
    private var coverageSectors: Set<Int> = []
    private var estimatedTargetCenter: SIMD3<Float>?
    private var lastAcceptedTransform: simd_float4x4?
    private var lastAcceptedTimestamp: TimeInterval = 0
    private var datasetReady = false
    private let ciContext = CIContext(options: [.cacheIntermediates: false])
    private let captureQueue = DispatchQueue(label: "jp.allsunday1122.splatlab.capture", qos: .userInitiated)
    private var isWritingFrame = false

    var canFinishCapture: Bool {
        acceptedFrames >= 24 &&
        featurePointCount >= 64 &&
        coverageSectorCount >= minimumCoverageSectors &&
        !isWritingFrame
    }

    var canRetryGeneration: Bool { datasetReady && projectURL != nil }

    var progressText: String { "撮影方向 \(coverageSectorCount) / \(coverageSectorTotal)" }

    var captureBand: String {
        if coverageSectorCount < 4 { return "対象の周囲を回る" }
        if coverageSectorCount < minimumCoverageSectors { return "反対側まで回り込む" }
        if acceptedFrames < targetFrames { return "高さを少し変えて仕上げる" }
        return "撮影は十分です"
    }

    var captureQualityText: String {
        if acceptedFrames < 24 {
            return "対象を中央に保ったまま、止まらずゆっくり1周してください"
        }
        if coverageSectorCount < minimumCoverageSectors {
            return "同じ側の写真に偏っています。対象の反対側まで回り込んでください"
        }
        if featurePointCount < 64 {
            return "立体の手がかりが不足しています。明るさや背景を変えて少し撮り足してください"
        }
        if acceptedFrames < targetFrames {
            return "生成できます。もう少し撮ると安定しやすくなります"
        }
        return "必要な方向がそろいました"
    }

    var trainingStageText: String {
        switch trainingProgress {
        case ..<0.18: return "写真の位置関係を確認しています"
        case ..<0.58: return "立体の形を組み立てています"
        case ..<0.88: return "色と細部を整えています"
        default: return "見返せる形に仕上げています"
        }
    }

    func attach(session: ARSession) {
        guard self.session !== session else { return }
        self.session = session
        session.delegate = self
    }

    func startCapture() {
        guard let session else { return }
        do {
            let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("SplatLab", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let project = root.appendingPathComponent(UUID().uuidString + ".splatproject", isDirectory: true)
            let images = project.appendingPathComponent("images", isDirectory: true)
            try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
            projectURL = project
            imagesURL = images
        } catch {
            phase = .failed("保存領域を準備できませんでした: \(error.localizedDescription)")
            return
        }

        captured.removeAll(keepingCapacity: true)
        featurePoints.removeAll(keepingCapacity: true)
        coverageSectors.removeAll(keepingCapacity: true)
        estimatedTargetCenter = nil
        acceptedFrames = 0
        featurePointCount = 0
        coverageSectorCount = 0
        lastAcceptedTransform = nil
        lastAcceptedTimestamp = 0
        resultURL = nil
        previewImage = nil
        trainingProgress = 0
        trainingIteration = 0
        splatCount = 0
        datasetReady = false
        isWritingFrame = false
        phase = .capturing
        trackingMessage = "対象を中央に保ち、周囲をゆっくり1周してください"

        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        config.isLightEstimationEnabled = true
        config.environmentTexturing = .none
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func finishCapture() {
        guard phase == .capturing, canFinishCapture else { return }
        session?.pause()
        do {
            try writePointCloudPLY()
            try writeTransformsJSON()
            datasetReady = true
            phase = .captured
            trackingMessage = "必要な撮影情報がそろいました"
        } catch {
            datasetReady = false
            phase = .failed("撮影データを準備できませんでした: \(error.localizedDescription)")
        }
    }

    func discardAndReset() {
        session?.pause()
        if let projectURL { try? FileManager.default.removeItem(at: projectURL) }
        projectURL = nil
        imagesURL = nil
        captured.removeAll()
        featurePoints.removeAll()
        coverageSectors.removeAll()
        estimatedTargetCenter = nil
        acceptedFrames = 0
        featurePointCount = 0
        coverageSectorCount = 0
        resultURL = nil
        previewImage = nil
        trainingProgress = 0
        trainingIteration = 0
        splatCount = 0
        datasetReady = false
        phase = .ready
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func retryGeneration() {
        guard canRetryGeneration else { return }
        phase = .captured
        train()
    }

    /// S2 enhancement entry point. The checkpoint created by the standard pass is reused, so this
    /// extends optimization instead of discarding the work already performed.
    func enhanceResult() {
        guard datasetReady, projectURL != nil, phase == .finished else { return }
        phase = .captured
        train(iterations: SplatReconstructionPolicy.enhancementIterations)
    }

    func train(iterations: Int = SplatReconstructionPolicy.standardIterations) {
        guard phase == .captured, datasetReady, let projectURL else { return }
        let targetIterations = max(1, iterations)
        phase = .training
        trainingProgress = 0
        trainingIteration = 0
        splatCount = 0
        UIApplication.shared.isIdleTimerDisabled = true

        let path = projectURL.path
        let checkpoint = projectURL.appendingPathComponent("training.msplat-checkpoint")
        let preprocessingFrames = captured.map { frame in
            SplatSeedFrame(
                filePath: frame.filePath,
                transformMatrix: frame.transformMatrix,
                flX: frame.flX,
                flY: frame.flY,
                cx: frame.cx,
                cy: frame.cy,
                w: frame.w,
                h: frame.h
            )
        }
        Task.detached(priority: .userInitiated) { [weak self] in
            autoreleasepool {
                _ = SplatForegroundIsolator.prepareProjectImages(
                    projectURL: projectURL,
                    frames: preprocessingFrames
                )
                let dataset = GaussianDataset(
                    path: path,
                    downscaleFactor: SplatReconstructionPolicy.datasetDownscale,
                    evalMode: false
                )
                guard dataset.numTrain >= 3 else {
                    Task { @MainActor [weak self] in
                        self?.failTraining("撮影画像を読み込めませんでした。生成をもう一度試してください")
                    }
                    return
                }

                let config = SplatReconstructionPolicy.makeConfig(iterations: targetIterations)
                let trainer = GaussianTrainer(dataset: dataset, config: config)

                if FileManager.default.fileExists(atPath: checkpoint.path) {
                    _ = trainer.loadCheckpoint(from: checkpoint.path)
                }

                let resumedIteration = trainer.iteration
                if resumedIteration > 0 {
                    let resumedCount = trainer.splatCount
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.trainingIteration = resumedIteration
                        self.splatCount = resumedCount
                        self.trainingProgress = min(1, Double(resumedIteration) / Double(targetIterations))
                    }
                }

                if resumedIteration < targetIterations {
                    for _ in resumedIteration..<targetIterations {
                        if Task.isCancelled { return }
                        let stats = trainer.step()
                        let iteration = stats.iteration
                        let shouldReport = iteration % 20 == 0 || iteration >= targetIterations
                        let thermalCheck = iteration % SplatReconstructionPolicy.thermalCheckInterval == 0
                        let thermalPause = thermalCheck && SplatReconstructionPolicy.requiresThermalPause(
                            ProcessInfo.processInfo.thermalState
                        )
                        let checkpointDue = iteration % SplatReconstructionPolicy.checkpointInterval == 0

                        if checkpointDue || thermalPause {
                            msplatSync()
                            _ = trainer.saveCheckpoint(to: checkpoint.path)
                        }

                        if shouldReport {
                            let count = stats.splatCount
                            Task { @MainActor [weak self] in
                                guard let self else { return }
                                self.trainingIteration = iteration
                                self.splatCount = count
                                self.trainingProgress = min(1, Double(iteration) / Double(targetIterations))
                            }
                        }

                        if thermalPause {
                            Task { @MainActor [weak self] in
                                self?.failTraining("端末温度が高くなったため生成を安全に一時停止しました。端末が冷えてから「生成だけもう一度試す」で続きから再開できます")
                            }
                            return
                        }
                    }
                }

                msplatSync()
                _ = trainer.saveCheckpoint(to: checkpoint.path)
                let output = projectURL.appendingPathComponent("result.splat")
                trainer.exportSplat(to: output.path)
                msplatSync()

                guard let attributes = try? FileManager.default.attributesOfItem(atPath: output.path),
                      let sizeNumber = attributes[.size] as? NSNumber,
                      sizeNumber.intValue > 0,
                      sizeNumber.intValue % 32 == 0 else {
                    Task { @MainActor [weak self] in
                        self?.failTraining("生成した3Dデータを保存できませんでした。生成をもう一度試してください")
                    }
                    return
                }

                let rendered = trainer.render(cameraIndex: 0)
                let preview = Self.makeImage(from: rendered)
                let finalCount = trainer.splatCount
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.resultURL = output
                    self.previewImage = preview
                    self.trainingIteration = targetIterations
                    self.splatCount = finalCount
                    self.trainingProgress = 1
                    self.phase = .finished
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            }
        }
    }

    private func failTraining(_ message: String) {
        phase = .failed(message)
        trackingMessage = message
        UIApplication.shared.isIdleTimerDisabled = false
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor [weak self] in
            self?.handleFrame(frame)
        }
    }

    private func handleFrame(_ frame: ARFrame) {
        guard phase == .capturing, !isWritingFrame, acceptedFrames < maxFrames else { return }

        switch frame.camera.trackingState {
        case .normal:
            break
        case .notAvailable:
            trackingMessage = "カメラ位置を追跡できません"
            return
        case .limited(let reason):
            trackingMessage = limitedReason(reason)
            return
        }

        if frame.timestamp - lastAcceptedTimestamp < 0.18 { return }
        if let previous = lastAcceptedTransform, !movedEnough(from: previous, to: frame.camera.transform) { return }
        guard let jpegData = makeJPEGData(pixelBuffer: frame.capturedImage) else {
            trackingMessage = "画像を保存できません。もう一度ゆっくり動かしてください"
            return
        }

        absorbFeaturePoints(frame.rawFeaturePoints, cameraTransform: frame.camera.transform)

        isWritingFrame = true
        let index = acceptedFrames
        let matrixRows = Self.rows(frame.camera.transform)
        let transform = frame.camera.transform
        let intrinsics = frame.camera.intrinsics
        let resolution = frame.camera.imageResolution
        let timestamp = frame.timestamp
        let imagesURL = imagesURL

        captureQueue.async { [weak self] in
            guard let imagesURL else { return }
            let fileName = String(format: "frame_%05d.jpg", index)
            let fileURL = imagesURL.appendingPathComponent(fileName)
            let success: Bool
            do {
                try jpegData.write(to: fileURL, options: .atomic)
                success = true
            } catch {
                success = false
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isWritingFrame = false
                guard success, self.phase == .capturing else { return }
                self.captured.append(CapturedView(
                    id: index,
                    filePath: "images/\(fileName)",
                    transformMatrix: matrixRows,
                    flX: intrinsics[0, 0],
                    flY: intrinsics[1, 1],
                    cx: intrinsics[2, 0],
                    cy: intrinsics[2, 1],
                    w: Int(resolution.width),
                    h: Int(resolution.height)
                ))
                self.updateCoverage(using: transform)
                self.acceptedFrames = self.captured.count
                self.lastAcceptedTransform = transform
                self.lastAcceptedTimestamp = timestamp
                self.trackingMessage = self.captureQualityText

                if self.acceptedFrames >= self.targetFrames && self.canFinishCapture {
                    self.finishCapture()
                } else if self.acceptedFrames >= self.maxFrames && !self.canFinishCapture {
                    self.phase = .failed("十分な方向から撮影できませんでした。対象を中央に置き、反対側まで回り込んでもう一度撮影してください")
                    self.session?.pause()
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            }
        }
    }

    private func makeJPEGData(pixelBuffer: CVPixelBuffer) -> Data? {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cg = ciContext.createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: cg).jpegData(compressionQuality: 0.86)
    }

    private func absorbFeaturePoints(_ cloud: ARPointCloud?, cameraTransform: simd_float4x4) {
        guard let cloud, !cloud.points.isEmpty else { return }

        if estimatedTargetCenter == nil {
            estimatedTargetCenter = estimateTargetCenter(from: cloud, cameraTransform: cameraTransform)
                ?? Self.fallbackTargetCenter(cameraTransform)
        }

        let step = max(1, cloud.points.count / 350)
        for index in stride(from: 0, to: cloud.points.count, by: step) {
            if featurePoints.count >= 12_000 { break }
            featurePoints[cloud.identifiers[index]] = cloud.points[index]
        }
        featurePointCount = featurePoints.count
    }

    private func estimateTargetCenter(from cloud: ARPointCloud, cameraTransform: simd_float4x4) -> SIMD3<Float>? {
        let worldToCamera = simd_inverse(cameraTransform)
        let step = max(1, cloud.points.count / 500)
        var xs: [Float] = []
        var ys: [Float] = []
        var zs: [Float] = []
        xs.reserveCapacity(128)
        ys.reserveCapacity(128)
        zs.reserveCapacity(128)

        for index in stride(from: 0, to: cloud.points.count, by: step) {
            let p = cloud.points[index]
            let cameraPoint = worldToCamera * SIMD4<Float>(p.x, p.y, p.z, 1)
            let depth = -cameraPoint.z
            guard depth >= 0.20, depth <= 1.50 else { continue }
            guard abs(cameraPoint.x) <= depth * 0.55,
                  abs(cameraPoint.y) <= depth * 0.55 else { continue }
            xs.append(p.x)
            ys.append(p.y)
            zs.append(p.z)
        }

        guard xs.count >= 8 else { return nil }
        xs.sort(); ys.sort(); zs.sort()
        let middle = xs.count / 2
        return SIMD3<Float>(xs[middle], ys[middle], zs[middle])
    }

    private func updateCoverage(using transform: simd_float4x4) {
        guard let center = estimatedTargetCenter else { return }
        let position = Self.cameraPosition(transform)
        let dx = position.x - center.x
        let dz = position.z - center.z
        let horizontalDistance = hypot(dx, dz)
        guard horizontalDistance >= 0.08 else { return }

        let angle = atan2(dx, dz)
        let normalized = (angle + .pi) / (2 * .pi)
        let rawSector = Int(floor(normalized * Float(coverageSectorTotal)))
        let sector = min(coverageSectorTotal - 1, max(0, rawSector))
        coverageSectors.insert(sector)
        coverageSectorCount = coverageSectors.count
    }

    private func writePointCloudPLY() throws {
        guard let projectURL else { throw dataError("保存先がありません") }
        guard featurePoints.count >= 64 else {
            throw dataError("立体の手がかりが不足しています。模様のある背景で対象の周囲をもう一度撮影してください")
        }

        let points = Array(featurePoints.values)
        let seedFrames = captured.map { frame in
            SplatSeedFrame(
                filePath: frame.filePath,
                transformMatrix: frame.transformMatrix,
                flX: frame.flX,
                flY: frame.flY,
                cx: frame.cx,
                cy: frame.cy,
                w: frame.w,
                h: frame.h
            )
        }
        let colors = SplatSeedColorizer.colorize(points: points, frames: seedFrames, projectURL: projectURL)
        var ply = "ply\nformat ascii 1.0\nelement vertex \(points.count)\nproperty float x\nproperty float y\nproperty float z\nproperty uchar red\nproperty uchar green\nproperty uchar blue\nend_header\n"
        ply.reserveCapacity(points.count * 56)
        for (index, p) in points.enumerated() {
            let color = colors.indices.contains(index) ? colors[index] : SplatSeedColorizer.fallback
            ply += "\(p.x) \(p.y) \(p.z) \(color.red) \(color.green) \(color.blue)\n"
        }
        try ply.write(to: projectURL.appendingPathComponent("points3D.ply"), atomically: true, encoding: .utf8)
    }

    private func writeTransformsJSON() throws {
        guard let projectURL else { throw dataError("保存先がありません") }
        guard !captured.isEmpty else { throw dataError("撮影画像がありません") }
        let frames = captured.map {
            NerfstudioFrame(
                filePath: $0.filePath,
                transformMatrix: $0.transformMatrix,
                flX: $0.flX,
                flY: $0.flY,
                cx: $0.cx,
                cy: $0.cy,
                w: $0.w,
                h: $0.h
            )
        }
        let dataset = NerfstudioDataset(
            cameraModel: "OPENCV",
            plyFilePath: "points3D.ply",
            frames: frames
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(dataset).write(to: projectURL.appendingPathComponent("transforms.json"), options: .atomic)
    }

    private func movedEnough(from a: simd_float4x4, to b: simd_float4x4) -> Bool {
        let pa = Self.cameraPosition(a)
        let pb = Self.cameraPosition(b)
        let translation = simd_distance(pa, pb)
        let qa = simd_quatf(a)
        let qb = simd_quatf(b)
        let dot = min(1, max(-1, abs(simd_dot(qa.vector, qb.vector))))
        let angle = 2 * acos(dot)

        // Do not let a user collect an apparently complete scan by rotating in place.
        // Rotation can supplement movement, but every accepted frame must include real translation.
        return translation >= 0.030 || (translation >= 0.012 && angle >= 0.080)
    }

    private func limitedReason(_ reason: ARCamera.TrackingState.Reason) -> String {
        switch reason {
        case .initializing: return "位置を合わせています。ゆっくり動かしてください"
        case .excessiveMotion: return "動きが速すぎます。もっとゆっくり"
        case .insufficientFeatures: return "模様が少ないため追跡困難です。背景や明るさを変えてください"
        case .relocalizing: return "位置を再確認しています"
        @unknown default: return "追跡が安定するまで少し動かしてください"
        }
    }

    private func dataError(_ message: String) -> NSError {
        NSError(domain: "SplatLab", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private static func cameraPosition(_ m: simd_float4x4) -> SIMD3<Float> {
        SIMD3<Float>(m.columns.3.x, m.columns.3.y, m.columns.3.z)
    }

    private static func fallbackTargetCenter(_ transform: simd_float4x4) -> SIMD3<Float> {
        let position = cameraPosition(transform)
        let cameraBack = SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        return position - cameraBack * 0.60
    }

    private static func rows(_ m: simd_float4x4) -> [[Float]] {
        (0..<4).map { row in (0..<4).map { col in m[col][row] } }
    }

    nonisolated private static func makeImage(from pixels: PixelData) -> UIImage? {
        let width = pixels.width
        let height = pixels.height
        guard width > 0, height > 0 else { return nil }
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for i in 0..<(width * height) {
            bytes[i * 4] = UInt8(clamping: Int(max(0, min(1, pixels.pixels[i * 3])) * 255))
            bytes[i * 4 + 1] = UInt8(clamping: Int(max(0, min(1, pixels.pixels[i * 3 + 1])) * 255))
            bytes[i * 4 + 2] = UInt8(clamping: Int(max(0, min(1, pixels.pixels[i * 3 + 2])) * 255))
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        let space = CGColorSpaceCreateDeviceRGB()
        guard let cg = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                               bytesPerRow: width * 4, space: space,
                               bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                               provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

struct ScanCameraView: UIViewRepresentable {
    @EnvironmentObject var model: ScanModel

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.backgroundColor = .black
        view.preferredFramesPerSecond = 60
        view.automaticallyUpdatesLighting = false
        model.attach(session: view.session)
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}
