# D2 W05 Map / geotag Wave 1 evidence

Date: 2026-08-16 JST
Worker: D2-005
Branch: `scaniverse/d2-w05-map`
Base: `scaniverse/d2-share-discover` @ `c47329211f5ec9495f29d0c171dbfe95323f5bd9`
Scope: Map / geotag opt-in / location display-hide only.

## Canonical refresh

- Notion canonical page `Scaniverse同等化｜4開発班＋統合本部 v2.0` was re-read before work. D2 includes browser/share metadata and geotag opt-in, and Map/Discover real-data display remains a gate.
- GitHub base branch was re-read before work. No `scaniverse/d2-w05-map` branch existed, so it was created from the current D2 base commit above.
- Existing client already had explicit location opt-in: no automatic location request/send, public-only location attachment, and pending location is cleared when visibility leaves public.

## Defect found

`scanlab-public` parsed missing bbox query parameters with `Number(null)`, which evaluates to `0`. A normal feed request without bbox therefore became a `0,0,0,0` geographic filter and could hide real Map/Discover data outside coordinate zero.

The same public response decorator also emitted stored coordinates for an unlisted share if legacy or malformed data happened to contain latitude/longitude. The current client does not create that state, but the public API should enforce the visibility boundary independently.

## Implementation

- Added a pure `geo_contract.mjs` shared contract for bbox parsing and response-location filtering.
- No bbox keys: no geographic filter.
- Partial, empty, non-numeric, out-of-range, reversed, or over-broad bbox: invalid.
- Valid bbox: apply the geographic query.
- Location is emitted by the public response only when `visibility === "public"` and both coordinates are finite and in range.
- Existing explicit SwiftUI opt-in flow is unchanged.
- Trusted `scene.spz + manifest.json` publish guard is untouched.

## Regression gate

Command:

`node scripts/test_scanlab_geo_contract.mjs`

Result: `PASS: ScanLab Map/geotag contract`

Covered cases:

- bbox omitted
- bbox partially supplied
- bbox supplied as all-empty
- bbox containing an empty value
- bbox containing a non-number
- valid bbox
- invalid/out-of-range/over-broad bbox
- public coordinate display
- unlisted/private coordinate suppression
- missing/invalid public coordinates
- Edge Function integration uses the shared parser/filter and does not restore the legacy `Number(null)` path
- publish UI retains explicit geotag opt-in
- leaving public visibility clears pending location
- only public submit can attach location
- Map remains wired to public scans with locations

## Harsh review result

PASS for this Wave's code contract. The first draft treated four explicitly empty bbox values as omitted; review changed this to invalid before commit. The first draft used a TypeScript-only helper; review changed it to runtime-neutral `.mjs` so the same contract can be executed directly by Node and imported by the Deno Edge Function.

## Remaining external gate

This worker did not deploy the Supabase Edge Function and did not alter the integration/base branch. Production real-data Map verification therefore remains an integration/deployment gate after this branch is merged/deployed. No unrelated branch or worker file was changed.
