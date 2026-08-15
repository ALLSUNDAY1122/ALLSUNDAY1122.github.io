# S4 physical-device acceptance gate

Updated: 2026-08-15 JST
Branch: `scaniverse/s4-mesh-photogrammetry`
Reference: `S4_SCANIVERSE_REFERENCE_20260630.md`

This gate exists because compilation cannot validate ARKit mesh quality, physical scale, RGB projection quality, LiDAR depth, tracking continuity, AR placement, or independent-reader interoperability.

The user-supplied Scaniverse bouquet recording/GLB is a **reference target only**. It must never be counted as Scan Lab evidence.

## A. LiDAR device

Use a LiDAR-capable iPhone/iPad and a known-length target such as a rigid 20–50 cm box/ruler arrangement.

1. Open Scan Lab → Mesh → LiDAR mesh → Medium.
2. Scan the known-length target from multiple sides until generation is enabled.
3. Press Pause; move the phone normally; press Resume and continue capture.
4. During the same capture, background the app once, wait briefly, foreground it, and continue.
5. Finish. Confirm a metric OBJ is generated and RGB texture baking starts automatically when 8+ RGB frames exist.
6. Confirm the final result is `mesh-textured.obj` plus `mesh-textured.mtl` and `mesh-textured-atlas.jpg`. If baking fails, confirm the raw shape OBJ remains usable and the failure is reported as texture-only.
7. Open `mesh-texture-bake.json` and record: selectedFrames, totalTriangles, assignedTriangles, projectionCoverage, atlasWidth/Height.
8. Inspect the textured result closely for wrong-camera projections, mirrored/upside-down imagery, large seams, ghosting, blank/gray patches and texture swimming. Record rather than hide defects.
9. Use 2-point measurement on the known-length target.
10. Record physical length, measured length and absolute/percentage error.
11. Open `ARビュー`, switch between `AR / オブジェクト`, place the Mesh on a horizontal surface and visually compare the known-length target to its physical size. The AR viewer must only be available for metric assets.
12. Apply crop and export OBJ; verify removed geometry is actually absent after reopening.
13. Generate the simplified OBJ at approximately 55%; compare face count and obvious shape loss.
14. If Object Capture is supported, separately generate its textured USDZ. Confirm that path still displays the scale-uncalibrated warning and does not expose metric measurement/metric AR placement.
15. Confirm the saved raw project contains RGB images, `mesh-project.json`, `lidar-depth/depth-index.json` and `.f32` depth samples.
16. Reprocess the saved raw images without recapturing and confirm a second result is produced.

Pass targets:
- No crash or unrecoverable tracking reset across manual pause/resume or background/foreground.
- Metric OBJ measurement error <= 3% on the known-length target for a normal, well-observed surface. Record actual error even if it fails.
- RGB atlas generation preserves ARKit meter scale.
- Texture projection is materially useful rather than a decorative atlas: no systematic orientation flip and no widespread unrelated-camera projection.
- `projectionCoverage` is recorded for every textured result. Until enough device samples exist, do not invent a universal numeric PASS threshold; visually poor coverage remains a failure even when the percentage is high.
- For similarly complex captures with >=100k triangles, the current baker should select an 8192 × 8192 atlas; 25k–99,999 uses 4096²; smaller uses 2048². Record actual memory/thermal behavior.
- Crop changes exported geometry, not only the preview.
- Simplified OBJ remains recognizable and opens without repair.
- Depth samples exist and their index dimensions match the stored payload size (`width × height × 4 bytes`).
- Reprocess succeeds from existing raw capture.
- AR placement does not scale the metric Mesh arbitrarily.

## B. Scaniverse bouquet reference comparison

For a flower/bouquet or similarly thin, complex ~0.5–0.8 m subject, compare against `S4_SCANIVERSE_REFERENCE_20260630.md`.

Reference values from the supplied Scaniverse GLB:
- 160,592 vertices;
- 275,481 triangles;
- bounding box ≈ 0.557 × 0.761 × 0.572 m;
- one embedded 8192 × 8192 JPEG atlas;
- 1,670 connected vertex components;
- ~9.83% boundary edges;
- visible recording measurement: 36 cm.

Record for the Scan Lab capture:
- vertices / triangles;
- metric bounding box;
- atlas dimensions and file size;
- `projectionCoverage`;
- number/character of visible holes;
- preservation of petals/leaves/stems/wrapping;
- whether cleanup incorrectly deletes disconnected thin parts;
- measurement error;
- capture time and post-processing time;
- peak-visible thermal/memory/storage symptoms.

One reference scan is not a universal polygon-count rule. However, a comparable subject that is an order of magnitude sparser, loses thin structures, or lacks useful high-resolution texture is an obvious practical-quality failure and remains below `PARITY`.

## C. Non-LiDAR device

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

## D. Representative quality set

At minimum repeat relevant paths on:
- textured small toy
- plush / cloth
- shoe
- ceramic object
- flower bouquet / thin foliage-like subject
- glossy mixed-material object
- room corner / medium scene

For each capture retain:
- device model and iOS version
- mode and range
- screenshots or screen recording
- output OBJ/USDZ where possible
- `mesh-texture-bake.json` when applicable
- processing time
- visible holes/double geometry/texture defects
- crash/thermal/storage observations

## Stop/return rule

If any test fails, return the exact failed step plus evidence to S4; do not mark the row `PARITY`. S4 should then implement the smallest reproducible fix and add a regression gate before retesting.
