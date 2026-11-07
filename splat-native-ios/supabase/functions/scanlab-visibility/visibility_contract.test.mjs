import test from "node:test";
import assert from "node:assert/strict";
import { buildScanLabVisibilityChange } from "./visibility_contract.mjs";

test("public without geotag only requires content privacy and rights confirmations", () => {
  assert.equal(buildScanLabVisibilityChange("private", { visibility: "public" }).error, "content_confirmation_required");
  assert.equal(buildScanLabVisibilityChange("private", { visibility: "public", contentConfirmed: true, privacyConfirmed: false, rightsConfirmed: true }).error, "public_safety_confirmation_required");
  const result = buildScanLabVisibilityChange("unlisted", { visibility: "public", contentConfirmed: true, privacyConfirmed: true, rightsConfirmed: true, publicPlaceConfirmed: false });
  assert.equal(result.error, undefined);
  assert.equal(result.rotateShareToken, true);
  assert.deepEqual(result.update, {
    visibility: "public",
    latitude: null,
    longitude: null,
    location_label: null,
    content_confirmed: true,
    public_place_confirmed: false,
    privacy_confirmed: true,
    rights_confirmed: true,
  });
});

test("partial or invalid public geotag fails closed", () => {
  const base = { visibility: "public", contentConfirmed: true, privacyConfirmed: true, rightsConfirmed: true, publicPlaceConfirmed: true };
  assert.equal(buildScanLabVisibilityChange("private", { ...base, latitude: 35.68 }).error, "invalid_public_location");
  assert.equal(buildScanLabVisibilityChange("private", { ...base, latitude: 91, longitude: 139.76 }).error, "invalid_public_location");
});

test("public geotag requires place confirmation and stores normalized location", () => {
  assert.equal(buildScanLabVisibilityChange("private", { visibility: "public", latitude: 35.68, longitude: 139.76, contentConfirmed: true, publicPlaceConfirmed: false, privacyConfirmed: true, rightsConfirmed: true }).error, "public_safety_confirmation_required");
  const result = buildScanLabVisibilityChange("unlisted", { visibility: "public", latitude: 35.68, longitude: 139.76, locationLabel: "  Tokyo  ", contentConfirmed: true, publicPlaceConfirmed: true, privacyConfirmed: true, rightsConfirmed: true });
  assert.equal(result.error, undefined);
  assert.equal(result.rotateShareToken, true);
  assert.deepEqual(result.update, { visibility: "public", latitude: 35.68, longitude: 139.76, location_label: "Tokyo", content_confirmed: true, public_place_confirmed: true, privacy_confirmed: true, rights_confirmed: true });
});

test("public to unlisted clears geodata and rotates the private link", () => {
  const r = buildScanLabVisibilityChange("public", { visibility: "unlisted", contentConfirmed: true });
  assert.equal(r.rotateShareToken, true);
  assert.equal(r.update.visibility, "unlisted");
  assert.equal(r.update.latitude, null);
  assert.equal(r.update.longitude, null);
  assert.equal(r.update.location_label, null);
  assert.equal(r.update.public_place_confirmed, false);
  assert.equal(r.update.content_confirmed, true);
});

test("unlisted to private revokes link generation state and clears sharing attestations", () => {
  const r = buildScanLabVisibilityChange("unlisted", { visibility: "private" });
  assert.equal(r.rotateShareToken, true);
  assert.equal(r.update.visibility, "private");
  assert.equal(r.update.content_confirmed, false);
  assert.equal(r.update.latitude, null);
});

test("private to unlisted requires sharing confirmation and rotates token", () => {
  assert.equal(buildScanLabVisibilityChange("private", { visibility: "unlisted", contentConfirmed: false }).error, "content_confirmation_required");
  const r = buildScanLabVisibilityChange("private", { visibility: "unlisted", contentConfirmed: true });
  assert.equal(r.rotateShareToken, true);
  assert.equal(r.update.visibility, "unlisted");
});

test("unknown target fails closed and same target is a no-op", () => {
  assert.equal(buildScanLabVisibilityChange("public", { visibility: "unexpected" }).error, "invalid_visibility");
  assert.deepEqual(buildScanLabVisibilityChange("private", { visibility: "private" }), { noop: true, targetVisibility: "private" });
});
