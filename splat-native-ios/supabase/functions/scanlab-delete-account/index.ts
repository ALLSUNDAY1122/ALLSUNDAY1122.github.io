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
  return header.toLowerCase().startsWith("bearer ") ? header.slice(7).trim() : null;
}

function ownedPath(userID: string, path: unknown): path is string {
  return typeof path === "string" && path.startsWith(`${userID}/`) && !path.includes("../");
}

async function removePaths(paths: string[]) {
  for (let i = 0; i < paths.length; i += 100) {
    const batch = paths.slice(i, i + 100);
    if (!batch.length) continue;
    const { error } = await admin.storage.from("scanlab-assets").remove(batch);
    if (error) return error;
  }
  return null;
}

async function discoverOwnedObjects(userID: string) {
  const files: string[] = [];
  const pending = [userID];
  while (pending.length) {
    const prefix = pending.pop()!;
    let offset = 0;
    while (true) {
      const { data, error } = await admin.storage.from("scanlab-assets").list(prefix, {
        limit: 100,
        offset,
        sortBy: { column: "name", order: "asc" },
      });
      if (error) return { files: [], error };
      const entries = data ?? [];
      for (const entry of entries) {
        const path = `${prefix}/${entry.name}`;
        if (!ownedPath(userID, path)) continue;
        if (entry.id) files.push(path);
        else pending.push(path);
      }
      if (entries.length < 100) break;
      offset += entries.length;
    }
  }
  return { files, error: null };
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
  if (scansError) return json({ error: "delete_prepare_failed", retryable: true }, 503);

  const referenced = (scans ?? [])
    .flatMap((scan) => [scan.asset_path, scan.preview_path])
    .filter((path): path is string => ownedPath(user.id, path));

  const discovered = await discoverOwnedObjects(user.id);
  if (discovered.error) return json({ error: "asset_list_failed", retryable: true }, 503);

  const paths = Array.from(new Set([...referenced, ...discovered.files]));
  const assetError = await removePaths(paths);
  if (assetError) return json({ error: "asset_delete_failed", retryable: true }, 503);

  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) return json({ error: "account_delete_failed", retryable: true }, 503);

  return json({ deleted: true, deleted_assets: paths.length });
});
