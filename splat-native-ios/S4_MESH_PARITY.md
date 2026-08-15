# S4 Mesh / Photogrammetry / LiDAR parity ledger

Updated: 2026-08-15 JST
Owner: S4 (`scaniverse/s4-mesh-photogrammetry`)
Baseline: `SCANIVERSE_PARITY_PLAN.md` + Scaniverse current Mesh workflow
Concrete reference: `S4_SCANIVERSE_REFERENCE_20260630.md`

## Rule

A UI control without a real 3D implementation is `MISSING`. Compile-only code cannot be promoted to `PARITY`. Device evidence is required for capture quality, scale, measurement, crop, texture quality, and independent-reader export validation.

## Capability matrix

| Capability | State | Current S4 evidence | Remaining gate |
|---|---|---|---|
| Mesh entry from root | PARTIAL | `RootScanView` routes to real Mesh flow plus runtime supervisor | Device UI check |
| Small / Medium / Large range | PARTIAL | `MeshScanSize` controls LiDAR radius and non-LiDAR voxel resolution/range | Calibrate against representative subjects |
| LiDAR mesh capture | NEAR_PARITY | ARKit `sceneReconstruction`, real `ARMeshAnchor` vertices/normals/faces | LiDAR device scan + visual/geometry audit |
| Metric scale | NEAR_PARITY | ARKit world-space meters retained in LiDAR and Visual Mesh OBJ | Known-length device test |
| Measurement | NEAR_PARITY | Two SceneKit mesh hit-tests + Euclidean world-space distance on metric assets only | Known-length accuracy test; Scaniverse reference demonstrates 36 cm readout |
| Geometry cleanup | PARTIAL | Degenerate-triangle removal, vertex compaction, real OBJ vertex-cluster simplifier | Preserve thin/disconnected detail; reference bouquet has 1,670 components and ~9.83% boundary edges |
| Crop/edit | PARTIAL | Crop removes triangles from real geometry and regenerates OBJ | Scaniverse-style trimming plus tonal/filter/sharpness edit parity |
| RGB raw capture | NEAR_PARITY | JPEG frames + camera transform + intrinsics stored in `.meshproject`; Visual Mesh fallback also stores these | Long-scan/storage stress test |
| LiDAR raw depth retention | PARTIAL | `smoothedSceneDepth`/`sceneDepth` persisted as Float32-meter sidecars with pose/intrinsics index | LiDAR device validation + recovery/reprocess consumption |
| Raw reprocess | PARTIAL | Raw browser can rerun RealityKit reconstruction from stored `.meshproject/images` without recapture | Selectable settings + device repeatability test |
| Textured model | PARTIAL | RealityKit `PhotogrammetrySession` produces textured USDZ on supported devices | **Primary quality gap:** reference GLB is 160,592 vertices / 275,481 triangles with one 8192² atlas; LiDAR-guided RGB texture baking / dense independent path needed |
| Non-LiDAR mesh | PARTIAL | ARKit `rawFeaturePoints` are deduplicated per sampled frame, require observations across 3+ frames, then voxelized and surfaced to metric OBJ; RGB/pose/intrinsics raw retained | Dense multi-view stereo/depth + high-resolution texture comparable to reference |
| OBJ interface | NEAR_PARITY | Real world-space OBJ from LiDAR or Visual Mesh; simplifier can regenerate lighter OBJ | Independent MeshLab/Blender reader test + textured OBJ path |
| USDZ interface | PARTIAL | Object Capture/reprocess output; explicitly marked scale-uncalibrated until calibration exists | Independent reader + explicit scale calibration |
| Exporter-facing asset contract | NEAR_PARITY | `MeshAssetDescriptor` sidecar records format/source/raw location/metric-scale status and coordinate-space contract | S6 consumer validation |
| FBX / GLB / STL / LAS / PLY interfaces | MISSING | S4 exposes canonical asset contract; actual format writers remain S6 scope | S6 exporters + independent readers; reference UI confirms all seven model export choices |
| Pause/resume | NEAR_PARITY | ARSession pause and resume without reset; tracking state is preserved by run without reset options | Device pause/resume continuity test |
| Background auto-pause | NEAR_PARITY | `scenePhase` pauses inactive/background capture and resumes active capture | Device lifecycle/interruption test |
| Mesh simplification | PARTIAL | Real vertex-cluster simplifier writes a new OBJ while retaining source | Texture-aware quality preservation; do not erase petals/leaves/thin surfaces to force watertightness |
| Mesh AR presentation | MISSING | no Scaniverse-equivalent live-camera AR/object toggle in S4 result flow | S0/S3/S4 ownership decision + implementation |

## Accuracy safeguards added during harsh review

1. Non-LiDAR stability is counted across separate sampled frames, not duplicate features inside one frame.
2. Completed Visual Mesh raw projects are retained; reset/discard only deletes an unfinished fallback project.
3. RealityKit photogrammetry USDZ is not falsely labelled as ARKit metric space. Its asset sidecar sets `hasMetricScale=false`, `linearUnit=uncalibrated` until an explicit calibration path exists.
4. Measurement controls are blocked for scale-uncalibrated photogrammetry results so the app cannot display false cm/m values.
5. CI rejects Mesh placeholders/fakes/mocks and any unexpected `URLSession` usage in Mesh implementation files.
6. Cleanup quality is no longer judged by watertightness alone. The supplied Scaniverse bouquet is visibly useful while containing many disconnected components and boundary edges.

## Concrete Scaniverse quality anchor

The user-supplied Scaniverse bouquet GLB is now the first exact Mesh reference:

- 14,363,212-byte GLB;
- 160,592 vertices;
- 275,481 triangles;
- meter-scale bounds ≈ 0.557 × 0.761 × 0.572 m;
- one embedded 8192 × 8192 JPEG UV atlas (~7.84 MB payload);
- no explicit vertex normals in the GLB;
- screen recording demonstrates 36 cm two-point measurement, AR view, trimming/edit controls, sharing and FBX/OBJ/GLB/USDZ/STL/PLY/LAS export choices.

See `S4_SCANIVERSE_REFERENCE_20260630.md` for the structural audit. One sample is not a universal polygon threshold, but an object in the same size/complexity class that is an order of magnitude sparser or lacks a high-resolution texture is an obvious parity failure.

## Current hard blocker to full parity

Apple RealityKit Object Capture on iOS cannot be the sole parity engine. Apple currently limits iOS `PhotogrammetrySession.Request.Detail` to `.reduced`, while the supplied Scaniverse reference materially exceeds that mobile system-output class in both geometry and texture resolution. S4 therefore needs an independent dense/textured reconstruction path.

For LiDAR devices, the next engineering priority is to retain ARKit meter-scale geometry and project/blend the stored RGB camera frames onto that geometry. For non-LiDAR devices, the ARKit feature-point fallback remains a real but coarse safety path; Scaniverse-class parity still requires dense MVS/depth estimation plus texture reconstruction.

## Human-only device gate

Run `S4_DEVICE_ACCEPTANCE.md`. The supplied Scaniverse files are reference evidence, not Scan Lab evidence. S4 cannot promote any physical-quality row to `PARITY` until Scan Lab output from the same/representative subject set is returned.

Current overall S4 state: **PARTIAL**. The reference files reveal a larger texture/density gap than compile-only review could show, so software work is **not** considered exhausted merely because CI is green.
