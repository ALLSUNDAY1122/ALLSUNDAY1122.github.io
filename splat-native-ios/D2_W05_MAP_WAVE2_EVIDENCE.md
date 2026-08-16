# D2 W05 Map / geotag Wave 2 evidence

Date: 2026-08-16 JST
Worker: D2-005
Branch: `scaniverse/d2-w05-map`
Wave start HEAD: `605eb1ceac70594525ac30acbd47f25bda6f2125`
Base rechecked: `scaniverse/d2-share-discover` @ `c47329211f5ec9495f29d0c171dbfe95323f5bd9`
Scope: Map / geotag opt-in / location display-hide only.

## Canonical refresh

- Re-read Notion canonical `Scaniverse同等化｜4開発班＋統合本部 v2.0`.
- D exit still requires a real published 3D to appear from Map / Discover, with hardcoded demo content forbidden.
- Re-read both GitHub base and worker branch before work; neither had moved since Wave 1.

## Live-state drift detected before implementation

The production Supabase `scanlab-public` Edge Function was re-read before any deploy.

- Production function is ACTIVE version 3.
- It was updated at 2026-08-16 21:48:33 JST while Wave 1 was in progress.
- Production v3 already contains a newer `bbox.mjs` parser, `Vary: Authorization`, and `Cache-Control: private, no-store`.
- Therefore Wave 1's older complete function source was **not** deployed; doing so would have regressed newer production behavior.
- Wave 2 rebases the worker-branch function source onto those live v3 contracts and keeps W05's location display boundary: coordinates are emitted only for `visibility === "public"`.

No production function deploy was performed in this Wave because the same shared function was being changed outside this worker branch. This avoids overwriting a concurrent worker's live update.

## Production real-data gate

The production database was queried without creating any rows.

Result: `public.scanlab_scans` currently contains **0 rows**.

Because the project explicitly forbids hardcoded/demo publication as proof, this worker did not fabricate a Map pin. Physical "real 3D appears on Map" evidence remains blocked until a real publish exists.

## Maximum unfinished Map delta implemented

Before this Wave, Map and Discover both consumed `backend.publicScans`, which is the global latest feed capped at 40 items. Moving the map did not query the displayed geographic area, even though the backend already supports bbox filtering.

Wave 2 changes:

- Added `ScanLabMapQueryPolicy` and `ScanLabMapBounds`.
- Added a separate `backend.mapScans` surface so Map viewport queries cannot replace Discover's global feed.
- Map uses SwiftUI Map camera end events to query only after the user finishes pan/zoom.
- Representable viewports call the existing bbox API.
- Viewports too broad or crossing a backend single-box boundary fall back to the global latest feed instead of leaving stale local pins.
- Added `mapRequestGeneration`; a late response from an older viewport cannot overwrite a newer viewport result.
- No CLLocationManager or automatic location permission/request was added. Publishing geotag remains explicit opt-in in `PublishScanView`.

## Harsh review corrections

1. First design reused `publicScans` for Map region queries. Rejected because it would silently replace Discover's global feed.
2. First design returned early for an unrepresentable camera region. Rejected because it could leave stale local pins displayed after zooming back out. Changed to global-feed fallback.
3. First design did not guard overlapping viewport requests. Added request generation so only the newest request may commit results.
4. Live production was newer than the branch function source. Rebased branch contracts to production v3 cache/bbox behavior before retaining W05 location suppression; no stale full-function deploy.

## Regression gate

Locally executed before commit:

- `swiftc SplatNative/ScanLabMapQuery.swift scripts/test_scanlab_map_query.swift`
  - PASS: Tokyo bbox math
  - PASS: world-sized region fails closed
  - PASS: antimeridian crossing fails closed to global fallback
  - PASS: zero-area and non-finite camera state fail closed
- `node scripts/test_scanlab_geo_contract.mjs`
  - PASS: omitted/partial/empty/invalid/valid bbox contract
  - PASS: public location display
  - PASS: unlisted/private location suppression
  - PASS: production v3 auth-aware/private cache headers preserved
  - PASS: explicit geotag opt-in source contract retained
- static source gate:
  - PASS: Map uses `mapScans`, not Discover `publicScans`
  - PASS: `.onMapCameraChange(frequency: .onEnd)` drives bbox requests
  - PASS: stale map-response generation guard exists
- `bash -n scripts/validate.sh`
  - PASS

The integrated `scripts/validate.sh` now executes both Map/geotag contract tests in CI.

## Remaining gate

- GitHub macOS CI must compile the SwiftUI/MapKit integration after this commit.
- A real user-owned 3D must be published in production before the final physical Map real-content gate can be closed.
- Production `scanlab-public` still needs W05's public-only response-location filter reconciled/deployed after shared-function ownership is clear; this Wave deliberately did not overwrite the concurrently updated live v3 function.
