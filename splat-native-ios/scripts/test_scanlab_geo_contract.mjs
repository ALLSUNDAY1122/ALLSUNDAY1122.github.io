import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import {
  locationForPublicResponse,
  parseBoundingBox,
} from "../supabase/functions/scanlab-public/geo_contract.mjs";

assert.deepEqual(
  parseBoundingBox(new URLSearchParams("mode=feed&limit=40")),
  { kind: "none" },
  "omitting bbox must not become a zero-degree bbox",
);
assert.equal(parseBoundingBox(new URLSearchParams("minLat=35")).kind, "invalid", "partial bbox must be rejected");
assert.equal(
  parseBoundingBox(new URLSearchParams("minLat=&maxLat=&minLon=&maxLon=")).kind,
  "invalid",
  "explicitly empty bbox must not be treated as omitted",
);
assert.equal(
  parseBoundingBox(new URLSearchParams("minLat=&maxLat=36&minLon=139&maxLon=140")).kind,
  "invalid",
  "empty bbox values must not coerce to zero",
);
assert.equal(
  parseBoundingBox(new URLSearchParams("minLat=x&maxLat=36&minLon=139&maxLon=140")).kind,
  "invalid",
  "non-numeric bbox must be rejected",
);
assert.deepEqual(
  parseBoundingBox(new URLSearchParams("minLat=35&maxLat=36&minLon=139&maxLon=140")),
  { kind: "valid", value: { minLat: 35, maxLat: 36, minLon: 139, maxLon: 140 } },
);
assert.equal(
  parseBoundingBox(new URLSearchParams("minLat=-91&maxLat=36&minLon=139&maxLon=140")).kind,
  "invalid",
  "out-of-range bbox must be rejected",
);
assert.equal(
  parseBoundingBox(new URLSearchParams("minLat=0&maxLat=91&minLon=139&maxLon=140")).kind,
  "invalid",
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
assert.match(functionSource, /parseBoundingBox\(url\.searchParams\)/, "feed must use the bbox parser");
assert.match(functionSource, /location:\s*locationForPublicResponse\(scan\)/, "public API must filter location by visibility");
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
assert.match(shellSource, /backend\.publicScans\.filter \{ \$0\.location != nil \}/, "Map must show only located public items");

console.log("PASS: ScanLab Map/geotag contract");
