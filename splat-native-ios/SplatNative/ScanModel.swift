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
}

struct NerfstudioDataset: Codable {
    let cameraModel: String
    let flX: Float
    let flY: Float
    let cx: Float
    let cy: Float
    let w: Int
    let h: Int
    let frames: [NerfstudioFrame]

    enum CodingKeys: String, CodingKey {
        case cameraModel = "camera_model"
        case flX = "fl_x"
        case flY = "fl_y"
        case cx, cy, w, h, frames
    }
}

struct NerfstudioFrame: Codable {
    let filePath: String
    let transformMatrix: [[Float]]

    enum CodingKeys: String, CodingKey {
        case filePath = "file_path"
        case transformMatrix = "transform_matrix"
    }
}

@MainActor
final class ScanModel: NSObject, ObservableObject {
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
    @Published var trackingMessage = "対象を中央に置いて開始してください"
    @Published var trainingProgress: Double = 0
    @Published var trainingIteration = 0
    @Published var splatCount = 0
    @Published var resultURL: URL?
    @Published var previewImage: UIImage?

    private(set) var session: ARSession?
    private var projectURL: URL?
    private var imagesURL: URL?
    private var captured: [CapturedView] = []
    private var firstIntrinsics: simd_float3x3?
    private var firstResolution: CGSize?
    private var lastAcceptedTransform: simd_float4x4?
    private var lastAcceptedTimestamp: TimeInterval = 0
    private let ciContext = CIContext(options: [.cacheIntermediates: false])
    private let captureQueue = DispatchQueue(label: "jp.allsunday1122.splatlab.capture", qos: .userInitiated)
    private var isWritingFrame = false

    var canFinishCapture: Bool { acceptedFrames >= 24 }
    var progressText: String { "\(acceptedFrames) / \(targetFrames)" }
    var captureBand: String {
        let n = acceptedFrames
        if n < targetFrames / 3 { return "低い位置" }
        if n < targetFrames * 2 / 3 { return "正面" }
        return "高い位置"
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
        acceptedFrames = 0
        firstIntrinsics = nil
        firstResolution = nil
        lastAcceptedTransform = nil
        lastAcceptedTimestamp = 0
        resultURL = nil
        previewImage = nil
        trainingProgress = 0
        trainingIteration = 0
        splatCount = 0
        isWritingFrame = false
        phase = .capturing
        trackingMessage = "対象の周囲をゆっくり移動してください"

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
            try writeTransformsJSON()
            phase = .captured
            trackingMessage = "撮影データを保存しました。端末内生成へ進めます。"
        } catch {
            phase = .failed("撮影データを書き出せませんでした: \(error.localizedDescription)")
        }
    }

    func discardAndReset() {
        session?.pause()
        if let projectURL { try? FileManager.default.removeItem(at: projectURL) }
        projectURL = nil
        imagesURL = nil
        captured.removeAll()
        acceptedFrames = 0
        resultURL = nil
        previewImage = nil
        trainingProgress = 0
        trainingIteration = 0
        splatCount = 0
        phase = .ready
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func train(iterations: Int = 2_000) {
        guard phase == .captured, let projectURL else { return }
        phase = .training
        trainingProgress = 0
        trainingIteration = 0
        splatCount = 0
        UIApplication.shared.isIdleTimerDisabled = true

        let path = projectURL.path
        Task.detached(priority: .userInitiated) { [weak self] in
            autoreleasepool {
                let dataset = GaussianDataset(path: path, downscaleFactor: 4.0, evalMode: false)
                var config = TrainingConfig()
                config.iterations = Int32(iterations)
                config.shDegree = 2
                config.shDegreeInterval = 500
                config.numDownscales = 0
                config.refineEvery = 100
                config.warmupLength = 250
                config.resetAlphaEvery = 20
                config.stopScreenSizeAt = Int32(iterations)
                config.bgColor = (0.02, 0.02, 0.025)
                let trainer = GaussianTrainer(dataset: dataset, config: config)

                for step in 0..<iterations {
                    if Task.isCancelled { return }
                    let stats = trainer.step()
                    if step % 20 == 0 || step == iterations - 1 {
                        let iteration = Int(stats.iteration)
                        let count = Int(stats.splatCount)
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            self.trainingIteration = iteration
                            self.splatCount = count
                            self.trainingProgress = min(1, Double(iteration) / Double(iterations))
                        }
                    }
                }

                let output = projectURL.appendingPathComponent("result.splat")
                trainer.exportSplat(to: output.path)
                let rendered = trainer.render(cameraIndex: 0)
                let preview = Self.makeImage(from: rendered)
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.resultURL = output
                    self.previewImage = preview
                    self.trainingProgress = 1
                    self.phase = .finished
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            }
        }
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor [weak self] in
            self?.handleFrame(frame)
        }
    }

    private func handleFrame(_ frame: ARFrame) {
        guard phase == .capturing, !isWritingFrame, acceptedFrames < targetFrames else { return }

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

        firstIntrinsics = firstIntrinsics ?? frame.camera.intrinsics
        firstResolution = firstResolution ?? frame.camera.imageResolution
        isWritingFrame = true
        let index = acceptedFrames
        let transform = frame.camera.transform
        let pixelBuffer = frame.capturedImage
        CVPixelBufferRetain(pixelBuffer)
        let imagesURL = imagesURL

        captureQueue.async { [weak self] in
            defer { CVPixelBufferRelease(pixelBuffer) }
            guard let self, let imagesURL else { return }
            let fileName = String(format: "frame_%05d.jpg", index)
            let fileURL = imagesURL.appendingPathComponent(fileName)
            let success = self.writeJPEG(pixelBuffer: pixelBuffer, to: fileURL)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isWritingFrame = false
                guard success, self.phase == .capturing else { return }
                self.captured.append(CapturedView(
                    id: index,
                    filePath: "images/\(fileName)",
                    transformMatrix: Self.rows(transform)
                ))
                self.acceptedFrames = self.captured.count
                self.lastAcceptedTransform = transform
                self.lastAcceptedTimestamp = frame.timestamp
                self.trackingMessage = self.acceptedFrames >= self.targetFrames
                    ? "撮影完了。生成へ進めます。"
                    : "\(self.captureBand)から、対象を中央に保ってゆっくり移動"
                if self.acceptedFrames >= self.targetFrames { self.finishCapture() }
            }
        }
    }

    private func writeJPEG(pixelBuffer: CVPixelBuffer, to url: URL) -> Bool {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cg = ciContext.createCGImage(image, from: image.extent) else { return false }
        guard let data = UIImage(cgImage: cg).jpegData(compressionQuality: 0.86) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private func writeTransformsJSON() throws {
        guard let projectURL, let intrinsics = firstIntrinsics, let resolution = firstResolution else {
            throw NSError(domain: "SplatLab", code: 1, userInfo: [NSLocalizedDescriptionKey: "カメラ情報が不足しています"])
        }
        let frames = captured.map { NerfstudioFrame(filePath: $0.filePath, transformMatrix: $0.transformMatrix) }
        let dataset = NerfstudioDataset(
            cameraModel: "OPENCV",
            flX: intrinsics[0,0], flY: intrinsics[1,1],
            cx: intrinsics[2,0], cy: intrinsics[2,1],
            w: Int(resolution.width), h: Int(resolution.height),
            frames: frames
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(dataset).write(to: projectURL.appendingPathComponent("transforms.json"), options: .atomic)
    }

    private func movedEnough(from a: simd_float4x4, to b: simd_float4x4) -> Bool {
        let pa = SIMD3<Float>(a.columns.3.x, a.columns.3.y, a.columns.3.z)
        let pb = SIMD3<Float>(b.columns.3.x, b.columns.3.y, b.columns.3.z)
        let translation = simd_distance(pa, pb)
        let qa = simd_quatf(a)
        let qb = simd_quatf(b)
        let dot = min(1, max(-1, abs(simd_dot(qa.vector, qb.vector))))
        let angle = 2 * acos(dot)
        return translation >= 0.025 || angle >= 0.045
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
        let provider = CGDataProvider(data: Data(bytes) as CFData)
        let space = CGColorSpaceCreateDeviceRGB()
        guard let cg = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                               bytesPerRow: width * 4, space: space,
                               bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                               provider: provider!, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return nil }
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
        view.rendersCameraGrain = false
        model.attach(session: view.session)
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}
