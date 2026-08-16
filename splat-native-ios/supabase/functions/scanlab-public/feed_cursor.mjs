const CURSOR_SEPARATOR = "~";
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function parseScanLabFeedCursor(rawCursor) {
  if (rawCursor == null) return { value: null };
  if (rawCursor.length > 96) return { value: null, error: "invalid_cursor" };

  const separatorIndex = rawCursor.lastIndexOf(CURSOR_SEPARATOR);
  if (separatorIndex <= 0 || separatorIndex === rawCursor.length - 1) {
    return { value: null, error: "invalid_cursor" };
  }

  const publishedAtRaw = rawCursor.slice(0, separatorIndex);
  const id = rawCursor.slice(separatorIndex + 1).toLowerCase();
  const millis = Date.parse(publishedAtRaw);
  if (!Number.isFinite(millis) || !UUID_PATTERN.test(id)) {
    return { value: null, error: "invalid_cursor" };
  }

  return {
    value: {
      publishedAt: new Date(millis).toISOString(),
      id,
    },
  };
}

export function makeScanLabFeedCursor(scan) {
  const millis = Date.parse(scan?.published_at ?? "");
  const id = String(scan?.id ?? "").toLowerCase();
  if (!Number.isFinite(millis) || !UUID_PATTERN.test(id)) return null;
  return `${new Date(millis).toISOString()}${CURSOR_SEPARATOR}${id}`;
}
