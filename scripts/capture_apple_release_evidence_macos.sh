#!/usr/bin/env bash
set -Eeuo pipefail

BUNDLE_ID="jp.allsunday.aihandoverlog"
APP_NAME="AI引継ぎ帳"

P12_PATH=""
PROFILE_PATH=""
API_KEY_PATH=""
TEAM_ID=""
KEY_ID=""
ISSUER_ID=""
APP_STORE_APP_ID=""
OUTPUT_DIR="${OUTPUT_DIR:-$PWD/apple_release_evidence}"

usage() {
  cat <<'EOF'
Create a sanitized Apple release evidence report.

Usage:
  ./capture_apple_release_evidence_macos.sh \
    --p12 /secure/AppleDistribution.p12 \
    --profile /secure/AI_Handover_Log_AppStore.mobileprovision \
    --api-key /secure/AuthKey_XXXXXXXXXX.p8 \
    --team-id ABCDEFGHIJ \
    --key-id KLMNOPQRST \
    --issuer-id 00000000-0000-0000-0000-000000000000 \
    [--app-store-app-id 1234567890] \
    [--output /secure/evidence]

The script prompts for the .p12 password without echoing it.
It never writes the password, private key, certificate body, profile body,
or API key body to the report.
EOF
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --p12) P12_PATH="$2"; shift 2 ;;
    --profile) PROFILE_PATH="$2"; shift 2 ;;
    --api-key) API_KEY_PATH="$2"; shift 2 ;;
    --team-id) TEAM_ID="$2"; shift 2 ;;
    --key-id) KEY_ID="$2"; shift 2 ;;
    --issuer-id) ISSUER_ID="$2"; shift 2 ;;
    --app-store-app-id) APP_STORE_APP_ID="$2"; shift 2 ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

need security
need openssl
need shasum
need python3
need /usr/libexec/PlistBuddy

[[ "$(uname -s)" == "Darwin" ]] || die "This script must run on macOS."
[[ -f "$P12_PATH" ]] || die "Apple Distribution .p12 not found."
[[ -f "$PROFILE_PATH" ]] || die "App Store Connect provisioning profile not found."
[[ -f "$API_KEY_PATH" ]] || die "App Store Connect .p8 key not found."
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || die "Team ID must be 10 uppercase letters or digits."
[[ "$KEY_ID" =~ ^[A-Z0-9]{10}$ ]] || die "API Key ID must be 10 uppercase letters or digits."
[[ "$ISSUER_ID" =~ ^[0-9a-fA-F-]{36}$ ]] || die "Issuer ID format is invalid."
if [[ -n "$APP_STORE_APP_ID" ]]; then
  [[ "$APP_STORE_APP_ID" =~ ^[0-9]+$ ]] || die "App Store App ID must be numeric."
fi

API_KEY_BASENAME="$(basename "$API_KEY_PATH")"
[[ "$API_KEY_BASENAME" == "AuthKey_${KEY_ID}.p8" ]] || \
  die "API key filename must be AuthKey_${KEY_ID}.p8."
grep -q "BEGIN PRIVATE KEY" "$API_KEY_PATH" || \
  die "The .p8 file does not contain an expected private-key header."

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
TEMP_DIR="$(mktemp -d)"
trap 'unset P12_PASSWORD; rm -rf "$TEMP_DIR"' EXIT

read -r -s -p "Enter the .p12 export password: " P12_PASSWORD
printf '\n'
[[ -n "$P12_PASSWORD" ]] || die ".p12 password is required."

CERT_PEM="$TEMP_DIR/distribution-cert.pem"
PROFILE_PLIST="$TEMP_DIR/profile.plist"

openssl pkcs12 \
  -in "$P12_PATH" \
  -clcerts -nokeys \
  -out "$CERT_PEM" \
  -passin fd:3 \
  3<<<"$P12_PASSWORD" >/dev/null 2>&1 || die "Could not open .p12."

grep -q "BEGIN CERTIFICATE" "$CERT_PEM" || die "No certificate found in .p12."

CERT_SUBJECT="$(openssl x509 -in "$CERT_PEM" -noout -subject | sed 's/^subject=//')"
CERT_ISSUER="$(openssl x509 -in "$CERT_PEM" -noout -issuer | sed 's/^issuer=//')"
CERT_SERIAL="$(openssl x509 -in "$CERT_PEM" -noout -serial | cut -d= -f2-)"
CERT_START="$(openssl x509 -in "$CERT_PEM" -noout -startdate | cut -d= -f2-)"
CERT_END="$(openssl x509 -in "$CERT_PEM" -noout -enddate | cut -d= -f2-)"
CERT_SHA256="$(openssl x509 -in "$CERT_PEM" -noout -fingerprint -sha256 | cut -d= -f2- | tr -d ':')"
P12_SHA256="$(shasum -a 256 "$P12_PATH" | awk '{print $1}')"

echo "$CERT_SUBJECT" | grep -q "Apple Distribution" || \
  die "The .p12 certificate is not Apple Distribution."
openssl x509 -in "$CERT_PEM" -checkend 604800 -noout >/dev/null || \
  die "The Apple Distribution certificate expires within 7 days."

security cms -D -i "$PROFILE_PATH" > "$PROFILE_PLIST" || \
  die "Could not decode provisioning profile."

PROFILE_UUID="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$PROFILE_PLIST")"
PROFILE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$PROFILE_PLIST")"
PROFILE_TEAM_ID="$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' "$PROFILE_PLIST")"
PROFILE_APP_IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' "$PROFILE_PLIST")"
PROFILE_GET_TASK_ALLOW="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:get-task-allow' "$PROFILE_PLIST" 2>/dev/null || true)"
PROFILE_EXPIRATION="$(/usr/libexec/PlistBuddy -c 'Print :ExpirationDate' "$PROFILE_PLIST")"
PROFILE_CREATION="$(/usr/libexec/PlistBuddy -c 'Print :CreationDate' "$PROFILE_PLIST")"
PROFILE_PROVISIONS_ALL="$(/usr/libexec/PlistBuddy -c 'Print :ProvisionsAllDevices' "$PROFILE_PLIST" 2>/dev/null || true)"
PROFILE_DEVICE_COUNT="$(/usr/libexec/PlistBuddy -c 'Print :ProvisionedDevices' "$PROFILE_PLIST" 2>/dev/null | grep -c '^[[:space:]]*[A-Fa-f0-9-]\+$' || true)"
PROFILE_SHA256="$(shasum -a 256 "$PROFILE_PATH" | awk '{print $1}')"
API_KEY_SHA256="$(shasum -a 256 "$API_KEY_PATH" | awk '{print $1}')"

[[ "$PROFILE_TEAM_ID" == "$TEAM_ID" ]] || die "Provisioning profile Team ID mismatch."
[[ "$PROFILE_APP_IDENTIFIER" == "$TEAM_ID.$BUNDLE_ID" ]] || \
  die "Provisioning profile application-identifier mismatch."
[[ "$PROFILE_GET_TASK_ALLOW" != "true" ]] || \
  die "Development profile detected; App Store Connect profile required."
[[ "$PROFILE_PROVISIONS_ALL" != "true" ]] || \
  die "Enterprise/In-House profile detected."
[[ "$PROFILE_DEVICE_COUNT" == "0" ]] || \
  die "Ad Hoc or development profile detected because devices are listed."

REPORT_JSON="$OUTPUT_DIR/AI_Handover_Log_v0.6_Apple_Registration_Evidence.json"
REPORT_MD="$OUTPUT_DIR/AI引継ぎ帳_v0.6_Apple登録完了証跡.md"

export APP_NAME BUNDLE_ID TEAM_ID KEY_ID ISSUER_ID APP_STORE_APP_ID
export CERT_SUBJECT CERT_ISSUER CERT_SERIAL CERT_START CERT_END CERT_SHA256 P12_SHA256
export PROFILE_UUID PROFILE_NAME PROFILE_TEAM_ID PROFILE_APP_IDENTIFIER
export PROFILE_EXPIRATION PROFILE_CREATION PROFILE_SHA256 API_KEY_SHA256 API_KEY_BASENAME
export REPORT_JSON REPORT_MD

python3 - <<'PY'
import json
import os
from datetime import datetime, timezone
from pathlib import Path

data = {
    "app": os.environ["APP_NAME"],
    "bundle_id": os.environ["BUNDLE_ID"],
    "captured_at": datetime.now(timezone.utc).isoformat(),
    "apple_account": {
        "team_id": os.environ["TEAM_ID"],
        "app_store_app_id": os.environ.get("APP_STORE_APP_ID") or None,
        "app_id_registered": True,
        "app_store_record_created": bool(os.environ.get("APP_STORE_APP_ID")),
    },
    "distribution_certificate": {
        "type": "Apple Distribution",
        "subject": os.environ["CERT_SUBJECT"],
        "issuer": os.environ["CERT_ISSUER"],
        "serial": os.environ["CERT_SERIAL"],
        "not_before": os.environ["CERT_START"],
        "not_after": os.environ["CERT_END"],
        "certificate_sha256": os.environ["CERT_SHA256"],
        "p12_file_sha256": os.environ["P12_SHA256"],
        "private_key_exported_to_report": False,
        "password_exported_to_report": False,
    },
    "provisioning_profile": {
        "name": os.environ["PROFILE_NAME"],
        "uuid": os.environ["PROFILE_UUID"],
        "team_id": os.environ["PROFILE_TEAM_ID"],
        "application_identifier": os.environ["PROFILE_APP_IDENTIFIER"],
        "creation": os.environ["PROFILE_CREATION"],
        "expiration": os.environ["PROFILE_EXPIRATION"],
        "file_sha256": os.environ["PROFILE_SHA256"],
        "type_check": "App Store Connect distribution profile",
    },
    "app_store_connect_api_key": {
        "key_id": os.environ["KEY_ID"],
        "issuer_id": os.environ["ISSUER_ID"],
        "filename": os.environ["API_KEY_BASENAME"],
        "file_sha256": os.environ["API_KEY_SHA256"],
        "private_key_exported_to_report": False,
        "authentication_test": "not performed by evidence collector",
    },
    "release_gate": {
        "version": "0.6.0",
        "build": "6",
        "credentials_structurally_valid": True,
        "signed_archive_created": False,
        "testflight_uploaded": False,
    },
}
Path(os.environ["REPORT_JSON"]).write_text(
    json.dumps(data, ensure_ascii=False, indent=2),
    encoding="utf-8",
)

md = f"""# AI引継ぎ帳 v0.6 Apple登録完了証跡

- Bundle ID：`{data['bundle_id']}`
- Team ID：`{data['apple_account']['team_id']}`
- App Store App ID：`{data['apple_account']['app_store_app_id'] or '未記録'}`
- Apple Distribution証明書期限：`{data['distribution_certificate']['not_after']}`
- 証明書SHA-256：`{data['distribution_certificate']['certificate_sha256']}`
- Provisioning Profile：`{data['provisioning_profile']['name']}`
- Profile UUID：`{data['provisioning_profile']['uuid']}`
- Profile期限：`{data['provisioning_profile']['expiration']}`
- API Key ID：`{data['app_store_connect_api_key']['key_id']}`
- Issuer ID：`{data['app_store_connect_api_key']['issuer_id']}`

## 判定

`APPLE_REGISTRATION_EVIDENCE_VALID`

証明書、プロファイル、APIキーの構造とTeam ID／Bundle IDの一致を確認しました。

この証跡には、秘密鍵本文、p12パスワード、APIキー本文、Apple Account認証情報は含まれません。

## 未完了

- 署名付きArchive作成
- Xcode Privacy Report
- Validate App
- TestFlightアップロード
- iPhone 16受入テスト
"""
Path(os.environ["REPORT_MD"]).write_text(md, encoding="utf-8")
PY

if grep -R -E \
  'BEGIN (PRIVATE KEY|ENCRYPTED PRIVATE KEY|RSA PRIVATE KEY)|BEGIN CERTIFICATE|PRIVATE KEY-----' \
  "$REPORT_JSON" "$REPORT_MD"; then
  rm -f "$REPORT_JSON" "$REPORT_MD"
  die "Private material was detected in sanitized output."
fi

printf '\nAPPLE_REGISTRATION_EVIDENCE_VALID\n'
printf 'JSON: %s\n' "$REPORT_JSON"
printf 'Markdown: %s\n' "$REPORT_MD"
