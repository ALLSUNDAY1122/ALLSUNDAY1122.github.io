import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import { buildScanLabVisibilityChange } from "./visibility_contract.mjs";

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

function shareUrl(id: string, visibility: string, shareToken: string) {
  const base = "https://allsunday1122.github.io/splat-native-ios/viewer/";
  if (visibility === "public") return `${base}?id=${encodeURIComponent(id)}`;
  if (visibility === "unlisted") return `${base}?token=${encodeURIComponent(shareToken)}`;
  return null;
}

type VisibilityBody = {
  scanId?: string;
  visibility?: string;
  latitude?: number | null;
  longitude?: number | null;
  locationLabel?: string | null;
  contentConfirmed?: boolean;
  publicPlaceConfirmed?: boolean;
  privacyConfirmed?: boolean;
  rightsConfirmed?: boolean;
};

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const token = bearer(req);
  if (!token) return json({ error: "unauthorized" }, 401);
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const user = userData.user;
  if (userError || !user) return json({ error: "unauthorized" }, 401);

  let body: VisibilityBody;
  try { body = await req.json(); } catch { return json({ error: "invalid_json" }, 400); }
  if (!body.scanId || !/^[0-9a-f-]{36}$/i.test(body.scanId)) return json({ error: "invalid_scan_id" }, 400);

  const { data: scan, error: scanError } = await admin
    .from("scanlab_scans")
    .select("id,owner_id,visibility,status,moderation_status,share_token,published_at")
    .eq("id", body.scanId)
    .maybeSingle();

  if (scanError || !scan) return json({ error: "not_found" }, 404);
  if (scan.owner_id !== user.id) return json({ error: "forbidden" }, 403);
  if (scan.status !== "published" || scan.moderation_status !== "approved") {
    return json({ error: "visibility_change_unavailable" }, 409);
  }

  const { count: reportCount, error: reportError } = await admin
    .from("scanlab_reports")
    .select("id", { count: "exact", head: true })
    .eq("scan_id", scan.id);
  if (reportError) return json({ error: "moderation_check_failed" }, 503);
  if ((reportCount ?? 0) > 0) return json({ error: "moderation_hold" }, 409);

  const change = buildScanLabVisibilityChange(scan.visibility, body);
  if (change.error) return json({ error: change.error }, 400);
  if (change.noop) {
    return json({
      id: scan.id,
      visibility: scan.visibility,
      publishedAt: scan.published_at,
      shareUrl: shareUrl(scan.id, scan.visibility, scan.share_token),
    });
  }

  const update = {
    ...change.update,
    ...(change.rotateShareToken ? { share_token: crypto.randomUUID() } : {}),
  };

  const { data: updated, error: updateError } = await admin
    .from("scanlab_scans")
    .update(update)
    .eq("id", scan.id)
    .eq("owner_id", user.id)
    .eq("status", "published")
    .eq("moderation_status", "approved")
    .eq("visibility", scan.visibility)
    .eq("share_token", scan.share_token)
    .select("id,visibility,share_token,published_at")
    .maybeSingle();

  if (updateError) return json({ error: "visibility_change_failed" }, 400);
  if (!updated) return json({ error: "visibility_change_conflict" }, 409);

  return json({
    id: updated.id,
    visibility: updated.visibility,
    publishedAt: updated.published_at,
    shareUrl: shareUrl(updated.id, updated.visibility, updated.share_token),
  });
});
