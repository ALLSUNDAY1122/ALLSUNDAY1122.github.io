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
    let depthFilePath: String?
    let depthWidth: Int?
    let depthHeight: Int?
    let depthBytesPerRow: Int?

    init(
        id: Int,
        filePath: String,
        transformMatrix: [[Float]],
        flX: Float,
        flY: Float,
        cx: Float,
        cy: Float,
        w: Int,
        h: Int,
        depthFilePath: String? = nil,
        depthWidth: Int? = nil,
        depthHeight: Int? = nil,
        depthBytesPerRow: Int? = nil
    ) {
        self.id = id
        self.filePath = filePath
        self.transformMatrix = transformMatrix
        self.flX = flX
        self.flY = flY
        self.cx = cx
        self.cy = cy
        self.w = w
        self.h = h
        self.depthFilePath = depthFilePath
        self.depthWidth = depthWidth
        self.depthHeight = depthHeight
        self.depthBytesPerRow = depthBytesPerRow
    }
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

struct CaptureManifest: Codable {
    let version: Int
    let frameCount: Int
    let depthFrameCount: Int
    let lidarIgnored: Bool
    let captureMode: String
    let orbitSectorCount: Int
    let elevationBandCount: Int
    let viewDirectionSectorCount: Int
    let spatialCellCount: Int
    let pathLengthMeters: Float
    let activeCaptureSeconds: Double
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

    private struct DepthPayload: Sendable {
        let data: Data
        let width: Int
        let height: Int
        let bytesPerRow: Int
    }

    private enum WorldMapArchiveResult: Sendable {
        case data(Data)
        case failed(String)
    }

    private enum WorldMapPersistenceOutcome: Sendable {
        case saved
        case reusedExisting(String)
        case failed(String)
    }

    @Published var phase: Phase = .ready
    @Published var acceptedFrames = 0
    @Published var targetFrames = 72
    @Published var featurePointCount = 0
    @Published var coverageSectorCount = 0
    @Published var trackingMessage = "対象を中央に置いて開始してください"
    @Published var trainingProgress: Double = 0
    @Published var trainingIteration = 0
    @Published var splatCount = 0
    @Published var resultURL: URL?
    @Published var previewImage: UIImage?
    @Published var isCapturePaused = false
    @Published var activeCaptureSeconds: Double = 0
    @Published var ignoreLiDAR = false
    @Published var depthCaptureActive = false
    @Published private(set) var isWorldMapPersistencePending = false

    let coverageSectorTotal = 12
    let minimumCoverageSectors = 8
    private let maxFrames = 240
    private let recoveryFramesRequired = 6

    private(set) weak var session: ARSession?
    private var projectURL: URL?
    private var imagesURL: URL?
    private var depthURL: URL?
    private var captured: [CapturedView] = []
    private var featurePoints: [UInt64: SIMD3<Float>] = [:]
    private var coverageSectors: Set<Int> = []
    private var elevationBands: Set<Int> = []
    private var viewDirectionSectors: Set<Int> = []
    private var spatialCells: Set<CaptureGridCell> = []
    private var estimatedTargetCenter: SIMD3<Float>?
    private var estimatedSubjectDistance: Float?
    private var lastAcceptedTransform: simd_float4x4?
    private var lastAcceptedTimestamp: TimeInterval = 0
    private var previousCoveragePosition: SIMD3<Float>?
    private var pathLengthMeters: Float = 0
    private var datasetReady = false
    private var pendingTrainingTarget = SplatReconstructionPolicy.standardIterations
    private let resourceGuard = SplatResourceGuard()
    private let trainingRunGate = SplatTrainingRunGate()
    private let projectStore = ScanProjectStore()
    private var memoryWarningObserver: NSObjectProtocol?
    private let ciContext = CIContext(options: [.cacheIntermediates: false])
    private let captureQueue = DispatchQueue(label: "jp.allsunday1122.splatlab.capture", qos: .userInitiated)
    private var isWritingFrame = false
    private var trackingNeedsRecovery = false
    private var stableTrackingFrames = 0
    private var activeCaptureStartedAt: TimeInterval?
    private var accumulatedCaptureSeconds: Double = 0
    private var systemPausedCapture = false
    private var pendingResumeWorldMap: ARWorldMap?
    private var requiresWorldMapForResume = false
    private var periodicWorldMapPersistenceTask: Task<Void, Never>?
    private var worldMapPersistenceGeneration = 0
    private var worldMapPersistenceWarning: String?
    private var userPauseRequested = false

    var lidarControlAvailable: Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }

    var canFinishCapture: Bool {
        acceptedFrames >= 24 &&
        featurePointCount >= 64 &&
        coverageSatisfied &&
        !isWritingFrame &&
        !trackingNeedsRecovery &&
        !isWorldMapPersistencePending
    }

    var canRetryGeneration: Bool {
        datasetReady && projectURL != nil && trainingRunGate.isIdle
    }

    var progressText: String { "撮影カバー \(coverageSectorCount) / \(coverageSectorTotal)" }

    var captureBand: String {
        if isWorldMapPersistencePending { return "位置を保存中" }
        if isCapturePaused { return "一時停止中" }
        if trackingNeedsRecovery { return "位置を復旧中" }
        if coverageSectorCount < 4 { return "ゆっくり位置を変える" }
        if coverageSectorCount < minimumCoverageSectors { return "反対側・別の方向へ" }
        if !coverageSatisfied { return "高さか移動範囲を増やす" }
        return "撮影は十分です"
    }

    var captureQualityText: String {
        if isWorldMapPersistencePending {
            return "撮影位置を安全に保存しています。完了するまでこの画面を維持します"
        }
        if isCapturePaused {
            return "撮影を一時停止しています。再開すると同じスキャンへ続けて追加できます"
        }
        if trackingNeedsRecovery {
            return "前に撮った場所を映しながら、ゆっくり動かして位置を合わせてください"
        }

        switch CapturePolicy.longScanStage(seconds: activeCaptureSeconds) {
        case .stopRecommended:
            return "撮影が3分を超えています。発熱と保存容量を抑えるため、必要な範囲を優先し、十分なら停止して生成してください"
        case .caution:
            return "撮影が90秒を超えています。必要な範囲を優先し、十分なら停止して生成してください"
        case .normal:
            break
        }

        if acceptedFrames < 24 {
            return "同じ場所に留まらず、ゆっくり連続して位置を変えてください"
        }
        if featurePointCount < 64 {
            return "立体の手がかりが不足しています。明るさや背景を変えて少し撮り足してください"
        }

        switch coverageMode {
        case .object:
            if coverageSectors.count >= 6 && elevationBands.count < 2 {
                return "反対側まで回れています。少し高い位置か低い位置からも撮り足してください"
            }
            if !coverageSatisfied {
                return "対象物の片側だけでは完了しません。対象を中央に保ち、反対側まで回って撮ってください"
            }
        case .scene:
            if !coverageSatisfied {
                return "部屋や屋外では位置を移しながら、別の方向も重ねて撮ってください"
            }
        }

        if acceptedFrames < targetFrames {
            return "生成できます。もう少し撮ると安定しやすくなります"
        }
        return "必要な方向がそろいました。停止して生成できます"
    }

    var trainingStageText: String {
        switch trainingProgress {
        case ..<0.18: return "写真の位置関係を確認しています"
        case ..<0.58: return "立体の形を組み立てています"
        case ..<0.88: return "色と細部を整えています"
        default: return "見返せる形に仕上げています"
        }
    }

    private var coverageMode: CaptureCoverageMode {
        CapturePolicy.coverageMode(subjectDistance: estimatedSubjectDistance)
    }

    private var coverageSatisfied: Bool {
        CapturePolicy.coverageSatisfied(
            subjectDistance: estimatedSubjectDistance,
            orbitSectors: coverageSectors.count,
            elevationBands: elevationBands.count,
            viewDirectionSectors: viewDirectionSectors.count,
            spatialCells: spatialCells.count,
            pathLength: pathLengthMeters
        )
    }

    func attach(session: ARSession) {
        if memoryWarningObserver == nil {
            let passResourceGuard = resourceGuard
            memoryWarningObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: .main
            ) { _ in
                passResourceGuard.noteMemoryWarning()
            }
        }
        guard self.session !== session else { return }
        self.session = session
        session.delegate = self
    }

    func startCapture() {
        guard let session else { return }
        do {
            let created = try projectStore.createProject(title: "スキャン", targetFrames: targetFrames)
            let project = created.0
            let images = project.appendingPathComponent("images", isDirectory: true)
            let depth = project.appendingPathComponent("depth", isDirectory: true)
            try FileManager.default.createDirectory(at: depth, withIntermediateDirectories: true)
            projectURL = project
            imagesURL = images
            depthURL = depth
        } catch {
            phase = .failed("保存領域を準備できませんでした: \(error.localizedDescription)")
            return
        }

        resetCaptureStateForNewProject()
        pendingTrainingTarget = SplatReconstructionPolicy.standardIterations
        phase = .capturing
        isCapturePaused = false
        trackingNeedsRecovery = true
        stableTrackingFrames = 0
        trackingMessage = "対象へ向けたまま、ゆっくり位置を変えてください"
        beginActiveCaptureTiming()
        session.run(makeWorldTrackingConfiguration(), options: [.resetTracking, .removeExistingAnchors])
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func pauseCapture() {
        guard phase == .capturing,
              !isCapturePaused,
              !isWorldMapPersistencePending,
              let projectURL else { return }

        closeActiveCaptureTiming()
        isCapturePaused = true
        userPauseRequested = true
        systemPausedCapture = false
        persistCaptureStateOrFail(stage: .capturing)
        guard phase == .capturing else { return }

        isWorldMapPersistencePending = true
        trackingMessage = "一時停止位置を安全に保存しています"
        let generation = worldMapPersistenceGeneration

        Task { @MainActor [weak self] in
            guard let self else { return }
            let outcome = await self.persistWorldMapForTransition(
                projectURL: projectURL,
                generation: generation
            )
            guard self.worldMapPersistenceGeneration == generation,
                  self.projectURL?.standardizedFileURL == projectURL.standardizedFileURL else { return }

            self.isWorldMapPersistencePending = false
            guard self.phase == .capturing else { return }

            switch outcome {
            case .saved:
                self.worldMapPersistenceWarning = nil
                self.session?.pause()
                self.trackingMessage = "撮影位置を保存して一時停止しました"
                UIApplication.shared.isIdleTimerDisabled = false
            case .reusedExisting(let warning):
                self.worldMapPersistenceWarning = warning
                self.session?.pause()
                self.trackingMessage = "最新位置の保存には失敗しましたが、直前の位置復元データを保持して一時停止しました"
                UIApplication.shared.isIdleTimerDisabled = false
            case .failed(let message):
                self.worldMapPersistenceWarning = message
                self.userPauseRequested = false
                self.systemPausedCapture = false
                self.isCapturePaused = false
                self.beginActiveCaptureTiming()
                self.trackingMessage = "位置復元情報を保存できないため一時停止を完了できませんでした。空き容量を確認し、アプリを閉じずに撮影を続けてください: \(message)"
                UIApplication.shared.isIdleTimerDisabled = true
            }
        }
    }

    func resumeCapture() {
        guard let session, !isWorldMapPersistencePending else { return }
        guard phase == .captured || (phase == .capturing && isCapturePaused) else { return }

        if requiresWorldMapForResume && pendingResumeWorldMap == nil {
            let message = "撮影済みrawデータは残っていますが、カメラ位置を復元する情報がありません。撮影の追加は行わず、保存済みデータから生成してください。"
            phase = .failed(message)
            trackingMessage = message
            UIApplication.shared.isIdleTimerDisabled = false
            return
        }

        if phase == .captured {
            datasetReady = false
            phase = .capturing
        }
        isCapturePaused = false
        userPauseRequested = false
        systemPausedCapture = false
        trackingNeedsRecovery = true
        stableTrackingFrames = 0
        beginActiveCaptureTiming()
        trackingMessage = requiresWorldMapForResume
            ? "保存位置を再確認しています。前に撮った場所を映しながらゆっくり動かしてください"
            : "前に撮った場所を映して位置を合わせています"
        persistCaptureStateOrFail(stage: .capturing)
        guard phase == .capturing else { return }

        let config = makeWorldTrackingConfiguration()
        var options: ARSession.RunOptions = []
        if let worldMap = pendingResumeWorldMap {
            config.initialWorldMap = worldMap
            options = [.resetTracking, .removeExistingAnchors]
        }
        session.run(config, options: options)
        pendingResumeWorldMap = nil
        requiresWorldMapForResume = false
        worldMapPersistenceWarning = nil
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func finishCapture() {
        guard phase == .capturing,
              canFinishCapture,
              !isWorldMapPersistencePending,
              let projectURL else { return }

        closeActiveCaptureTiming()
        isCapturePaused = true
        userPauseRequested = true
        do {
            try writeTransformsJSON()
            try writeCaptureManifest()
            try persistProjectSnapshot(stage: .captured)
            if let first = captured.first {
                try? projectStore.setThumbnail(
                    from: projectURL.appendingPathComponent(first.filePath),
                    projectURL: projectURL
                )
            }
            datasetReady = true
        } catch {
            isCapturePaused = false
            userPauseRequested = false
            datasetReady = false
            phase = .failed("撮影データを準備できませんでした: \(error.localizedDescription)")
            UIApplication.shared.isIdleTimerDisabled = false
            return
        }

        isWorldMapPersistencePending = true
        trackingMessage = "撮影位置を保存して生成準備を確定しています"
        let generation = worldMapPersistenceGeneration

        Task { @MainActor [weak self] in
            guard let self else { return }
            let outcome = await self.persistWorldMapForTransition(
                projectURL: projectURL,
                generation: generation
            )
            guard self.worldMapPersistenceGeneration == generation,
                  self.projectURL?.standardizedFileURL == projectURL.standardizedFileURL else { return }

            self.isWorldMapPersistencePending = false
            guard self.phase == .capturing else { return }
            self.session?.pause()
            self.isCapturePaused = false
            self.userPauseRequested = false
            self.phase = .captured
            UIApplication.shared.isIdleTimerDisabled = false

            switch outcome {
            case .saved:
                self.worldMapPersistenceWarning = nil
                self.trackingMessage = "必要な撮影情報と位置復元データを安全に保存しました"
            case .reusedExisting(let warning):
                self.worldMapPersistenceWarning = warning
                self.trackingMessage = "撮影データは保存済みです。位置復元には直前の保存データを使用します"
            case .failed(let message):
                self.worldMapPersistenceWarning = message
                self.trackingMessage = "撮影データは保存済みで3D生成できます。位置復元情報だけ保存できなかったため、再起動後は撮影を追加できません"
            }
        }
    }

    func discardAndReset() {
        invalidateWorldMapPersistence()
        closeActiveCaptureTiming()
        session?.pause()
        if let projectURL { try? projectStore.moveToTrash(projectURL: projectURL) }
        projectURL = nil
        imagesURL = nil
        depthURL = nil
        captured.removeAll()
        featurePoints.removeAll()
        coverageSectors.removeAll()
        elevationBands.removeAll()
        viewDirectionSectors.removeAll()
        spatialCells.removeAll()
        estimatedTargetCenter = nil
        estimatedSubjectDistance = nil
        previousCoveragePosition = nil
        pathLengthMeters = 0
        acceptedFrames = 0
        featurePointCount = 0
        coverageSectorCount = 0
        resultURL = nil
        previewImage = nil
        trainingProgress = 0
        trainingIteration = 0
        splatCount = 0
        datasetReady = false
        pendingTrainingTarget = SplatReconstructionPolicy.standardIterations
        isCapturePaused = false
        activeCaptureSeconds = 0
        accumulatedCaptureSeconds = 0
        depthCaptureActive = false
        trackingNeedsRecovery = false
        stableTrackingFrames = 0
        pendingResumeWorldMap = nil
        requiresWorldMapForResume = false
        userPauseRequested = false
        worldMapPersistenceWarning = nil
        phase = .ready
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func train() {
        pendingTrainingTarget = SplatReconstructionPolicy.standardIterations
        startTraining(targetIterations: pendingTrainingTarget)
    }

    func retryGeneration() {
        guard canRetryGeneration else { return }
        phase = .captured
        startTraining(targetIterations: pendingTrainingTarget)
    }

    func enhanceResult() {
        guard datasetReady,
              projectURL != nil,
              phase == .finished,
              trainingRunGate.isIdle else { return }
        let target = SplatReconstructionPolicy.enhancementTarget(from: trainingIteration)
        guard target > trainingIteration else { return }
        pendingTrainingTarget = target
        phase = .captured
        startTraining(targetIterations: target)
    }

    private func startTraining(targetIterations: Int) {
        guard phase == .captured, datasetReady, let projectURL else { return }
        guard let runToken = trainingRunGate.beginRun() else { return }
        let requestedTarget = min(SplatReconstructionPolicy.trainingHorizon, max(1, targetIterations))
        pendingTrainingTarget = requestedTarget
        do {
            try persistProjectSnapshot(stage: .processing)
        } catch {
            trainingRunGate.finishRun(runToken)
            failTraining("生成状態を保存できませんでした: \(error.localizedDescription)")
            return
        }
        phase = .training
        trainingProgress = 0
        splatCount = 0
        UIApplication.shared.isIdleTimerDisabled = true

        let path = projectURL.path
        let checkpoint = projectURL.appendingPathComponent("training.msplat-checkpoint")
        let geometryPoints = Array(featurePoints.values)
        let seedFrames = captured.map(Self.seedFrame(from:))
        let firstSourceFrame = captured.first
        let runContext = SplatReconstructionRunContext(
            runID: runToken.runID,
            sessionID: projectURL.lastPathComponent,
            sourceFrameCount: captured.count,
            sourceImageWidth: firstSourceFrame?.w,
            sourceImageHeight: firstSourceFrame?.h,
            effectiveDownscale: Double(SplatReconstructionPolicy.datasetDownscale),
            checkpointPath: checkpoint.lastPathComponent
        )
        let passResourceGuard = resourceGuard
        let passTrainingRunGate = trainingRunGate
        passResourceGuard.resetForPass()
        let runStartedAt = Date()
        let runStartUptime = ProcessInfo.processInfo.systemUptime
        let initialThermalState = splatThermalStateName(ProcessInfo.processInfo.thermalState)

        Task.detached(priority: .userInitiated) { [weak self] in
            defer {
                passTrainingRunGate.finishRun(runToken)
                Task { @MainActor [weak self] in
                    self?.objectWillChange.send()
                }
            }

            autoreleasepool {
                let writeEarlyReport: (
                    String,
                    SplatReconstructionPhase,
                    SplatReconstructionStopReason?,
                    String?
                ) -> Void = { outcome, phase, stopReason, errorMessage in
                    let report = passResourceGuard.makeReport(
                        startedAt: runStartedAt,
                        startUptime: runStartUptime,
                        passStartIteration: 0,
                        targetIteration: requestedTarget,
                        finalIteration: 0,
                        finalSplatCount: 0,
                        initialThermalState: initialThermalState,
                        finalThermalState: splatThermalStateName(ProcessInfo.processInfo.thermalState),
                        outcome: outcome,
                        context: runContext,
                        phase: phase,
                        stopReason: stopReason,
                        checkpointIteration: nil,
                        resumeOutcome: .notAttempted,
                        errorMessage: errorMessage
                    )
                    SplatReconstructionRunReport.write(report, projectURL: projectURL)
                }

                writeEarlyReport("running-preflight", .preflight, nil, nil)

                do {
                    let plyURL = projectURL.appendingPathComponent("points3D.ply")
                    if !FileManager.default.fileExists(atPath: plyURL.path) {
                        try Self.preparePointCloudPLY(
                            projectURL: projectURL,
                            points: geometryPoints,
                            frames: seedFrames
                        )
                    }
                } catch {
                    let message = "初期3Dデータを準備できませんでした: \(error.localizedDescription)"
                    writeEarlyReport("failed-preflight", .preflight, .other, message)
                    Task { @MainActor [weak self] in
                        self?.failTraining(message)
                    }
                    return
                }

                let preflightEvaluation = passResourceGuard.evaluate(splatCount: 0)
                if let reason = preflightEvaluation.reason {
                    let stopReason = SplatReconstructionStopReason(resourcePauseReason: reason)
                    let report = passResourceGuard.makeReport(
                        startedAt: runStartedAt,
                        startUptime: runStartUptime,
                        passStartIteration: 0,
                        targetIteration: requestedTarget,
                        finalIteration: 0,
                        finalSplatCount: 0,
                        initialThermalState: initialThermalState,
                        finalThermalState: splatThermalStateName(ProcessInfo.processInfo.thermalState),
                        outcome: "preflight-\(reason.rawValue)",
                        context: runContext,
                        phase: .preflight,
                        stopReason: stopReason,
                        checkpointIteration: nil,
                        resumeOutcome: .notAttempted
                    )
                    SplatReconstructionRunReport.write(report, projectURL: projectURL)
                    Task { @MainActor [weak self] in
                        self?.failTraining(reason.userMessage)
                    }
                    return
                }

                writeEarlyReport("running-dataset-init", .datasetInit, nil, nil)
                let dataset = GaussianDataset(
                    path: path,
                    downscaleFactor: SplatReconstructionPolicy.datasetDownscale,
                    evalMode: false
                )
                guard dataset.numTrain >= 3 else {
                    let message = "撮影画像を読み込めませんでした。生成をもう一度試してください"
                    writeEarlyReport("failed-dataset-init", .datasetInit, .other, message)
                    Task { @MainActor [weak self] in
                        self?.failTraining(message)
                    }
                    return
                }

                let config = SplatReconstructionPolicy.makeConfig()
                writeEarlyReport("running-trainer-init", .trainerInit, nil, nil)
                let trainer = GaussianTrainer(dataset: dataset, config: config)

                let checkpointExists = FileManager.default.fileExists(atPath: checkpoint.path)
                let loadedCheckpointIteration: Int?
                if checkpointExists {
                    writeEarlyReport("running-checkpoint-load", .checkpointLoad, nil, nil)
                    loadedCheckpointIteration = trainer.loadCheckpoint(from: checkpoint.path)
                } else {
                    loadedCheckpointIteration = nil
                }

                let resumedIteration = trainer.iteration
                let resumeOutcome = SplatCheckpointResumeOutcome.classify(
                    checkpointExists: checkpointExists,
                    loadedIteration: loadedCheckpointIteration
                )
                let effectiveTarget = SplatReconstructionPolicy.boundedTarget(
                    requestedTarget,
                    resumedIteration: resumedIteration
                )
                let passStart = resumedIteration
                let writeRunReport: (
                    String,
                    SplatReconstructionPhase,
                    SplatReconstructionStopReason?,
                    Int,
                    Int,
                    Int?,
                    String?
                ) -> Void = { outcome, phase, stopReason, finalIteration, finalSplatCount, checkpointIteration, errorMessage in
                    let report = passResourceGuard.makeReport(
                        startedAt: runStartedAt,
                        startUptime: runStartUptime,
                        passStartIteration: passStart,
                        targetIteration: effectiveTarget,
                        finalIteration: finalIteration,
                        finalSplatCount: finalSplatCount,
                        initialThermalState: initialThermalState,
                        finalThermalState: splatThermalStateName(ProcessInfo.processInfo.thermalState),
                        outcome: outcome,
                        context: runContext,
                        phase: phase,
                        stopReason: stopReason,
                        checkpointIteration: checkpointIteration,
                        resumeOutcome: resumeOutcome,
                        errorMessage: errorMessage
                    )
                    SplatReconstructionRunReport.write(report, projectURL: projectURL)
                }
                let checkpointSaveFailureMessage = "再開用チェックポイントを保存できなかったため、安全のため生成を停止しました。撮影データは保持しています。空き容量を確認してから生成をもう一度試してください"
                let failCheckpointSave: (String, Int, Int) -> Void = { outcome, iteration, count in
                    writeRunReport(
                        outcome,
                        .checkpointSave,
                        .trainerError,
                        iteration,
                        count,
                        nil,
                        checkpointSaveFailureMessage
                    )
                    Task { @MainActor [weak self] in
                        self?.failTraining(checkpointSaveFailureMessage)
                    }
                }

                if checkpointExists && loadedCheckpointIteration == nil {
                    let message = "保存済みチェックポイントを再開できませんでした。元の撮影データは保持しています"
                    writeRunReport(
                        "failed-checkpoint-load",
                        .checkpointLoad,
                        .trainerError,
                        0,
                        trainer.splatCount,
                        nil,
                        message
                    )
                    Task { @MainActor [weak self] in
                        self?.failTraining(message)
                    }
                    return
                }

                let initialResourceEvaluation = passResourceGuard.evaluate(splatCount: trainer.splatCount)
                if let reason = initialResourceEvaluation.reason {
                    msplatSync()
                    guard trainer.saveCheckpoint(to: checkpoint.path) else {
                        failCheckpointSave(
                            "failed-checkpoint-save-resource-pause",
                            resumedIteration,
                            trainer.splatCount
                        )
                        return
                    }
                    writeRunReport(
                        "paused-\(reason.rawValue)",
                        checkpointExists ? .checkpointLoad : .trainerInit,
                        SplatReconstructionStopReason(resourcePauseReason: reason),
                        resumedIteration,
                        trainer.splatCount,
                        resumedIteration,
                        nil
                    )
                    Task { @MainActor [weak self] in
                        self?.failTraining(reason.userMessage)
                    }
                    return
                }

                if resumedIteration > 0 {
                    let resumedCount = trainer.splatCount
                    let resumedProgress = min(1, Double(resumedIteration) / Double(max(1, effectiveTarget)))
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.trainingIteration = resumedIteration
                        self.splatCount = resumedCount
                        self.trainingProgress = resumedProgress
                    }
                }

                if resumedIteration < effectiveTarget {
                    writeRunReport(
                        "running-training-step",
                        .trainingStep,
                        nil,
                        resumedIteration,
                        trainer.splatCount,
                        checkpointExists ? resumedIteration : nil,
                        nil
                    )
                    for _ in resumedIteration..<effectiveTarget {
                        if Task.isCancelled {
                            msplatSync()
                            let iteration = trainer.iteration
                            let count = trainer.splatCount
                            guard trainer.saveCheckpoint(to: checkpoint.path) else {
                                failCheckpointSave(
                                    "cancelled-checkpoint-save-failed",
                                    iteration,
                                    count
                                )
                                return
                            }
                            let message = "生成タスクがキャンセルされました"
                            writeRunReport(
                                "cancelled",
                                .trainingStep,
                                .cancellation,
                                iteration,
                                count,
                                iteration,
                                message
                            )
                            Task { @MainActor [weak self] in
                                self?.failTraining(message)
                            }
                            return
                        }
                        let stats = trainer.step()
                        let iteration = stats.iteration
                        let shouldReport = iteration % 20 == 0 || iteration >= effectiveTarget
                        let thermalCheck = iteration % SplatReconstructionPolicy.thermalCheckInterval == 0
                        let thermalPause = thermalCheck && SplatReconstructionPolicy.requiresThermalPause(
                            ProcessInfo.processInfo.thermalState
                        )
                        let checkpointDue = iteration % SplatReconstructionPolicy.checkpointInterval == 0
                        let shouldCheckResources = iteration % 20 == 0 || checkpointDue
                        let resourceEvaluation = shouldCheckResources
                            ? passResourceGuard.evaluate(splatCount: stats.splatCount)
                            : nil
                        let resourcePauseReason = resourceEvaluation?.reason

                        if checkpointDue || thermalPause || resourcePauseReason != nil {
                            msplatSync()
                            guard trainer.saveCheckpoint(to: checkpoint.path) else {
                                failCheckpointSave(
                                    "failed-checkpoint-save-training",
                                    iteration,
                                    stats.splatCount
                                )
                                return
                            }
                        }

                        if shouldReport {
                            let count = stats.splatCount
                            let progress = min(1, Double(iteration) / Double(max(1, effectiveTarget)))
                            Task { @MainActor [weak self] in
                                guard let self else { return }
                                self.trainingIteration = iteration
                                self.splatCount = count
                                self.trainingProgress = progress
                            }
                        }

                        if let reason = resourcePauseReason {
                            writeRunReport(
                                "paused-\(reason.rawValue)",
                                .trainingStep,
                                SplatReconstructionStopReason(resourcePauseReason: reason),
                                iteration,
                                stats.splatCount,
                                iteration,
                                nil
                            )
                            Task { @MainActor [weak self] in
                                self?.failTraining(reason.userMessage)
                            }
                            return
                        }

                        if thermalPause {
                            let message = "端末温度が高くなったため生成を安全に一時停止しました。端末が冷えてから「生成だけもう一度試す」で続きから再開できます"
                            writeRunReport(
                                "paused-thermal",
                                .trainingStep,
                                .thermal,
                                iteration,
                                stats.splatCount,
                                iteration,
                                nil
                            )
                            Task { @MainActor [weak self] in
                                self?.failTraining(message)
                            }
                            return
                        }

                        if checkpointDue {
                            writeRunReport(
                                "running-training-step",
                                .trainingStep,
                                nil,
                                iteration,
                                stats.splatCount,
                                iteration,
                                nil
                            )
                        }
                    }
                }

                msplatSync()
                let finalCheckpointIteration = trainer.iteration
                let finalCheckpointCount = trainer.splatCount
                writeRunReport(
                    "running-checkpoint-save",
                    .checkpointSave,
                    nil,
                    finalCheckpointIteration,
                    finalCheckpointCount,
                    nil,
                    nil
                )
                guard trainer.saveCheckpoint(to: checkpoint.path) else {
                    failCheckpointSave(
                        "failed-checkpoint-save-final",
                        finalCheckpointIteration,
                        finalCheckpointCount
                    )
                    return
                }
                let pendingOutput = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
                writeRunReport(
                    "running-export",
                    .export,
                    nil,
                    trainer.iteration,
                    trainer.splatCount,
                    finalCheckpointIteration,
                    nil
                )
                trainer.exportSplat(to: pendingOutput.path)
                msplatSync()

                guard let attributes = try? FileManager.default.attributesOfItem(atPath: pendingOutput.path),
                      let sizeNumber = attributes[.size] as? NSNumber,
                      sizeNumber.intValue > 0,
                      sizeNumber.intValue % 32 == 0 else {
                    let message = "生成した3Dデータを保存できませんでした。生成をもう一度試してください"
                    writeRunReport(
                        "failed-export",
                        .export,
                        .trainerError,
                        trainer.iteration,
                        trainer.splatCount,
                        trainer.iteration,
                        message
                    )
                    Task { @MainActor [weak self] in
                        self?.failTraining(message)
                    }
                    return
                }

                let output: URL
                do {
                    let store = ScanProjectStore()
                    output = try store.commitPendingSplat(projectURL: projectURL)
                    _ = try store.updateManifest(projectURL: projectURL) { manifest in
                        manifest.stage = .finished
                        manifest.outputs[ScanRepresentationKind.splat.rawValue] = output.lastPathComponent
                        manifest.lastError = nil
                    }
                } catch {
                    let message = "生成した3Dデータの安全な保存を完了できませんでした: \(error.localizedDescription)"
                    writeRunReport(
                        "failed-export-commit",
                        .export,
                        .other,
                        trainer.iteration,
                        trainer.splatCount,
                        trainer.iteration,
                        message
                    )
                    Task { @MainActor [weak self] in
                        self?.failTraining(message)
                    }
                    return
                }

                writeRunReport(
                    "running-preview",
                    .preview,
                    nil,
                    trainer.iteration,
                    trainer.splatCount,
                    finalCheckpointIteration,
                    nil
                )
                let rendered = trainer.render(cameraIndex: 0)
                let preview = Self.makeImage(from: rendered)
                let finalCount = trainer.splatCount
                _ = passResourceGuard.evaluate(splatCount: finalCount)
                writeRunReport(
                    "completed",
                    .preview,
                    nil,
                    effectiveTarget,
                    finalCount,
                    effectiveTarget,
                    nil
                )
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.resultURL = output
                    self.previewImage = preview
                    if let preview, let thumbnail = preview.jpegData(compressionQuality: 0.82) {
                        try? self.projectStore.setThumbnail(data: thumbnail, projectURL: projectURL)
                    }
                    self.trainingIteration = effectiveTarget
                    self.splatCount = finalCount
                    self.trainingProgress = 1
                    self.phase = .finished
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            }
        }
    }

    private func failTraining(_ message: String) {
        if let projectURL {
            try? projectStore.updateManifest(projectURL: projectURL) { manifest in
                manifest.stage = .failed
                manifest.lastError = message
            }
        }
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
        guard phase == .capturing, !isCapturePaused, !isWritingFrame else { return }
        updateCaptureDuration()

        switch frame.camera.trackingState {
        case .normal:
            if trackingNeedsRecovery {
                stableTrackingFrames += 1
                if stableTrackingFrames < recoveryFramesRequired {
                    trackingMessage = "位置を復旧しています（\(stableTrackingFrames)/\(recoveryFramesRequired)）"
                    return
                }
                trackingNeedsRecovery = false
                trackingMessage = "位置を復旧しました。撮影を続けられます"
            }
        case .notAvailable:
            markTrackingLost(message: "カメラ位置を追跡できません。前に撮った場所へ戻ってください")
            return
        case .limited(let reason):
            markTrackingLost(message: limitedReason(reason))
            return
        }

        guard CapturePolicy.shouldAcceptFrame(
            previous: lastAcceptedTransform,
            current: frame.camera.transform,
            subjectDistance: estimatedSubjectDistance,
            previousTimestamp: lastAcceptedTimestamp,
            currentTimestamp: frame.timestamp
        ) else { return }

        if acceptedFrames >= maxFrames {
            guard frameAddsMissingCoverage(using: frame.camera.transform) else {
                trackingMessage = coverageSatisfied
                    ? "保存容量を守るため追加撮影を停止しました。現在の撮影で生成できます"
                    : "保存容量を守るため、未撮影の方向・高さだけを追加してください"
                return
            }
        }

        if let stats = CaptureImageQualityEvaluator.evaluate(pixelBuffer: frame.capturedImage),
           let rejection = CaptureImageQualityPolicy.rejection(for: stats) {
            trackingMessage = rejection.userMessage
            return
        }

        guard let jpegData = makeJPEGData(pixelBuffer: frame.capturedImage) else {
            trackingMessage = "画像を保存できません。もう一度ゆっくり動かしてください"
            return
        }

        absorbFeaturePoints(frame.rawFeaturePoints, cameraTransform: frame.camera.transform)
        let depthPayload = ignoreLiDAR ? nil : Self.copyDepthPayload(frame.sceneDepth?.depthMap)

        isWritingFrame = true
        let index = acceptedFrames
        let matrixRows = Self.rows(frame.camera.transform)
        let transform = frame.camera.transform
        let intrinsics = frame.camera.intrinsics
        let resolution = frame.camera.imageResolution
        let timestamp = frame.timestamp
        let imagesURL = imagesURL
        let depthURL = depthURL

        captureQueue.async { [weak self] in
            guard let imagesURL else {
                Task { @MainActor [weak self] in
                    self?.isWritingFrame = false
                    self?.trackingMessage = "撮影データの保存先を確認できませんでした"
                }
                return
            }
            let fileName = String(format: "frame_%05d.jpg", index)
            let fileURL = imagesURL.appendingPathComponent(fileName)
            var depthRelativePath: String?
            var writeError: Error?

            do {
                try jpegData.write(to: fileURL, options: .atomic)
                if let depthPayload, let depthURL {
                    let depthName = String(format: "depth_%05d.f32", index)
                    try depthPayload.data.write(to: depthURL.appendingPathComponent(depthName), options: .atomic)
                    depthRelativePath = "depth/\(depthName)"
                }
            } catch {
                writeError = error
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isWritingFrame = false
                guard self.phase == .capturing, !self.isCapturePaused else { return }
                guard writeError == nil else {
                    let message = "撮影データを保存できませんでした。iPhoneの空き容量を確認してください。"
                    self.closeActiveCaptureTiming()
                    self.phase = .failed(message)
                    self.trackingMessage = message
                    self.session?.pause()
                    UIApplication.shared.isIdleTimerDisabled = false
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
                    h: Int(resolution.height),
                    depthFilePath: depthRelativePath,
                    depthWidth: depthPayload?.width,
                    depthHeight: depthPayload?.height,
                    depthBytesPerRow: depthPayload?.bytesPerRow
                ))
                self.depthCaptureActive = self.captured.contains { $0.depthFilePath != nil }
                self.updateCoverage(using: transform)
                self.acceptedFrames = self.captured.count
                self.lastAcceptedTransform = transform
                self.lastAcceptedTimestamp = timestamp
                if self.acceptedFrames % 4 == 0 {
                    self.persistCaptureStateOrFail(stage: .capturing)
                    guard self.phase == .capturing else { return }
                }
                if self.acceptedFrames == 1, let projectURL = self.projectURL {
                    try? self.projectStore.setThumbnail(from: fileURL, projectURL: projectURL)
                }
                if self.acceptedFrames == 1 || self.acceptedFrames % 12 == 0 {
                    self.schedulePeriodicWorldMapPersistence()
                }
                self.trackingMessage = self.captureQualityText
            }
        }
    }

    private func makeJPEGData(pixelBuffer: CVPixelBuffer) -> Data? {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cg = ciContext.createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: cg).jpegData(compressionQuality: 0.90)
    }

    private func absorbFeaturePoints(_ cloud: ARPointCloud?, cameraTransform: simd_float4x4) {
        guard let cloud, !cloud.points.isEmpty else { return }

        if estimatedTargetCenter == nil,
           let center = estimateTargetCenter(from: cloud, cameraTransform: cameraTransform) {
            estimatedTargetCenter = center
            estimatedSubjectDistance = simd_distance(Self.cameraPosition(cameraTransform), center)
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
            guard depth >= 0.20, depth <= 4.00 else { continue }
            guard abs(cameraPoint.x) <= depth * 0.70,
                  abs(cameraPoint.y) <= depth * 0.70 else { continue }
            xs.append(p.x)
            ys.append(p.y)
            zs.append(p.z)
        }

        guard xs.count >= 8 else { return nil }
        xs.sort(); ys.sort(); zs.sort()
        let middle = xs.count / 2
        return SIMD3<Float>(xs[middle], ys[middle], zs[middle])
    }

    private func frameAddsMissingCoverage(using transform: simd_float4x4) -> Bool {
        let position = Self.cameraPosition(transform)
        let viewSector = CapturePolicy.viewDirectionSector(transform: transform, count: coverageSectorTotal)
        let cell = CapturePolicy.spatialCell(cameraPosition: position)
        let translation = previousCoveragePosition.map { simd_distance($0, position) } ?? 0

        var orbitSectorIsNew = false
        var elevationBandIsNew = false
        if let center = estimatedTargetCenter {
            if let sector = CapturePolicy.orbitSector(
                cameraPosition: position,
                center: center,
                count: coverageSectorTotal
            ) {
                orbitSectorIsNew = !coverageSectors.contains(sector)
            }
            if let band = CapturePolicy.elevationBand(cameraPosition: position, center: center) {
                elevationBandIsNew = !elevationBands.contains(band)
            }
        }

        return CapturePolicy.softLimitAllowsFrame(
            mode: coverageMode,
            coverageSatisfied: coverageSatisfied,
            orbitSectorIsNew: orbitSectorIsNew,
            elevationBandIsNew: elevationBandIsNew,
            viewDirectionIsNew: !viewDirectionSectors.contains(viewSector),
            spatialCellIsNew: !spatialCells.contains(cell),
            spatialCellCount: spatialCells.count,
            pathLength: pathLengthMeters,
            translationSinceLast: translation
        )
    }

    private func updateCoverage(using transform: simd_float4x4) {
        let position = Self.cameraPosition(transform)

        if let previousCoveragePosition {
            let delta = simd_distance(previousCoveragePosition, position)
            if delta.isFinite && delta <= 1.25 {
                pathLengthMeters += delta
            }
        }
        previousCoveragePosition = position

        viewDirectionSectors.insert(
            CapturePolicy.viewDirectionSector(transform: transform, count: coverageSectorTotal)
        )
        spatialCells.insert(CapturePolicy.spatialCell(cameraPosition: position))

        if let center = estimatedTargetCenter {
            if let sector = CapturePolicy.orbitSector(
                cameraPosition: position,
                center: center,
                count: coverageSectorTotal
            ) {
                coverageSectors.insert(sector)
            }
            if let band = CapturePolicy.elevationBand(cameraPosition: position, center: center) {
                elevationBands.insert(band)
            }
        }

        let score = CapturePolicy.coverageScore(
            subjectDistance: estimatedSubjectDistance,
            orbitSectors: coverageSectors.count,
            elevationBands: elevationBands.count,
            viewDirectionSectors: viewDirectionSectors.count,
            spatialCells: spatialCells.count,
            pathLength: pathLengthMeters
        )
        coverageSectorCount = min(coverageSectorTotal, max(0, Int((score * Float(coverageSectorTotal)).rounded())))
    }

    nonisolated private static func preparePointCloudPLY(
        projectURL: URL,
        points: [SIMD3<Float>],
        frames: [SplatSeedFrame]
    ) throws {
        guard points.count >= 64 else {
            throw NSError(
                domain: "SplatLab",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "立体の手がかりが不足しています"]
            )
        }

        let colors = SplatSeedColorizer.colorize(points: points, frames: frames, projectURL: projectURL)
        let skySeeds = SplatSkySeeder.makeSeeds(
            frames: frames,
            geometryPoints: points,
            projectURL: projectURL
        )
        let totalCount = points.count + skySeeds.count
        var ply = "ply\nformat ascii 1.0\nelement vertex \(totalCount)\nproperty float x\nproperty float y\nproperty float z\nproperty uchar red\nproperty uchar green\nproperty uchar blue\nend_header\n"
        ply.reserveCapacity(totalCount * 56)
        for (index, point) in points.enumerated() {
            let color = colors.indices.contains(index) ? colors[index] : SplatSeedColorizer.fallback
            ply += "\(point.x) \(point.y) \(point.z) \(color.red) \(color.green) \(color.blue)\n"
        }
        for seed in skySeeds {
            let p = seed.position
            let c = seed.color
            ply += "\(p.x) \(p.y) \(p.z) \(c.red) \(c.green) \(c.blue)\n"
        }
        try ply.write(
            to: projectURL.appendingPathComponent("points3D.ply"),
            atomically: true,
            encoding: .utf8
        )
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

    private func writeCaptureManifest() throws {
        guard let projectURL else { throw dataError("保存先がありません") }
        let manifest = CaptureManifest(
            version: 2,
            frameCount: captured.count,
            depthFrameCount: captured.filter { $0.depthFilePath != nil }.count,
            lidarIgnored: ignoreLiDAR,
            captureMode: coverageMode == .object ? "object" : "scene",
            orbitSectorCount: coverageSectors.count,
            elevationBandCount: elevationBands.count,
            viewDirectionSectorCount: viewDirectionSectors.count,
            spatialCellCount: spatialCells.count,
            pathLengthMeters: pathLengthMeters,
            activeCaptureSeconds: activeCaptureSeconds
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: projectURL.appendingPathComponent("capture_manifest.json"), options: .atomic)
    }

    private func makeCaptureCheckpoint() -> ScanCaptureCheckpoint {
        let frames = captured.map { frame in
            StoredCapturedFrame(
                id: frame.id,
                filePath: frame.filePath,
                transformMatrix: frame.transformMatrix,
                flX: frame.flX,
                flY: frame.flY,
                cx: frame.cx,
                cy: frame.cy,
                w: frame.w,
                h: frame.h,
                depthFilePath: frame.depthFilePath,
                depthWidth: frame.depthWidth,
                depthHeight: frame.depthHeight,
                depthBytesPerRow: frame.depthBytesPerRow
            )
        }
        var storedFeatures: [StoredFeaturePoint] = []
        storedFeatures.reserveCapacity(featurePoints.count)
        for (id, point) in featurePoints {
            storedFeatures.append(StoredFeaturePoint(id: id, x: point.x, y: point.y, z: point.z))
        }
        storedFeatures.sort { $0.id < $1.id }

        let center: StoredVector3?
        if let value = estimatedTargetCenter {
            center = StoredVector3(x: value.x, y: value.y, z: value.z)
        } else {
            center = nil
        }

        let previousPosition: StoredVector3?
        if let value = previousCoveragePosition {
            previousPosition = StoredVector3(x: value.x, y: value.y, z: value.z)
        } else {
            previousPosition = nil
        }

        var storedCells: [StoredGridCell] = []
        storedCells.reserveCapacity(spatialCells.count)
        for cell in spatialCells {
            storedCells.append(StoredGridCell(x: cell.x, z: cell.z))
        }
        storedCells.sort { lhs, rhs in
            if lhs.x == rhs.x { return lhs.z < rhs.z }
            return lhs.x < rhs.x
        }

        let storedCoverageSectors: [Int] = coverageSectors.sorted()
        let storedElevationBands: [Int] = elevationBands.sorted()
        let storedViewDirectionSectors: [Int] = viewDirectionSectors.sorted()
        let storedLastTransform: [[Float]]? = lastAcceptedTransform.map(Self.rows)

        let checkpoint = ScanCaptureCheckpoint(
            frames: frames,
            featurePoints: storedFeatures,
            coverageSectors: storedCoverageSectors,
            estimatedTargetCenter: center,
            lastAcceptedTransform: storedLastTransform,
            lastAcceptedTimestamp: lastAcceptedTimestamp,
            elevationBands: storedElevationBands,
            viewDirectionSectors: storedViewDirectionSectors,
            spatialCells: storedCells,
            estimatedSubjectDistance: estimatedSubjectDistance,
            previousCoveragePosition: previousPosition,
            pathLengthMeters: pathLengthMeters,
            accumulatedCaptureSeconds: activeCaptureSeconds,
            ignoreLiDAR: ignoreLiDAR
        )
        return checkpoint
    }

    private func persistProjectSnapshot(stage: ScanProjectStage, lastError: String? = nil) throws {
        guard let projectURL else { throw dataError("保存先がありません") }
        try projectStore.saveCheckpoint(makeCaptureCheckpoint(), projectURL: projectURL)
        _ = try projectStore.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = stage
            manifest.acceptedFrames = acceptedFrames
            manifest.targetFrames = targetFrames
            manifest.featurePointCount = featurePointCount
            manifest.coverageSectorCount = coverageSectorCount
            manifest.rawDataRetained = true
            manifest.lastError = lastError
        }
    }

    private func persistCaptureStateOrFail(stage: ScanProjectStage) {
        do {
            try persistProjectSnapshot(stage: stage)
        } catch {
            let message = "撮影状態を保存できませんでした。iPhoneの空き容量を確認してください: \(error.localizedDescription)"
            closeActiveCaptureTiming()
            phase = .failed(message)
            trackingMessage = message
            session?.pause()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    func restoreSavedProject(id: String) {
        do {
            let summary = try projectStore.loadProject(id: id)
            guard summary.manifest.rawDataRetained else {
                throw dataError("再開に必要なrawデータがありません")
            }
            let checkpoint = try projectStore.loadCheckpoint(projectURL: summary.projectURL)

            invalidateWorldMapPersistence()
            session?.pause()
            closeActiveCaptureTiming()
            projectURL = summary.projectURL
            imagesURL = summary.projectURL.appendingPathComponent("images", isDirectory: true)
            depthURL = summary.projectURL.appendingPathComponent("depth", isDirectory: true)
            restoreCaptureCheckpoint(checkpoint)
            targetFrames = summary.manifest.targetFrames
            pendingTrainingTarget = SplatReconstructionPolicy.standardIterations
            pendingResumeWorldMap = loadPersistedWorldMap(projectURL: summary.projectURL)
            requiresWorldMapForResume = true
            userPauseRequested = false
            systemPausedCapture = false
            activeCaptureStartedAt = nil
            resultURL = projectStore.trustedSplatURL(projectURL: summary.projectURL)
            if let thumbnail = summary.thumbnailURL {
                previewImage = UIImage(contentsOfFile: thumbnail.path)
            }

            let transformsURL = summary.projectURL.appendingPathComponent("transforms.json")
            let hasProcessableCapture = FileManager.default.fileExists(atPath: transformsURL.path)
                && !captured.isEmpty
            if summary.manifest.stage == .captured || (summary.manifest.stage == .failed && hasProcessableCapture) {
                datasetReady = true
                phase = .captured
                isCapturePaused = false
                trackingMessage = pendingResumeWorldMap == nil
                    ? "保存した撮影を開きました。3D生成はできますが、撮影の追加には位置復元データがありません"
                    : "保存した撮影を開きました。生成するか、撮影を追加できます"
            } else {
                guard pendingResumeWorldMap != nil else {
                    throw dataError("撮影位置を復元するWorldMapがありません。rawデータは削除していません")
                }
                datasetReady = false
                phase = .capturing
                isCapturePaused = true
                trackingNeedsRecovery = true
                stableTrackingFrames = 0
                trackingMessage = "保存した撮影を復元しました。「撮影を再開」で位置を合わせて続けられます"
            }
            UIApplication.shared.isIdleTimerDisabled = false
        } catch {
            let message = "保存した撮影状態を復元できませんでした: \(error.localizedDescription)"
            phase = .failed(message)
            trackingMessage = message
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func restoreCaptureCheckpoint(_ checkpoint: ScanCaptureCheckpoint) {
        captured = checkpoint.frames.map { frame in
            CapturedView(
                id: frame.id,
                filePath: frame.filePath,
                transformMatrix: frame.transformMatrix,
                flX: frame.flX,
                flY: frame.flY,
                cx: frame.cx,
                cy: frame.cy,
                w: frame.w,
                h: frame.h,
                depthFilePath: frame.depthFilePath,
                depthWidth: frame.depthWidth,
                depthHeight: frame.depthHeight,
                depthBytesPerRow: frame.depthBytesPerRow
            )
        }
        featurePoints = Dictionary(uniqueKeysWithValues: checkpoint.featurePoints.map {
            ($0.id, SIMD3<Float>($0.x, $0.y, $0.z))
        })
        coverageSectors = Set(checkpoint.coverageSectors)
        elevationBands = Set(checkpoint.elevationBands ?? [])
        viewDirectionSectors = Set(checkpoint.viewDirectionSectors ?? [])
        spatialCells = Set((checkpoint.spatialCells ?? []).map { CaptureGridCell(x: $0.x, z: $0.z) })
        estimatedTargetCenter = checkpoint.estimatedTargetCenter.map { SIMD3<Float>($0.x, $0.y, $0.z) }
        estimatedSubjectDistance = checkpoint.estimatedSubjectDistance
        lastAcceptedTransform = checkpoint.lastAcceptedTransform.flatMap(Self.matrix(from:))
        lastAcceptedTimestamp = checkpoint.lastAcceptedTimestamp
        previousCoveragePosition = checkpoint.previousCoveragePosition.map { SIMD3<Float>($0.x, $0.y, $0.z) }
        pathLengthMeters = checkpoint.pathLengthMeters ?? 0
        accumulatedCaptureSeconds = checkpoint.accumulatedCaptureSeconds ?? 0
        activeCaptureSeconds = accumulatedCaptureSeconds
        ignoreLiDAR = checkpoint.ignoreLiDAR ?? false
        depthCaptureActive = captured.contains { $0.depthFilePath != nil }
        acceptedFrames = captured.count
        featurePointCount = featurePoints.count
        let score = CapturePolicy.coverageScore(
            subjectDistance: estimatedSubjectDistance,
            orbitSectors: coverageSectors.count,
            elevationBands: elevationBands.count,
            viewDirectionSectors: viewDirectionSectors.count,
            spatialCells: spatialCells.count,
            pathLength: pathLengthMeters
        )
        coverageSectorCount = min(coverageSectorTotal, max(0, Int((score * Float(coverageSectorTotal)).rounded())))
        isWritingFrame = false
    }

    private func schedulePeriodicWorldMapPersistence() {
        guard periodicWorldMapPersistenceTask == nil,
              !isWorldMapPersistencePending,
              let projectURL else { return }
        let generation = worldMapPersistenceGeneration
        periodicWorldMapPersistenceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let outcome = await self.persistWorldMapSnapshot(
                projectURL: projectURL,
                generation: generation
            )
            guard self.worldMapPersistenceGeneration == generation else { return }
            self.periodicWorldMapPersistenceTask = nil
            switch outcome {
            case .saved:
                self.worldMapPersistenceWarning = nil
            case .reusedExisting(let warning), .failed(let warning):
                self.worldMapPersistenceWarning = warning
            }
        }
    }

    private func persistWorldMapForTransition(
        projectURL: URL,
        generation: Int
    ) async -> WorldMapPersistenceOutcome {
        if let existingTask = periodicWorldMapPersistenceTask {
            await existingTask.value
        }
        guard worldMapPersistenceGeneration == generation,
              self.projectURL?.standardizedFileURL == projectURL.standardizedFileURL else {
            return .failed("保存対象のスキャンが切り替わりました")
        }
        return await persistWorldMapSnapshot(projectURL: projectURL, generation: generation)
    }

    private func persistWorldMapSnapshot(
        projectURL: URL,
        generation: Int
    ) async -> WorldMapPersistenceOutcome {
        let hadExistingMap = projectStore.hasWorldMap(projectURL: projectURL)
        let archiveResult = await requestCurrentWorldMapArchive()

        guard worldMapPersistenceGeneration == generation,
              self.projectURL?.standardizedFileURL == projectURL.standardizedFileURL,
              FileManager.default.fileExists(atPath: projectURL.path) else {
            return .failed("保存対象のスキャンが切り替わりました")
        }

        switch archiveResult {
        case .failed(let message):
            return hadExistingMap ? .reusedExisting(message) : .failed(message)
        case .data(let data):
            let targetURL = projectStore.worldMapURL(projectURL: projectURL)
            do {
                try await Task.detached(priority: .utility) {
                    try ScanWorldMapArchiveStore.write(data, to: targetURL)
                }.value
                return .saved
            } catch {
                let message = "WorldMapを書き込めませんでした: \(error.localizedDescription)"
                return hadExistingMap ? .reusedExisting(message) : .failed(message)
            }
        }
    }

    private func requestCurrentWorldMapArchive() async -> WorldMapArchiveResult {
        guard let session else { return .failed("ARSessionを確認できません") }
        return await withCheckedContinuation { continuation in
            session.getCurrentWorldMap { worldMap, error in
                if let error {
                    continuation.resume(returning: .failed(error.localizedDescription))
                    return
                }
                guard let worldMap else {
                    continuation.resume(returning: .failed("現在の撮影位置を取得できません"))
                    return
                }
                do {
                    let data = try NSKeyedArchiver.archivedData(
                        withRootObject: worldMap,
                        requiringSecureCoding: true
                    )
                    guard !data.isEmpty else {
                        continuation.resume(returning: .failed("WorldMap archiveが空です"))
                        return
                    }
                    continuation.resume(returning: .data(data))
                } catch {
                    continuation.resume(returning: .failed(error.localizedDescription))
                }
            }
        }
    }

    private func invalidateWorldMapPersistence() {
        worldMapPersistenceGeneration &+= 1
        periodicWorldMapPersistenceTask?.cancel()
        periodicWorldMapPersistenceTask = nil
        isWorldMapPersistencePending = false
    }

    private func loadPersistedWorldMap(projectURL: URL) -> ARWorldMap? {
        let url = projectStore.worldMapURL(projectURL: projectURL)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data)
    }

    private func makeWorldTrackingConfiguration() -> ARWorldTrackingConfiguration {
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        config.isLightEstimationEnabled = true
        config.environmentTexturing = .none
        if !ignoreLiDAR && ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        return config
    }

    private func markTrackingLost(message: String) {
        trackingNeedsRecovery = true
        stableTrackingFrames = 0
        trackingMessage = message
    }

    func handleSessionInterrupted() {
        guard phase == .capturing else { return }
        closeActiveCaptureTiming()
        systemPausedCapture = true
        isCapturePaused = true
        trackingNeedsRecovery = true
        stableTrackingFrames = 0
        trackingMessage = "カメラが中断されました。raw状態を保存し、位置復元データも更新します"
        persistCaptureStateOrFail(stage: .capturing)
        guard phase == .capturing else { return }
        schedulePeriodicWorldMapPersistence()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func handleSessionInterruptionEnded() {
        guard phase == .capturing, systemPausedCapture, let session else { return }
        systemPausedCapture = false
        if userPauseRequested {
            trackingMessage = worldMapPersistenceWarning == nil
                ? "撮影は一時停止中です"
                : "撮影は一時停止中です。位置復元データの保存状態を確認してください"
            UIApplication.shared.isIdleTimerDisabled = false
            return
        }

        isCapturePaused = false
        trackingNeedsRecovery = true
        stableTrackingFrames = 0
        beginActiveCaptureTiming()
        trackingMessage = worldMapPersistenceWarning.map {
            "位置復元データの保存に注意が必要です。アプリを閉じず、前に撮った場所を映して続けてください: \($0)"
        } ?? "前に撮った場所を映して位置を再確認してください"
        session.run(makeWorldTrackingConfiguration(), options: [])
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func handleApplicationBecameInactive() {
        guard phase == .capturing, !isCapturePaused else { return }
        handleSessionInterrupted()
    }

    func handleApplicationBecameActive() {
        guard phase == .capturing, systemPausedCapture else { return }
        handleSessionInterruptionEnded()
    }

    private func beginActiveCaptureTiming() {
        if activeCaptureStartedAt == nil {
            activeCaptureStartedAt = ProcessInfo.processInfo.systemUptime
        }
        updateCaptureDuration()
    }

    private func closeActiveCaptureTiming() {
        if let activeCaptureStartedAt {
            accumulatedCaptureSeconds += max(0, ProcessInfo.processInfo.systemUptime - activeCaptureStartedAt)
            self.activeCaptureStartedAt = nil
        }
        activeCaptureSeconds = accumulatedCaptureSeconds
    }

    private func updateCaptureDuration() {
        let current = activeCaptureStartedAt.map {
            accumulatedCaptureSeconds + max(0, ProcessInfo.processInfo.systemUptime - $0)
        } ?? accumulatedCaptureSeconds
        activeCaptureSeconds = current
    }

    private func resetCaptureStateForNewProject() {
        invalidateWorldMapPersistence()
        captured.removeAll(keepingCapacity: true)
        featurePoints.removeAll(keepingCapacity: true)
        coverageSectors.removeAll(keepingCapacity: true)
        elevationBands.removeAll(keepingCapacity: true)
        viewDirectionSectors.removeAll(keepingCapacity: true)
        spatialCells.removeAll(keepingCapacity: true)
        estimatedTargetCenter = nil
        estimatedSubjectDistance = nil
        acceptedFrames = 0
        featurePointCount = 0
        coverageSectorCount = 0
        lastAcceptedTransform = nil
        lastAcceptedTimestamp = 0
        previousCoveragePosition = nil
        pathLengthMeters = 0
        resultURL = nil
        previewImage = nil
        trainingProgress = 0
        trainingIteration = 0
        splatCount = 0
        datasetReady = false
        isWritingFrame = false
        trackingNeedsRecovery = false
        stableTrackingFrames = 0
        activeCaptureStartedAt = nil
        accumulatedCaptureSeconds = 0
        activeCaptureSeconds = 0
        depthCaptureActive = false
        systemPausedCapture = false
        pendingResumeWorldMap = nil
        requiresWorldMapForResume = false
        userPauseRequested = false
        worldMapPersistenceWarning = nil
    }

    private func limitedReason(_ reason: ARCamera.TrackingState.Reason) -> String {
        switch reason {
        case .initializing: return "位置を合わせています。ゆっくり動かしてください"
        case .excessiveMotion: return "動きが速すぎます。もっとゆっくり動かしてください"
        case .insufficientFeatures: return "模様が少なく追跡が不安定です。前に撮った場所や模様のある場所を映してください"
        case .relocalizing: return "前に撮った場所を探して位置を復旧しています"
        @unknown default: return "追跡が安定するまで前に撮った場所を映してください"
        }
    }

    private func dataError(_ message: String) -> NSError {
        NSError(domain: "SplatLab", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private static func seedFrame(from frame: CapturedView) -> SplatSeedFrame {
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

    private static func cameraPosition(_ m: simd_float4x4) -> SIMD3<Float> {
        CapturePolicy.cameraPosition(m)
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

    nonisolated private static func copyDepthPayload(_ pixelBuffer: CVPixelBuffer?) -> DepthPayload? {
        guard let pixelBuffer else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard width > 0, height > 0, bytesPerRow > 0 else { return nil }
        return DepthPayload(
            data: Data(bytes: baseAddress, count: bytesPerRow * height),
            width: width,
            height: height,
            bytesPerRow: bytesPerRow
        )
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
