const BOX_KEYS = ["minLat", "maxLat", "minLon", "maxLon"];

export function parseScanLabBoundingBox(searchParams) {
  const raw = BOX_KEYS.map((key) => searchParams.get(key));
  const suppliedCount = raw.reduce((count, value) => count + (value === null ? 0 : 1), 0);

  if (suppliedCount === 0) return { value: null };
  if (suppliedCount !== BOX_KEYS.length || raw.some((value) => value === null || value.trim() === "")) {
    return { value: null, error: "invalid_bbox" };
  }

  const [minLat, maxLat, minLon, maxLon] = raw.map((value) => Number(value));
  if (
    ![minLat, maxLat, minLon, maxLon].every(Number.isFinite) ||
    minLat < -90 || maxLat > 90 || minLon < -180 || maxLon > 180 ||
    minLat > maxLat || minLon > maxLon ||
    (maxLat - minLat) > 90 || (maxLon - minLon) > 180
  ) {
    return { value: null, error: "invalid_bbox" };
  }

  return { value: { minLat, maxLat, minLon, maxLon } };
}
