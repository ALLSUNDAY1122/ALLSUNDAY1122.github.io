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
    @Published private(set) var libraryProjects: [ScanProjectSummary] = []
    @Published private(set) var trashProjects: [ScanProjectSummary] = []
    @Published private(set) var libraryStorageBytes: Int64 = 0
    @Published private(set) var activeManifest: ScanProjectManifest?

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
    private let projectStore = ScanProjectStore()
    private var loadedFromDisk = false

    override init() {
        super.init()
        refreshLibrary()
    }

    var canFinishCapture: Bool {
        acceptedFrames >= 24 &&
        featurePointCount >= 64 &&
        coverageSectorCount >= minimumCoverageSectors &&
        !isWritingFrame
    }

    var canRetryGeneration: Bool { datasetReady && projectURL != nil }
    var activeProjectCanProcess: Bool { datasetReady && projectURL != nil }
    var activeProjectHasRaw: Bool { activeManifest?.rawDataRetained == true }
    var activeProjectIsDraft: Bool { activeManifest?.stage == .capturing }

    var activeProjectCanResume: Bool {
        guard let stage = activeManifest?.stage,
              stage == .capturing || stage == .captured,
              let projectURL,
              (try? projectStore.loadCheckpoint(projectURL: projectURL)) != nil else { return false }
        return !loadedFromDisk || projectStore.hasWorldMap(projectURL: projectURL)
    }

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

    func refreshLibrary() {
        libraryProjects = projectStore.listProjects()
        trashProjects = projectStore.listTrash()
        libraryStorageBytes = projectStore.storageBytes(includeTrash: true)
    }

    func startCapture() {
        guard let session else { return }
        if projectURL != nil {
            returnToLibrary()
        }
        do {
            let created = try projectStore.createProject(title: "スキャン", targetFrames: targetFrames)
            projectURL = created.0
            imagesURL = created.0.appendingPathComponent("images", isDirectory: true)
            activeManifest = created.1
        } catch {
            phase = .failed("保存領域を準備できませんでした: \(error.localizedDescription)")
            return
        }

        resetCaptureMemory()
        loadedFromDisk = false
        phase = .capturing
        trackingMessage = "対象を中央に保ち、周囲をゆっくり1周してください"

        let config = makeWorldTrackingConfiguration()
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        UIApplication.shared.isIdleTimerDisabled = true
        refreshLibrary()
    }

    func finishCapture() {
        guard phase == .capturing, canFinishCapture else { return }
        persistWorldMapIfPossible()
        do {
            try writePointCloudPLY()
            try writeTransformsJSON()
            persistCaptureCheckpoint(force: true, stage: .captured)
            if let projectURL {
                activeManifest = try projectStore.updateManifest(projectURL: projectURL) { manifest in
                    manifest.stage = .captured
                    manifest.acceptedFrames = self.acceptedFrames
                    manifest.targetFrames = self.targetFrames
                    manifest.featurePointCount = self.featurePointCount
                    manifest.coverageSectorCount = self.coverageSectorCount
                    manifest.rawDataRetained = true
                    manifest.lastError = nil
                }
            }
            datasetReady = true
            phase = .captured
            trackingMessage = "必要な撮影情報がそろいました"
            session?.pause()
            UIApplication.shared.isIdleTimerDisabled = false
            refreshLibrary()
        } catch {
            datasetReady = false
            markActiveProjectFailed("撮影データを準備できませんでした: \(error.localizedDescription)")
        }
    }

    /// Saves an in-progress scan without destroying raw data. A later cold resume requires an ARWorldMap.
    func saveDraftAndReturnToLibrary() {
        guard phase == .capturing else {
            returnToLibrary()
            return
        }
        persistWorldMapIfPossible()
        persistCaptureCheckpoint(force: true, stage: .capturing)
        session?.pause()
        UIApplication.shared.isIdleTimerDisabled = false
        clearActiveRuntimeState()
        refreshLibrary()
    }

    /// Leaves a completed/captured project in the local library.
    func returnToLibrary() {
        if phase == .capturing {
            persistWorldMapIfPossible()
            persistCaptureCheckpoint(force: true, stage: .capturing)
        }
        session?.pause()
        UIApplication.shared.isIdleTimerDisabled = false
        clearActiveRuntimeState()
        refreshLibrary()
    }

    /// Backward-compatible destructive action. S5 makes it recoverable by moving the project to Recently Deleted.
    func discardAndReset() {
        session?.pause()
        if let projectURL {
            do {
                try projectStore.moveToTrash(projectURL: projectURL)
            } catch {
                phase = .failed("スキャンを最近削除した項目へ移動できませんでした: \(error.localizedDescription)")
                return
            }
        }
        UIApplication.shared.isIdleTimerDisabled = false
        clearActiveRuntimeState()
        refreshLibrary()
    }

    func openProject(id: String) {
        do {
            let summary = try projectStore.loadProject(id: id)
            session?.pause()
            projectURL = summary.projectURL
            imagesURL = summary.projectURL.appendingPathComponent("images", isDirectory: true)
            activeManifest = summary.manifest
            loadedFromDisk = true
            restoreRuntimeState(from: summary)
            if let result = summary.resultURL {
                resultURL = result
                phase = .finished
            } else {
                phase = .captured
            }
        } catch {
            clearActiveRuntimeState()
            phase = .failed("保存済みスキャンを開けませんでした: \(error.localizedDescription)")
        }
    }

    func resumeActiveCapture() {
        guard let session, let projectURL, activeProjectCanResume else { return }
        do {
            let checkpoint = try projectStore.loadCheckpoint(projectURL: projectURL)
            restoreCheckpoint(checkpoint)
            let config = makeWorldTrackingConfiguration()
            var runOptions: ARSession.RunOptions = []
            var resumeMessage = "撮影を再開しました。続きから対象の周囲を回ってください"

            if loadedFromDisk {
                let worldMapURL = projectStore.worldMapURL(projectURL: projectURL)
                guard let data = try? Data(contentsOf: worldMapURL),
                      let worldMap = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
                    phase = .failed("撮影済みrawデータは保存されていますが、カメラ位置を復元する情報がありません。既存データは削除されていません。")
                    return
                }
                config.initialWorldMap = worldMap
                runOptions = [.resetTracking, .removeExistingAnchors]
                resumeMessage = "保存位置を再確認しています。対象を映しながらゆっくり動かしてください"
            }

            activeManifest = try projectStore.updateManifest(projectURL: projectURL) { manifest in
                manifest.stage = .capturing
                manifest.lastError = nil
                manifest.rawDataRetained = true
            }
            session.run(config, options: runOptions)
            trackingMessage = resumeMessage
            loadedFromDisk = false
            phase = .capturing
            UIApplication.shared.isIdleTimerDisabled = true
            refreshLibrary()
        } catch {
            phase = .failed("保存した撮影状態を復元できませんでした: \(error.localizedDescription)")
        }
    }

    func retryGeneration() {
        guard canRetryGeneration else { return }
        phase = .captured
        train()
    }

    func reprocessCurrentSplat() {
        guard let projectURL else { return }
        do {
            _ = try projectStore.reprocessRequest(projectURL: projectURL, representation: .splat)
            datasetReady = true
            phase = .captured
            train()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Stable S5 handoff for S4: S4 can request the same retained raw package for Mesh reconstruction.
    func reprocessRequest(for representation: ScanRepresentationKind) throws -> ScanReprocessRequest {
        guard let projectURL else { throw ScanProjectStoreError.projectNotFound }
        return try projectStore.reprocessRequest(projectURL: projectURL, representation: representation)
    }

    func clearRawDataForActiveProject() {
        guard let projectURL, resultURL != nil else { return }
        do {
            try projectStore.clearRawData(projectURL: projectURL)
            datasetReady = false
            captured.removeAll()
            featurePoints.removeAll()
            coverageSectors.removeAll()
            acceptedFrames = activeManifest?.acceptedFrames ?? acceptedFrames
            activeManifest = try projectStore.loadManifest(projectURL: projectURL)
            refreshLibrary()
        } catch {
            phase = .failed("rawデータを整理できませんでした: \(error.localizedDescription)")
        }
    }

    func renameActiveProject(_ value: String) {
        guard let projectURL else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            activeManifest = try projectStore.updateManifest(projectURL: projectURL) { manifest in
                manifest.title = String(trimmed.prefix(80))
            }
            refreshLibrary()
        } catch {
            trackingMessage = "名前を保存できませんでした"
        }
    }

    func deleteProject(id: String) {
        do {
            let summary = try projectStore.loadProject(id: id)
            try projectStore.moveToTrash(projectURL: summary.projectURL)
            if activeManifest?.id == id { clearActiveRuntimeState() }
            refreshLibrary()
        } catch {
            phase = .failed("スキャンを削除できませんでした: \(error.localizedDescription)")
        }
    }

    func restoreProject(id: String) {
        do {
            try projectStore.restoreFromTrash(id: id)
            refreshLibrary()
        } catch {
            phase = .failed("スキャンを復元できませんでした: \(error.localizedDescription)")
        }
    }

    func permanentlyDeleteProject(id: String) {
        do {
            try projectStore.permanentlyDeleteFromTrash(id: id)
            refreshLibrary()
        } catch {
            phase = .failed("スキャンを完全に削除できませんでした: \(error.localizedDescription)")
        }
    }

    func handleScenePhase(_ scenePhase: ScenePhase) {
        guard scenePhase != .active, phase == .capturing else { return }
        persistCaptureCheckpoint(force: true, stage: .capturing)
        persistWorldMapIfPossible()
    }

    func train(iterations: Int = 2_000) {
        guard phase == .captured, datasetReady, let projectURL else { return }
        phase = .training
        trainingProgress = 0
        trainingIteration = 0
        splatCount = 0
        UIApplication.shared.isIdleTimerDisabled = true
        do {
            activeManifest = try projectStore.updateManifest(projectURL: projectURL) { manifest in
                manifest.stage = .processing
                manifest.lastError = nil
            }
        } catch {
            failTraining("生成状態を保存できませんでした: \(error.localizedDescription)")
            return
        }

        let path = projectURL.path
        Task.detached(priority: .userInitiated) { [weak self] in
            autoreleasepool {
                let dataset = GaussianDataset(path: path, downscaleFactor: 4.0, evalMode: false)
                guard dataset.numTrain >= 3 else {
                    Task { @MainActor [weak self] in
                        self?.failTraining("撮影画像を読み込めませんでした。生成をもう一度試してください")
                    }
                    return
                }

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
                        let iteration = stats.iteration
                        let count = stats.splatCount
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            self.trainingIteration = iteration
                            self.splatCount = count
                            self.trainingProgress = min(1, Double(iteration) / Double(iterations))
                        }
                    }
                }

                msplatSync()
                let pending = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
                try? FileManager.default.removeItem(at: pending)
                trainer.exportSplat(to: pending.path)
                msplatSync()

                guard let attributes = try? FileManager.default.attributesOfItem(atPath: pending.path),
                      let sizeNumber = attributes[.size] as? NSNumber,
                      sizeNumber.intValue > 0,
                      sizeNumber.intValue % 32 == 0 else {
                    Task { @MainActor [weak self] in
                        self?.failTraining("生成した3Dデータを保存できませんでした。生成をもう一度試してください")
                    }
                    return
                }

                let detachedStore = ScanProjectStore(rootURL: projectURL.deletingLastPathComponent())
                let output: URL
                do {
                    output = try detachedStore.commitPendingSplat(projectURL: projectURL)
                } catch {
                    Task { @MainActor [weak self] in
                        self?.failTraining("生成した3Dデータの安全な保存を完了できませんでした。生成をもう一度試してください")
                    }
                    return
                }

                let rendered = trainer.render(cameraIndex: 0)
                let preview = Self.makeImage(from: rendered)
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    do {
                        if let jpeg = preview?.jpegData(compressionQuality: 0.82) {
                            try? self.projectStore.setThumbnail(data: jpeg, projectURL: projectURL)
                        }
                        self.activeManifest = try self.projectStore.updateManifest(projectURL: projectURL) { manifest in
                            manifest.stage = .finished
                            manifest.outputs[ScanRepresentationKind.splat.rawValue] = output.lastPathComponent
                            manifest.lastError = nil
                        }
                    } catch {
                        self.failTraining("3Dは生成できましたが、ライブラリ情報を保存できませんでした: \(error.localizedDescription)")
                        return
                    }
                    self.resultURL = output
                    self.previewImage = preview
                    self.trainingProgress = 1
                    self.phase = .finished
                    UIApplication.shared.isIdleTimerDisabled = false
                    self.refreshLibrary()
                }
            }
        }
    }

    func restartAfterSessionInterruption() {
        guard phase == .capturing, let activeSession = session else { return }
        // Do not reset tracking here: the stored camera transforms and feature points share this world coordinate system.
        let config = makeWorldTrackingConfiguration()
        activeSession.run(config)
        trackingMessage = "位置を再確認しています。対象を中央にしてゆっくり動かしてください"
    }

    private func failTraining(_ message: String) {
        phase = .failed(message)
        trackingMessage = message
        UIApplication.shared.isIdleTimerDisabled = false
        markManifest(stage: .failed, error: message)
        refreshLibrary()
    }

    private func markActiveProjectFailed(_ message: String) {
        phase = .failed(message)
        trackingMessage = message
        UIApplication.shared.isIdleTimerDisabled = false
        markManifest(stage: .failed, error: message)
        refreshLibrary()
    }

    private func failCaptureStorage() {
        let message = "撮影データを保存できませんでした。iPhoneの空き容量を確認して、このスキャンを開き直してから撮影を再開してください"
        datasetReady = false
        trackingMessage = message
        phase = .failed(message)
        session?.pause()
        UIApplication.shared.isIdleTimerDisabled = false
        markManifest(stage: .failed, error: message)
        refreshLibrary()
    }

    private func markManifest(stage: ScanProjectStage, error: String?) {
        guard let projectURL else { return }
        activeManifest = try? projectStore.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = stage
            manifest.lastError = error
            manifest.acceptedFrames = self.acceptedFrames
            manifest.featurePointCount = self.featurePointCount
            manifest.coverageSectorCount = self.coverageSectorCount
        }
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
        guard let imagesURL else {
            failCaptureStorage()
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

        captureQueue.async { [weak self] in
            let fileName = String(format: "frame_%05d.jpg", index)
            let fileURL = imagesURL.appendingPathComponent(fileName)
            let success = (try? jpegData.write(to: fileURL, options: .atomic)) != nil
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isWritingFrame = false
                guard self.phase == .capturing else { return }
                guard success else {
                    self.failCaptureStorage()
                    return
                }
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
                self.persistCaptureCheckpoint(force: self.acceptedFrames <= 3 || self.acceptedFrames % 3 == 0, stage: .capturing)
                if self.acceptedFrames == 1, let projectURL = self.projectURL {
                    try? self.projectStore.setThumbnail(from: fileURL, projectURL: projectURL)
                    self.activeManifest = try? self.projectStore.loadManifest(projectURL: projectURL)
                }
                if self.acceptedFrames % 12 == 0 {
                    self.persistWorldMapIfPossible()
                }

                if self.acceptedFrames >= self.targetFrames && self.canFinishCapture {
                    self.finishCapture()
                } else if self.acceptedFrames >= self.maxFrames && !self.canFinishCapture {
                    let message = "十分な方向から撮影できませんでした。対象を中央に置き、反対側まで回り込んでもう一度撮影してください"
                    self.persistCaptureCheckpoint(force: true, stage: .capturing)
                    self.persistWorldMapIfPossible()
                    self.phase = .failed(message)
                    self.trackingMessage = message
                    self.markManifest(stage: .failed, error: message)
                    self.session?.pause()
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            }
        }
    }

    private func persistCaptureCheckpoint(force: Bool, stage: ScanProjectStage) {
        guard let projectURL else { return }
        if !force {
            // Keep manifest current even when the heavier binary point-cloud checkpoint is throttled.
            activeManifest = try? projectStore.updateManifest(projectURL: projectURL) { manifest in
                manifest.stage = stage
                manifest.acceptedFrames = self.acceptedFrames
                manifest.targetFrames = self.targetFrames
                manifest.featurePointCount = self.featurePointCount
                manifest.coverageSectorCount = self.coverageSectorCount
                manifest.rawDataRetained = true
            }
            return
        }
        let storedFrames = captured.map {
            StoredCapturedFrame(
                id: $0.id,
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
        let storedPoints = featurePoints.map { key, value in
            StoredFeaturePoint(id: key, x: value.x, y: value.y, z: value.z)
        }
        let center = estimatedTargetCenter.map { StoredVector3(x: $0.x, y: $0.y, z: $0.z) }
        let checkpoint = ScanCaptureCheckpoint(
            frames: storedFrames,
            featurePoints: storedPoints,
            coverageSectors: Array(coverageSectors),
            estimatedTargetCenter: center,
            lastAcceptedTransform: lastAcceptedTransform.map(Self.rows),
            lastAcceptedTimestamp: lastAcceptedTimestamp
        )
        do {
            try projectStore.saveCheckpoint(checkpoint, projectURL: projectURL)
            activeManifest = try projectStore.updateManifest(projectURL: projectURL) { manifest in
                manifest.stage = stage
                manifest.acceptedFrames = self.acceptedFrames
                manifest.targetFrames = self.targetFrames
                manifest.featurePointCount = self.featurePointCount
                manifest.coverageSectorCount = self.coverageSectorCount
                manifest.rawDataRetained = true
                manifest.lastError = nil
            }
        } catch {
            trackingMessage = "撮影は続けられますが、途中状態の保存に失敗しました"
        }
    }

    private func persistWorldMapIfPossible() {
        guard let session, let projectURL else { return }
        let targetURL = projectStore.worldMapURL(projectURL: projectURL)
        session.getCurrentWorldMap { worldMap, _ in
            guard let worldMap,
                  let data = try? NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true) else { return }
            try? data.write(to: targetURL, options: .atomic)
        }
    }

    private func restoreRuntimeState(from summary: ScanProjectSummary) {
        resetCaptureMemory()
        acceptedFrames = summary.manifest.acceptedFrames
        targetFrames = summary.manifest.targetFrames
        featurePointCount = summary.manifest.featurePointCount
        coverageSectorCount = summary.manifest.coverageSectorCount
        datasetReady = (try? projectStore.reprocessRequest(projectURL: summary.projectURL, representation: .splat)) != nil
        resultURL = summary.resultURL
        if let thumbnail = summary.thumbnailURL {
            previewImage = UIImage(contentsOfFile: thumbnail.path)
        }
        if let checkpoint = try? projectStore.loadCheckpoint(projectURL: summary.projectURL) {
            restoreCheckpoint(checkpoint)
        }
        if let error = summary.manifest.lastError {
            trackingMessage = error
        } else if summary.manifest.stage == .capturing || summary.manifest.stage == .captured {
            trackingMessage = activeProjectCanResume
                ? "保存した撮影状態を復元しました"
                : "撮影rawデータを保存しています"
        } else {
            trackingMessage = "保存済みスキャンを開きました"
        }
    }

    private func restoreCheckpoint(_ checkpoint: ScanCaptureCheckpoint) {
        captured = checkpoint.frames.map {
            CapturedView(
                id: $0.id,
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
        featurePoints = Dictionary(uniqueKeysWithValues: checkpoint.featurePoints.map {
            ($0.id, SIMD3<Float>($0.x, $0.y, $0.z))
        })
        coverageSectors = Set(checkpoint.coverageSectors)
        estimatedTargetCenter = checkpoint.estimatedTargetCenter.map { SIMD3<Float>($0.x, $0.y, $0.z) }
        lastAcceptedTransform = checkpoint.lastAcceptedTransform.flatMap(Self.matrix(from:))
        lastAcceptedTimestamp = checkpoint.lastAcceptedTimestamp
        acceptedFrames = captured.count
        featurePointCount = featurePoints.count
        coverageSectorCount = coverageSectors.count
    }

    private func resetCaptureMemory() {
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
    }

    private func clearActiveRuntimeState() {
        projectURL = nil
        imagesURL = nil
        activeManifest = nil
        loadedFromDisk = false
        resetCaptureMemory()
        phase = .ready
        trackingMessage = "対象を中央に置いて開始してください"
    }

    private func makeWorldTrackingConfiguration() -> ARWorldTrackingConfiguration {
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        config.isLightEstimationEnabled = true
        config.environmentTexturing = .none
        return config
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
        let points = featurePoints.values
        var ply = "ply\nformat ascii 1.0\nelement vertex \(points.count)\nproperty float x\nproperty float y\nproperty float z\nend_header\n"
        ply.reserveCapacity(points.count * 40)
        for p in points {
            ply += "\(p.x) \(p.y) \(p.z)\n"
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
        case .relocalizing: return "保存位置を再確認しています。対象を映しながらゆっくり動かしてください"
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

    private static func matrix(from rows: [[Float]]) -> simd_float4x4? {
        guard rows.count == 4, rows.allSatisfy({ $0.count == 4 }) else { return nil }
        var matrix = matrix_identity_float4x4
        for row in 0..<4 {
            for column in 0..<4 {
                matrix[column][row] = rows[row][column]
            }
        }
        return matrix
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
