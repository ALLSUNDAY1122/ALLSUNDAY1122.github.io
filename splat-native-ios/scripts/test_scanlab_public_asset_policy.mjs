import assert from "node:assert/strict";
import { parseScanLabFeedAssetPolicy } from "../supabase/functions/scanlab-public/feed_asset_policy.mjs";

const parse = (query = "") => parseScanLabFeedAssetPolicy(new URLSearchParams(query));

assert.deepEqual(parse(), { includeModel: true });
assert.deepEqual(parse("includeModel=1"), { includeModel: true });
assert.deepEqual(parse("includeModel=0"), { includeModel: false });
assert.equal(parse("includeModel=").error, "invalid_include_model");
assert.equal(parse("includeModel=false").error, "invalid_include_model");
assert.equal(parse("includeModel=2").error, "invalid_include_model");

console.log("PASS: scanlab-public feed asset policy only suppresses model URLs when explicitly requested");
