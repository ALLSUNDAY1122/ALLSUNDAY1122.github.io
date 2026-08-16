# D2 W05 Map / geotag Wave 4 evidence

Date: 2026-08-17 JST
Worker: D2-005
Branch: `scaniverse/d2-w05-map`
Wave start HEAD: `3870ec379cf7a93946a320c21ffed532a7f12be0`
Base rechecked: `scaniverse/d2-share-discover` @ `c47329211f5ec9495f29d0c171dbfe95323f5bd9`
Scope: Map / geotag opt-in / location display-hide only.

## Canonical refresh

- Re-read Notion canonical `Scaniverse同等化｜4開発班＋統合本部 v2.0`.
- D still owns geotag opt-in and Map; hardcoded/demo Map proof remains forbidden.
- Re-read integration PR #4145, D2 base, this worker branch, and production Supabase.
- Production `scanlab_scans` still has 0 rows, so the physical real-publish → Map gate cannot honestly be closed in this Wave.

## Largest unfinished gap

The app said geotag was opt-in but actually forced every `public` publication to attach current coordinates:

- `PublishScanView.canSubmit` required `locationPicker.location != nil`.
- `ScanLabBackend+TrustedPublish` rejected `public` when `location == nil`.
- production `scanlab-publish` v3 rejected public rows with null coordinates.
- production DB CHECK `scanlab_public_requires_location_and_attestation` rejected published public rows with null coordinates.
- production `scanlab_private.publish_guard()` also required coordinates for public rows.
- success copy claimed every public post was on both Map and Discover.

That means the user could not choose the privacy-preserving state “public in Discover, not on Map”, contradicting the canonical `geotag opt-in` responsibility.

## Contract implemented

Public visibility and Map geotag are now separate choices:

- public + no geotag → Discover/public browser URL only, no Map pin;
- public + geotag → Map + Discover;
- unlisted/private → no public location response as protected in Waves 1–3.

Public privacy and rights confirmations remain mandatory whether or not location is attached.
`public_place_confirmed` becomes mandatory only when the user actually opts into a geotag.
Partial or invalid coordinates remain rejected.

UI changes:

- public selector is presented as `公開（Discover）`;
- Map location section is explicitly marked optional;
- copy explicitly says public Discover publishing works without location;
- action button changes between `Discoverへ公開` and `Map・Discoverへ公開`;
- success copy correctly states whether Map listing was selected;
- changing/removing a selected location resets the place confirmation.

## Server / database hardening

A pure `geo_publish_contract.mjs` validates the Edge Function contract:

- no-location public is valid when privacy + rights are confirmed;
- one-coordinate-only input is invalid;
- attached coordinates must be finite/in range;
- attached location requires `public_place_confirmed`.

Migration `20260816160000_scanlab_d2_optional_public_geotag_v12.sql` replaces the old mandatory-location CHECK with an optional-geotag safety CHECK and updates `scanlab_private.publish_guard()`.

The v12 trigger was derived from the live production v11 definition rather than old repository v7, preserving:

- `security definer`;
- `scanlab_private.consume_rate_limit(...)`;
- `publish_shared`, 10 / 1 hour rate limiting;
- current `published_at` behavior.

## Concurrent-worker protection

During Wave 4 refresh, another worker had just updated `scanlab-visibility` to v2 and W03 branch HEAD. W05 did not touch that function or W03 branch.
Before any W05 ref/production mutation, the relevant shared state was rechecked.
Only `scanlab-publish` plus the public-geotag DB constraint/guard are in W05's live mutation scope.

## Regression gate

`test_scanlab_geo_contract.mjs` now asserts all prior W05/W06 behavior plus:

- public Discover without geotag is allowed;
- geotagged public requires place confirmation;
- public always requires privacy + rights confirmations;
- partial location is rejected;
- client no longer forces a geotag;
- publish action/copy distinguishes Discover-only vs Map+Discover;
- Edge Function uses the optional-geotag helper;
- database migration explicitly permits `(latitude is null and longitude is null)`;
- v12 migration preserves W08 shared publish rate limiting.

Existing bbox validation, public-only response filtering, unlisted/private location suppression, viewport Map separation, stale-response rejection, W06 cursor pagination, and auth-aware cache behavior remain covered.

## Harsh review

1. UI-only relaxation was rejected because server and DB would still reject the request.
2. Dropping all public safety confirmations was rejected; only location-specific confirmation became conditional.
3. Allowing one coordinate or stale location metadata was rejected.
4. Replacing the trigger from repository v7 was rejected because production has newer v11 rate-limit logic.
5. Fake production scan insertion was rejected; the physical gate remains blocked on a real user-owned publish.
6. Updating W03/W06/W08 branches was rejected; only W05 branch is written.

## Remaining physical gate

Production has no real scan rows. The final parity proof still requires a real user-owned trusted 3D:
1. publish public without geotag → visible in Discover and absent from Map;
2. publish/republish with explicit geotag → visible in Map;
3. open the real asset from Map in another environment.

No fake/demo 3D or pin is accepted as evidence.
