# S4 Mesh / Photogrammetry / LiDAR parity ledger

Updated: 2026-08-15 JST
Owner: S4 (`scaniverse/s4-mesh-photogrammetry`)
Baseline: `SCANIVERSE_PARITY_PLAN.md` + Scaniverse current Mesh workflow

## Rule

A UI control without a real 3D implementation is `MISSING`. Compile-only code cannot be promoted to `PARITY`. Device evidence is required for capture quality, scale, measurement, crop, texture quality, and independent-reader export validation.

## Capability matrix

| Capability | State | Current S4 evidence | Remaining gate |
|---|---|---|---|
| Mesh entry from root | PARTIAL | `RootScanView` routes to real Mesh flow | Device UI check |
| Small / Medium / Large range | PARTIAL | `MeshScanSize` filters LiDAR triangles by world-space capture radius | Calibrate against representative subjects |
| LiDAR mesh capture | NEAR_PARITY | ARKit `sceneReconstruction`, real `ARMeshAnchor` vertices/normals/faces | LiDAR device scan + visual/geometry audit |
| Metric scale | NEAR_PARITY | ARKit world-space meters retained in OBJ | Known-length device test |
| Measurement | NEAR_PARITY | Two SceneKit mesh hit-tests + Euclidean world-space distance | Known-length accuracy test |
| Geometry cleanup | PARTIAL | Degenerate-triangle removal + vertex compaction | Hole/noise quality audit; simplification still required |
| Crop/edit | PARTIAL | Crop removes triangles from real geometry and regenerates OBJ | Round/cylindrical crop + interactive bounds parity |
| RGB raw capture | NEAR_PARITY | JPEG frames + camera transform + intrinsics stored in `.meshproject` | Long-scan/storage stress test |
| LiDAR raw depth retention | MISSING | ARKit mesh is retained but per-frame LiDAR depth is not yet persisted | Save sceneDepth/smoothedSceneDepth where available |
| Raw reprocess | PARTIAL | `.meshproject` manifest and RGB source survive processing | Reprocess UI + selectable reconstruction settings |
| Textured model | PARTIAL | RealityKit `PhotogrammetrySession` path produces textured USDZ on supported devices | Device quality audit; LiDAR-guided texture baking needed |
| Non-LiDAR photogrammetry | PARTIAL | Uses Apple Object Capture when `PhotogrammetrySession.isSupported` | Must cover Scaniverse-class A12+ non-LiDAR devices not supported by Object Capture |
| OBJ interface | NEAR_PARITY | Real world-space OBJ with normals | Independent MeshLab/Blender reader test |
| USDZ interface | PARTIAL | Object Capture output | Independent reader + scale validation |
| FBX / GLB / STL / LAS / PLY interfaces | MISSING | Reserved for S4/S6 contract | Implement canonical mesh asset interface then S6 exporters |
| Pause/resume | MISSING | Not yet exposed in Mesh capture | Implement lifecycle-safe pause/resume |
| Background auto-pause | MISSING | Not yet implemented | Add scenePhase handling |
| Mesh simplification | MISSING | Current clean step removes degenerates only | Add quality-preserving simplifier + dense option |

## Current hard blocker to full parity

Scaniverse has historically supported non-LiDAR iOS devices down to A12-class hardware. Apple RealityKit Object Capture on iOS is explicitly gated by `PhotogrammetrySession.isSupported` and cannot be assumed to cover every such device. Therefore S4 must not label the non-LiDAR path `PARITY` until an independent RGB reconstruction route or equivalent supported-device coverage is proven on target devices.

## Device evidence required before S4 can be marked PARITY

1. LiDAR iPhone/iPad: object, room corner, thin object, glossy/low-texture object.
2. Non-LiDAR iPhone: same representative object set where technically applicable.
3. Known-length target: compare physical length vs in-app measurement and exported-model scale.
4. Crop: verify removed geometry is actually absent from exported model.
5. Texture: inspect seams, blur, missing regions, orientation and color consistency.
6. Independent readers: open OBJ/USDZ in at least two external readers without repair.
7. Raw reprocess: reconstruct the same capture twice without recapturing.
8. Long scan / memory / storage / interruption tests.

Current overall S4 state: **PARTIAL**.
