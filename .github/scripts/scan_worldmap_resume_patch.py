from pathlib import Path

model = Path('splat-native-ios/SplatNative/ScanModel.swift')
text = model.read_text()

replacements = [
('''    private var accumulatedCaptureSeconds: Double = 0
    private var systemPausedCapture = false
''', '''    private var accumulatedCaptureSeconds: Double = 0
    private var systemPausedCapture = false
    private var pendingResumeWorldMap: ARWorldMap?
    private var requiresWorldMapForResume = false
'''),
('''        closeActiveCaptureTiming()
        isCapturePaused = true
        systemPausedCapture = false
        persistCaptureStateOrFail(stage: .capturing)
''', '''        closeActiveCaptureTiming()
        isCapturePaused = true
        systemPausedCapture = false
        persistWorldMapIfPossible()
        persistCaptureStateOrFail(stage: .capturing)
'''),
('''    func resumeCapture() {
        guard let session else { return }
        guard phase == .captured || (phase == .capturing && isCapturePaused) else { return }

        if phase == .captured {
            datasetReady = false
            phase = .capturing
        }
        isCapturePaused = false
        systemPausedCapture = false
        trackingNeedsRecovery = true
        stableTrackingFrames = 0
        beginActiveCaptureTiming()
        trackingMessage = "前に撮った場所を映して位置を合わせています"
        persistCaptureStateOrFail(stage: .capturing)
        guard phase == .capturing else { return }

        // Do not reset tracking here. Old and resumed poses must remain in one coordinate system.
        session.run(makeWorldTrackingConfiguration(), options: [])
        UIApplication.shared.isIdleTimerDisabled = true
    }
''', '''    func resumeCapture() {
        guard let session else { return }
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
        UIApplication.shared.isIdleTimerDisabled = true
    }
'''),
('''        closeActiveCaptureTiming()
        session?.pause()
        isCapturePaused = false
''', '''        closeActiveCaptureTiming()
        persistWorldMapIfPossible()
        session?.pause()
        isCapturePaused = false
'''),
('''        depthCaptureActive = false
        trackingNeedsRecovery = false
        stableTrackingFrames = 0
        phase = .ready
''', '''        depthCaptureActive = false
        trackingNeedsRecovery = false
        stableTrackingFrames = 0
        pendingResumeWorldMap = nil
        requiresWorldMapForResume = false
        phase = .ready
'''),
('''                if self.acceptedFrames % 4 == 0 {
                    self.persistCaptureStateOrFail(stage: .capturing)
                    guard self.phase == .capturing else { return }
                }
                self.trackingMessage = self.captureQualityText
''', '''                if self.acceptedFrames % 4 == 0 {
                    self.persistCaptureStateOrFail(stage: .capturing)
                    guard self.phase == .capturing else { return }
                }
                if self.acceptedFrames == 1, let projectURL = self.projectURL {
                    try? self.projectStore.setThumbnail(from: fileURL, projectURL: projectURL)
                }
                if self.acceptedFrames % 12 == 0 {
                    self.persistWorldMapIfPossible()
                }
                self.trackingMessage = self.captureQualityText
'''),
('''            StoredCapturedFrame(
                id: frame.id,
                filePath: frame.filePath,
                transformMatrix: frame.transformMatrix,
                flX: frame.flX,
                flY: frame.flY,
                cx: frame.cx,
                cy: frame.cy,
                w: frame.w,
                h: frame.h
            )
''', '''            StoredCapturedFrame(
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
'''),
('''        let center = estimatedTargetCenter.map { StoredVector3(x: $0.x, y: $0.y, z: $0.z) }
        return ScanCaptureCheckpoint(
            frames: frames,
            featurePoints: storedFeatures,
            coverageSectors: coverageSectors.sorted(),
            estimatedTargetCenter: center,
            lastAcceptedTransform: lastAcceptedTransform.map { Self.rows($0) },
            lastAcceptedTimestamp: lastAcceptedTimestamp
        )
''', '''        let center = estimatedTargetCenter.map { StoredVector3(x: $0.x, y: $0.y, z: $0.z) }
        let previousPosition = previousCoveragePosition.map { StoredVector3(x: $0.x, y: $0.y, z: $0.z) }
        let storedCells = spatialCells.map { StoredGridCell(x: $0.x, z: $0.z) }
            .sorted { lhs, rhs in lhs.x == rhs.x ? lhs.z < rhs.z : lhs.x < rhs.x }
        return ScanCaptureCheckpoint(
            frames: frames,
            featurePoints: storedFeatures,
            coverageSectors: coverageSectors.sorted(),
            estimatedTargetCenter: center,
            lastAcceptedTransform: lastAcceptedTransform.map { Self.rows($0) },
            lastAcceptedTimestamp: lastAcceptedTimestamp,
            elevationBands: elevationBands.sorted(),
            viewDirectionSectors: viewDirectionSectors.sorted(),
            spatialCells: storedCells,
            estimatedSubjectDistance: estimatedSubjectDistance,
            previousCoveragePosition: previousPosition,
            pathLengthMeters: pathLengthMeters,
            accumulatedCaptureSeconds: activeCaptureSeconds,
            ignoreLiDAR: ignoreLiDAR
        )
'''),
('''    private func makeWorldTrackingConfiguration() -> ARWorldTrackingConfiguration {
''', '''    func restoreSavedProject(id: String) {
        do {
            let summary = try projectStore.loadProject(id: id)
            guard summary.manifest.rawDataRetained else {
                throw dataError("再開に必要なrawデータがありません")
            }
            let checkpoint = try projectStore.loadCheckpoint(projectURL: summary.projectURL)

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
            let message = "保存した撮影状態を復元できませんでした: \\(error.localizedDescription)"
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

    private func persistWorldMapIfPossible() {
        guard let session, let projectURL else { return }
        let targetURL = projectStore.worldMapURL(projectURL: projectURL)
        session.getCurrentWorldMap { worldMap, _ in
            guard let worldMap,
                  let data = try? NSKeyedArchiver.archivedData(
                    withRootObject: worldMap,
                    requiringSecureCoding: true
                  ) else { return }
            try? data.write(to: targetURL, options: .atomic)
        }
    }

    private func loadPersistedWorldMap(projectURL: URL) -> ARWorldMap? {
        let url = projectStore.worldMapURL(projectURL: projectURL)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data)
    }

    private func makeWorldTrackingConfiguration() -> ARWorldTrackingConfiguration {
'''),
('''        trackingMessage = "カメラが中断されました。戻ると同じスキャンを復旧します"
        persistCaptureStateOrFail(stage: .capturing)
''', '''        trackingMessage = "カメラが中断されました。戻ると同じスキャンを復旧します"
        persistWorldMapIfPossible()
        persistCaptureStateOrFail(stage: .capturing)
'''),
('''        depthCaptureActive = false
        systemPausedCapture = false
    }
''', '''        depthCaptureActive = false
        systemPausedCapture = false
        pendingResumeWorldMap = nil
        requiresWorldMapForResume = false
    }
'''),
('''    private static func rows(_ m: simd_float4x4) -> [[Float]] {
        (0..<4).map { row in (0..<4).map { col in m[col][row] } }
    }
''', '''    private static func rows(_ m: simd_float4x4) -> [[Float]] {
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
''')
]

for old, new in replacements:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'ScanModel anchor count={count}: {old[:100]!r}')
    text = text.replace(old, new, 1)
model.write_text(text)

library = Path('splat-native-ios/SplatNative/ScanLibraryView.swift')
text = library.read_text()
replacements = [
('''struct ScanLibraryView: View {
    @Environment(\\.dismiss) private var dismiss
''', '''struct ScanLibraryView: View {
    @Environment(\\.dismiss) private var dismiss
    @EnvironmentObject private var model: ScanModel
'''),
('''        } else {
            rowLabel(project, canOpen: false)
        }
    }

    private func rowLabel(_ project: ScanProjectSummary, canOpen: Bool) -> some View {
''', '''        } else if canContinue(project) {
            VStack(alignment: .leading, spacing: 8) {
                rowLabel(project, canOpen: false)
                Button {
                    model.restoreSavedProject(id: project.id)
                    dismiss()
                } label: {
                    Label(continueLabel(project), systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        } else {
            rowLabel(project, canOpen: false)
        }
    }

    private func canContinue(_ project: ScanProjectSummary) -> Bool {
        guard (try? store.loadCheckpoint(projectURL: project.projectURL)) != nil else { return false }
        let transforms = project.projectURL.appendingPathComponent("transforms.json")
        switch project.manifest.stage {
        case .capturing:
            return store.hasWorldMap(projectURL: project.projectURL)
        case .captured:
            return true
        case .failed:
            return FileManager.default.fileExists(atPath: transforms.path)
                || store.hasWorldMap(projectURL: project.projectURL)
        case .processing, .finished:
            return false
        }
    }

    private func continueLabel(_ project: ScanProjectSummary) -> String {
        switch project.manifest.stage {
        case .capturing: return "撮影を再開"
        case .captured: return "生成へ戻る"
        case .failed: return "保存状態から復旧"
        case .processing, .finished: return "開く"
        }
    }

    private func rowLabel(_ project: ScanProjectSummary, canOpen: Bool) -> some View {
''')
]
for old, new in replacements:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'Library anchor count={count}: {old[:100]!r}')
    text = text.replace(old, new, 1)
library.write_text(text)
