# S3 Splat Viewer / Edit / Measure — Status

Updated: 2026-08-15
Branch: `scaniverse/s3-splat-viewer-edit`
Owner: S3

## Scope

S3 owns initial useful view, orbit/pan/zoom/reset, crop, exposure/contrast, on-device measurement, non-destructive edit state, edit persistence, reprocess/enhance entry points, loading failures, and viewer-side render performance.

## Wave 1 implementation

- Initial framing keeps robust median / 90th-percentile distance and now also derives initial orbit direction from the first capture poses in `transforms.json` when available.
- The 180-degree renderer correction is applied in camera space instead of rotating translated scene data around the world origin.
- One-finger drag: orbit.
- Two-finger drag: real camera/target translation pan.
- Pinch: zoom.
- Two-finger double tap and UI action: reset view.
- Crop is applied to real Splat points, not a visual mask. Source points remain retained in memory, so edits are non-destructive.
- Crop uses robust per-axis 1st/99th percentile ranges when an axis is actively trimmed; untouched axes do not silently drop outliers.
- Exposure and contrast rebuild the displayed Splat point colors. SH inputs keep their higher-order coefficients and modify only SH0/DC color; sRGB inputs stay sRGB.
- Edit settings are persisted next to the Splat as `result.viewer.json`.
- Two-point measurement picks visible Splat positions projected through the active camera and reports distance in mm/cm/m using the original ARKit/world scale.
- Loading/render/edit failures have user-visible recovery/warning states instead of console-only errors.
- Edit rebuilds are debounced and performed from retained source points; point transformation runs off the main actor before a new Metal chunk is swapped in.
- A dedicated viewer UI exposes View / Crop / Adjust / Measure tools plus Reprocess, export, and guarded new-scan actions.

## Regression gates added

`SplatViewerStateTests.swift`

- default settings are non-destructive
- invalid edit ranges are normalized and bounded
- edit settings JSON round-trip
- measurement unit formatting

## Current parity ledger after code implementation, before device validation

| S3 row | State | Evidence / blocker |
|---|---|---|
| Initial useful view | NEAR_PARITY | robust framing + capture-pose initial orbit + camera-space roll fix; real-device representative-set validation still required |
| Orbit / zoom / reset | NEAR_PARITY | implemented; real-device gesture/quality validation required |
| Pan | NEAR_PARITY | true two-finger target translation implemented; real-device direction/sensitivity validation required |
| Crop Splat | NEAR_PARITY | real point filtering + persisted non-destructive state implemented; crop UX and representative scans require device validation |
| Exposure / contrast | NEAR_PARITY | real SH0/sRGB adjustment with higher-order SH retained; visual parity requires device comparison |
| Measurement | NEAR_PARITY | projected two-point selection + AR-scale Euclidean distance implemented; tap accuracy / scale requires real-device validation |
| Edit persistence | PARTIAL | sidecar persistence exists; reopening after full app relaunch depends on S5 library/lifecycle |
| Reprocess entry point | PARTIAL | existing raw reprocess is exposed in viewer; lifecycle robustness belongs to S5 |
| Enhance entry point | MISSING / S2 dependency | do not fake Enhance by restarting training. S2 must expose a genuine continuation/checkpoint or additional-training API before S3 can wire the entry point |
| Edited export contract | S6 dependency | current export shares the base Splat file; S6 must decide/apply persisted viewer edits for edited-file export parity |
| Loading failure UX | NEAR_PARITY | visible retry/error path implemented; corrupt/huge-file validation remains |
| Render performance | PARTIAL | 60 fps target + edit debounce + off-main point transform; real-device frame time, memory and thermal evidence required |

## Explicit cross-session requirements for S0

1. **S2 → S3 Enhance API**: provide a genuine additional-training continuation/checkpoint operation over an already processed raw scan. A fresh 2,000-iteration rerun must not be labeled Enhance.
2. **S5 → S3 reopen contract**: when a saved Splat project is reopened, restore `result.splat` together with `result.viewer.json` and preserve raw data needed for reprocess.
3. **S6 → S3 export contract**: base export versus edited export must be explicit. If exporting edited output, crop and color settings must be applied deterministically rather than merely changing the viewer.
4. **S8 device gate**: verify all gestures, crop sensitivity, measurement tap accuracy, scale, 60-fps behavior, memory, and error recovery on representative scans.

## Human-only gate

S3 must not mark any user-facing viewer row `PARITY` until an iPhone run validates the representative test set against Scaniverse for gesture feel, initial viewpoint, crop usability, edit appearance, measurement accuracy, frame rate, memory, and failure recovery. Until then the highest honest state is `NEAR_PARITY`.
