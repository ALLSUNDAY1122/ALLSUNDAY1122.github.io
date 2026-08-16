import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import { parseScanLabBoundingBox } from "./bbox.mjs";
import { makeScanLabFeedCursor, parseScanLabFeedCursor } from "./feed_cursor.mjs";

const cors = {
  "Access-Control-Allow-Origin": "https://allsunday1122.github.io",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Vary": "Authorization",
  "Cache-Control": "private, no-store",
};

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
});

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);

async function signed(path: string | null, expiresIn = 600) {
  if (!path) return null;
  const { data, error } = await supabase.storage.from("scanlab-assets").createSignedUrl(path, expiresIn);
  if (error) return null;
  return data.signedUrl;
}

async function decorate(scan: Record<string, any>) {
  const [{ data: profile }, modelUrl, previewUrl, { count: likeCount }] = await Promise.all([
    supabase.from("scanlab_profiles").select("handle,display_name,avatar_path").eq("id", scan.owner_id).maybeSingle(),
    signed(scan.asset_path),
    signed(scan.preview_path),
    supabase.from("scanlab_likes").select("scan_id", { count: "exact", head: true }).eq("scan_id", scan.id),
  ]);
  return {
    id: scan.id,
    title: scan.title,
    caption: scan.caption,
    visibility: scan.visibility,
    publishedAt: scan.published_at,
    location: scan.latitude == null || scan.longitude == null ? null : {
      latitude: scan.latitude,
      longitude: scan.longitude,
      label: scan.location_label,
    },
    author: profile ? { id: scan.owner_id, handle: profile.handle, displayName: profile.display_name } : null,
    likeCount: likeCount ?? 0,
    modelUrl,
    previewUrl,
  };
}

async function blockedUserIds(req: Request) {
  const header = req.headers.get("authorization") ?? "";
  if (!header.toLowerCase().startsWith("bearer ")) return new Set<string>();
  const token = header.slice(7);
  const { data: userData } = await supabase.auth.getUser(token);
  const user = userData.user;
  if (!user) return new Set<string>();
  const { data } = await supabase.from("scanlab_blocks").select("blocked_id").eq("blocker_id", user.id);
  return new Set((data ?? []).map((row) => row.blocked_id as string));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "GET") return json({ error: "method_not_allowed" }, 405);

  const url = new URL(req.url);
  const mode = url.searchParams.get("mode") ?? "feed";

  if (mode === "feed") {
    const limit = Math.min(Math.max(Number(url.searchParams.get("limit") ?? 24) || 24, 1), 40);
    const fetchLimit = Math.min(limit * 3 + 1, 121);
    const cursor = parseScanLabFeedCursor(url.searchParams.get("cursor"));
    if (cursor.error) return json({ error: cursor.error }, 400);

    let query = supabase
      .from("scanlab_scans")
      .select("id,owner_id,title,caption,visibility,published_at,latitude,longitude,location_label,asset_path,preview_path")
      .eq("visibility", "public")
      .eq("status", "published")
      .eq("moderation_status", "approved")
      .order("published_at", { ascending: false })
      .order("id", { ascending: false })
      .limit(fetchLimit);

    if (cursor.value) {
      const { publishedAt, id } = cursor.value;
      query = query.or(`published_at.lt.${publishedAt},and(published_at.eq.${publishedAt},id.lt.${id})`);
    }

    const bbox = parseScanLabBoundingBox(url.searchParams);
    if (bbox.error) return json({ error: bbox.error }, 400);
    if (bbox.value) {
      query = query
        .gte("latitude", bbox.value.minLat)
        .lte("latitude", bbox.value.maxLat)
        .gte("longitude", bbox.value.minLon)
        .lte("longitude", bbox.value.maxLon);
    }

    const [{ data, error }, blocked] = await Promise.all([query, blockedUserIds(req)]);
    if (error) return json({ error: "feed_unavailable" }, 503);

    const rows = data ?? [];
    const visibleRows = rows.filter((scan) => !blocked.has(scan.owner_id));
    const pageRows = visibleRows.slice(0, limit);
    let nextCursor: string | null = null;

    if (pageRows.length === limit && (visibleRows.length > limit || rows.length === fetchLimit)) {
      nextCursor = makeScanLabFeedCursor(pageRows[pageRows.length - 1]);
    } else if (pageRows.length < limit && rows.length === fetchLimit) {
      // A block-heavy batch may contain fewer than `limit` visible rows. Advance past every
      // row already inspected so the next request cannot loop forever on blocked content.
      nextCursor = makeScanLabFeedCursor(rows[rows.length - 1]);
    }

    return json({ items: await Promise.all(pageRows.map(decorate)), nextCursor });
  }

  if (mode === "share") {
    const id = url.searchParams.get("id");
    const token = url.searchParams.get("token");
    if (!id && !token) return json({ error: "missing_share_key" }, 400);
    if (token && !/^[0-9a-f-]{36}$/i.test(token)) return json({ error: "invalid_token" }, 400);

    let query = supabase
      .from("scanlab_scans")
      .select("id,owner_id,title,caption,visibility,published_at,latitude,longitude,location_label,asset_path,preview_path,status,moderation_status")
      .eq("status", "published")
      .eq("moderation_status", "approved")
      .limit(1);

    if (token) query = query.eq("share_token", token).eq("visibility", "unlisted");
    else query = query.eq("id", id!).eq("visibility", "public");

    const { data, error } = await query.maybeSingle();
    if (error || !data) return json({ error: "not_found" }, 404);
    return json({ item: await decorate(data) });
  }

  return json({ error: "unknown_mode" }, 400);
});
