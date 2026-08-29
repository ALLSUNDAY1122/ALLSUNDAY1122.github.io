#!/usr/bin/env python3
"""Materialize the isolated S13 geometry experiment into the iOS app.

The patch is deliberately narrow and evidence-driven:
1. prefer smoothedSceneDepth for future captures while retaining sceneDepth fallback,
2. rebuild points3D.ply from persisted depth when available and invalidate only pre-S13 trainer checkpoints,
3. expose a same-raw reprocess entry for trusted finished scans so the physical A/B test does not require recapture,
4. preserve the currently trusted result before reprocess so any failed experiment can recover it.

The script is idempotent and fails closed if the expected HQ source shape drifts.
"""
from __future__ import annotations

import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
MODEL_PATH = ROOT / "SplatNative" / "ScanModel.swift"
LIBRARY_PATH = ROOT / "SplatNative" / "ScanLibraryView.swift"
text = MODEL_PATH.read_text()
library = LIBRARY_PATH.read_text()

old_depth = "let depthPayload = ignoreLiDAR ? nil : Self.copyDepthPayload(frame.sceneDepth?.depthMap)"
new_depth = "let depthPayload = ignoreLiDAR ? nil : Self.copyDepthPayload((frame.smoothedSceneDepth ?? frame.sceneDepth)?.depthMap)"
if old_depth in text:
    text = text.replace(old_depth, new_depth, 1)
elif new_depth not in text:
    raise SystemExit("S13: capture depth callsite drifted")

old_frames = """        let geometryPoints = Array(featurePoints.values)\n        let seedFrames = captured.map(Self.seedFrame(from:))\n        let firstSourceFrame = captured.first\n"""
new_frames = """        let geometryPoints = Array(featurePoints.values)\n        let seedFrames = captured.map(Self.seedFrame(from:))\n        let depthSeedFrames = captured.map { frame in\n            SplatDepthSeedFrame(\n                depthFilePath: frame.depthFilePath,\n                depthWidth: frame.depthWidth,\n                depthHeight: frame.depthHeight,\n                depthBytesPerRow: frame.depthBytesPerRow,\n                transformMatrix: frame.transformMatrix,\n                flX: frame.flX,\n                flY: frame.flY,\n                cx: frame.cx,\n                cy: frame.cy,\n                w: frame.w,\n                h: frame.h\n            )\n        }\n        let firstSourceFrame = captured.first\n"""
if old_frames in text:
    text = text.replace(old_frames, new_frames, 1)
elif new_frames not in text:
    raise SystemExit("S13: detached seed-frame callsite drifted")

old_prepare = """                do {\n                    let plyURL = projectURL.appendingPathComponent(\"points3D.ply\")\n                    if !FileManager.default.fileExists(atPath: plyURL.path) {\n                        try Self.preparePointCloudPLY(\n                            projectURL: projectURL,\n                            points: geometryPoints,\n                            frames: seedFrames\n                        )\n                    }\n                } catch {\n"""
new_prepare = """                do {\n                    let seedOutcome = try SplatDepthSeedBuilder.preparePointCloudPLY(\n                        projectURL: projectURL,\n                        depthFrames: depthSeedFrames,\n                        fallbackPoints: geometryPoints,\n                        colorFrames: seedFrames\n                    )\n                    if seedOutcome.requiresFreshTrainer,\n                       FileManager.default.fileExists(atPath: checkpoint.path) {\n                        try? FileManager.default.removeItem(at: checkpoint)\n                    }\n                    writeEarlyReport(\n                        \"running-preflight-seed-\\(seedOutcome.source.rawValue)\",\n                        .preflight,\n                        nil,\n                        nil\n                    )\n                } catch {\n"""
if old_prepare in text:
    text = text.replace(old_prepare, new_prepare, 1)
elif new_prepare not in text:
    raise SystemExit("S13: preflight point-cloud callsite drifted")

restore_marker = """    func restoreSavedProject(id: String) {\n"""
reprocess_method = """    /// S13 physical A/B entry: re-run reconstruction from the exact same durable raw capture.\n    /// The current trusted result is protected before entering `.captured`, while the on-disk\n    /// manifest intentionally remains `.finished`. When `train()` transitions it to `.processing`,\n    /// the normal Store swap therefore preserves the current result as the previous result.\n    func restoreFinishedProjectForS13Reprocess(id: String) {\n        do {\n            let summary = try projectStore.loadProject(id: id)\n            guard summary.manifest.stage == .finished,\n                  summary.manifest.rawDataRetained,\n                  let trustedURL = SplatProjectTrustRecovery.trustedResultURL(for: summary),\n                  (try? projectStore.reprocessRequest(\n                    projectURL: summary.projectURL,\n                    representation: .splat\n                  )) != nil else {\n                throw dataError(\"同じ撮影から再生成するためのrawデータを確認できません\")\n            }\n            let checkpoint = try projectStore.loadCheckpoint(projectURL: summary.projectURL)\n            try SplatPreviousResultEvidence.preserveBeforeReprocess(sourceURL: trustedURL)\n\n            invalidateWorldMapPersistence()\n            session?.pause()\n            closeActiveCaptureTiming()\n            projectURL = summary.projectURL\n            imagesURL = summary.projectURL.appendingPathComponent(\"images\", isDirectory: true)\n            depthURL = summary.projectURL.appendingPathComponent(\"depth\", isDirectory: true)\n            restoreCaptureCheckpoint(checkpoint)\n            targetFrames = summary.manifest.targetFrames\n            pendingTrainingTarget = SplatReconstructionPolicy.standardIterations\n            pendingResumeWorldMap = loadPersistedWorldMap(projectURL: summary.projectURL)\n            requiresWorldMapForResume = true\n            userPauseRequested = false\n            systemPausedCapture = false\n            activeCaptureStartedAt = nil\n            resultURL = trustedURL\n            if let thumbnail = summary.thumbnailURL {\n                previewImage = UIImage(contentsOfFile: thumbnail.path)\n            }\n            datasetReady = true\n            phase = .captured\n            isCapturePaused = false\n            trackingNeedsRecovery = false\n            stableTrackingFrames = 0\n            trainingProgress = 0\n            trainingIteration = 0\n            splatCount = 0\n            trackingMessage = \"同じ撮影rawを読み込みました。撮影を追加せず「3Dを生成」でS13比較を開始できます\"\n            UIApplication.shared.isIdleTimerDisabled = false\n        } catch {\n            let message = \"同じ撮影から再生成する準備に失敗しました: \\(error.localizedDescription)\"\n            phase = .failed(message)\n            trackingMessage = message\n            UIApplication.shared.isIdleTimerDisabled = false\n        }\n    }\n\n"""
if reprocess_method not in text:
    if restore_marker not in text:
        raise SystemExit("S13: saved-project restore callsite drifted")
    text = text.replace(restore_marker, reprocess_method + restore_marker, 1)

old_trusted_row = """        if let trustedURL = SplatProjectTrustRecovery.trustedResultURL(for: project) {\n            NavigationLink {\n                SavedSplatView(\n                    url: trustedURL,\n                    title: project.manifest.title\n                )\n            } label: {\n                rowLabel(project, canOpen: true)\n            }\n        } else if canContinue(project) {\n"""
new_trusted_row = """        if let trustedURL = SplatProjectTrustRecovery.trustedResultURL(for: project) {\n            VStack(alignment: .leading, spacing: 8) {\n                NavigationLink {\n                    SavedSplatView(\n                        url: trustedURL,\n                        title: project.manifest.title\n                    )\n                } label: {\n                    rowLabel(project, canOpen: true)\n                }\n                if canReprocessTrusted(project) {\n                    Button {\n                        model.restoreFinishedProjectForS13Reprocess(id: project.id)\n                        dismiss()\n                    } label: {\n                        Label(\"同じ撮影から再生成\", systemImage: \"arrow.triangle.2.circlepath\")\n                            .frame(maxWidth: .infinity)\n                    }\n                    .buttonStyle(.bordered)\n                    .accessibilityHint(\"現在の完成3Dを保護し、保存済みraw撮影だけを使って再生成します\")\n                }\n            }\n        } else if canContinue(project) {\n"""
if old_trusted_row in library:
    library = library.replace(old_trusted_row, new_trusted_row, 1)
elif new_trusted_row not in library:
    raise SystemExit("S13: trusted library row callsite drifted")

continue_marker = """    private func canContinue(_ project: ScanProjectSummary) -> Bool {\n"""
can_reprocess = """    private func canReprocessTrusted(_ project: ScanProjectSummary) -> Bool {\n        guard project.manifest.stage == .finished,\n              project.manifest.rawDataRetained,\n              (try? store.loadCheckpoint(projectURL: project.projectURL)) != nil,\n              (try? store.reprocessRequest(\n                projectURL: project.projectURL,\n                representation: .splat\n              )) != nil else {\n            return false\n        }\n        return true\n    }\n\n"""
if can_reprocess not in library:
    if continue_marker not in library:
        raise SystemExit("S13: library continuation helper callsite drifted")
    library = library.replace(continue_marker, can_reprocess + continue_marker, 1)

MODEL_PATH.write_text(text)
LIBRARY_PATH.write_text(library)
print("S13 depth-seed + same-raw reprocess materialization complete")
