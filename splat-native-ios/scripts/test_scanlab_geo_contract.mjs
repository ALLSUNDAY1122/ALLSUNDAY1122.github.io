import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { parseScanLabBoundingBox } from "../supabase/functions/scanlab-public/bbox.mjs";
import { locationForPublicResponse } from "../supabase/functions/scanlab-public/geo_contract.mjs";

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

const functionSource = readFileSync(
  fileURLToPath(new URL("../supabase/functions/scanlab-public/index.ts", import.meta.url)),
  "utf8",
);
assert.match(functionSource, /parseScanLabBoundingBox\(url\.searchParams\)/, "feed must use the deployed bbox parser contract");
assert.match(functionSource, /location:\s*locationForPublicResponse\(scan\)/, "public API must filter location by visibility");
assert.match(functionSource, /"Vary": "Authorization"/, "authenticated blocked-user feed must keep auth-aware cache variance");
assert.match(functionSource, /"Cache-Control": "private, no-store"/, "personalized public feed must not regress to shared caching");
assert.doesNotMatch(
  functionSource,
  /Number\(url\.searchParams\.get\("minLat"\)\)/,
  "legacy missing-bbox-to-zero coercion must not return",
);

const publishSource = readFileSync(
  fileURLToPath(new URL("../SplatNative/PublishScanView.swift", import.meta.url)),
  "utf8",
);
assert.match(publishSource, /位置情報は自動取得・自動送信しません/, "geotag must remain explicit opt-in");
assert.match(publishSource, /現在地を公開地点に設定/, "explicit location action must remain visible");
assert.match(publishSource, /if newValue != \.public \{ locationPicker\.clear\(\)/, "leaving public must clear pending location");
assert.match(
  publishSource,
  /visibility == \.public && locationPicker\.location != nil/,
  "only public submissions may attach location",
);

const shellSource = readFileSync(
  fileURLToPath(new URL("../SplatNative/ScanLabShellView.swift", import.meta.url)),
  "utf8",
);
assert.match(shellSource, /struct ScanLabMapView: View/, "Map UI must remain wired");
assert.match(shellSource, /backend\.mapScans\.filter \{ \$0\.location != nil \}/, "Map must show only located public items from the map feed");

console.log("PASS: ScanLab Map/geotag contract");
