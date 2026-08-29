#!/usr/bin/env python3
"""Materialize the isolated S13 depth-seed experiment into ScanModel.swift.

This intentionally patches only three narrow call sites so Build 8's memory/densification
contracts remain unchanged:
1. prefer smoothedSceneDepth when capturing future depth maps,
2. copy persisted depth metadata into Sendable S13 frame descriptors before Task.detached,
3. regenerate points3D.ply with the S13 recipe and invalidate only pre-S13 checkpoints.

The script is idempotent and fails closed if the expected HQ source shape drifts.
"""
from __future__ import annotations

import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
MODEL_PATH = ROOT / "SplatNative" / "ScanModel.swift"
text = MODEL_PATH.read_text()

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

MODEL_PATH.write_text(text)
print("S13 depth-seed materialization complete")
