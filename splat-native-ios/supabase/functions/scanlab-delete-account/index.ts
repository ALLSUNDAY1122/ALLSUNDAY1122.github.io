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

  const { data: scans, error: scansError } = await admin
    .from("scanlab_scans")
    .select("asset_path,preview_path")
    .eq("owner_id", user.id);
  if (scansError) return json({ error: "delete_prepare_failed" }, 503);

  const paths = Array.from(new Set((scans ?? []).flatMap((scan) => [scan.asset_path, scan.preview_path]).filter((p): p is string => typeof p === "string" && p.startsWith(`${user.id}/`))));
  for (let i = 0; i < paths.length; i += 100) {
    const batch = paths.slice(i, i + 100);
    if (batch.length) {
      const { error } = await admin.storage.from("scanlab-assets").remove(batch);
      if (error) return json({ error: "asset_delete_failed" }, 503);
    }
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) return json({ error: "account_delete_failed" }, 503);

  return json({ deleted: true });
});
