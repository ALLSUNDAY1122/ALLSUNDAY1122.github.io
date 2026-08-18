export const SCANLAB_VISIBILITIES = new Set(["private", "unlisted", "public"]);

function normalizedLocationLabel(value) {
  if (value == null) return { value: null };
  if (typeof value !== "string") return { error: "invalid_location_label" };
  const trimmed = value.trim();
  if (trimmed.length > 120) return { error: "invalid_location_label" };
  return { value: trimmed.length === 0 ? null : trimmed };
}

function normalizedPublicLocation(input) {
  const latitude = input?.latitude;
  const longitude = input?.longitude;
  const hasLatitude = latitude != null;
  const hasLongitude = longitude != null;

  if (!hasLatitude && !hasLongitude) {
    return { latitude: null, longitude: null, locationLabel: null, hasGeotag: false };
  }
  if (hasLatitude !== hasLongitude) return { error: "invalid_public_location" };
  if (
    typeof latitude !== "number" || !Number.isFinite(latitude) || latitude < -90 || latitude > 90 ||
    typeof longitude !== "number" || !Number.isFinite(longitude) || longitude < -180 || longitude > 180
  ) {
    return { error: "invalid_public_location" };
  }

  const label = normalizedLocationLabel(input?.locationLabel);
  if (label.error) return { error: label.error };
  return { latitude, longitude, locationLabel: label.value, hasGeotag: true };
}

export function buildScanLabVisibilityChange(currentVisibility, input) {
  if (!SCANLAB_VISIBILITIES.has(currentVisibility)) return { error: "invalid_current_visibility" };
  const targetVisibility = typeof input?.visibility === "string" ? input.visibility : "";
  if (!SCANLAB_VISIBILITIES.has(targetVisibility)) return { error: "invalid_visibility" };
  if (targetVisibility === currentVisibility) return { noop: true, targetVisibility };

  const rotateShareToken = currentVisibility === "unlisted" || targetVisibility === "unlisted";

  if (targetVisibility === "public") {
    if (input?.contentConfirmed !== true) return { error: "content_confirmation_required" };
    if (input?.privacyConfirmed !== true || input?.rightsConfirmed !== true) {
      return { error: "public_safety_confirmation_required" };
    }

    const location = normalizedPublicLocation(input);
    if (location.error) return { error: location.error };
    if (location.hasGeotag && input?.publicPlaceConfirmed !== true) {
      return { error: "public_safety_confirmation_required" };
    }

    return {
      noop: false,
      targetVisibility,
      rotateShareToken,
      update: {
        visibility: "public",
        latitude: location.latitude,
        longitude: location.longitude,
        location_label: location.locationLabel,
        content_confirmed: true,
        public_place_confirmed: location.hasGeotag,
        privacy_confirmed: true,
        rights_confirmed: true,
      },
    };
  }

  if (targetVisibility === "unlisted") {
    if (input?.contentConfirmed !== true) return { error: "content_confirmation_required" };
    return {
      noop: false,
      targetVisibility,
      rotateShareToken,
      update: {
        visibility: "unlisted",
        latitude: null,
        longitude: null,
        location_label: null,
        content_confirmed: true,
        public_place_confirmed: false,
        privacy_confirmed: false,
        rights_confirmed: false,
      },
    };
  }

  return {
    noop: false,
    targetVisibility,
    rotateShareToken,
    update: {
      visibility: "private",
      latitude: null,
      longitude: null,
      location_label: null,
      content_confirmed: false,
      public_place_confirmed: false,
      privacy_confirmed: false,
      rights_confirmed: false,
    },
  };
}
