import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import { parseScanLabAssetPath, assetContentType } from "./asset_delivery.mjs";

const cors = {
  "Access-Control-Allow-Origin": "https://allsunday1122.github.io",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, range",
  "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
  "Access-Control-Expose-Headers": "Accept-Ranges, Content-Length, Content-Range, ETag",
  "Cache-Control": "private, no-store",
  "Vary": "Authorization",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json; charset=utf-8" } });
const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false, autoRefreshToken: false } });

async function signed(path: string | null, expiresIn = 120) {
  if (!path) return null;
  const { data, error } = await supabase.storage.from("scanlab-assets").createSignedUrl(path, expiresIn);
  return error ? null : data.signedUrl;
}
function assetUrl(scan: Record<string, any>) {
  if (!parseScanLabAssetPath(scan.asset_path, scan.owner_id, scan.id)) return null;
  const key = scan.visibility === "unlisted" ? `token=${encodeURIComponent(scan.share_token)}` : `id=${encodeURIComponent(scan.id)}`;
  return `${Deno.env.get("SUPABASE_URL")}/functions/v1/scanlab-public?mode=asset&${key}`;
}
async function decorate(scan: Record<string, any>) {
  const [{ data: profile }, previewUrl, { count: likeCount }] = await Promise.all([
    supabase.from("scanlab_profiles").select("handle,display_name,avatar_path").eq("id", scan.owner_id).maybeSingle(),
    signed(scan.preview_path),
    supabase.from("scanlab_likes").select("scan_id", { count: "exact", head: true }).eq("scan_id", scan.id),
  ]);
  return {
    id: scan.id, title: scan.title, caption: scan.caption, visibility: scan.visibility, publishedAt: scan.published_at,
    location: scan.latitude == null || scan.longitude == null ? null : { latitude: scan.latitude, longitude: scan.longitude, label: scan.location_label },
    author: profile ? { id: scan.owner_id, handle: profile.handle, displayName: profile.display_name } : null,
    likeCount: likeCount ?? 0, modelUrl: assetUrl(scan), previewUrl,
  };
}
async function blockedUserIds(req: Request) {
  const header = req.headers.get("authorization") ?? "";
  if (!header.toLowerCase().startsWith("bearer ")) return new Set<string>();
  const { data: userData } = await supabase.auth.getUser(header.slice(7));
  if (!userData.user) return new Set<string>();
  const { data } = await supabase.from("scanlab_blocks").select("blocked_id").eq("blocker_id", userData.user.id);
  return new Set((data ?? []).map((row) => row.blocked_id as string));
}
async function sharedScan(url: URL) {
  const id = url.searchParams.get("id");
  const token = url.searchParams.get("token");
  if (!id && !token) return { error: "missing_share_key", status: 400 };
  if (token && !/^[0-9a-f-]{36}$/i.test(token)) return { error: "invalid_token", status: 400 };
  let query = supabase.from("scanlab_scans")
    .select("id,owner_id,title,caption,visibility,published_at,latitude,longitude,location_label,asset_path,preview_path,status,moderation_status,share_token")
    .eq("status", "published").eq("moderation_status", "approved").limit(1);
  query = token ? query.eq("share_token", token).eq("visibility", "unlisted") : query.eq("id", id!).eq("visibility", "public");
  const { data, error } = await query.maybeSingle();
  return error || !data ? { error: "not_found", status: 404 } : { scan: data };
}
async function serveAsset(req: Request, url: URL) {
  const result = await sharedScan(url);
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
  responseHeaders.set("Cache-Control", "private, max-age=60");
  for (const name of ["accept-ranges", "content-length", "content-range", "etag"]) {
    const value = upstream.headers.get(name); if (value) responseHeaders.set(name, value);
  }
  return new Response(req.method === "HEAD" ? null : upstream.body, { status: upstream.status, headers: responseHeaders });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (!["GET", "HEAD"].includes(req.method)) return json({ error: "method_not_allowed" }, 405);
  const url = new URL(req.url);
  const mode = url.searchParams.get("mode") ?? "feed";
  if (mode === "asset") return serveAsset(req, url);
  if (req.method !== "GET") return json({ error: "method_not_allowed" }, 405);

  if (mode === "feed") {
    const limit = Math.min(Math.max(Number(url.searchParams.get("limit") ?? 24) || 24, 1), 40);
    let query = supabase.from("scanlab_scans")
      .select("id,owner_id,title,caption,visibility,published_at,latitude,longitude,location_label,asset_path,preview_path,share_token")
      .eq("visibility", "public").eq("status", "published").eq("moderation_status", "approved")
      .order("published_at", { ascending: false }).limit(Math.min(limit * 2, 80));
    const rawBox = ["minLat", "maxLat", "minLon", "maxLon"].map((key) => url.searchParams.get(key));
    const supplied = rawBox.filter((value) => value !== null).length;
    if (supplied && supplied !== 4) return json({ error: "invalid_bbox" }, 400);
    if (supplied === 4) {
      const [minLat, maxLat, minLon, maxLon] = rawBox.map((value) => Number(value));
      if (![minLat,maxLat,minLon,maxLon].every(Number.isFinite) || minLat < -90 || maxLat > 90 || minLon < -180 || maxLon > 180 || minLat > maxLat || minLon > maxLon || maxLat-minLat > 90 || maxLon-minLon > 180) return json({ error: "invalid_bbox" }, 400);
      query = query.gte("latitude", minLat).lte("latitude", maxLat).gte("longitude", minLon).lte("longitude", maxLon);
    }
    const [{ data, error }, blocked] = await Promise.all([query, blockedUserIds(req)]);
    if (error) return json({ error: "feed_unavailable" }, 503);
    return json({ items: await Promise.all((data ?? []).filter((scan) => !blocked.has(scan.owner_id)).slice(0, limit).map(decorate)) });
  }
  if (mode === "share") {
    const result = await sharedScan(url);
    if (!("scan" in result)) return json({ error: result.error }, result.status);
    return json({ item: await decorate(result.scan!) });
  }
  return json({ error: "unknown_mode" }, 400);
});
