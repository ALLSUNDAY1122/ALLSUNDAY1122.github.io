#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT / "splat-native-ios/SplatNative/ScanModel.swift"
TESTS = ROOT / "splat-native-ios/SplatNativeTests/ScanColdResumePersistenceTests.swift"
HELPER = ROOT / "splat-native-ios/SplatNative/ScanWorldMapArchiveStore.swift"
GATE = ROOT / "splat-native-ios/scripts/test_worldmap_durability_contract.py"
WORKFLOW = ROOT / ".github/workflows/splat-native-ios.yml"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, got {count}")
    return text.replace(old, new, 1)


def regex_once(text: str, pattern: str, replacement: str, label: str) -> str:
    out, count = re.subn(pattern, lambda _: replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, got {count}")
    return out


model = MODEL.read_text()
if "persistWorldMapForTransition(" in model and "ScanWorldMapArchiveStore.write(data, to: targetURL)" in model:
    print("WorldMap transition patch already present")
else:
    depth_block = (
        "    private struct DepthPayload: Sendable {\n"
        "        let data: Data\n"
        "        let width: Int\n"
        "        let height: Int\n"
        "        let bytesPerRow: Int\n"
        "    }\n"
    )
    enums = (
        "\n"
        "    private enum WorldMapArchiveResult: Sendable {\n"
        "        case data(Data)\n"
        "        case failed(String)\n"
        "    }\n"
        "\n"
        "    private enum WorldMapPersistenceOutcome: Sendable {\n"
        "        case saved\n"
        "        case reusedExisting(String)\n"
        "        case failed(String)\n"
        "    }\n"
    )
    model = replace_once(model, depth_block, depth_block + enums, "WorldMap result types")

    model = replace_once(
        model,
        "    @Published var depthCaptureActive = false\n",
        "    @Published var depthCaptureActive = false\n"
        "    @Published private(set) var isWorldMapPersistencePending = false\n",
        "published WorldMap state",
    )
    model = replace_once(
        model,
        "    private var requiresWorldMapForResume = false\n",
        "    private var requiresWorldMapForResume = false\n"
        "    private var periodicWorldMapPersistenceTask: Task<Void, Never>?\n"
        "    private var worldMapPersistenceGeneration = 0\n"
        "    private var worldMapPersistenceWarning: String?\n"
        "    private var userPauseRequested = false\n",
        "private WorldMap state",
    )
    model = replace_once(
        model,
        "        !isWritingFrame &&\n        !trackingNeedsRecovery\n",
        "        !isWritingFrame &&\n        !trackingNeedsRecovery &&\n        !isWorldMapPersistencePending\n",
        "finish admission",
    )
    model = replace_once(
        model,
        "    var captureBand: String {\n        if isCapturePaused { return \"一時停止中\" }\n",
        "    var captureBand: String {\n        if isWorldMapPersistencePending { return \"位置を保存中\" }\n"
        "        if isCapturePaused { return \"一時停止中\" }\n",
        "capture persistence band",
    )
    model = replace_once(
        model,
        "    var captureQualityText: String {\n        if isCapturePaused {\n",
        "    var captureQualityText: String {\n"
        "        if isWorldMapPersistencePending {\n"
        "            return \"撮影位置を安全に保存しています。完了するまでこの画面を維持します\"\n"
        "        }\n"
        "        if isCapturePaused {\n",
        "capture persistence message",
    )

    pause = '''    func pauseCapture() {
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
'''
    model = regex_once(
        model,
        r"    func pauseCapture\(\) \{.*?\n    \}\n(?=\n    func resumeCapture\(\))",
        pause.rstrip("\n"),
        "pauseCapture",
    )

    resume = '''    func resumeCapture() {
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
'''
    model = regex_once(
        model,
        r"    func resumeCapture\(\) \{.*?\n    \}\n(?=\n    func finishCapture\(\))",
        resume.rstrip("\n"),
        "resumeCapture",
    )

    finish = '''    func finishCapture() {
        guard phase == .capturing,
              canFinishCapture,
              !isWorldMapPersistencePending,
              let projectURL else { return }

        closeActiveCaptureTiming()
        isCapturePaused = true
        userPauseRequested = true
        do {
            // A captured project must be independently processable before the UI can leave capture.
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
'''
    model = regex_once(
        model,
        r"    func finishCapture\(\) \{.*?\n    \}\n(?=\n    func discardAndReset\(\))",
        finish.rstrip("\n"),
        "finishCapture",
    )

    model = replace_once(
        model,
        "    func discardAndReset() {\n        closeActiveCaptureTiming()\n",
        "    func discardAndReset() {\n        invalidateWorldMapPersistence()\n        closeActiveCaptureTiming()\n",
        "discard invalidation",
    )
    model = replace_once(
        model,
        "        pendingResumeWorldMap = nil\n        requiresWorldMapForResume = false\n        phase = .ready\n",
        "        pendingResumeWorldMap = nil\n        requiresWorldMapForResume = false\n"
        "        userPauseRequested = false\n        worldMapPersistenceWarning = nil\n        phase = .ready\n",
        "discard WorldMap reset",
    )

    model = replace_once(
        model,
        "                if self.acceptedFrames % 12 == 0 {\n                    self.persistWorldMapIfPossible()\n                }\n",
        "                if self.acceptedFrames == 1 || self.acceptedFrames % 12 == 0 {\n"
        "                    self.schedulePeriodicWorldMapPersistence()\n"
        "                }\n",
        "periodic WorldMap scheduling",
    )

    model = replace_once(
        model,
        "            let checkpoint = try projectStore.loadCheckpoint(projectURL: summary.projectURL)\n\n            session?.pause()\n",
        "            let checkpoint = try projectStore.loadCheckpoint(projectURL: summary.projectURL)\n\n"
        "            invalidateWorldMapPersistence()\n            session?.pause()\n",
        "restore persistence invalidation",
    )
    model = replace_once(
        model,
        "            requiresWorldMapForResume = true\n            systemPausedCapture = false\n",
        "            requiresWorldMapForResume = true\n            userPauseRequested = false\n            systemPausedCapture = false\n",
        "restore pause intent",
    )

    worldmap = '''    private func schedulePeriodicWorldMapPersistence() {
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
'''
    model = regex_once(
        model,
        r"    private func persistWorldMapIfPossible\(\) \{.*?\n    \}\n(?=\n    private func loadPersistedWorldMap)",
        worldmap.rstrip("\n"),
        "WorldMap persistence implementation",
    )

    lifecycle = '''    func handleSessionInterrupted() {
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
'''
    model = regex_once(
        model,
        r"    func handleSessionInterrupted\(\) \{.*?\n    \}\n\n    func handleSessionInterruptionEnded\(\) \{.*?\n    \}\n\n    func handleApplicationBecameInactive\(\) \{.*?\n    \}\n\n    func handleApplicationBecameActive\(\) \{.*?\n    \}",
        lifecycle.rstrip("\n"),
        "session interruption lifecycle",
    )

    reset = '''    private func resetCaptureStateForNewProject() {
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
'''
    model = regex_once(
        model,
        r"    private func resetCaptureStateForNewProject\(\) \{.*?\n    \}\n(?=\n    private func limitedReason)",
        reset.rstrip("\n"),
        "new project reset",
    )

    if "persistWorldMapIfPossible()" in model:
        raise SystemExit("obsolete fire-and-forget WorldMap method/call remains")
    MODEL.write_text(model)

HELPER.write_text('''import Foundation

enum ScanWorldMapArchiveStoreError: LocalizedError {
    case emptyArchive
    case missingParentDirectory
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .emptyArchive: return "WorldMap archiveが空です"
        case .missingParentDirectory: return "WorldMap保存先projectがありません"
        case .verificationFailed: return "保存したWorldMap archiveを検証できません"
        }
    }
}

enum ScanWorldMapArchiveStore {
    static func write(_ data: Data, to targetURL: URL) throws {
        guard !data.isEmpty else { throw ScanWorldMapArchiveStoreError.emptyArchive }
        let parent = targetURL.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ScanWorldMapArchiveStoreError.missingParentDirectory
        }

        try data.write(to: targetURL, options: .atomic)
        let values = try targetURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true,
              values.fileSize == data.count else {
            throw ScanWorldMapArchiveStoreError.verificationFailed
        }
    }
}
''')

tests = TESTS.read_text()
if "testWorldMapArchiveStoreAtomicallyReplacesExistingArchive" not in tests:
    addition = '''
    func testWorldMapArchiveStoreAtomicallyReplacesExistingArchive() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let target = root.appendingPathComponent("worldmap.arexperience")
        try Data([0x01]).write(to: target, options: .atomic)

        let replacement = Data([0x10, 0x20, 0x30, 0x40])
        try ScanWorldMapArchiveStore.write(replacement, to: target)

        XCTAssertEqual(try Data(contentsOf: target), replacement)
    }

    func testWorldMapArchiveStoreRejectsEmptyArchiveWithoutReplacingExistingData() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let target = root.appendingPathComponent("worldmap.arexperience")
        let existing = Data([0xAA, 0xBB])
        try existing.write(to: target, options: .atomic)

        XCTAssertThrowsError(try ScanWorldMapArchiveStore.write(Data(), to: target))
        XCTAssertEqual(try Data(contentsOf: target), existing)
    }
'''
    close = tests.rfind("\n}")
    if close < 0:
        raise SystemExit("ScanColdResumePersistenceTests closing brace not found")
    TESTS.write_text(tests[:close] + "\n" + addition + tests[close:])

GATE.write_text('''#!/usr/bin/env python3
from pathlib import Path
import re

model = Path("splat-native-ios/SplatNative/ScanModel.swift").read_text()
helper = Path("splat-native-ios/SplatNative/ScanWorldMapArchiveStore.swift").read_text()
tests = Path("splat-native-ios/SplatNativeTests/ScanColdResumePersistenceTests.swift").read_text()

if "persistWorldMapIfPossible()" in model:
    raise SystemExit("WorldMap durability regression: fire-and-forget persistence returned")
for needle in (
    "isWorldMapPersistencePending",
    "persistWorldMapForTransition(",
    "schedulePeriodicWorldMapPersistence()",
    "ScanWorldMapArchiveStore.write(data, to: targetURL)",
    "acceptedFrames == 1 || self.acceptedFrames % 12 == 0",
    "invalidateWorldMapPersistence()",
):
    if needle not in model:
        raise SystemExit(f"missing WorldMap durability contract: {needle}")

pause = re.search(r"func pauseCapture\\(\\) \\{(.*?)\\n    \\}\\n\\n    func resumeCapture", model, re.S)
finish = re.search(r"func finishCapture\\(\\) \\{(.*?)\\n    \\}\\n\\n    func discardAndReset", model, re.S)
if not pause or pause.group(1).find("persistWorldMapForTransition") > pause.group(1).find("session?.pause()"):
    raise SystemExit("pauseCapture must settle WorldMap before pausing ARSession")
if not finish or finish.group(1).find("persistWorldMapForTransition") > finish.group(1).find("self.phase = .captured"):
    raise SystemExit("finishCapture must settle WorldMap before exposing captured UI")
if "try data.write(to: targetURL, options: .atomic)" not in helper or "values.fileSize == data.count" not in helper:
    raise SystemExit("WorldMap archive store must atomically write and verify byte count")
if "testWorldMapArchiveStoreRejectsEmptyArchiveWithoutReplacingExistingData" not in tests:
    raise SystemExit("missing WorldMap archive replacement regression")
print("PASS: WorldMap pause/finish persistence is ordered, serialized, atomic, and failure-aware")
''')

workflow = WORKFLOW.read_text()
anchor = "          python3 splat-native-ios/scripts/test_mesh_durability_contract.py\n"
if "test_worldmap_durability_contract.py" not in workflow:
    if anchor not in workflow:
        raise SystemExit("main workflow static-check anchor not found")
    workflow = workflow.replace(
        anchor,
        anchor + "          python3 splat-native-ios/scripts/test_worldmap_durability_contract.py\n",
        1,
    )
    WORKFLOW.write_text(workflow)

print("WorldMap transition patch applied")
