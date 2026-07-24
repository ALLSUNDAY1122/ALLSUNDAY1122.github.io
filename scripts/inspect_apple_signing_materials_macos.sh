#!/usr/bin/env bash
set -Eeuo pipefail

BUNDLE_ID="jp.allsunday.aihandoverlog"
TEAM_ID=""
KEY_ID=""
ISSUER_ID=""
CERTIFICATE=""
PROFILE=""
API_KEY=""
OUTPUT_DIR="${OUTPUT_DIR:-$(pwd)/apple_signing_validation}"

usage() {
  cat <<'EOF'
AI引継ぎ帳 Apple署名素材検査

Usage:
  ./inspect_apple_signing_materials_macos.sh \
    --certificate /path/to/AppleDistribution.p12 \
    --profile /path/to/AppStore.mobileprovision \
    --api-key /path/to/AuthKey_XXXXXXXXXX.p8 \
    --team-id ABCDEFGHIJ \
    --key-id KLMNOPQRST \
    --issuer-id 00000000-0000-0000-0000-000000000000

Options:
  --bundle-id ID       Default: jp.allsunday.aihandoverlog
  --output-dir PATH    Non-secret report output directory
  -h, --help           Show help

The .p12 password is requested securely and is never written to disk or logs.
No certificate, profile, API private key, password, or Base64 secret is copied
to the output directory.
EOF
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --certificate) CERTIFICATE="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --api-key) API_KEY="$2"; shift 2 ;;
    --team-id) TEAM_ID="$2"; shift 2 ;;
    --key-id) KEY_ID="$2"; shift 2 ;;
    --issuer-id) ISSUER_ID="$2"; shift 2 ;;
    --bundle-id) BUNDLE_ID="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

[[ "$(uname -s)" == "Darwin" ]] || die "This script must run on macOS."
need security
need openssl
need python3
need plutil
need shasum
need /usr/libexec/PlistBuddy

[[ -f "$CERTIFICATE" ]] || die "Certificate .p12 not found."
[[ -f "$PROFILE" ]] || die "Provisioning profile not found."
[[ -f "$API_KEY" ]] || die "API .p8 key not found."
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || die "Team ID must be 10 uppercase letters or digits."
[[ "$KEY_ID" =~ ^[A-Z0-9]{10}$ ]] || die "API Key ID must be 10 uppercase letters or digits."
[[ "$ISSUER_ID" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]] \
  || die "Issuer ID must be a UUID."
[[ "$BUNDLE_ID" == "jp.allsunday.aihandoverlog" ]] \
  || die "Unexpected Bundle ID: $BUNDLE_ID"

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
WORK_DIR="$(mktemp -d)"
KEYCHAIN_PATH="$WORK_DIR/validation.keychain-db"
PROFILE_PLIST="$WORK_DIR/profile.plist"
CERT_PEM="$WORK_DIR/distribution.pem"
CERT_DER="$WORK_DIR/distribution.der"
API_PUBLIC_KEY="$WORK_DIR/api-public.pem"
REPORT_JSON="$OUTPUT_DIR/AI_Handover_Log_Apple_Signing_Materials_Validation.json"
REPORT_TXT="$OUTPUT_DIR/AI_Handover_Log_Apple_Signing_Materials_Validation.txt"

cleanup() {
  set +e
  security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1
  rm -rf "$WORK_DIR"
  unset P12_PASSWORD KEYCHAIN_PASSWORD
}
trap cleanup EXIT

read -r -s -p "Enter the .p12 export password: " P12_PASSWORD
printf '\n'
[[ -n "$P12_PASSWORD" ]] || die ".p12 password is required."
KEYCHAIN_PASSWORD="$(openssl rand -base64 36 | tr -d '\n')"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null
security set-keychain-settings -lut 1800 "$KEYCHAIN_PATH" >/dev/null
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null

if ! security import "$CERTIFICATE" \
  -P "$P12_PASSWORD" \
  -A -t cert -f pkcs12 \
  -k "$KEYCHAIN_PATH" >/dev/null 2>&1; then
  die "Could not import .p12. Check the export password and file."
fi

IDENTITIES="$(security find-identity -v -p codesigning "$KEYCHAIN_PATH" 2>/dev/null || true)"
IDENTITY_COUNT="$(printf '%s\n' "$IDENTITIES" | grep -c '"Apple Distribution:' || true)"
[[ "$IDENTITY_COUNT" -eq 1 ]] \
  || die "Exactly one Apple Distribution signing identity is required; found $IDENTITY_COUNT."

security find-certificate -a -c "Apple Distribution" -p "$KEYCHAIN_PATH" > "$CERT_PEM"
grep -q "BEGIN CERTIFICATE" "$CERT_PEM" || die "Apple Distribution certificate was not exported."
openssl x509 -in "$CERT_PEM" -outform DER -out "$CERT_DER"

CERT_SUBJECT="$(openssl x509 -in "$CERT_PEM" -noout -subject | sed 's/^subject=//')"
CERT_ISSUER="$(openssl x509 -in "$CERT_PEM" -noout -issuer | sed 's/^issuer=//')"
CERT_SERIAL="$(openssl x509 -in "$CERT_PEM" -noout -serial | cut -d= -f2-)"
CERT_NOT_BEFORE="$(openssl x509 -in "$CERT_PEM" -noout -startdate | cut -d= -f2-)"
CERT_NOT_AFTER="$(openssl x509 -in "$CERT_PEM" -noout -enddate | cut -d= -f2-)"
CERT_SHA256="$(openssl x509 -in "$CERT_PEM" -noout -fingerprint -sha256 | cut -d= -f2 | tr -d ':')"

openssl x509 -in "$CERT_PEM" -checkend 0 -noout >/dev/null \
  || die "Apple Distribution certificate is expired."

security cms -D -i "$PROFILE" > "$PROFILE_PLIST" \
  || die "Could not decode provisioning profile."
plutil -lint "$PROFILE_PLIST" >/dev/null

PROFILE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$PROFILE_PLIST")"
PROFILE_UUID="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$PROFILE_PLIST")"
PROFILE_TEAM_ID="$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' "$PROFILE_PLIST")"
PROFILE_APP_IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' "$PROFILE_PLIST")"
PROFILE_BUNDLE_ID="${PROFILE_APP_IDENTIFIER#"$PROFILE_TEAM_ID."}"
PROFILE_EXPIRATION="$(/usr/libexec/PlistBuddy -c 'Print :ExpirationDate' "$PROFILE_PLIST")"
PROFILE_GET_TASK_ALLOW="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:get-task-allow' "$PROFILE_PLIST" 2>/dev/null || true)"
PROFILE_BETA_REPORTS="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:beta-reports-active' "$PROFILE_PLIST" 2>/dev/null || true)"
PROFILE_APS_ENVIRONMENT="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:aps-environment' "$PROFILE_PLIST" 2>/dev/null || true)"

[[ "$PROFILE_TEAM_ID" == "$TEAM_ID" ]] \
  || die "Provisioning profile Team ID mismatch."
[[ "$PROFILE_BUNDLE_ID" == "$BUNDLE_ID" ]] \
  || die "Provisioning profile Bundle ID mismatch."
[[ "$PROFILE_GET_TASK_ALLOW" != "true" ]] \
  || die "Development provisioning profile detected; App Store Connect profile required."
[[ "$PROFILE_APS_ENVIRONMENT" == "" ]] \
  || die "Unexpected push notification entitlement found."

if /usr/libexec/PlistBuddy -c 'Print :ProvisionedDevices' "$PROFILE_PLIST" >/dev/null 2>&1; then
  die "ProvisionedDevices is present; this is not an App Store Connect distribution profile."
fi
if /usr/libexec/PlistBuddy -c 'Print :ProvisionsAllDevices' "$PROFILE_PLIST" >/dev/null 2>&1; then
  die "ProvisionsAllDevices is present; enterprise profile detected."
fi

python3 - "$PROFILE_PLIST" "$CERT_DER" <<'PY'
import hashlib
import plistlib
import sys
from pathlib import Path

profile_path = Path(sys.argv[1])
certificate_path = Path(sys.argv[2])
with profile_path.open("rb") as handle:
    profile = plistlib.load(handle)

actual = hashlib.sha256(certificate_path.read_bytes()).hexdigest()
allowed = {
    hashlib.sha256(bytes(item)).hexdigest()
    for item in profile.get("DeveloperCertificates", [])
}
if actual not in allowed:
    raise SystemExit(
        "ERROR: The Apple Distribution certificate is not included in the provisioning profile."
    )

expiration = profile["ExpirationDate"]
if expiration.timestamp() <= __import__("time").time():
    raise SystemExit("ERROR: Provisioning profile is expired.")
PY

grep -q "BEGIN PRIVATE KEY" "$API_KEY" \
  || die "API key does not contain BEGIN PRIVATE KEY."
openssl pkey -in "$API_KEY" -check -noout >/dev/null 2>&1 \
  || die "API .p8 private key could not be parsed."
openssl pkey -in "$API_KEY" -pubout -out "$API_PUBLIC_KEY" >/dev/null 2>&1
API_PUBLIC_SHA256="$(openssl pkey -pubin -in "$API_PUBLIC_KEY" -outform DER 2>/dev/null | shasum -a 256 | awk '{print $1}')"
API_KEY_FILENAME="$(basename "$API_KEY")"
if [[ "$API_KEY_FILENAME" =~ ^AuthKey_([A-Z0-9]{10})\.p8$ ]]; then
  [[ "${BASH_REMATCH[1]}" == "$KEY_ID" ]] \
    || die "API key filename Key ID does not match --key-id."
fi

python3 - \
  "$REPORT_JSON" \
  "$REPORT_TXT" \
  "$BUNDLE_ID" \
  "$TEAM_ID" \
  "$CERT_SUBJECT" \
  "$CERT_ISSUER" \
  "$CERT_SERIAL" \
  "$CERT_NOT_BEFORE" \
  "$CERT_NOT_AFTER" \
  "$CERT_SHA256" \
  "$PROFILE_NAME" \
  "$PROFILE_UUID" \
  "$PROFILE_TEAM_ID" \
  "$PROFILE_BUNDLE_ID" \
  "$PROFILE_EXPIRATION" \
  "$PROFILE_GET_TASK_ALLOW" \
  "$PROFILE_BETA_REPORTS" \
  "$KEY_ID" \
  "$ISSUER_ID" \
  "$API_PUBLIC_SHA256" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

(
    report_json,
    report_txt,
    bundle_id,
    team_id,
    cert_subject,
    cert_issuer,
    cert_serial,
    cert_not_before,
    cert_not_after,
    cert_sha256,
    profile_name,
    profile_uuid,
    profile_team_id,
    profile_bundle_id,
    profile_expiration,
    profile_get_task_allow,
    profile_beta_reports,
    key_id,
    issuer_id,
    api_public_sha256,
) = sys.argv[1:]

report = {
    "app": "AI引継ぎ帳",
    "bundle_id": bundle_id,
    "validated_at": datetime.now(timezone.utc).isoformat(),
    "result": "passed",
    "certificate": {
        "type": "Apple Distribution",
        "subject": cert_subject,
        "issuer": cert_issuer,
        "serial_number": cert_serial,
        "not_before": cert_not_before,
        "not_after": cert_not_after,
        "sha256_fingerprint": cert_sha256,
        "private_key_included_in_p12": True,
    },
    "provisioning_profile": {
        "name": profile_name,
        "uuid": profile_uuid,
        "team_id": profile_team_id,
        "bundle_id": profile_bundle_id,
        "expiration": profile_expiration,
        "get_task_allow": profile_get_task_allow.lower() == "true",
        "beta_reports_active": profile_beta_reports.lower() == "true",
        "contains_distribution_certificate": True,
        "provisioned_devices_present": False,
        "enterprise_profile": False,
    },
    "app_store_connect_api_key": {
        "key_id": key_id,
        "issuer_id": issuer_id,
        "private_key_format": "PKCS8 PEM",
        "public_key_sha256": api_public_sha256,
        "online_authentication_tested": False,
    },
    "security": {
        "secret_files_copied_to_report": False,
        "p12_password_stored": False,
        "private_key_content_stored": False,
    },
}
Path(report_json).write_text(
    json.dumps(report, ensure_ascii=False, indent=2),
    encoding="utf-8",
)

lines = [
    "AI引継ぎ帳 Apple署名素材検査: PASSED",
    f"Bundle ID: {bundle_id}",
    f"Team ID: {team_id}",
    f"Certificate expiration: {cert_not_after}",
    f"Certificate SHA-256: {cert_sha256}",
    f"Profile name: {profile_name}",
    f"Profile UUID: {profile_uuid}",
    f"Profile expiration: {profile_expiration}",
    f"API Key ID: {key_id}",
    f"API Issuer ID: {issuer_id}",
    f"API public key SHA-256: {api_public_sha256}",
    "API online authentication: not tested",
    "Secrets stored in report: no",
]
Path(report_txt).write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

printf '\nVALIDATION_PASSED\n'
printf 'Non-secret JSON: %s\n' "$REPORT_JSON"
printf 'Non-secret summary: %s\n' "$REPORT_TXT"
