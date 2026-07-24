#!/usr/bin/env bash
set -Eeuo pipefail

EXPECTED_BUNDLE_ID="jp.allsunday.aihandoverlog"
EXPECTED_VERSION="0.6.0"
EXPECTED_BUILD="6"

CERTIFICATE=""
PROFILE=""
API_KEY=""
TEAM_ID=""
KEY_ID=""
ISSUER_ID=""
REPORT_PATH="${REPORT_PATH:-Apple_Signing_Assets_Verification.json}"

usage() {
  cat <<'EOF'
AI引継ぎ帳 Apple署名資産検証

Usage:
  ./verify_apple_signing_assets_macos.sh \
    --certificate /path/to/AppleDistribution.p12 \
    --profile /path/to/AppStore.mobileprovision \
    --api-key /path/to/AuthKey_XXXXXXXXXX.p8 \
    --team-id ABCDEFGHIJ \
    --key-id KLMNOPQRST \
    --issuer-id 00000000-0000-0000-0000-000000000000 \
    [--report /path/to/report.json]

This script:
- prompts for the .p12 password without echoing it;
- verifies certificate/private-key pairing in a temporary keychain;
- verifies the provisioning profile Team ID, Bundle ID, distribution type,
  expiration, and selected certificate fingerprint;
- verifies the App Store Connect .p8 private key format;
- writes a non-secret JSON report.

It does not upload, sign, or store credentials.
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
    --report) REPORT_PATH="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

[[ "$(uname -s)" == "Darwin" ]] || die "Run this script on macOS."
need security
need openssl
need plutil
need python3
need /usr/libexec/PlistBuddy

[[ -f "$CERTIFICATE" ]] || die "Apple Distribution .p12 not found."
[[ -f "$PROFILE" ]] || die "Provisioning profile not found."
[[ -f "$API_KEY" ]] || die "App Store Connect API .p8 not found."
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || die "Team ID must be 10 alphanumeric characters."
[[ "$KEY_ID" =~ ^[A-Z0-9]{10}$ ]] || die "API Key ID must be 10 alphanumeric characters."
[[ "$ISSUER_ID" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] \
  || die "Issuer ID must be a UUID."

read -r -s -p "Enter the .p12 export password: " P12_PASSWORD
printf '\n'
[[ -n "$P12_PASSWORD" ]] || die ".p12 password is required."

WORK_DIR="$(mktemp -d)"
KEYCHAIN_PATH="$WORK_DIR/verification.keychain-db"
KEYCHAIN_PASSWORD="$(openssl rand -base64 36 | tr -d '\n')"
PROFILE_PLIST="$WORK_DIR/profile.plist"
CERT_PEM="$WORK_DIR/distribution-cert.pem"
P12_INFO="$WORK_DIR/p12-info.txt"

cleanup() {
  set +e
  security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1
  rm -rf "$WORK_DIR"
  unset P12_PASSWORD KEYCHAIN_PASSWORD
}
trap cleanup EXIT

printf 'Validating .p12 structure...\n'
openssl pkcs12 \
  -in "$CERTIFICATE" \
  -passin "pass:$P12_PASSWORD" \
  -info -noout \
  >"$P12_INFO" 2>&1 \
  || die "The .p12 could not be opened with the supplied password."

openssl pkcs12 \
  -in "$CERTIFICATE" \
  -passin "pass:$P12_PASSWORD" \
  -clcerts -nokeys \
  -out "$CERT_PEM" \
  >/dev/null 2>&1 \
  || die "No certificate could be extracted from the .p12."

CERT_SUBJECT="$(openssl x509 -in "$CERT_PEM" -noout -subject | sed 's/^subject=//')"
CERT_ISSUER="$(openssl x509 -in "$CERT_PEM" -noout -issuer | sed 's/^issuer=//')"
CERT_NOT_BEFORE="$(openssl x509 -in "$CERT_PEM" -noout -startdate | cut -d= -f2-)"
CERT_NOT_AFTER="$(openssl x509 -in "$CERT_PEM" -noout -enddate | cut -d= -f2-)"
CERT_SHA1="$(openssl x509 -in "$CERT_PEM" -noout -fingerprint -sha1 | cut -d= -f2 | tr -d ':')"
CERT_SHA256="$(openssl x509 -in "$CERT_PEM" -noout -fingerprint -sha256 | cut -d= -f2 | tr -d ':')"

openssl x509 -in "$CERT_PEM" -checkend 0 -noout \
  || die "The Apple Distribution certificate is expired."

echo "$CERT_SUBJECT" | grep -q "Apple Distribution" \
  || die "The .p12 certificate is not an Apple Distribution certificate."

printf 'Validating certificate/private-key pairing...\n'
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null
security set-keychain-settings -lut 3600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$CERTIFICATE" \
  -P "$P12_PASSWORD" \
  -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH" >/dev/null
security set-key-partition-list \
  -S apple-tool:,apple: \
  -k "$KEYCHAIN_PASSWORD" \
  "$KEYCHAIN_PATH" >/dev/null

IDENTITY_OUTPUT="$(security find-identity -v -p codesigning "$KEYCHAIN_PATH")"
IDENTITY_COUNT="$(printf '%s\n' "$IDENTITY_OUTPUT" | grep -c '"Apple Distribution:' || true)"
(( IDENTITY_COUNT >= 1 )) \
  || die "The .p12 does not contain a usable Apple Distribution certificate/private-key identity."

printf 'Validating provisioning profile...\n'
security cms -D -i "$PROFILE" > "$PROFILE_PLIST" \
  || die "The provisioning profile could not be decoded."
plutil -lint "$PROFILE_PLIST" >/dev/null

PROFILE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$PROFILE_PLIST")"
PROFILE_UUID="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$PROFILE_PLIST")"
PROFILE_TEAM_ID="$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' "$PROFILE_PLIST")"
PROFILE_APP_IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' "$PROFILE_PLIST")"
PROFILE_GET_TASK_ALLOW="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:get-task-allow' "$PROFILE_PLIST" 2>/dev/null || true)"
PROFILE_EXPIRATION="$(/usr/libexec/PlistBuddy -c 'Print :ExpirationDate' "$PROFILE_PLIST")"
PROFILE_PROVISIONS_ALL_DEVICES="$(/usr/libexec/PlistBuddy -c 'Print :ProvisionsAllDevices' "$PROFILE_PLIST" 2>/dev/null || true)"
PROFILE_PROVISIONED_DEVICES="$(/usr/libexec/PlistBuddy -c 'Print :ProvisionedDevices' "$PROFILE_PLIST" 2>/dev/null || true)"

[[ "$PROFILE_TEAM_ID" == "$TEAM_ID" ]] \
  || die "Provisioning profile Team ID does not match."
[[ "$PROFILE_APP_IDENTIFIER" == "$TEAM_ID.$EXPECTED_BUNDLE_ID" ]] \
  || die "Provisioning profile Bundle ID does not match."
[[ "$PROFILE_GET_TASK_ALLOW" != "true" ]] \
  || die "A development profile was supplied; App Store Connect distribution profile required."
[[ -z "$PROFILE_PROVISIONS_ALL_DEVICES" ]] \
  || die "An enterprise profile was supplied; App Store Connect distribution profile required."
[[ -z "$PROFILE_PROVISIONED_DEVICES" ]] \
  || die "An Ad Hoc/development profile was supplied; App Store Connect distribution profile required."

python3 - "$PROFILE_PLIST" <<'PY'
from datetime import datetime, timezone
import plistlib
import sys

with open(sys.argv[1], "rb") as handle:
    profile = plistlib.load(handle)
expiration = profile["ExpirationDate"]
if expiration.tzinfo is None:
    expiration = expiration.replace(tzinfo=timezone.utc)
if expiration <= datetime.now(timezone.utc):
    raise SystemExit("ERROR: Provisioning profile is expired.")
PY

PROFILE_CERT_SHA1="$(
  python3 - "$PROFILE_PLIST" "$WORK_DIR" <<'PY'
import hashlib
import plistlib
import sys
from pathlib import Path

profile_path = Path(sys.argv[1])
work_dir = Path(sys.argv[2])
with profile_path.open("rb") as handle:
    profile = plistlib.load(handle)
certificates = profile.get("DeveloperCertificates", [])
if len(certificates) != 1:
    raise SystemExit(
        f"ERROR: Expected one distribution certificate in profile; found {len(certificates)}."
    )
der = certificates[0]
(work_dir / "profile-cert.der").write_bytes(der)
print(hashlib.sha1(der).hexdigest().upper())
PY
)"

[[ "$PROFILE_CERT_SHA1" == "$CERT_SHA1" ]] \
  || die "The provisioning profile does not contain the supplied Apple Distribution certificate."

printf 'Validating App Store Connect API private key...\n'
grep -q "BEGIN PRIVATE KEY" "$API_KEY" \
  || die "The API key does not contain BEGIN PRIVATE KEY."
openssl pkey -in "$API_KEY" -check -noout >/dev/null 2>&1 \
  || die "The App Store Connect .p8 is not a valid private key."

API_KEY_ALGORITHM="$(
  openssl pkey -in "$API_KEY" -text -noout 2>/dev/null \
    | awk 'NR==1 {print $0}'
)"
API_KEY_SHA256="$(shasum -a 256 "$API_KEY" | awk '{print $1}')"

REPORT_PATH="$(python3 - "$REPORT_PATH" <<'PY'
from pathlib import Path
import sys
print(Path(sys.argv[1]).expanduser().resolve())
PY
)"
mkdir -p "$(dirname "$REPORT_PATH")"

export REPORT_PATH EXPECTED_BUNDLE_ID EXPECTED_VERSION EXPECTED_BUILD
export TEAM_ID KEY_ID ISSUER_ID
export CERT_SUBJECT CERT_ISSUER CERT_NOT_BEFORE CERT_NOT_AFTER CERT_SHA1 CERT_SHA256
export PROFILE_NAME PROFILE_UUID PROFILE_TEAM_ID PROFILE_APP_IDENTIFIER PROFILE_EXPIRATION PROFILE_CERT_SHA1
export API_KEY_ALGORITHM API_KEY_SHA256

python3 <<'PY'
import json
import os
from pathlib import Path

report = {
    "app": "AI引継ぎ帳",
    "bundle_id": os.environ["EXPECTED_BUNDLE_ID"],
    "version": os.environ["EXPECTED_VERSION"],
    "build": os.environ["EXPECTED_BUILD"],
    "team_id": os.environ["TEAM_ID"],
    "distribution_certificate": {
        "subject": os.environ["CERT_SUBJECT"],
        "issuer": os.environ["CERT_ISSUER"],
        "not_before": os.environ["CERT_NOT_BEFORE"],
        "not_after": os.environ["CERT_NOT_AFTER"],
        "sha1_fingerprint": os.environ["CERT_SHA1"],
        "sha256_fingerprint": os.environ["CERT_SHA256"],
        "private_key_pair_verified": True,
        "expired": False,
    },
    "provisioning_profile": {
        "name": os.environ["PROFILE_NAME"],
        "uuid": os.environ["PROFILE_UUID"],
        "team_id": os.environ["PROFILE_TEAM_ID"],
        "application_identifier": os.environ["PROFILE_APP_IDENTIFIER"],
        "expiration": os.environ["PROFILE_EXPIRATION"],
        "distribution_certificate_sha1": os.environ["PROFILE_CERT_SHA1"],
        "development_profile": False,
        "ad_hoc_profile": False,
        "enterprise_profile": False,
    },
    "app_store_connect_api_key": {
        "key_id": os.environ["KEY_ID"],
        "issuer_id": os.environ["ISSUER_ID"],
        "private_key_valid": True,
        "private_key_format_summary": os.environ["API_KEY_ALGORITHM"],
        "sha256": os.environ["API_KEY_SHA256"],
        "private_key_content_in_report": False,
    },
    "ready_for_github_environment_secret_registration": True,
    "ready_for_signing": True,
}
Path(os.environ["REPORT_PATH"]).write_text(
    json.dumps(report, ensure_ascii=False, indent=2),
    encoding="utf-8",
)
PY

printf '\nAPPLE_SIGNING_ASSETS_VERIFIED\n'
printf 'Bundle ID: %s\n' "$EXPECTED_BUNDLE_ID"
printf 'Team ID: %s\n' "$TEAM_ID"
printf 'Certificate expires: %s\n' "$CERT_NOT_AFTER"
printf 'Profile: %s\n' "$PROFILE_NAME"
printf 'Profile expires: %s\n' "$PROFILE_EXPIRATION"
printf 'API Key ID: %s\n' "$KEY_ID"
printf 'Non-secret report: %s\n' "$REPORT_PATH"
