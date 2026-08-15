# S4 Scaniverse Mesh reference — 2026-06-30 bouquet

Recorded: 2026-08-15 JST from user-supplied Scaniverse screen recording + exported GLB.
Purpose: concrete parity reference only. This is **not** Scan Lab device evidence and does not satisfy `S4_DEVICE_ACCEPTANCE.md`.

## Source fingerprints

- Screen recording SHA-256: `dc80892a768eb53ee7ea880f9f8ef8d9c4db81250f9e11bf55009d41f506f3f5`
- GLB SHA-256: `2fb3d4e21363a1f461e8d11ca3dc1ec88f48b8135f7f3a94907631c4aa2add13`
- GLB `asset.generator`: `Scaniverse (https://scaniverse.com)`

## Observed user workflow

The recording shows a real saved bouquet scan opened in Scaniverse, then:

1. free orbit/zoom in the object viewer;
2. edit surface with trimming, filter, exposure/tonal and sharpness controls;
3. AR view with live camera background and `AR / object` switching;
4. two-tap measurement; one demonstrated span reads **36 cm**;
5. share surface with link sharing, message, Sketchfab, video creation and model export;
6. model export choices shown in the UI: **FBX, OBJ, GLB, USDZ, STL, PLY, LAS**.

Cross-session ownership remains unchanged: S4 owns Mesh generation/edit/measurement and the exporter-facing asset contract; S6 owns final multi-format writers/share/video; S7 owns public link/discovery/backend. S4 now supplies metric Mesh AR/object presentation because it depends directly on the metric Mesh contract.

## GLB structure

| Property | Reference value |
|---|---:|
| GLB size | 14,363,212 bytes |
| Meshes | 1 |
| Primitives | 1 triangle primitive |
| Vertices | 160,592 |
| Triangles | 275,481 |
| Indices | 826,443 (`UInt32`) |
| Position attribute | `VEC3 Float32` |
| UV attribute | `VEC2 Float32` |
| Explicit normal attribute | none |
| Materials | 1 |
| Textures | 1 |
| Texture | embedded JPEG, 8192 × 8192 RGB |
| Texture JPEG payload | 7,844,205 bytes |
| PBR metallic factor | 0.0 |
| Root transform | identity / no model-space scale transform |

### Metric bounds

Position bounds directly stored in the GLB:

- X: `-0.259854 ... +0.296914 m` → **0.556768 m**
- Y: `-0.089140 ... +0.671742 m` → **0.760882 m**
- Z: `-0.295960 ... +0.276329 m` → **0.572289 m**

This is consistent with meter-scale geometry and with the 36 cm in-app measurement visible in the recording. The model is effectively Y-up in this sample.

## Geometry quality characteristics

The reference is **not watertight**, and that is important for our quality priorities.

- 1,670 connected vertex components on this flower/bouquet scan;
- 42,725 boundary edges out of 434,580 unique edges (~9.83%);
- only 8 non-manifold edges with incidence > 2;
- no zero-area triangles at the `1e-12 m²` threshold;
- total triangle surface area ≈ 1.0253 m².

Interpretation: Scaniverse accepts many disconnected thin/occluded pieces where that preserves visible detail. S4 must not optimize for watertightness at the expense of petals, leaves, wrapping, thin stems or texture fidelity.

## Texture quality characteristics

The GLB uses a single large UV atlas. The atlas is heavily packed with many disconnected texture islands rather than a simple single-camera projection. That implies a real texture-unwrapping / view-selection / blending stage.

The 8K atlas is a decisive parity signal: an untextured LiDAR OBJ or a coarse vertex-color preview is not practically comparable for this object class.

## Consequences for S4

1. **Textured Mesh must become the normal final LiDAR result**, not an optional afterthought.
2. LiDAR geometry should keep ARKit meter scale while RGB frames are used for texture projection/baking.
3. Thin disconnected components must survive cleanup unless they are demonstrably noise.
4. Geometry simplification must be texture-aware and must not erase petals/leaves/wrapping merely to reduce component count.
5. Current non-LiDAR feature-point voxel Mesh remains far below this reference in geometry density.
6. Apple iOS Object Capture alone cannot be treated as the parity engine; S4 needs an independent dense/textured path where the system API cannot reproduce this output class.
7. S4 device comparison should record at minimum: vertex count, triangle count, bounding-box scale, texture dimensions/file size, visible holes, thin-structure retention, measurement error and processing time.

## Reference-driven implementation wave

This reference exposed software gaps that were invisible in compile-only review, so S4 was reopened instead of waiting for device testing.

- `MeshRGBTextureBaker.swift` projects the saved RGB capture frames back onto the original ARKit meter-scale LiDAR Mesh, chooses a source view per face, writes textured OBJ/MTL plus a 2K/4K/8K JPEG atlas, and records `projectionCoverage` in `mesh-texture-bake.json`.
- LiDAR result flow automatically attempts RGB texture baking when enough frames are available. Texture failure does not discard the underlying metric geometry.
- `MeshARViewer.swift` adds `AR / オブジェクト` switching for metric assets. ARSCNView raycasting places the Mesh without applying an arbitrary scale transform.
- Scale-uncalibrated photogrammetry output remains excluded from metric measurement and metric AR placement.
- `S4_DEVICE_ACCEPTANCE.md` now checks atlas resolution, projection orientation/seams/ghosting, projection coverage, known-length measurement, 1:1 AR placement, and direct comparison with this reference.

These additions close structural workflow gaps but do **not** prove practical-quality parity. First-generation RGB projection still needs device validation for coordinate convention, occlusion, seam/blend quality, color consistency and 8K memory/thermal behavior. Non-LiDAR dense reconstruction is still a separate major gap.

## Reference-only target band

Do **not** turn one bouquet into a universal hard threshold. For a similarly complex ~0.5–0.8 m object, however, a result that is an order of magnitude below this geometry density or lacks a multi-megapixel texture is an obvious practical-quality regression and must remain below `PARITY`.
