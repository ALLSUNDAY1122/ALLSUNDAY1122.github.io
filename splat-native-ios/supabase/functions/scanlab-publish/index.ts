import { createClient } from "npm:@supabase/supabase-js@2.112.3";

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { "Content-Type": "application/json; charset=utf-8" },
});

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);

function bearer(req: Request) {
  const header = req.headers.get("authorization") ?? "";
  return header.toLowerCase().startsWith("bearer ") ? header.slice(7) : null;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const token = bearer(req);
  if (!token) return json({ error: "unauthorized" }, 401);

  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const user = userData.user;
  if (userError || !user) return json({ error: "unauthorized" }, 401);

  let body: { scanId?: string };
  try { body = await req.json(); } catch { return json({ error: "invalid_json" }, 400); }
  if (!body.scanId || !/^[0-9a-f-]{36}$/i.test(body.scanId)) return json({ error: "invalid_scan_id" }, 400);

  const { data: scan, error: scanError } = await admin
    .from("scanlab_scans")
    .select("id,owner_id,visibility,status,moderation_status,asset_path,preview_path,latitude,longitude,public_place_confirmed,privacy_confirmed,rights_confirmed,content_confirmed,share_token")
    .eq("id", body.scanId)
    .maybeSingle();

  if (scanError || !scan) return json({ error: "not_found" }, 404);
  if (scan.owner_id !== user.id) return json({ error: "forbidden" }, 403);
  if (!scan.asset_path.startsWith(`${user.id}/`)) return json({ error: "invalid_asset_path" }, 400);

  if (["public", "unlisted"].includes(scan.visibility) && !scan.content_confirmed) {
    return json({ error: "content_confirmation_required" }, 400);
  }
  if (scan.visibility === "public") {
    if (scan.latitude == null || scan.longitude == null || !scan.public_place_confirmed || !scan.privacy_confirmed || !scan.rights_confirmed) {
      return json({ error: "public_safety_confirmation_required" }, 400);
    }
  }

  const { count: reportCount, error: reportError } = await admin
    .from("scanlab_reports")
    .select("id", { count: "exact", head: true })
    .eq("scan_id", scan.id);
  if (reportError) return json({ error: "moderation_check_failed" }, 503);
  if ((reportCount ?? 0) > 0) return json({ error: "moderation_hold" }, 409);

  const slash = scan.asset_path.lastIndexOf("/");
  const folder = slash > 0 ? scan.asset_path.slice(0, slash) : "";
  const fileName = slash > 0 ? scan.asset_path.slice(slash + 1) : scan.asset_path;
  const { data: files, error: listError } = await admin.storage.from("scanlab-assets").list(folder, { search: fileName, limit: 10 });
  if (listError || !(files ?? []).some((f) => f.name === fileName)) return json({ error: "asset_missing" }, 409);

  const { data: updated, error: updateError } = await admin
    .from("scanlab_scans")
    .update({ status: "published", moderation_status: "approved" })
    .eq("id", scan.id)
    .eq("owner_id", user.id)
    .select("id,visibility,share_token,published_at")
    .single();

  if (updateError) {
    const rateLimited = updateError.message?.includes("rate limit") ?? false;
    const objectionable = updateError.message?.includes("objectionable") ?? false;
    return json({ error: rateLimited ? "publish_rate_limited" : objectionable ? "content_rejected" : "publish_failed" }, rateLimited ? 429 : 400);
  }

  const base = "https://allsunday1122.github.io/splat-native-ios/viewer/";
  const shareUrl = updated.visibility === "public"
    ? `${base}?id=${encodeURIComponent(updated.id)}`
    : updated.visibility === "unlisted"
      ? `${base}?token=${encodeURIComponent(updated.share_token)}`
      : null;

  return json({ id: updated.id, visibility: updated.visibility, publishedAt: updated.published_at, shareUrl });
});
