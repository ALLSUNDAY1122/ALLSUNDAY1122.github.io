import { createClient } from "npm:@supabase/supabase-js@2.112.3";

function requireEnv(name: string) {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`missing ${name}`);
  return value;
}

if (Deno.env.get("D2_ACCOUNT_DELETE_E2E") !== "1") {
  throw new Error("refusing destructive E2E without D2_ACCOUNT_DELETE_E2E=1");
}

const url = requireEnv("SUPABASE_URL");
const serviceRole = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
const publishableKey = requireEnv("SUPABASE_PUBLISHABLE_KEY");
const admin = createClient(url, serviceRole, { auth: { persistSession: false, autoRefreshToken: false } });
const userClient = createClient(url, publishableKey, { auth: { persistSession: false, autoRefreshToken: false } });

const runID = crypto.randomUUID();
const email = `d2-delete-e2e-${runID}@example.com`;
const password = `D2!${crypto.randomUUID()}aA9`;
let userID: string | null = null;
let orphanPath: string | null = null;

async function assertNoStoragePrefix(id: string) {
  const { data, error } = await admin.storage.from("scanlab-assets").list(id, { limit: 100 });
  if (error) throw error;
  if ((data ?? []).length !== 0) throw new Error(`storage prefix survived deletion for ${id}`);
}

try {
  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });
  if (createError || !created.user) throw createError ?? new Error("test user was not created");
  userID = created.user.id;

  const { error: signInError } = await userClient.auth.signInWithPassword({ email, password });
  if (signInError) throw signInError;

  orphanPath = `${userID}/d2-delete-e2e/${runID}/nested/orphan.bin`;
  const payload = new TextEncoder().encode(`d2-delete-e2e:${runID}`);
  const { error: uploadError } = await userClient.storage
    .from("scanlab-assets")
    .upload(orphanPath, payload, { contentType: "application/octet-stream", upsert: false });
  if (uploadError) throw uploadError;

  const { data: beforeRows, error: beforeProfileError } = await admin
    .from("scanlab_profiles")
    .select("id")
    .eq("id", userID);
  if (beforeProfileError) throw beforeProfileError;
  const profileExisted = (beforeRows ?? []).length > 0;

  const { data: deleted, error: invokeError } = await userClient.functions.invoke("scanlab-delete-account", {
    body: { confirm: true },
  });
  if (invokeError) throw invokeError;
  if (!deleted?.deleted || deleted?.sessions_revoked !== true) {
    throw new Error(`unexpected delete response: ${JSON.stringify(deleted)}`);
  }

  const { data: authAfter, error: authAfterError } = await admin.auth.admin.getUserById(userID);
  if (!authAfterError && authAfter.user) throw new Error("auth user survived account deletion");

  const { data: afterRows, error: afterProfileError } = await admin
    .from("scanlab_profiles")
    .select("id")
    .eq("id", userID);
  if (afterProfileError) throw afterProfileError;
  if (profileExisted && (afterRows ?? []).length !== 0) throw new Error("profile row survived auth cascade");

  await assertNoStoragePrefix(userID);

  const { error: refreshError } = await userClient.auth.refreshSession();
  if (!refreshError) throw new Error("deleted account unexpectedly refreshed its session");

  const { error: reauthError } = await userClient.auth.signInWithPassword({ email, password });
  if (!reauthError) throw new Error("deleted account unexpectedly signed in again");

  console.log("account-delete-live-e2e: PASS");
} finally {
  if (orphanPath) await admin.storage.from("scanlab-assets").remove([orphanPath]).catch(() => undefined);
  if (userID) await admin.auth.admin.deleteUser(userID).catch(() => undefined);
}
