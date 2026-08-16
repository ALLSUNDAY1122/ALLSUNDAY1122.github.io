import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { parseScanLabBoundingBox } from "../supabase/functions/scanlab-public/bbox.mjs";
import { makeScanLabFeedCursor, parseScanLabFeedCursor } from "../supabase/functions/scanlab-public/feed_cursor.mjs";
import { locationForPublicResponse } from "../supabase/functions/scanlab-public/geo_contract.mjs";
import { validateScanLabPublicGeoSafety } from "../supabase/functions/scanlab-publish/geo_publish_contract.mjs";

assert.deepEqual(
  parseScanLabBoundingBox(new URLSearchParams("mode=feed&limit=40")),
  { value: null },
  "omitting bbox must not become a zero-degree bbox",
);
assert.equal(parseScanLabBoundingBox(new URLSearchParams("minLat=35")).error, "invalid_bbox", "partial bbox must be rejected");
assert.equal(
  parseScanLabBoundingBox(new URLSearchParams("minLat=&maxLat=&minLon=&maxLon=")).error,
  "invalid_bbox",
  "explicitly empty bbox must not be treated as omitted",
);
assert.equal(
  parseScanLabBoundingBox(new URLSearchParams("minLat=&maxLat=36&minLon=139&maxLon=140")).error,
  "invalid_bbox",
  "empty bbox values must not coerce to zero",
);
assert.equal(
  parseScanLabBoundingBox(new URLSearchParams("minLat=x&maxLat=36&minLon=139&maxLon=140")).error,
  "invalid_bbox",
  "non-numeric bbox must be rejected",
);
assert.deepEqual(
  parseScanLabBoundingBox(new URLSearchParams("minLat=35&maxLat=36&minLon=139&maxLon=140")),
  { value: { minLat: 35, maxLat: 36, minLon: 139, maxLon: 140 } },
);
assert.equal(
  parseScanLabBoundingBox(new URLSearchParams("minLat=-91&maxLat=36&minLon=139&maxLon=140")).error,
  "invalid_bbox",
  "out-of-range bbox must be rejected",
);
assert.equal(
  parseScanLabBoundingBox(new URLSearchParams("minLat=0&maxLat=91&minLon=139&maxLon=140")).error,
  "invalid_bbox",
  "overly broad bbox must be rejected",
);

const publicLocation = {
  visibility: "public",
  latitude: 35.6812,
  longitude: 139.7671,
  location_label: "Tokyo",
};
assert.deepEqual(locationForPublicResponse(publicLocation), {
  latitude: 35.6812,
  longitude: 139.7671,
  label: "Tokyo",
});
assert.equal(
  locationForPublicResponse({ ...publicLocation, visibility: "unlisted" }),
  null,
  "unlisted share responses must never expose stored coordinates",
);
assert.equal(
  locationForPublicResponse({ ...publicLocation, visibility: "private" }),
  null,
  "private data must never expose stored coordinates",
);
assert.equal(
  locationForPublicResponse({ visibility: "public", latitude: undefined, longitude: 139.7671 }),
  null,
  "public location must require both coordinates",
);
assert.equal(
  locationForPublicResponse({ visibility: "public", latitude: 91, longitude: 139.7671 }),
  null,
  "invalid coordinates must not be emitted",
);

const publicBase = {
  visibility: "public",
  latitude: null,
  longitude: null,
  public_place_confirmed: false,
  privacy_confirmed: true,
  rights_confirmed: true,
};
assert.deepEqual(
  validateScanLabPublicGeoSafety(publicBase),
  { ok: true },
  "public Discover publishing must work without opting into a geotag",
);
assert.deepEqual(
  validateScanLabPublicGeoSafety({ ...publicBase, latitude: 35.6812, longitude: 139.7671, public_place_confirmed: true }),
  { ok: true },
  "a confirmed geotagged public scan may appear in Map",
);
assert.equal(
  validateScanLabPublicGeoSafety({ ...publicBase, latitude: 35.6812, longitude: null }).error,
  "invalid_public_location",
  "partial coordinates must never publish",
);
assert.equal(
  validateScanLabPublicGeoSafety({ ...publicBase, latitude: 35.6812, longitude: 139.7671 }).error,
  "public_location_confirmation_required",
  "Map geotag requires the public-place attestation",
);
assert.equal(
  validateScanLabPublicGeoSafety({ ...publicBase, privacy_confirmed: false }).error,
  "public_safety_confirmation_required",
  "public Discover publishing still requires privacy confirmation",
);
assert.equal(
  validateScanLabPublicGeoSafety({ ...publicBase, rights_confirmed: false }).error,
  "public_safety_confirmation_required",
  "public Discover publishing still requires rights confirmation",
);

const cursor = makeScanLabFeedCursor({
  published_at: "2026-08-16T13:56:04.000Z",
  id: "11111111-1111-4111-8111-111111111111",
});
assert.equal(cursor, "2026-08-16T13:56:04.000Z~11111111-1111-4111-8111-111111111111");
assert.deepEqual(parseScanLabFeedCursor(cursor), {
  value: {
    publishedAt: "2026-08-16T13:56:04.000Z",
    id: "11111111-1111-4111-8111-111111111111",
  },
});
assert.equal(parseScanLabFeedCursor("broken").error, "invalid_cursor", "pagination cursor validation must be preserved");

const functionSource = readFileSync(
  fileURLToPath(new URL("../supabase/functions/scanlab-public/index.ts", import.meta.url)),
  "utf8",
);
assert.match(functionSource, /parseScanLabBoundingBox\(url\.searchParams\)/, "feed must use the deployed bbox parser contract");
assert.match(functionSource, /location:\s*locationForPublicResponse\(scan\)/, "public API must filter location by visibility");
assert.match(functionSource, /parseScanLabFeedCursor\(url\.searchParams\.get\("cursor"\)\)/, "W06 cursor pagination must not be rolled back by the geotag privacy fix");
assert.match(functionSource, /nextCursor/, "paged Discover response contract must be preserved");
assert.match(functionSource, /"Vary": "Authorization"/, "authenticated blocked-user feed must keep auth-aware cache variance");
assert.match(functionSource, /"Cache-Control": "private, no-store"/, "personalized public feed must not regress to shared caching");
assert.doesNotMatch(
  functionSource,
  /Number\(url\.searchParams\.get\("minLat"\)\)/,
  "legacy missing-bbox-to-zero coercion must not return",
);

const publishFunctionSource = readFileSync(
  fileURLToPath(new URL("../supabase/functions/scanlab-publish/index.ts", import.meta.url)),
  "utf8",
);
assert.match(
  publishFunctionSource,
  /validateScanLabPublicGeoSafety\(scan\)/,
  "publish Edge Function must use the optional-geotag server contract",
);
assert.doesNotMatch(
  publishFunctionSource,
  /scan\.latitude == null \|\| scan\.longitude == null/,
  "server publication must not regress to mandatory public coordinates",
);

const migrationSource = readFileSync(
  fileURLToPath(new URL("../supabase/migrations/20260816160000_scanlab_d2_optional_public_geotag_v12.sql", import.meta.url)),
  "utf8",
);
assert.match(
  migrationSource,
  /\(latitude is null and longitude is null\)/,
  "database contract must explicitly allow public Discover rows without a geotag",
);
assert.match(
  migrationSource,
  /latitude is not null[\s\S]*longitude is not null[\s\S]*public_place_confirmed/,
  "database contract must require complete coordinates plus place confirmation when geotagged",
);
assert.match(
  migrationSource,
  /consume_rate_limit\([\s\S]*'publish_shared'[\s\S]*10[\s\S]*interval '1 hour'/,
  "W08 shared publish rate limiting must be preserved by the v12 trigger",
);

const publishSource = readFileSync(
  fileURLToPath(new URL("../SplatNative/PublishScanView.swift", import.meta.url)),
  "utf8",
);
assert.match(publishSource, /位置情報は自動取得・自動送信しません/, "geotag must remain explicit opt-in");
assert.match(publishSource, /位置情報を付けなくてもDiscoverへ公開できます/, "public publishing must visibly allow no geotag");
assert.match(publishSource, /現在地を公開地点に設定/, "explicit location action must remain visible");
assert.match(publishSource, /if newValue != \.public \{ locationPicker\.clear\(\)/, "leaving public must clear pending location");
assert.match(
  publishSource,
  /visibility == \.public && locationPicker\.location != nil/,
  "only public submissions may attach location",
);
assert.match(
  publishSource,
  /locationPicker\.location == nil \? "Discoverへ公開" : "Map・Discoverへ公開"/,
  "publish action must distinguish Discover-only from Map+Discover",
);
assert.doesNotMatch(
  publishSource,
  /return locationPicker\.location != nil && publicPlaceConfirmed && privacyConfirmed && rightsConfirmed/,
  "client must not force geotag opt-in for public Discover publishing",
);

const trustedPublishSource = readFileSync(
  fileURLToPath(new URL("../SplatNative/ScanLabBackend+TrustedPublish.swift", import.meta.url)),
  "utf8",
);
assert.doesNotMatch(
  trustedPublishSource,
  /guard location != nil else/,
  "trusted publish client must not require a geotag for public Discover",
);
assert.match(
  trustedPublishSource,
  /if location != nil && !publicPlaceConfirmed/,
  "trusted publish must still require place confirmation when a geotag is selected",
);

const shellSource = readFileSync(
  fileURLToPath(new URL("../SplatNative/ScanLabShellView.swift", import.meta.url)),
  "utf8",
);
assert.match(shellSource, /struct ScanLabMapView: View/, "Map UI must remain wired");
assert.match(shellSource, /backend\.mapScans\.filter \{ \$0\.location != nil \}/, "Map must show only located public items from the map feed");

console.log("PASS: ScanLab Map/geotag contract");
