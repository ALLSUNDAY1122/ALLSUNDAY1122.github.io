import assert from "node:assert/strict";
import { parseScanLabBoundingBox } from "../supabase/functions/scanlab-public/bbox.mjs";

const parse = (query = "") => parseScanLabBoundingBox(new URLSearchParams(query));

assert.equal(parse().value, null, "missing bbox must mean no geographic filter");
assert.equal(parse().error, undefined);

assert.deepEqual(
  parse("minLat=35&maxLat=36&minLon=139&maxLon=140").value,
  { minLat: 35, maxLat: 36, minLon: 139, maxLon: 140 },
  "complete bbox must be parsed",
);

for (const query of [
  "minLat=35",
  "minLat=&maxLat=36&minLon=139&maxLon=140",
  "minLat=36&maxLat=35&minLon=139&maxLon=140",
  "minLat=-91&maxLat=35&minLon=139&maxLon=140",
  "minLat=0&maxLat=10&minLon=-170&maxLon=170",
  "minLat=abc&maxLat=36&minLon=139&maxLon=140",
]) {
  assert.equal(parse(query).error, "invalid_bbox", `invalid bbox should fail closed: ${query}`);
}

console.log("PASS: scanlab-public bbox parsing distinguishes missing filters from 0,0");
