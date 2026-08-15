# S4 Mesh / Photogrammetry / LiDAR parity ledger

Updated: 2026-08-15 JST
Owner: S4 (`scaniverse/s4-mesh-photogrammetry`)
Baseline: `SCANIVERSE_PARITY_PLAN.md` + Scaniverse current Mesh workflow

## Rule

A UI control without a real 3D implementation is `MISSING`. Compile-only code cannot be promoted to `PARITY`. Device evidence is required for capture quality, scale, measurement, crop, texture quality, and independent-reader export validation.

## Capability matrix

| Capability | State | Current S4 evidence | Remaining gate |
|---|---|---|---|
| Mesh entry from root | PARTIAL | `RootScanView` routes to real Mesh flow plus runtime supervisor | Device UI check |
| Small / Medium / Large range | PARTIAL | `MeshScanSize` controls LiDAR radius and non-LiDAR voxel resolution/range | Calibrate against representative subjects |
| LiDAR mesh capture | NEAR_PARITY | ARKit `sceneReconstruction`, real `ARMeshAnchor` vertices/normals/faces | LiDAR device scan + visual/geometry audit |
| Metric scale | NEAR_PARITY | ARKit world-space meters retained in LiDAR and Visual Mesh OBJ | Known-length device test |
| Measurement | NEAR_PARITY | Two SceneKit mesh hit-tests + Euclidean world-space distance on metric assets only | Known-length accuracy test |
| Geometry cleanup | PARTIAL | Degenerate-triangle removal, vertex compaction, real OBJ vertex-cluster simplifier | Hole/noise/simplification quality audit |
| Crop/edit | PARTIAL | Crop removes triangles from real geometry and regenerates OBJ | Round/cylindrical crop + interactive bounds parity |
| RGB raw capture | NEAR_PARITY | JPEG frames + camera transform + intrinsics stored in `.meshproject`; Visual Mesh fallback also stores these | Long-scan/storage stress test |
| LiDAR raw depth retention | PARTIAL | `smoothedSceneDepth`/`sceneDepth` persisted as Float32-meter sidecars with pose/intrinsics index | LiDAR device validation + recovery/reprocess consumption |
| Raw reprocess | PARTIAL | Raw browser can rerun RealityKit reconstruction from stored `.meshproject/images` without recapture | Selectable settings + device repeatability test |
| Textured model | PARTIAL | RealityKit `PhotogrammetrySession` produces textured USDZ on supported devices | Device quality audit; metric calibration / LiDAR-guided texture baking needed |
| Non-LiDAR mesh | PARTIAL | ARKit `rawFeaturePoints` are deduplicated per sampled frame, require observations across 3+ frames, then voxelized and surfaced to metric OBJ; RGB/pose/intrinsics raw retained | Dense multi-view stereo + texture quality comparable to Scaniverse |
| OBJ interface | NEAR_PARITY | Real world-space OBJ from LiDAR or Visual Mesh; simplifier can regenerate lighter OBJ | Independent MeshLab/Blender reader test |
| USDZ interface | PARTIAL | Object Capture/reprocess output; explicitly marked scale-uncalibrated until calibration exists | Independent reader + explicit scale calibration |
| Exporter-facing asset contract | NEAR_PARITY | `MeshAssetDescriptor` sidecar records format/source/raw location/metric-scale status and coordinate-space contract | S6 consumer validation |
| FBX / GLB / STL / LAS / PLY interfaces | MISSING | S4 now exposes canonical asset contract; actual format writers remain S6 scope | S6 exporters + independent readers |
| Pause/resume | NEAR_PARITY | ARSession pause and resume without reset; tracking state is preserved by run without reset options | Device pause/resume continuity test |
| Background auto-pause | NEAR_PARITY | `scenePhase` pauses inactive/background capture and resumes active capture | Device lifecycle/interruption test |
| Mesh simplification | PARTIAL | Real vertex-cluster simplifier writes a new OBJ while retaining source | Quality-preserving target-density calibration |

## Accuracy safeguards added during harsh review

1. Non-LiDAR stability is counted across separate sampled frames, not duplicate features inside one frame.
2. Completed Visual Mesh raw projects are retained; reset/discard only deletes an unfinished fallback project.
3. RealityKit photogrammetry USDZ is not falsely labelled as ARKit metric space. Its asset sidecar sets `hasMetricScale=false`, `linearUnit=uncalibrated` until an explicit calibration path exists.
4. Measurement controls are blocked for scale-uncalibrated photogrammetry results so the app cannot display false cm/m values.
5. CI rejects Mesh placeholders/fakes/mocks and any unexpected `URLSession` usage in Mesh implementation files.

## Current hard blocker to full parity

Apple RealityKit Object Capture on iOS is hardware-gated, so it cannot supply Scaniverse-class dense photogrammetry across non-LiDAR devices. S4 now has a genuine non-LiDAR metric Mesh fallback based on ARKit visual feature points, but it is intentionally classified only as `PARTIAL`: it produces coarse geometry rather than dense, textured multi-view reconstruction. Full parity still requires dense non-LiDAR MVS/depth estimation, metric calibration of textured photogrammetry output, and physical-device evidence.

## Human-only device gate

Run `S4_DEVICE_ACCEPTANCE.md`. S4 cannot promote any physical-quality row to `PARITY` without those results.

Current overall S4 state: **PARTIAL**. Software implementation has advanced to the physical-device quality gate; the remaining `PARTIAL/MISSING` rows must not be hidden by a green build.
