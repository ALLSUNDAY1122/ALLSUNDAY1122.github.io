import { createClient } from "npm:@supabase/supabase-js@2.112.3";

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { "Content-Type": "application/json; charset=utf-8" },
});
const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const allowed = new Set(["public", "unlisted", "private"]);

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const header = req.headers.get("authorization") ?? "";
  if (!header.toLowerCase().startsWith("bearer ")) return json({ error: "unauthorized" }, 401);
  const { data: userData } = await admin.auth.getUser(header.slice(7));
  if (!userData.user) return json({ error: "unauthorized" }, 401);

  let body: { scanId?: string; visibility?: string };
  try { body = await req.json(); } catch { return json({ error: "invalid_json" }, 400); }
  if (!body.scanId || !/^[0-9a-f-]{36}$/i.test(body.scanId)) return json({ error: "invalid_scan_id" }, 400);
  if (!body.visibility || !allowed.has(body.visibility)) return json({ error: "invalid_visibility" }, 400);

  const { data: current, error: readError } = await admin.from("scanlab_scans")
    .select("id,owner_id,visibility,status,share_token")
    .eq("id", body.scanId).maybeSingle();
  if (readError || !current) return json({ error: "not_found" }, 404);
  if (current.owner_id !== userData.user.id) return json({ error: "forbidden" }, 403);

  const nextStatus = body.visibility === "private" && current.status === "published" ? "hidden" : current.status;
  const { data: updated, error: updateError } = await admin.from("scanlab_scans")
    .update({ visibility: body.visibility, status: nextStatus })
    .eq("id", current.id).eq("owner_id", userData.user.id)
    .select("id,visibility,status,published_at,share_token").single();
  if (updateError) return json({ error: "visibility_update_failed" }, 400);

  const base = "https://allsunday1122.github.io/splat-native-ios/viewer/";
  const shareUrl = updated.status !== "published" ? null
    : updated.visibility === "public" ? `${base}?id=${encodeURIComponent(updated.id)}`
    : updated.visibility === "unlisted" ? `${base}?token=${encodeURIComponent(updated.share_token)}`
    : null;

  return json({ id: updated.id, visibility: updated.visibility, status: updated.status, publishedAt: updated.published_at, shareUrl });
});
