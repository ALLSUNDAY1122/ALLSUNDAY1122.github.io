export function validateScanLabPublicGeoSafety(scan) {
  if (scan.visibility !== "public") return { ok: true };

  if (!scan.privacy_confirmed || !scan.rights_confirmed) {
    return { ok: false, error: "public_safety_confirmation_required" };
  }

  const hasLatitude = scan.latitude != null;
  const hasLongitude = scan.longitude != null;
  if (hasLatitude !== hasLongitude) {
    return { ok: false, error: "invalid_public_location" };
  }

  if (!hasLatitude) return { ok: true };

  if (
    typeof scan.latitude !== "number" || !Number.isFinite(scan.latitude) ||
    typeof scan.longitude !== "number" || !Number.isFinite(scan.longitude) ||
    scan.latitude < -90 || scan.latitude > 90 ||
    scan.longitude < -180 || scan.longitude > 180
  ) {
    return { ok: false, error: "invalid_public_location" };
  }

  if (!scan.public_place_confirmed) {
    return { ok: false, error: "public_location_confirmation_required" };
  }

  return { ok: true };
}
