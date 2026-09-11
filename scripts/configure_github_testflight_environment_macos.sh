#!/usr/bin/env bash
set -Eeuo pipefail

ENVIRONMENT="testflight-production"
REPO="${GITHUB_REPOSITORY:-ALLSUNDAY1122/ALLSUNDAY1122.github.io}"

usage() {
  cat <<'EOF'
Usage:
  ./configure_github_testflight_environment_macos.sh \
    --certificate /path/to/AppleDistribution.p12 \
    --profile /path/to/AppStore.mobileprovision \
    --api-key /path/to/AuthKey_XXXXXXXXXX.p8 \
    --team-id ABCDEFGHIJ \
    --key-id KLMNOPQRST \
    --issuer-id 00000000-0000-0000-0000-000000000000

Optional:
  --repo OWNER/REPO
  --environment NAME

The script does not print secret contents.
It sends values directly to GitHub Environment secrets using gh CLI.
EOF
}

CERTIFICATE=""
PROFILE=""
API_KEY=""
TEAM_ID=""
KEY_ID=""
ISSUER_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --certificate) CERTIFICATE="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --api-key) API_KEY="$2"; shift 2 ;;
    --team-id) TEAM_ID="$2"; shift 2 ;;
    --key-id) KEY_ID="$2"; shift 2 ;;
    --issuer-id) ISSUER_ID="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --environment) ENVIRONMENT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

command -v gh >/dev/null 2>&1 || {
  echo "GitHub CLI (gh) is required." >&2
  exit 1
}
command -v openssl >/dev/null 2>&1 || {
  echo "openssl is required." >&2
  exit 1
}
command -v security >/dev/null 2>&1 || {
  echo "macOS security command is required." >&2
  exit 1
}

[[ -f "$CERTIFICATE" ]] || { echo "Certificate .p12 not found." >&2; exit 1; }
[[ -f "$PROFILE" ]] || { echo "Provisioning profile not found." >&2; exit 1; }
[[ -f "$API_KEY" ]] || { echo "API .p8 key not found." >&2; exit 1; }
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || { echo "Invalid Team ID." >&2; exit 1; }
[[ "$KEY_ID" =~ ^[A-Z0-9]{10}$ ]] || { echo "Invalid API Key ID." >&2; exit 1; }
[[ "$ISSUER_ID" =~ ^[0-9a-fA-F-]{36}$ ]] || { echo "Invalid Issuer ID." >&2; exit 1; }

gh auth status >/dev/null
grep -q "BEGIN PRIVATE KEY" "$API_KEY" || {
  echo "The API key does not appear to be a .p8 private key." >&2
  exit 1
}

PROFILE_PLIST="$(mktemp)"
trap 'rm -f "$PROFILE_PLIST"' EXIT
security cms -D -i "$PROFILE" > "$PROFILE_PLIST"
PROFILE_TEAM_ID="$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' "$PROFILE_PLIST")"
PROFILE_APP_IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' "$PROFILE_PLIST")"

[[ "$PROFILE_TEAM_ID" == "$TEAM_ID" ]] || {
  echo "Provisioning profile Team ID mismatch." >&2
  exit 1
}
[[ "$PROFILE_APP_IDENTIFIER" == "$TEAM_ID.jp.allsunday.aihandoverlog" ]] || {
  echo "Provisioning profile Bundle ID mismatch." >&2
  exit 1
}

read -r -s -p "Enter the .p12 export password: " P12_PASSWORD
printf '\n'
[[ -n "$P12_PASSWORD" ]] || { echo "P12 password is required." >&2; exit 1; }

TEMP_KEYCHAIN_PASSWORD="$(openssl rand -base64 36 | tr -d '\n')"

echo "Configuring GitHub Environment secrets for $REPO / $ENVIRONMENT."

printf '%s' "$TEAM_ID" \
  | gh secret set APPLE_TEAM_ID --repo "$REPO" --env "$ENVIRONMENT"

base64 < "$CERTIFICATE" | tr -d '\n' \
  | gh secret set APPLE_DISTRIBUTION_CERTIFICATE_P12_BASE64 --repo "$REPO" --env "$ENVIRONMENT"

printf '%s' "$P12_PASSWORD" \
  | gh secret set APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD --repo "$REPO" --env "$ENVIRONMENT"

base64 < "$PROFILE" | tr -d '\n' \
  | gh secret set APPLE_PROVISIONING_PROFILE_BASE64 --repo "$REPO" --env "$ENVIRONMENT"

printf '%s' "$TEMP_KEYCHAIN_PASSWORD" \
  | gh secret set APPLE_TEMP_KEYCHAIN_PASSWORD --repo "$REPO" --env "$ENVIRONMENT"

base64 < "$API_KEY" | tr -d '\n' \
  | gh secret set APP_STORE_CONNECT_API_KEY_P8_BASE64 --repo "$REPO" --env "$ENVIRONMENT"

printf '%s' "$KEY_ID" \
  | gh secret set APP_STORE_CONNECT_API_KEY_ID --repo "$REPO" --env "$ENVIRONMENT"

printf '%s' "$ISSUER_ID" \
  | gh secret set APP_STORE_CONNECT_ISSUER_ID --repo "$REPO" --env "$ENVIRONMENT"

unset P12_PASSWORD TEMP_KEYCHAIN_PASSWORD

echo "Secrets configured. Review the Environment protection rules in GitHub Settings."
