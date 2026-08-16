import { createClient } from "npm:@supabase/supabase-js@2.112.3";

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
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

function validUUID(value: unknown): value is string {
  return typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function safeOwnedPath(path: unknown, ownerId: string) {
  if (typeof path !== "string" || !path.startsWith(`${ownerId}/`)) return null;
  if (path.includes("..") || path.includes("//")) return null;
  return path;
}

async function removePaths(paths: string[]) {
  if (paths.length === 0) return null;
  const { error } = await admin.storage.from("scanlab-assets").remove(paths);
  return error;
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
  if (!validUUID(body.scanId)) return json({ error: "invalid_scan_id" }, 400);

  const { data: scan, error: scanError } = await admin
    .from("scanlab_scans")
    .select("id,owner_id,asset_path,preview_path,status")
    .eq("id", body.scanId)
    .maybeSingle();
  if (scanError) return json({ error: "scan_lookup_failed" }, 503);
  if (!scan) return json({ deleted: true, scanId: body.scanId, recovered: true });
  if (scan.owner_id !== user.id) return json({ error: "forbidden" }, 403);

  const assetPath = safeOwnedPath(scan.asset_path, user.id);
  const previewPath = scan.preview_path == null ? null : safeOwnedPath(scan.preview_path, user.id);
  if (!assetPath || (scan.preview_path != null && !previewPath)) return json({ error: "invalid_asset_path" }, 409);

  // Hide first. If storage cleanup fails, public/feed/share reads stop immediately and a retry
  // can safely resume cleanup without exposing a half-deleted scan.
  const { error: hideError } = await admin
    .from("scanlab_scans")
    .update({ status: "hidden", moderation_status: "pending" })
    .eq("id", scan.id)
    .eq("owner_id", user.id);
  if (hideError) return json({ error: "delete_prepare_failed" }, 503);

  const slash = assetPath.lastIndexOf("/");
  const folder = slash > 0 ? assetPath.slice(0, slash) : "";
  const { data: files, error: listError } = await admin.storage.from("scanlab-assets").list(folder, { limit: 100 });
  if (listError) return json({ error: "asset_cleanup_pending", retryable: true }, 503);

  const paths = new Set<string>();
  for (const file of files ?? []) paths.add(folder ? `${folder}/${file.name}` : file.name);
  paths.add(assetPath);
  if (previewPath) paths.add(previewPath);

  const cleanupError = await removePaths([...paths]);
  if (cleanupError) return json({ error: "asset_cleanup_pending", retryable: true }, 503);

  const { error: deleteError } = await admin
    .from("scanlab_scans")
    .delete()
    .eq("id", scan.id)
    .eq("owner_id", user.id);
  if (deleteError) return json({ error: "metadata_cleanup_pending", retryable: true }, 503);

  return json({ deleted: true, scanId: scan.id, recovered: scan.status === "hidden" });
});
