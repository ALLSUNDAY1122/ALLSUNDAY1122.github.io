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

function canonicalPackage(ownerId: string, scanId: string, assetPath: unknown, previewPath: unknown) {
  const folder = `${ownerId}/${scanId}`;
  if (assetPath !== `${folder}/scene.spz`) return null;
  if (previewPath != null && previewPath !== `${folder}/preview.jpg` && previewPath !== `${folder}/preview.png`) return null;
  return { folder, assetPath: `${folder}/scene.spz`, previewPath: previewPath as string | null };
}

async function listFolderPaths(folder: string) {
  const paths: string[] = [];
  const pageSize = 100;
  for (let offset = 0; offset < 1000; offset += pageSize) {
    const { data, error } = await admin.storage.from("scanlab-assets").list(folder, {
      limit: pageSize,
      offset,
      sortBy: { column: "name", order: "asc" },
    });
    if (error) return { paths: null, error: "asset_cleanup_pending" as const };
    for (const file of data ?? []) paths.push(`${folder}/${file.name}`);
    if ((data ?? []).length < pageSize) return { paths, error: null };
  }
  return { paths: null, error: "asset_cleanup_limit_exceeded" as const };
}

async function removePaths(paths: string[]) {
  for (let i = 0; i < paths.length; i += 100) {
    const batch = paths.slice(i, i + 100);
    if (batch.length === 0) continue;
    const { error } = await admin.storage.from("scanlab-assets").remove(batch);
    if (error) return error;
  }
  return null;
}

async function cleanupCanonicalFolder(ownerId: string, scanId: string, previewPath: string | null = null) {
  const folder = `${ownerId}/${scanId}`;
  const listed = await listFolderPaths(folder);
  if (listed.error) return listed.error;

  const paths = new Set(listed.paths ?? []);
  paths.add(`${folder}/scene.spz`);
  paths.add(`${folder}/manifest.json`);
  if (previewPath) paths.add(previewPath);

  const cleanupError = await removePaths([...paths]);
  return cleanupError ? "asset_cleanup_pending" as const : null;
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

  // Scope the service-role lookup by owner at the database boundary. A caller must not be able
  // to distinguish another user's scan UUID from an absent scan via 403 vs success behavior.
  const { data: scan, error: scanError } = await admin
    .from("scanlab_scans")
    .select("id,owner_id,asset_path,preview_path,status")
    .eq("id", body.scanId)
    .eq("owner_id", user.id)
    .maybeSingle();
  if (scanError) return json({ error: "scan_lookup_failed" }, 503);

  // A missing owner row can still have durable package remnants after a historical metadata-only
  // delete or interrupted legacy flow. The authenticated owner's canonical folder can be
  // derived safely from user.id + scanId, so recover those orphaned objects before success.
  if (!scan) {
    const recoveryError = await cleanupCanonicalFolder(user.id, body.scanId);
    if (recoveryError) return json({ error: recoveryError, retryable: true }, 503);
    return json({ deleted: true, scanId: body.scanId, recovered: true });
  }

  const packagePaths = canonicalPackage(user.id, scan.id, scan.asset_path, scan.preview_path);
  if (!packagePaths) return json({ error: "invalid_asset_path" }, 409);

  // Revoke publication first. If cleanup fails, share/feed reads stop immediately while the
  // hidden metadata row remains as a durable retry cursor for the owner.
  const { error: hideError } = await admin
    .from("scanlab_scans")
    .update({ status: "hidden", moderation_status: "pending" })
    .eq("id", scan.id)
    .eq("owner_id", user.id);
  if (hideError) return json({ error: "delete_prepare_failed" }, 503);

  const cleanupError = await cleanupCanonicalFolder(user.id, scan.id, packagePaths.previewPath);
  if (cleanupError) return json({ error: cleanupError, retryable: true }, 503);

  const { error: deleteError } = await admin
    .from("scanlab_scans")
    .delete()
    .eq("id", scan.id)
    .eq("owner_id", user.id);
  if (deleteError) return json({ error: "metadata_cleanup_pending", retryable: true }, 503);

  return json({ deleted: true, scanId: scan.id, recovered: scan.status === "hidden" });
});
