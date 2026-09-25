#!/usr/bin/env node

const baseURL = process.env.SCANLAB_SUPABASE_URL ?? "https://gybchnyqlqwmajwkhsly.supabase.co";
const publishableKey = process.env.SCANLAB_PUBLISHABLE_KEY ?? "sb_publishable_jYM9b6kivVT80sbAQ2syFw_zSUANBHV";
const email = process.env.SCANLAB_E2E_EMAIL;
const password = process.env.SCANLAB_E2E_PASSWORD;

if (!email || !password) {
  console.error("SCANLAB_E2E_EMAIL and SCANLAB_E2E_PASSWORD are required. No credentials are stored in the repository.");
  process.exit(2);
}

const jsonHeaders = {
  apikey: publishableKey,
  "Content-Type": "application/json",
};

async function request(path, options = {}) {
  const response = await fetch(`${baseURL}${path}`, options);
  const text = await response.text();
  let body = null;
  if (text) {
    try {
      body = JSON.parse(text);
    } catch {
      body = text;
    }
  }
  if (!response.ok) {
    const summary = typeof body === "string" ? body.slice(0, 240) : JSON.stringify(body);
    throw new Error(`${options.method ?? "GET"} ${path} -> ${response.status}: ${summary}`);
  }
  return { response, body };
}

function authHeaders(accessToken, extra = {}) {
  return {
    ...jsonHeaders,
    Authorization: `Bearer ${accessToken}`,
    ...extra,
  };
}

async function main() {
  const login = await request("/auth/v1/token?grant_type=password", {
    method: "POST",
    headers: jsonHeaders,
    body: JSON.stringify({ email, password }),
  });

  const accessToken = login.body?.access_token;
  const refreshToken = login.body?.refresh_token;
  const userID = login.body?.user?.id;
  if (!accessToken || !refreshToken || !userID) {
    throw new Error("Password login succeeded without a complete session.");
  }

  const profileQuery = `/rest/v1/scanlab_profiles?id=eq.${encodeURIComponent(userID)}&select=id,handle,display_name,avatar_path`;
  const profileRead = await request(profileQuery, {
    headers: authHeaders(accessToken),
  });
  if (!Array.isArray(profileRead.body) || profileRead.body.length !== 1 || profileRead.body[0].id !== userID) {
    throw new Error("Own profile was not readable through authenticated RLS.");
  }

  const originalProfile = profileRead.body[0];
  const profileWrite = await request(`/rest/v1/scanlab_profiles?id=eq.${encodeURIComponent(userID)}`, {
    method: "PATCH",
    headers: authHeaders(accessToken, { Prefer: "return=representation" }),
    body: JSON.stringify({
      handle: originalProfile.handle,
      display_name: originalProfile.display_name,
    }),
  });
  if (!Array.isArray(profileWrite.body) || profileWrite.body.length !== 1 || profileWrite.body[0].id !== userID) {
    throw new Error("Own profile UPDATE did not return the authenticated profile.");
  }

  const refreshed = await request("/auth/v1/token?grant_type=refresh_token", {
    method: "POST",
    headers: jsonHeaders,
    body: JSON.stringify({ refresh_token: refreshToken }),
  });
  const refreshedAccessToken = refreshed.body?.access_token;
  if (!refreshedAccessToken || refreshed.body?.user?.id !== userID) {
    throw new Error("Session refresh did not preserve the authenticated user.");
  }

  const profileAfterRefresh = await request(profileQuery, {
    headers: authHeaders(refreshedAccessToken),
  });
  if (!Array.isArray(profileAfterRefresh.body) || profileAfterRefresh.body.length !== 1) {
    throw new Error("Refreshed session could not read the authenticated profile.");
  }

  await request("/auth/v1/logout", {
    method: "POST",
    headers: authHeaders(refreshedAccessToken),
  });

  console.log(JSON.stringify({
    gate: "scanlab-auth-session-profile-live-e2e",
    status: "PASS",
    user_id: userID,
    checks: [
      "password_sign_in",
      "profile_rls_read",
      "profile_rls_update",
      "session_refresh",
      "profile_read_after_refresh",
      "sign_out",
    ],
  }));
}

main().catch((error) => {
  console.error(JSON.stringify({
    gate: "scanlab-auth-session-profile-live-e2e",
    status: "FAIL",
    error: error instanceof Error ? error.message : String(error),
  }));
  process.exit(1);
});
