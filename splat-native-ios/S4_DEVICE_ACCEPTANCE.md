# S4 physical-device acceptance gate

Updated: 2026-08-15 JST
Branch: `scaniverse/s4-mesh-photogrammetry`

This gate exists because compilation cannot validate ARKit mesh quality, physical scale, LiDAR depth, photogrammetry texture quality, tracking continuity, or independent-reader interoperability.

## A. LiDAR device

Use a LiDAR-capable iPhone/iPad and a known-length target such as a rigid 20–50 cm box/ruler arrangement.

1. Open Scan Lab → Mesh → LiDAR mesh → Medium.
2. Scan the known-length target from multiple sides until generation is enabled.
3. Press Pause; move the phone normally; press Resume and continue capture.
4. During the same capture, background the app once, wait briefly, foreground it, and continue.
5. Finish and generate the OBJ.
6. Use 2-point measurement on the known-length target.
7. Record physical length, measured length and absolute/percentage error.
8. Apply crop and export OBJ; verify removed geometry is actually absent after reopening.
9. Generate the simplified OBJ at approximately 55%; compare face count and obvious shape loss.
10. If enough RGB frames exist and Object Capture is supported, generate textured USDZ. Confirm it displays the scale-uncalibrated warning and does not expose metric measurement.
11. Confirm the saved raw project contains RGB images, `mesh-project.json`, `lidar-depth/depth-index.json` and `.f32` depth samples.
12. Reprocess the saved raw images without recapturing and confirm a second USDZ is produced.

Pass targets:
- No crash or unrecoverable tracking reset across manual pause/resume or background/foreground.
- Metric OBJ measurement error <= 3% on the known-length target for a normal, well-observed surface. Record actual error even if it fails.
- Crop changes exported geometry, not only the preview.
- Simplified OBJ remains recognizable and opens without repair.
- Depth samples exist and their index dimensions match the stored payload size (`width × height × 4 bytes`).
- Reprocess succeeds from existing raw capture.

## B. Non-LiDAR device

Use an ARKit-capable iPhone where both LiDAR scene reconstruction and iOS Object Capture are unavailable. Prefer a textured, rigid subject such as a shoe, printed box or toy.

1. Open Scan Lab → Mesh. Confirm `非LiDAR Visual Mesh` is offered.
2. Start Visual Mesh and move slowly around the subject with overlapping views.
3. Continue until at least 16 RGB frames and 48 stable 3D voxels are reported.
4. Generate Visual Mesh.
5. Inspect whether the OBJ is connected, roughly matches the subject silhouette, and preserves plausible physical scale.
6. Open the OBJ in an independent reader and record whether repair is required.
7. Repeat once with a low-texture or glossy subject and record the failure behavior rather than forcing a pass.

Pass targets for the fallback itself:
- No fake/prebundled geometry; output changes materially with the scanned subject.
- Generated OBJ is non-empty and third-party readable.
- Scale is broadly consistent with ARKit world coordinates.
- Failure on weak visual features is explicit rather than silently producing a convincing but wrong model.

Important: even a full pass here does **not** promote non-LiDAR Mesh to Scaniverse `PARITY`. This fallback is intentionally coarse; dense textured non-LiDAR MVS remains a separate quality gap.

## C. Representative quality set

At minimum repeat relevant paths on:
- textured small toy
- plush / cloth
- shoe
- ceramic object
- glossy mixed-material object
- room corner / medium scene

For each capture retain:
- device model and iOS version
- mode and range
- screenshots or screen recording
- output OBJ/USDZ where possible
- processing time
- visible holes/double geometry/texture defects
- crash/thermal/storage observations

## Stop/return rule

If any test fails, return the exact failed step plus evidence to S4; do not mark the row `PARITY`. S4 should then implement the smallest reproducible fix and add a regression gate before retesting.
