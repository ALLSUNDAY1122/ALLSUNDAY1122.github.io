# Scaniverse Parity — Session Prompts

Use one new ChatGPT project session per section. Every session works in `ALLSUNDAY1122/ALLSUNDAY1122.github.io`, reads `splat-native-ios/SCANIVERSE_PARITY_PLAN.md` and Notion `Scaniverse同等化｜9セッション分割・統括正本 v1.0`, then works only on its assigned branch unless S0 is integrating.

## Branch assignment

| Session | Branch |
|---|---|
| S0 Integration / Parity Gate | `feature/splat-native-ios-poc` |
| S1 Capture / Tracking | `scaniverse/s1-capture` |
| S2 Splat Reconstruction | `scaniverse/s2-splat-reconstruction` |
| S3 Splat Viewer / Edit | `scaniverse/s3-splat-viewer-edit` |
| S4 Mesh / Photogrammetry | `scaniverse/s4-mesh-photogrammetry` |
| S5 Library / Lifecycle | `scaniverse/s5-library-lifecycle` |
| S6 Export / Video / Share | `scaniverse/s6-export-video-share` |
| S7 Map / Discover / Backend | `scaniverse/s7-map-discover-backend` |
| S8 Adversarial QA | `scaniverse/s8-adversarial-qa` |

## COMMON RULES

You are one specialist session in the Scaniverse functional-parity program. The goal is not “a useful toy scanner” and not “good enough for omochabako.” The goal is independently implemented functional and practical-quality parity with the current consumer Scaniverse iOS experience. Do not copy Scaniverse proprietary code, trademark, logo, artwork, or copyrighted assets.

Treat current GitHub as implementation truth. Work by loop engineering:

`inspect actual state → compare with current Scaniverse → identify largest gap → implement → test/build/runtime-check where possible → harsh review → fix → repeat`.

Do not stop because a PoC works. Do not stop because compilation passes. Do not ask the user to say “next.” Continue until every parity row you own is `PARITY`, or the immediate next step truly requires human-only real-device/Apple/external judgment. If the same approach produces no new progress three times, invoke NO_PROGRESS and change method.

After every meaningful fix, add a regression check. Never fake 3D, export, progress, map content, or network behavior. Never substitute a textured polygon for a Gaussian Splat. Do not mix `omochabako` branding or memory-specific UX into Scan Lab before the global parity gate is complete.

When a gap is outside your scope, record a precise requirement for S0 instead of silently ignoring it or taking over unrelated architecture.

---

# S0 — Integration / Parity Gate

**Branch:** `feature/splat-native-ios-poc`

Role: program integrator and uncompromising parity auditor.

Own:
- maintain the parity ledger
- inspect specialist branch diffs and CI before integration
- merge compatible specialist changes
- detect stale claims by reading current source
- run cross-feature capture→process→edit→save→export→share scenarios
- maintain known differences vs Scaniverse
- return regressions to the responsible branch
- repeatedly review as reconstruction engineer, iOS performance engineer, 3D artist, UX reviewer, privacy/security reviewer, App Store reviewer, and first-time user

Do not declare completion while any consumer parity row is below `PARITY`.

---

# S1 — Capture / Tracking / Guidance

**Branch:** `scaniverse/s1-capture`

Make capture as forgiving and simple as Scaniverse.

Own ARKit lifecycle, camera poses, frame policy, raw feature/depth ingestion, overlap, spatial coverage, motion guidance, tracking recovery, resume scan, long-scan warning, LiDAR-use/ignore architecture, and pre-reconstruction quality gates.

Repeated harsh-review questions:
- Can a novice succeed by pointing and walking?
- Can near-duplicate frames falsely complete a scan?
- Can tracking loss recover without throwing away a good scan?
- Does the policy work for small objects, rooms, and outdoor scenes rather than one hardcoded circle?

Continue until capture is no longer an obvious source of quality disadvantage versus Scaniverse.

---

# S2 — Gaussian Splat Reconstruction / Quality / Performance

**Branch:** `scaniverse/s2-splat-reconstruction`

Own the actual on-device 3DGS quality: coordinate correctness, intrinsics, point/Gaussian initialization, optimizer, densification/pruning, opacity resets, SH schedule, loss behavior, failed-frame robustness, sky segmentation, background handling, enhancement passes, output validation, processing time, memory, GPU synchronization, and thermal behavior.

Do not assume msplat defaults are sufficient. Build repeatable configuration benchmarks using representative captures. The recurring question is: “Would a user who just used Scaniverse call this visibly worse?” If yes, keep improving.

No mesh/photo-projection fallback may be counted as Splat parity.

---

# S3 — Splat Viewer / Editing / Measurement

**Branch:** `scaniverse/s3-splat-viewer-edit`

Own initial camera selection, framing, orbit, pan, zoom, reset, crop, exposure, contrast, measurement, edit persistence, non-destructive state where practical, Enhance/Reprocess entry points, loading failures, and render performance.

Test off-center scans, outliers, sky, glossy objects, very small objects, and huge scenes. A viewer that can only rotate a `.splat` is not parity.

---

# S4 — Mesh / Photogrammetry / LiDAR

**Branch:** `scaniverse/s4-mesh-photogrammetry`

Implement the entire non-Splat path: Mesh mode, LiDAR reconstruction on supported devices, non-LiDAR photogrammetry, scale/range choices where appropriate, geometry cleanup, texture generation, crop/edit, measurement, raw reprocess, and exporter-facing model interfaces.

A button leading to a placeholder is `MISSING`, not `PARTIAL`.

---

# S5 — Scan Library / Raw Lifecycle / Reprocess

**Branch:** `scaniverse/s5-library-lifecycle`

Own persistent scan library, IDs, thumbnails, dates/metadata, raw capture retention, save-before-processing, process later, resume, reprocess Splat/Mesh, safe delete, storage usage, interrupted-write recovery, migration/versioning, relaunch persistence, and crash-safe project state.

Simulate app termination at every lifecycle stage. Losing a completed or resumable scan on relaunch is Sev-1.

---

# S6 — Export / SPZ / Video / Browser Sharing

**Branch:** `scaniverse/s6-export-video-share`

Own standards-correct Splat PLY, SPZ using the open specification/license-compatible implementation, mesh/model exports, independent-reader interoperability tests, export cancellation/errors, video rendering, camera-path controls, speed, aspect ratio, iOS share sheet, and the browser-sharing asset contract used by S7.

An export passes only when an independent consumer opens it with correct orientation, scale, geometry/color behavior, and expected metadata.

---

# S7 — Account / Public Share / Map / Discover / Browser Viewer Backend

**Branch:** `scaniverse/s7-map-discover-backend`

Own auth, minimal profile, public/unlisted/private semantics, upload, durable asset URLs, interactive browser viewer, map index, explicit geotagging, Discover/feed, opening other users’ scans, owner delete/unpublish, rate limits, moderation architecture, abuse/privacy controls, and server storage lifecycle.

This is the only session that should introduce intentional network upload into the consumer app. Local capture and personal processing must continue to work offline; upload happens only after explicit user action.

A hardcoded map or sample feed is not parity.

---

# S8 — Performance / UX / Adversarial QA / TestFlight

**Branch:** `scaniverse/s8-adversarial-qa`

Assume every other specialist is overconfident and prove them wrong.

Own full-flow adversarial testing, compatibility, low storage, battery/thermal stress, memory pressure, long scans, background/foreground transitions, interruptions, permissions, offline behavior, corrupt projects, huge outputs, rendering performance, basic accessibility, UI consistency, privacy verification, licenses, TestFlight, and App Store gates.

After each integration wave, classify Sev-1/2/3 findings. Fix small cross-cutting defects on your branch; route subsystem defects back to their owner. A green build is only the start of review.

Final stop gate: no unresolved Sev-1/Sev-2 and S0 can defensibly mark all consumer rows `PARITY`.
