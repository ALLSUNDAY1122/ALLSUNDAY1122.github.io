const boundingBoxKeys = ["minLat", "maxLat", "minLon", "maxLon"];

export function parseBoundingBox(params) {
  const raw = boundingBoxKeys.map((key) => params.get(key));
  const provided = raw.map((value) => value !== null);

  if (!provided.some(Boolean)) return { kind: "none" };
  if (!provided.every(Boolean)) return { kind: "invalid" };
  if (raw.some((value) => value.trim() === "")) return { kind: "invalid" };

  const values = raw.map((value) => Number(value));
  if (!values.every(Number.isFinite)) return { kind: "invalid" };

  const [minLat, maxLat, minLon, maxLon] = values;
  if (
    minLat < -90 || maxLat > 90 || minLon < -180 || maxLon > 180 ||
    minLat > maxLat || minLon > maxLon ||
    (maxLat - minLat) > 90 || (maxLon - minLon) > 180
  ) {
    return { kind: "invalid" };
  }

  return { kind: "valid", value: { minLat, maxLat, minLon, maxLon } };
}

export function locationForPublicResponse(scan) {
  if (scan.visibility !== "public") return null;
  if (typeof scan.latitude !== "number" || !Number.isFinite(scan.latitude)) return null;
  if (typeof scan.longitude !== "number" || !Number.isFinite(scan.longitude)) return null;
  if (scan.latitude < -90 || scan.latitude > 90 || scan.longitude < -180 || scan.longitude > 180) return null;

  return {
    latitude: scan.latitude,
    longitude: scan.longitude,
    label: typeof scan.location_label === "string" ? scan.location_label : null,
  };
}
