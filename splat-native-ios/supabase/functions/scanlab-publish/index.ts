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

function cleanText(value: unknown, maxLength: number) {
  if (typeof value !== "string") return null;
  return value.replace(/[\u0000-\u001f\u007f]/g, " ").replace(/\s+/g, " ").trim().slice(0, maxLength);
}

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const shareBase = "https://allsunday1122.github.io/splat-native-ios/viewer/";

function shareUrlFor(scan: { id: string; visibility: string; share_token: string }) {
  return scan.visibility === "public"
    ? `${shareBase}?id=${encodeURIComponent(scan.id)}`
    : scan.visibility === "unlisted"
      ? `${shareBase}#token=${encodeURIComponent(scan.share_token)}`
      : null;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const token = bearer(req);
  if (!token) return json({ error: "unauthorized" }, 401);

  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const user = userData.user;
  if (userError || !user) return json({ error: "unauthorized" }, 401);

  let body: { scanId?: string; title?: string; description?: string };
  try { body = await req.json(); } catch { return json({ error: "invalid_json" }, 400); }
  if (!body.scanId || !uuid.test(body.scanId)) return json({ error: "invalid_scan_id" }, 400);

  const title = body.title === undefined ? null : cleanText(body.title, 80);
  const description = body.description === undefined ? null : cleanText(body.description, 500);
  if (body.title !== undefined && !title) return json({ error: "invalid_title" }, 400);

  const { data: scan, error: scanError } = await admin
    .from("scanlab_scans")
    .select("id,owner_id,title,caption,visibility,status,moderation_status,asset_path,preview_path,latitude,longitude,public_place_confirmed,privacy_confirmed,rights_confirmed,content_confirmed,share_token,published_at")
    .eq("id", body.scanId)
    .maybeSingle();

  if (scanError || !scan) return json({ error: "not_found" }, 404);
  if (scan.owner_id !== user.id) return json({ error: "forbidden" }, 403);
  const expectedFolder = `${user.id}/${scan.id}`;
  if (scan.asset_path !== `${expectedFolder}/scene.spz`) return json({ error: "trusted_package_required" }, 409);
  if (scan.preview_path && ![`${expectedFolder}/preview.jpg`, `${expectedFolder}/preview.png`].includes(scan.preview_path)) {
    return json({ error: "invalid_preview_path" }, 409);
  }

  if (scan.status === "published") {
    return json({
      id: scan.id,
      title: scan.title,
      description: scan.caption,
      visibility: scan.visibility,
      publishedAt: scan.published_at,
      shareUrl: shareUrlFor(scan),
      hasPreview: Boolean(scan.preview_path),
      alreadyPublished: true,
    });
  }

  if (["public", "unlisted"].includes(scan.visibility) && !scan.content_confirmed) {
    return json({ error: "content_confirmation_required" }, 400);
  }
  if (scan.visibility === "public") {
    const hasLat = scan.latitude != null;
    const hasLon = scan.longitude != null;
    if (!scan.privacy_confirmed || !scan.rights_confirmed || hasLat !== hasLon || (hasLat && !scan.public_place_confirmed)) {
      return json({ error: "public_safety_confirmation_required" }, 400);
    }
  }

  const { count: reportCount, error: reportError } = await admin
    .from("scanlab_reports")
    .select("id", { count: "exact", head: true })
    .eq("scan_id", scan.id);
  if (reportError) return json({ error: "moderation_check_failed" }, 503);
  if ((reportCount ?? 0) > 0) return json({ error: "moderation_hold" }, 409);

  const { data: files, error: listError } = await admin.storage.from("scanlab-assets").list(expectedFolder, { limit: 8 });
  if (listError) return json({ error: "asset_check_failed" }, 503);
  const byName = new Map((files ?? []).map((f) => [f.name, f]));
  const scene = byName.get("scene.spz");
  const manifest = byName.get("manifest.json");
  if (!scene) return json({ error: "asset_missing" }, 409);
  if (!manifest) return json({ error: "manifest_missing" }, 409);
  if (!scene.metadata?.size || scene.metadata.size < 64) return json({ error: "asset_invalid" }, 409);
  if (!manifest.metadata?.size || manifest.metadata.size < 2 || manifest.metadata.size > 65536) return json({ error: "manifest_invalid" }, 409);
  if (scene.metadata?.mimetype && scene.metadata.mimetype !== "application/octet-stream") return json({ error: "asset_mime_invalid" }, 409);
  if (manifest.metadata?.mimetype && !["application/json", "application/octet-stream"].includes(manifest.metadata.mimetype)) return json({ error: "manifest_mime_invalid" }, 409);

  const metadata: Record<string, string> = {};
  if (title !== null) metadata.title = title;
  if (description !== null) metadata.caption = description;

  const { data: updated, error: updateError } = await admin
    .from("scanlab_scans")
    .update({ ...metadata, status: "published", moderation_status: "approved" })
    .eq("id", scan.id)
    .eq("owner_id", user.id)
    .neq("status", "published")
    .select("id,title,caption,visibility,share_token,preview_path,published_at")
    .maybeSingle();

  if (updateError) {
    const rateLimited = updateError.message?.includes("rate limit") ?? false;
    const objectionable = updateError.message?.includes("objectionable") ?? false;
    return json({ error: rateLimited ? "publish_rate_limited" : objectionable ? "content_rejected" : "publish_failed" }, rateLimited ? 429 : 400);
  }
  if (!updated) return json({ error: "lifecycle_conflict" }, 409);

  return json({
    id: updated.id,
    title: updated.title,
    description: updated.caption,
    visibility: updated.visibility,
    publishedAt: updated.published_at,
    shareUrl: shareUrlFor(updated),
    hasPreview: Boolean(updated.preview_path),
    alreadyPublished: false,
  });
});
