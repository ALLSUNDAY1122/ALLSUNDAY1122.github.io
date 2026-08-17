#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

: "${SUPABASE_URL:?SUPABASE_URL is required}"
: "${SUPABASE_SERVICE_ROLE_KEY:?SUPABASE_SERVICE_ROLE_KEY is required}"
: "${SUPABASE_PUBLISHABLE_KEY:?SUPABASE_PUBLISHABLE_KEY is required}"

command -v deno >/dev/null 2>&1 || { echo "deno is required" >&2; exit 1; }

export D2_ACCOUNT_DELETE_E2E=1
deno run --allow-env=SUPABASE_URL,SUPABASE_SERVICE_ROLE_KEY,SUPABASE_PUBLISHABLE_KEY,D2_ACCOUNT_DELETE_E2E --allow-net tests/account-delete-live-e2e.ts
