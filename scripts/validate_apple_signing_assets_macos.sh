#!/usr/bin/env bash
set -Eeuo pipefail

BUNDLE_ID="jp.allsunday.aihandoverlog"
REPORT_PATH="${REPORT_PATH:-apple_signing_assets_validation.json}"

usage() {
  cat <<'EOF'
AI引継ぎ帳 Apple signing asset validator

Usage:
  ./validate_apple_signing_assets_macos.sh \
    --certificate /path/to/AppleDistribution.p12 \
    --profile /path/to/AppStore.mobileprovision \
    --api-key /path/to/AuthKey_XXXXXXXXXX.p8 \
    --team-id ABCDEFGHIJ \
    --key-id KLMNOPQRST \
    --issuer-id 00000000-0000-0000-0000-000000000000 \
    [--report /path/to/report.json]

The script:
- runs locally on macOS;
- never prints the .p12 password or private key;
- does not upload or copy credentials;
- writes only non-secret fingerprints and metadata to the report.

Do not send the credential files or their contents to ChatGPT, GitHub issues,
pull requests, Notion, email, or other messaging services.
EOF
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
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
    --report) REPORT_PATH="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

[[ "$(uname -s)" == "Darwin" ]] || die "This validator must run on macOS."
command -v security >/dev/null || die "security command not found."
command -v openssl >/dev/null || die "openssl command not found."
command -v python3 >/dev/null || die "python3 command not found."
[[ -x /usr/libexec/PlistBuddy ]] || die "PlistBuddy not found."

[[ -f "$CERTIFICATE" ]] || die ".p12 certificate file not found."
[[ -f "$PROFILE" ]] || die ".mobileprovision file not found."
[[ -f "$API_KEY" ]] || die ".p8 API key file not found."
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || die "Team ID must be 10 uppercase letters/digits."
[[ "$KEY_ID" =~ ^[A-Z0-9]{10}$ ]] || die "API Key ID must be 10 uppercase letters/digits."
[[ "$ISSUER_ID" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] \
  || die "Issuer ID must be a UUID."

EXPECTED_API_KEY_NAME="AuthKey_${KEY_ID}.p8"
[[ "$(basename "$API_KEY")" == "$EXPECTED_API_KEY_NAME" ]] || {
  printf 'WARNING: API key filename is %s; Apple convention is %s.\n' \
    "$(basename "$API_KEY")" "$EXPECTED_API_KEY_NAME" >&2
}

TMP_DIR="$(mktemp -d)"
trap 'unset P12_PASSWORD; rm -rf "$TMP_DIR"' EXIT

read -r -s -p "Enter the .p12 export password: " P12_PASSWORD
printf '\n'
[[ -n "$P12_PASSWORD" ]] || die ".p12 password is required."
export P12_PASSWORD

CERT_PEM="$TMP_DIR/distribution-cert.pem"
PROFILE_PLIST="$TMP_DIR/profile.plist"

openssl pkcs12 \
  -in "$CERTIFICATE" \
  -clcerts \
  -nokeys \
  -passin env:P12_PASSWORD \
  -out "$CERT_PEM" \
  >/dev/null 2>&1 \
  || die "Unable to decrypt .p12 or certificate is invalid."

openssl pkcs12 \
  -in "$CERTIFICATE" \
  -nocerts \
  -noout \
  -passin env:P12_PASSWORD \
  >/dev/null 2>&1 \
  || die ".p12 does not contain a usable private key."

CERT_SUBJECT="$(openssl x509 -in "$CERT_PEM" -noout -subject -nameopt RFC2253 | sed 's/^subject=//')"
CERT_ISSUER="$(openssl x509 -in "$CERT_PEM" -noout -issuer -nameopt RFC2253 | sed 's/^issuer=//')"
CERT_SERIAL="$(openssl x509 -in "$CERT_PEM" -noout -serial | cut -d= -f2-)"
CERT_NOT_BEFORE="$(openssl x509 -in "$CERT_PEM" -noout -startdate | cut -d= -f2-)"
CERT_NOT_AFTER="$(openssl x509 -in "$CERT_PEM" -noout -enddate | cut -d= -f2-)"
CERT_FINGERPRINT="$(openssl x509 -in "$CERT_PEM" -noout -fingerprint -sha256 | cut -d= -f2-)"
openssl x509 -in "$CERT_PEM" -checkend 86400 -noout >/dev/null \
  || die "Distribution certificate expires within 24 hours."
grep -q "Apple Distribution" <<<"$CERT_SUBJECT" \
  || die "The .p12 certificate is not an Apple Distribution certificate."
grep -q "$TEAM_ID" <<<"$CERT_SUBJECT" \
  || die "Distribution certificate subject does not contain the expected Team ID."

security cms -D -i "$PROFILE" > "$PROFILE_PLIST" \
  || die "Provisioning profile could not be decoded."

PROFILE_UUID="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$PROFILE_PLIST")"
PROFILE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$PROFILE_PLIST")"
PROFILE_TEAM_ID="$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' "$PROFILE_PLIST")"
PROFILE_APP_IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' "$PROFILE_PLIST")"
PROFILE_GET_TASK_ALLOW="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:get-task-allow' "$PROFILE_PLIST" 2>/dev/null || true)"
PROFILE_EXPIRATION="$(/usr/libexec/PlistBuddy -c 'Print :ExpirationDate' "$PROFILE_PLIST")"
PROFILE_PLATFORM="$(/usr/libexec/PlistBuddy -c 'Print :Platform:0' "$PROFILE_PLIST" 2>/dev/null || true)"
PROFILE_BETA_REPORTS_ACTIVE="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:beta-reports-active' "$PROFILE_PLIST" 2>/dev/null || true)"
PROFILE_PROVISIONS_ALL_DEVICES="$(/usr/libexec/PlistBuddy -c 'Print :ProvisionsAllDevices' "$PROFILE_PLIST" 2>/dev/null || true)"
PROFILE_PROVISIONED_DEVICES="$(/usr/libexec/PlistBuddy -c 'Print :ProvisionedDevices:0' "$PROFILE_PLIST" 2>/dev/null || true)"

[[ "$PROFILE_TEAM_ID" == "$TEAM_ID" ]] || die "Provisioning profile Team ID mismatch."
[[ "$PROFILE_APP_IDENTIFIER" == "$TEAM_ID.$BUNDLE_ID" ]] \
  || die "Provisioning profile application-identifier mismatch."
[[ "$PROFILE_GET_TASK_ALLOW" != "true" ]] \
  || die "Development provisioning profile detected; App Store Connect distribution profile required."
[[ -z "$PROFILE_PROVISIONS_ALL_DEVICES" || "$PROFILE_PROVISIONS_ALL_DEVICES" == "false" ]] \
  || die "Enterprise/In-House profile detected; App Store Connect profile required."
[[ -z "$PROFILE_PROVISIONED_DEVICES" ]] \
  || die "Ad Hoc or Development profile detected; App Store Connect profile must not contain devices."
[[ "$PROFILE_BETA_REPORTS_ACTIVE" == "true" ]] \
  || die "Profile does not have beta-reports-active=true; wrong distribution profile type is likely."
[[ "$PROFILE_PLATFORM" == "iOS" ]] \
  || die "Provisioning profile platform must be iOS."

python3 - "$PROFILE_PLIST" <<'PY'
import datetime as dt
import plistlib
import sys

with open(sys.argv[1], "rb") as handle:
    profile = plistlib.load(handle)

expiration = profile["ExpirationDate"]
now = dt.datetime.now(dt.timezone.utc)
if expiration.tzinfo is None:
    expiration = expiration.replace(tzinfo=dt.timezone.utc)
if expiration <= now + dt.timedelta(days=1):
    raise SystemExit("ERROR: Provisioning profile expires within 24 hours.")
PY

FIRST_LINE="$(head -n1 "$API_KEY" | tr -d '\r')"
LAST_LINE="$(tail -n1 "$API_KEY" | tr -d '\r')"
[[ "$FIRST_LINE" == "-----BEGIN PRIVATE KEY-----" ]] \
  || die ".p8 does not start with BEGIN PRIVATE KEY."
[[ "$LAST_LINE" == "-----END PRIVATE KEY-----" ]] \
  || die ".p8 does not end with END PRIVATE KEY."

openssl pkey -in "$API_KEY" -check -noout >/dev/null 2>&1 \
  || die ".p8 private key is not structurally valid."

CERT_FILE_SHA256="$(shasum -a 256 "$CERTIFICATE" | awk '{print $1}')"
PROFILE_FILE_SHA256="$(shasum -a 256 "$PROFILE" | awk '{print $1}')"
API_KEY_FILE_SHA256="$(shasum -a 256 "$API_KEY" | awk '{print $1}')"

python3 - "$REPORT_PATH" <<PY
import json
from pathlib import Path

report = {
    "app": "AI引継ぎ帳",
    "bundle_id": "$BUNDLE_ID",
    "team_id": "$TEAM_ID",
    "certificate": {
        "type": "Apple Distribution",
        "subject": "$CERT_SUBJECT",
        "issuer": "$CERT_ISSUER",
        "serial": "$CERT_SERIAL",
        "not_before": "$CERT_NOT_BEFORE",
        "not_after": "$CERT_NOT_AFTER",
        "sha256_fingerprint": "$CERT_FINGERPRINT",
        "file_sha256": "$CERT_FILE_SHA256",
        "private_key_present": True,
    },
    "provisioning_profile": {
        "name": "$PROFILE_NAME",
        "uuid": "$PROFILE_UUID",
        "team_id": "$PROFILE_TEAM_ID",
        "application_identifier": "$PROFILE_APP_IDENTIFIER",
        "platform": "$PROFILE_PLATFORM",
        "expiration": "$PROFILE_EXPIRATION",
        "get_task_allow": "$PROFILE_GET_TASK_ALLOW",
        "beta_reports_active": "$PROFILE_BETA_REPORTS_ACTIVE",
        "file_sha256": "$PROFILE_FILE_SHA256",
    },
    "app_store_connect_api_key": {
        "key_id": "$KEY_ID",
        "issuer_id": "$ISSUER_ID",
        "filename": "$(basename "$API_KEY")",
        "file_sha256": "$API_KEY_FILE_SHA256",
        "private_key_structure_valid": True,
    },
    "validation": {
        "certificate_matches_team": True,
        "profile_matches_team_and_bundle": True,
        "profile_is_app_store_distribution": True,
        "api_key_structure_valid": True,
        "credentials_uploaded": False,
        "result": "PASS",
    },
}
path = Path("$REPORT_PATH")
path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"Validation report: {path.resolve()}")
PY

unset P12_PASSWORD

cat <<EOF

APPLE_SIGNING_ASSETS_VALIDATION_PASS
Bundle ID: $BUNDLE_ID
Team ID: $TEAM_ID
Certificate fingerprint: $CERT_FINGERPRINT
Provisioning profile: $PROFILE_NAME
Provisioning UUID: $PROFILE_UUID
Profile expiration: $PROFILE_EXPIRATION
API Key ID: $KEY_ID
Issuer ID: $ISSUER_ID

The report contains no certificate password or private key contents.
Do not upload the credential files themselves.
EOF
