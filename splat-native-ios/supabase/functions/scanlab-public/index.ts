import { createClient } from "npm:@supabase/supabase-js@2.112.3";

const cors = {
  "Access-Control-Allow-Origin": "https://allsunday1122.github.io",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Cache-Control": "public, max-age=30, s-maxage=60",
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

function publicPreviewEndpoint(scanId: string) {
  return `https://gybchnyqlqwmajwkhsly.supabase.co/functions/v1/scanlab-public?mode=preview&id=${encodeURIComponent(scanId)}`;
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
    previewImageUrl: scan.visibility === "public" && scan.preview_path ? publicPreviewEndpoint(scan.id) : null,
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

  if (mode === "preview") {
    const id = url.searchParams.get("id");
    if (!id || !/^[0-9a-f-]{36}$/i.test(id)) return json({ error: "invalid_id" }, 400);
    const { data: scan, error } = await supabase
      .from("scanlab_scans")
      .select("id,visibility,status,moderation_status,preview_path")
      .eq("id", id)
      .eq("visibility", "public")
      .eq("status", "published")
      .eq("moderation_status", "approved")
      .maybeSingle();
    if (error || !scan?.preview_path) return new Response("Not Found", { status: 404, headers: cors });
    const { data: file, error: downloadError } = await supabase.storage.from("scanlab-assets").download(scan.preview_path);
    if (downloadError || !file) return new Response("Not Found", { status: 404, headers: cors });
    const contentType = file.type === "image/png" ? "image/png" : file.type === "image/jpeg" ? "image/jpeg" : null;
    if (!contentType) return new Response("Unsupported preview", { status: 415, headers: cors });
    return new Response(file, {
      status: 200,
      headers: {
        ...cors,
        "Cache-Control": "public, max-age=300, s-maxage=600",
        "Content-Type": contentType,
      },
    });
  }

  if (mode === "feed") {
    const limit = Math.min(Math.max(Number(url.searchParams.get("limit") ?? 24) || 24, 1), 40);
    let query = supabase
      .from("scanlab_scans")
      .select("id,owner_id,title,caption,visibility,published_at,latitude,longitude,location_label,asset_path,preview_path")
      .eq("visibility", "public")
      .eq("status", "published")
      .eq("moderation_status", "approved")
      .order("published_at", { ascending: false })
      .limit(Math.min(limit * 2, 80));

    const minLat = Number(url.searchParams.get("minLat"));
    const maxLat = Number(url.searchParams.get("maxLat"));
    const minLon = Number(url.searchParams.get("minLon"));
    const maxLon = Number(url.searchParams.get("maxLon"));
    const hasBox = [minLat, maxLat, minLon, maxLon].every(Number.isFinite);
    if (hasBox) {
      if (minLat < -90 || maxLat > 90 || minLon < -180 || maxLon > 180 || minLat > maxLat || minLon > maxLon || (maxLat - minLat) > 90 || (maxLon - minLon) > 180) {
        return json({ error: "invalid_bbox" }, 400);
      }
      query = query.gte("latitude", minLat).lte("latitude", maxLat).gte("longitude", minLon).lte("longitude", maxLon);
    }

    const [{ data, error }, blocked] = await Promise.all([query, blockedUserIds(req)]);
    if (error) return json({ error: "feed_unavailable" }, 503);
    const visible = (data ?? []).filter((scan) => !blocked.has(scan.owner_id)).slice(0, limit);
    return json({ items: await Promise.all(visible.map(decorate)) });
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
