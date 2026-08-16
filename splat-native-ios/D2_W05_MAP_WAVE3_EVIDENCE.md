# D2 W05 Map / geotag Wave 3 evidence

Date: 2026-08-16 JST
Worker: D2-005
Branch: `scaniverse/d2-w05-map`
Wave start HEAD: `c7d863da383ae68ab27754ee6509a68b24d7da1d`
Base rechecked: `scaniverse/d2-share-discover` @ `c47329211f5ec9495f29d0c171dbfe95323f5bd9`
Scope: Map / geotag opt-in / location display-hide only.

## Canonical refresh

- Re-read Notion canonical `Scaniverse同等化｜4開発班＋統合本部 v2.0`.
- D exit still requires a real explicitly published 3D to appear in Map / Discover; hardcoded demo proof remains forbidden.
- Re-read integration PR #4145, D2 base, and this worker branch before work.
- Production DB still contains 0 `scanlab_scans` rows, so no fake Map pin or fake live E2E was created.

## Live drift found after Wave 2

Production `scanlab-public` had moved from v3 to **v4** at 2026-08-16 23:01:35 JST.

v4 correctly added W06 Discover cursor pagination (`feed_cursor.mjs`, stable `published_at + id` ordering, `nextCursor`) while preserving bbox filtering and auth-aware private cache headers.

However, v4's shared `decorate()` returned stored coordinates for any row with latitude/longitude. Because the same decorator serves `mode=share`, a published `unlisted` scan could expose its stored geotag to anyone holding the share token. This regressed W05's Wave 2 public-only location boundary.

## Production fix

Before deploy, the W06 branch was checked and its latest pagination commit was already represented by production v4. No later shared-function change was observed.

Production `scanlab-public` was deployed as **v5 / ACTIVE** at 2026-08-16 23:51:39 JST.

v5 preserves all v4 behavior and adds only the W05 privacy boundary:

- imports `locationForPublicResponse()` from `geo_contract.mjs`;
- `decorate()` emits location only when `scan.visibility === "public"` and coordinates are finite/in range;
- `unlisted` and `private` responses return `location: null` even if coordinates exist in storage;
- W06 cursor pagination remains intact;
- bbox filtering remains intact;
- `Vary: Authorization` and `Cache-Control: private, no-store` remain intact;
- `verify_jwt=false` remains unchanged because this public endpoint intentionally supports anonymous public/share reads and performs optional bearer-token handling internally.

The deployed v5 source was fetched back immediately after deploy and verified to contain `feed_cursor.mjs`, `bbox.mjs`, `geo_contract.mjs`, cursor parsing, `nextCursor`, and `locationForPublicResponse(scan)`.

## Harsh review corrections

1. Re-deploying the W05 v3-era source would have removed W06 pagination. Rejected.
2. Fixing only the `share` query by dropping latitude/longitude columns would duplicate privacy rules and risk divergence between response paths. Kept a single response-level visibility function instead.
3. Leaving the fix only on the worker branch was rejected because production v4 was actively exposing the wrong response contract. A minimal live v5 patch was applied after checking the latest shared-function state.
4. Creating a temporary published scan to demonstrate the fix was rejected because the canonical explicitly forbids fake/demo publication as parity proof and production currently has zero real scans.

## Regression gate added

`test_scanlab_geo_contract.mjs` now protects both W05 and the live W06 contract:

- public geotag is emitted;
- unlisted/private geotag is suppressed;
- malformed/out-of-range coordinates are suppressed;
- bbox omission/validation contract is retained;
- W06 cursor make/parse contract is retained;
- `scanlab-public/index.ts` must still parse `cursor` and return `nextCursor`;
- auth-aware private cache headers are retained;
- Publish UI remains explicit location opt-in;
- Map remains wired to the separate `mapScans` surface.

The existing integrated `scripts/validate.sh` already executes this Map/geotag test, so no duplicate CI workflow was added.

## Remaining physical gate

- Production `scanlab_scans` count is still 0.
- Therefore the canonical physical gate — a real user-owned 3D explicitly published and then actually visible/openable from Map — remains blocked on the first real publish, not on a Map code placeholder.
- GitHub macOS CI for this Wave is expected to run from the final single commit; its immutable run result is the final compile/regression evidence for the branch commit.
