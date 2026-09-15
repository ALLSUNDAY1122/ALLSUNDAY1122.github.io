#!/usr/bin/env node

const baseURL = process.env.SCANLAB_SUPABASE_URL ?? "https://gybchnyqlqwmajwkhsly.supabase.co";
const publishableKey = process.env.SCANLAB_PUBLISHABLE_KEY ?? "sb_publishable_jYM9b6kivVT80sbAQ2syFw_zSUANBHV";

const attempts = 3;

async function fetchSettings() {
  let lastError;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      const response = await fetch(`${baseURL}/auth/v1/settings`, {
        headers: { apikey: publishableKey },
        signal: AbortSignal.timeout(10_000),
      });
      const text = await response.text();
      let body;
      try {
        body = text ? JSON.parse(text) : null;
      } catch {
        throw new Error(`Auth settings returned non-JSON HTTP ${response.status}`);
      }
      if (!response.ok) {
        throw new Error(`Auth settings returned HTTP ${response.status}`);
      }
      return body;
    } catch (error) {
      lastError = error;
      if (attempt < attempts) {
        await new Promise((resolve) => setTimeout(resolve, attempt * 1_000));
      }
    }
  }
  throw lastError;
}

async function main() {
  const settings = await fetchSettings();
  const emailEnabled = settings?.external?.email;
  const signupDisabled = settings?.disable_signup;
  const autoConfirm = settings?.mailer_autoconfirm ?? settings?.autoconfirm;

  if (emailEnabled !== true) {
    throw new Error("Hosted Supabase Auth has email authentication disabled.");
  }
  if (signupDisabled !== false) {
    throw new Error("Hosted Supabase Auth has signup disabled.");
  }
  if (typeof autoConfirm !== "boolean") {
    throw new Error("Hosted Supabase Auth settings did not expose a recognized email confirmation mode.");
  }

  console.log(JSON.stringify({
    gate: "scanlab-hosted-auth-readiness",
    status: "PASS",
    email_auth_enabled: emailEnabled,
    signup_enabled: !signupDisabled,
    email_confirmation_required: !autoConfirm,
  }));
}

main().catch((error) => {
  console.error(JSON.stringify({
    gate: "scanlab-hosted-auth-readiness",
    status: "FAIL",
    error: error instanceof Error ? error.message : String(error),
  }));
  process.exit(1);
});
