# SCAN-001 Stable Frame Engine

## Goal

Select only completed, stable book pages from a continuous video. A page-turn boundary is **not** a page candidate by itself.

## Pipeline

1. `AVAssetReader` decodes video sequentially.
2. Sample at 8 fps by default; convert each sampled frame to a 64x48 luma thumbnail.
3. Measure frame-to-frame motion with normalized mean absolute difference (MAD).
4. Feed observations into a streaming stability state machine.
5. Accept only stable runs lasting at least 420 ms, with settle/departure padding.
6. Pick the best frame inside each stable run using 60% sharpness, 30% stability, 10% temporal centrality.
7. Collapse consecutive runs that are the same page using exposure-insensitive centered MAD plus dHash distance.
8. Re-open only the selected timestamps at full resolution with `AVAssetImageGenerator` and write JPEGs plus `page_candidates.json`.

The streaming selector retains only the active run and one small thumbnail per accepted page, avoiding memory growth proportional to video frame count.

## Why not simple scene-change detection?

Scene-change detection is useful for finding motion boundaries, but a page turn itself is a large scene change. Selecting the boundary frame directly risks capturing fingers, curled paper, blur, or a half-turned page. The stable-frame engine uses the motion spike only to end a prior stable run; it waits for a new stable run before selecting another page.

The fixture test `testStableSelectorDiffersFromNaiveSceneChangeBaseline` demonstrates this: the naive baseline chooses the transition boundary while the stable selector never chooses it.

## Current calibration defaults

- analysis: 8 fps
- stable motion: <= 0.035 normalized MAD
- unstable motion: >= 0.075 normalized MAD
- minimum stable duration: 420 ms
- settle padding: 120 ms
- departure padding: 80 ms
- duplicate test: centered MAD <= 0.020 AND dHash distance <= 6

These are initial fixture-safe defaults, **not Golden-calibrated constants**. They must be tuned against `RPReplay_Final1787451151.mp4` before Golden PASS.

## Golden Dataset status

The Golden video is intentionally not committed to GitHub. In the current Worker session its binary is unavailable, so Golden page recall, transition false-positive rate, and duplicate rate remain pending. The engine must not be marked Golden PASS until the provided video is run and results are recorded as evidence.
