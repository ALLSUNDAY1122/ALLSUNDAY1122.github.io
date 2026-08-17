import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import { parseScanLabBoundingBox } from "./bbox.mjs";
import { makeScanLabFeedCursor, parseScanLabFeedCursor } from "./feed_cursor.mjs";
import { parseScanLabFeedAssetPolicy } from "./feed_asset_policy.mjs";
import { locationForPublicResponse } from "./geo_contract.mjs";
import { parseScanLabAssetPath, assetContentType } from "./asset_delivery.mjs";

const cors = {
  "Access-Control-Allow-Origin": "https://allsunday1122.github.io",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, range",
  "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
  "Access-Control-Expose-Headers": "Accept-Ranges, Content-Length, Content-Range, ETag",
  "Vary": "Authorization",
  "Cache-Control": "private, no-store",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json; charset=utf-8" } });
const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false, autoRefreshToken: false } });
const shareUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

async function signed(path: string | null, expiresIn = 120) {
  if (!path) return null;
  const { data, error } = await supabase.storage.from("scanlab-assets").createSignedUrl(path, expiresIn);
  return error ? null : data.signedUrl;
}

function durableAssetUrl(scan: Record<string, any>) {
  if (!parseScanLabAssetPath(scan.asset_path, scan.owner_id, scan.id)) return null;
  const key = scan.visibility === "unlisted" ? `token=${encodeURIComponent(scan.share_token)}` : `id=${encodeURIComponent(scan.id)}`;
  return `${Deno.env.get("SUPABASE_URL")}/functions/v1/scanlab-public?mode=asset&${key}`;
}

async function decorate(scan: Record<string, any>, includeModel = true) {
  const modelUrl = includeModel ? durableAssetUrl(scan) : null;
  const [{ data: profile }, previewUrl, { count: likeCount }] = await Promise.all([
    supabase.from("scanlab_profiles").select("handle,display_name,avatar_path").eq("id", scan.owner_id).maybeSingle(),
    signed(scan.preview_path),
    supabase.from("scanlab_likes").select("scan_id", { count: "exact", head: true }).eq("scan_id", scan.id),
  ]);
  return {
    id: scan.id,
    title: scan.title,
    caption: scan.caption,
    visibility: scan.visibility,
    publishedAt: scan.published_at,
    location: locationForPublicResponse(scan),
    author: profile ? { id: scan.owner_id, handle: profile.handle, displayName: profile.display_name } : null,
    likeCount: likeCount ?? 0,
    modelUrl,
    previewUrl,
  };
}

async function requestUserId(req: Request) {
  const header = req.headers.get("authorization") ?? "";
  if (!header.toLowerCase().startsWith("bearer ")) return null;
  const { data } = await supabase.auth.getUser(header.slice(7));
  return data.user?.id ?? null;
}

async function blockedUserIds(userId: string | null) {
  if (!userId) return new Set<string>();
  const [{ data: outgoing, error: outgoingError }, { data: incoming, error: incomingError }] = await Promise.all([
    supabase.from("scanlab_blocks").select("blocked_id").eq("blocker_id", userId),
    supabase.from("scanlab_blocks").select("blocker_id").eq("blocked_id", userId),
  ]);
  if (outgoingError || incomingError) throw new Error("block_lookup_failed");
  return new Set([
    ...(outgoing ?? []).map((row) => row.blocked_id as string),
    ...(incoming ?? []).map((row) => row.blocker_id as string),
  ]);
}

async function sharedScan(url: URL, userId: string | null) {
  const id = url.searchParams.get("id"), token = url.searchParams.get("token");
  if (!id && !token) return { error: "missing_share_key", status: 400 };
  if (id && token) return { error: "ambiguous_share_key", status: 400 };
  if (id && !shareUUID.test(id)) return { error: "invalid_id", status: 400 };
  if (token && !shareUUID.test(token)) return { error: "invalid_token", status: 400 };
  let query = supabase.from("scanlab_scans").select("id,owner_id,title,caption,visibility,published_at,latitude,longitude,location_label,asset_path,preview_path,status,moderation_status,share_token").eq("status", "published").eq("moderation_status", "approved").limit(1);
  query = token ? query.eq("share_token", token).eq("visibility", "unlisted") : query.eq("id", id!).eq("visibility", "public");
  const { data, error } = await query.maybeSingle();
  if (error || !data) return { error: "not_found", status: 404 };
  try {
    const blocked = await blockedUserIds(userId);
    if (blocked.has(data.owner_id)) return { error: "not_found", status: 404 };
  } catch {
    return { error: "access_check_unavailable", status: 503 };
  }
  return { scan: data };
}

async function serveAsset(req: Request, url: URL, userId: string | null) {
  const result = await sharedScan(url, userId);
  if (!("scan" in result)) return json({ error: result.error }, result.status);
  const scan = result.scan!;
  if (!parseScanLabAssetPath(scan.asset_path, scan.owner_id, scan.id)) return json({ error: "asset_contract_invalid" }, 409);
  const temporary = await signed(scan.asset_path);
  if (!temporary) return json({ error: "asset_unavailable" }, 503);
  const headers = new Headers();
  const range = req.headers.get("range");
  if (range) headers.set("Range", range);
  const upstream = await fetch(temporary, { method: req.method === "HEAD" ? "HEAD" : "GET", headers });
  if (!upstream.ok && upstream.status !== 206) return json({ error: upstream.status === 404 ? "asset_not_found" : "asset_unavailable" }, upstream.status === 404 ? 404 : 503);
  const responseHeaders = new Headers(cors);
  responseHeaders.set("Content-Type", upstream.headers.get("content-type") || assetContentType(scan.asset_path));
  responseHeaders.set("Cache-Control", "private, no-store");
  for (const name of ["accept-ranges", "content-length", "content-range", "etag"]) {
    const value = upstream.headers.get(name);
    if (value) responseHeaders.set(name, value);
  }
  return new Response(req.method === "HEAD" ? null : upstream.body, { status: upstream.status, headers: responseHeaders });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (!["GET", "HEAD"].includes(req.method)) return json({ error: "method_not_allowed" }, 405);
  const url = new URL(req.url), mode = url.searchParams.get("mode") ?? "feed", userId = await requestUserId(req);
  if (mode === "asset") return serveAsset(req, url, userId);
  if (req.method !== "GET") return json({ error: "method_not_allowed" }, 405);
  if (mode === "feed") {
    const limit = Math.min(Math.max(Number(url.searchParams.get("limit") ?? 24) || 24, 1), 40), fetchLimit = Math.min(limit * 3 + 1, 121), cursor = parseScanLabFeedCursor(url.searchParams.get("cursor"));
    if (cursor.error) return json({ error: cursor.error }, 400);
    const assetPolicy = parseScanLabFeedAssetPolicy(url.searchParams);
    if (assetPolicy.error) return json({ error: assetPolicy.error }, 400);
    let query = supabase.from("scanlab_scans").select("id,owner_id,title,caption,visibility,published_at,latitude,longitude,location_label,asset_path,preview_path,share_token").eq("visibility", "public").eq("status", "published").eq("moderation_status", "approved").order("published_at", { ascending: false }).order("id", { ascending: false }).limit(fetchLimit);
    if (cursor.value) {
      const { publishedAt, id } = cursor.value;
      query = query.or(`published_at.lt.${publishedAt},and(published_at.eq.${publishedAt},id.lt.${id})`);
    }
    const bbox = parseScanLabBoundingBox(url.searchParams);
    if (bbox.error) return json({ error: bbox.error }, 400);
    if (bbox.value) query = query.gte("latitude", bbox.value.minLat).lte("latitude", bbox.value.maxLat).gte("longitude", bbox.value.minLon).lte("longitude", bbox.value.maxLon);
    let blocked: Set<string>;
    try { blocked = await blockedUserIds(userId); } catch { return json({ error: "feed_unavailable" }, 503); }
    const { data, error } = await query;
    if (error) return json({ error: "feed_unavailable" }, 503);
    const rows = data ?? [], visibleRows = rows.filter((scan) => !blocked.has(scan.owner_id)), pageRows = visibleRows.slice(0, limit);
    let nextCursor = null;
    if (pageRows.length === limit && (visibleRows.length > limit || rows.length === fetchLimit)) nextCursor = makeScanLabFeedCursor(pageRows[pageRows.length - 1]);
    else if (pageRows.length < limit && rows.length === fetchLimit) nextCursor = makeScanLabFeedCursor(rows[rows.length - 1]);
    return json({ items: await Promise.all(pageRows.map((scan) => decorate(scan, assetPolicy.includeModel))), nextCursor });
  }
  if (mode === "share") {
    const result = await sharedScan(url, userId);
    if (!("scan" in result)) return json({ error: result.error }, result.status);
    return json({ item: await decorate(result.scan!) });
  }
  return json({ error: "unknown_mode" }, 400);
});
