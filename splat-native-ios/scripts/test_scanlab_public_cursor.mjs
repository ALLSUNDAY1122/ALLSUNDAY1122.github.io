import assert from "node:assert/strict";
import { makeScanLabFeedCursor, parseScanLabFeedCursor } from "../supabase/functions/scanlab-public/feed_cursor.mjs";

const id = "123e4567-e89b-42d3-a456-426614174000";
const later = "2026-08-16T12:34:56.789Z";
const cursor = makeScanLabFeedCursor({ id, published_at: later });
assert.equal(cursor, `${later}~${id}`);
assert.deepEqual(parseScanLabFeedCursor(cursor).value, { publishedAt: later, id });
assert.equal(parseScanLabFeedCursor(null).value, null);

for (const bad of [
  "",
  later,
  `${later}~not-a-uuid`,
  `not-a-date~${id}`,
  `${later}~${id}~extra`,
  "x".repeat(97),
]) {
  assert.equal(parseScanLabFeedCursor(bad).error, "invalid_cursor", `must reject: ${bad}`);
}

assert.equal(makeScanLabFeedCursor({ id: "bad", published_at: later }), null);
assert.equal(makeScanLabFeedCursor({ id, published_at: "bad" }), null);
console.log("PASS: Discover feed cursor is validated, deterministic, and injection-resistant");
