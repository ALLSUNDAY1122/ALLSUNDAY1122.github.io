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

function packageState(files: Array<{ name: string; metadata?: Record<string, any> | null }>) {
  const byName = new Map(files.map((file) => [file.name, file]));
  const scene = byName.get("scene.spz");
  const manifest = byName.get("manifest.json");
  if (!scene) return { ready: false, error: "asset_missing" } as const;
  if (!manifest) return { ready: false, error: "manifest_missing" } as const;

  const sceneSize = Number(scene.metadata?.size ?? 0);
  const manifestSize = Number(manifest.metadata?.size ?? 0);
  if (!Number.isFinite(sceneSize) || sceneSize < 64) return { ready: false, error: "asset_invalid" } as const;
  if (!Number.isFinite(manifestSize) || manifestSize < 2 || manifestSize > 65536) return { ready: false, error: "manifest_invalid" } as const;

  const sceneMime = scene.metadata?.mimetype;
  const manifestMime = manifest.metadata?.mimetype;
  if (sceneMime && sceneMime !== "application/octet-stream") return { ready: false, error: "asset_mime_invalid" } as const;
  if (manifestMime && !["application/json", "application/octet-stream"].includes(manifestMime)) {
    return { ready: false, error: "manifest_mime_invalid" } as const;
  }
  return { ready: true } as const;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const token = bearer(req);
  if (!token) return json({ error: "unauthorized" }, 401);

  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const user = userData.user;
  if (userError || !user) return json({ error: "unauthorized" }, 401);

  let body: { action?: string; scanId?: string; title?: string; caption?: string };
  try { body = await req.json(); } catch { return json({ error: "invalid_json" }, 400); }
  const action = body.action ?? "init";

  if (action === "init") {
    const title = typeof body.title === "string" ? body.title.trim() : "";
    const caption = typeof body.caption === "string" ? body.caption.trim() : "";
    if (title.length < 1 || title.length > 80) return json({ error: "invalid_title" }, 400);
    if (caption.length > 500) return json({ error: "invalid_caption" }, 400);

    const scanId = crypto.randomUUID();
    const folder = `${user.id}/${scanId}`;
    const assetPath = `${folder}/scene.spz`;

    const { error: insertError } = await admin.from("scanlab_scans").insert({
      id: scanId,
      owner_id: user.id,
      title,
      caption,
      visibility: "private",
      status: "draft",
      moderation_status: "pending",
      asset_path: assetPath,
      preview_path: null,
    });
    if (insertError) return json({ error: "upload_init_failed" }, 503);

    return json({
      scanId,
      paths: {
        scene: assetPath,
        manifest: `${folder}/manifest.json`,
        previewJpeg: `${folder}/preview.jpg`,
        previewPng: `${folder}/preview.png`,
      },
      required: ["scene.spz", "manifest.json"],
    }, 201);
  }

  if (action === "validate") {
    if (!body.scanId || !uuid.test(body.scanId)) return json({ error: "invalid_scan_id" }, 400);
    const { data: scan, error: scanError } = await admin
      .from("scanlab_scans")
      .select("id,owner_id,asset_path,status")
      .eq("id", body.scanId)
      .maybeSingle();
    if (scanError || !scan) return json({ error: "not_found" }, 404);
    if (scan.owner_id !== user.id) return json({ error: "forbidden" }, 403);
    if (scan.status !== "draft") return json({ error: "upload_closed" }, 409);

    const folder = `${user.id}/${scan.id}`;
    if (scan.asset_path !== `${folder}/scene.spz`) return json({ error: "trusted_package_required" }, 409);
    const { data: files, error: listError } = await admin.storage.from("scanlab-assets").list(folder, { limit: 8 });
    if (listError) return json({ error: "asset_check_failed" }, 503);

    const state = packageState(files ?? []);
    if (!state.ready) return json({ error: state.error }, 409);
    return json({ scanId: scan.id, ready: true });
  }

  return json({ error: "unknown_action" }, 400);
});
