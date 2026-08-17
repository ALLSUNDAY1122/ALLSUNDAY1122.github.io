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

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const token = bearer(req);
  if (!token) return json({ error: "unauthorized" }, 401);

  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const user = userData.user;
  if (userError || !user) return json({ error: "unauthorized" }, 401);

  let body: { scanId?: string };
  try { body = await req.json(); } catch { return json({ error: "invalid_json" }, 400); }
  if (!body.scanId || !uuid.test(body.scanId)) return json({ error: "invalid_scan_id" }, 400);

  const { data: scan, error: scanError } = await admin
    .from("scanlab_scans")
    .select("id,owner_id,status,visibility,share_token")
    .eq("id", body.scanId)
    .maybeSingle();
  if (scanError || !scan) return json({ error: "not_found" }, 404);
  if (scan.owner_id !== user.id) return json({ error: "forbidden" }, 403);

  if (scan.status !== "published") {
    return json({ id: scan.id, status: scan.status, visibility: scan.visibility, unpublished: false });
  }

  const { data: updated, error: updateError } = await admin
    .from("scanlab_scans")
    .update({ status: "hidden" })
    .eq("id", scan.id)
    .eq("owner_id", user.id)
    .eq("status", "published")
    .select("id,status,visibility,published_at,share_token")
    .maybeSingle();

  if (updateError) return json({ error: "unpublish_failed" }, 400);
  if (!updated) return json({ error: "lifecycle_conflict" }, 409);

  // Preserve visibility, share_token and all storage assets. A later publish call can move
  // hidden -> published only after the current safety, moderation and package checks pass again.
  return json({
    id: updated.id,
    status: updated.status,
    visibility: updated.visibility,
    publishedAt: updated.published_at,
    unpublished: true,
  });
});
