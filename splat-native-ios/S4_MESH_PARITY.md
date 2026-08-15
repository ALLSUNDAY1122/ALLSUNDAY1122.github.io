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
| Measurement | NEAR_PARITY | Two SceneKit mesh hit-tests + Euclidean world-space distance | Known-length accuracy test |
| Geometry cleanup | PARTIAL | Degenerate-triangle removal, vertex compaction, real OBJ vertex-cluster simplifier | Hole/noise/simplification quality audit |
| Crop/edit | PARTIAL | Crop removes triangles from real geometry and regenerates OBJ | Round/cylindrical crop + interactive bounds parity |
| RGB raw capture | NEAR_PARITY | JPEG frames + camera transform + intrinsics stored in `.meshproject`; Visual Mesh fallback also stores these | Long-scan/storage stress test |
| LiDAR raw depth retention | PARTIAL | `smoothedSceneDepth`/`sceneDepth` persisted as Float32-meter sidecars with pose/intrinsics index | LiDAR device validation + recovery/reprocess consumption |
| Raw reprocess | PARTIAL | Raw browser can rerun RealityKit reconstruction from stored `.meshproject/images` without recapture | Selectable settings + device repeatability test |
| Textured model | PARTIAL | RealityKit `PhotogrammetrySession` produces textured USDZ on supported devices | Device quality audit; LiDAR-guided texture baking needed |
| Non-LiDAR mesh | PARTIAL | Real ARKit `rawFeaturePoints` are multi-frame accumulated, stability-filtered, voxelized and surfaced to metric OBJ; RGB/pose/intrinsics raw retained | Dense multi-view stereo + texture quality comparable to Scaniverse |
| OBJ interface | NEAR_PARITY | Real world-space OBJ from LiDAR or Visual Mesh; simplifier can regenerate lighter OBJ | Independent MeshLab/Blender reader test |
| USDZ interface | PARTIAL | Object Capture/reprocess output | Independent reader + scale validation |
| FBX / GLB / STL / LAS / PLY interfaces | MISSING | Reserved for S4/S6 contract | Implement canonical mesh asset interface then S6 exporters |
| Pause/resume | NEAR_PARITY | ARSession pause and resume without reset; tracking state is preserved by run without reset options | Device pause/resume continuity test |
| Background auto-pause | NEAR_PARITY | `scenePhase` pauses inactive/background capture and resumes active capture | Device lifecycle/interruption test |
| Mesh simplification | PARTIAL | Real vertex-cluster simplifier writes a new OBJ while retaining source | Quality-preserving target-density calibration |

## Current hard blocker to full parity

Apple RealityKit Object Capture on iOS is hardware-gated, so it cannot supply Scaniverse-class dense photogrammetry across non-LiDAR devices. S4 now has a genuine non-LiDAR metric Mesh fallback based on ARKit visual feature points, but it is intentionally classified only as `PARTIAL`: it produces coarse geometry rather than dense, textured multi-view reconstruction. Full parity still requires a dense non-LiDAR MVS/depth-estimation path and device evidence.

## Device evidence required before S4 can be marked PARITY

1. LiDAR iPhone/iPad: object, room corner, thin object, glossy/low-texture object.
2. Non-LiDAR iPhone: same representative object set; record Visual Mesh density and failure cases.
3. Known-length target: compare physical length vs in-app measurement and exported-model scale.
4. Crop: verify removed geometry is actually absent from exported model.
5. Texture: inspect seams, blur, missing regions, orientation and color consistency.
6. Independent readers: open OBJ/USDZ in at least two external readers without repair.
7. Raw reprocess: reconstruct the same capture twice without recapturing.
8. LiDAR depth sidecar: validate dimensions, units, pose/intrinsics linkage and recovery.
9. Pause/background/foreground: verify tracking continuity and no corrupted project state.
10. Long scan / memory / storage / interruption tests.

Current overall S4 state: **PARTIAL**.
