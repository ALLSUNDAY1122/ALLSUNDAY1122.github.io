#!/usr/bin/env bash
set -Eeuo pipefail

BUNDLE_ID="jp.allsunday.aihandoverlog"
OUTPUT_JSON=""
P12_PATH=""
PROFILE_PATH=""
API_KEY_PATH=""
TEAM_ID=""
KEY_ID=""
ISSUER_ID=""

usage() {
  cat <<'EOF'
Validate Apple signing assets locally on macOS without uploading secrets.

Usage:
  ./validate_apple_signing_assets_macos.sh \
    --certificate /path/to/AppleDistribution.p12 \
    --profile /path/to/AppStore.mobileprovision \
    --api-key /path/to/AuthKey_XXXXXXXXXX.p8 \
    --team-id ABCDEFGHIJ \
    --key-id KLMNOPQRST \
    --issuer-id 00000000-0000-0000-0000-000000000000 \
    [--output-json /path/to/non-secret-summary.json]

The .p12 password is requested with hidden input.
No secret value is printed or written to the summary.
EOF
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --certificate) P12_PATH="$2"; shift 2 ;;
    --profile) PROFILE_PATH="$2"; shift 2 ;;
    --api-key) API_KEY_PATH="$2"; shift 2 ;;
    --team-id) TEAM_ID="$2"; shift 2 ;;
    --key-id) KEY_ID="$2"; shift 2 ;;
    --issuer-id) ISSUER_ID="$2"; shift 2 ;;
    --output-json) OUTPUT_JSON="$2"; shift 2 ;;
    --bundle-id) BUNDLE_ID="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

[[ "$(uname -s)" == "Darwin" ]] || die "This script must run on macOS."
need openssl
need security
need /usr/libexec/PlistBuddy
need python3
need shasum

[[ -f "$P12_PATH" ]] || die "Certificate .p12 file not found."
[[ -f "$PROFILE_PATH" ]] || die "Provisioning profile file not found."
[[ -f "$API_KEY_PATH" ]] || die "App Store Connect .p8 file not found."
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || die "Team ID must be 10 uppercase letters or digits."
[[ "$KEY_ID" =~ ^[A-Z0-9]{10}$ ]] || die "API Key ID must be 10 uppercase letters or digits."
[[ "$ISSUER_ID" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] \
  || die "Issuer ID must be a UUID."

if [[ -z "$OUTPUT_JSON" ]]; then
  OUTPUT_JSON="$(pwd)/AI_Handover_Log_Apple_Signing_Assets_Validation.json"
fi

WORK="$(mktemp -d)"
chmod 700 "$WORK"
trap 'unset P12_PASSWORD; rm -rf "$WORK"' EXIT

read -r -s -p "Enter the .p12 export password: " P12_PASSWORD
printf '\n'
[[ -n "$P12_PASSWORD" ]] || die ".p12 password is required."
export P12_PASSWORD

CERT_PEM="$WORK/certificate.pem"
KEY_PEM="$WORK/private-key.pem"
PROFILE_PLIST="$WORK/profile.plist"

printf '[1/4] Validating Apple Distribution certificate and private key...\n'
openssl pkcs12 \
  -in "$P12_PATH" \
  -clcerts -nokeys \
  -passin env:P12_PASSWORD \
  -out "$CERT_PEM" >/dev/null 2>&1 \
  || die "Unable to read the certificate from the .p12 file."

openssl pkcs12 \
  -in "$P12_PATH" \
  -nocerts -nodes \
  -passin env:P12_PASSWORD \
  -out "$KEY_PEM" >/dev/null 2>&1 \
  || die "Unable to read the private key from the .p12 file."

chmod 600 "$CERT_PEM" "$KEY_PEM"
openssl pkey -in "$KEY_PEM" -check -noout >/dev/null 2>&1 \
  || die "The .p12 private key failed validation."

CERT_SUBJECT="$(openssl x509 -in "$CERT_PEM" -noout -subject -nameopt RFC2253)"
CERT_ISSUER="$(openssl x509 -in "$CERT_PEM" -noout -issuer -nameopt RFC2253)"
CERT_NOT_BEFORE="$(openssl x509 -in "$CERT_PEM" -noout -startdate | cut -d= -f2-)"
CERT_NOT_AFTER="$(openssl x509 -in "$CERT_PEM" -noout -enddate | cut -d= -f2-)"
CERT_SHA256="$(openssl x509 -in "$CERT_PEM" -noout -fingerprint -sha256 | cut -d= -f2 | tr -d ':')"

printf '%s' "$CERT_SUBJECT" | grep -q "Apple Distribution" \
  || die "The .p12 certificate is not an Apple Distribution certificate."

openssl x509 -in "$CERT_PEM" -checkend 0 -noout >/dev/null \
  || die "The Apple Distribution certificate is expired."

CERT_PUBLIC_DIGEST="$(
  openssl x509 -in "$CERT_PEM" -pubkey -noout \
    | openssl pkey -pubin -outform DER 2>/dev/null \
    | shasum -a 256 | awk '{print $1}'
)"
KEY_PUBLIC_DIGEST="$(
  openssl pkey -in "$KEY_PEM" -pubout -outform DER 2>/dev/null \
    | shasum -a 256 | awk '{print $1}'
)"
[[ "$CERT_PUBLIC_DIGEST" == "$KEY_PUBLIC_DIGEST" ]] \
  || die "The .p12 certificate and private key do not match."

printf '[2/4] Validating App Store Connect provisioning profile...\n'
security cms -D -i "$PROFILE_PATH" > "$PROFILE_PLIST" \
  || die "Unable to decode the provisioning profile."

PROFILE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$PROFILE_PLIST")"
PROFILE_UUID="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$PROFILE_PLIST")"
PROFILE_TEAM_ID="$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' "$PROFILE_PLIST")"
PROFILE_APP_ID="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' "$PROFILE_PLIST")"
PROFILE_GET_TASK_ALLOW="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:get-task-allow' "$PROFILE_PLIST" 2>/dev/null || true)"
PROFILE_PROVISIONS_ALL="$(/usr/libexec/PlistBuddy -c 'Print :ProvisionsAllDevices' "$PROFILE_PLIST" 2>/dev/null || true)"
PROFILE_EXPIRATION="$(
  python3 - "$PROFILE_PLIST" <<'PY'
import plistlib
import sys
from pathlib import Path
with Path(sys.argv[1]).open("rb") as handle:
    profile = plistlib.load(handle)
print(profile["ExpirationDate"].isoformat())
PY
)"

[[ "$PROFILE_TEAM_ID" == "$TEAM_ID" ]] \
  || die "Provisioning profile Team ID mismatch."
[[ "$PROFILE_APP_ID" == "$TEAM_ID.$BUNDLE_ID" ]] \
  || die "Provisioning profile application-identifier mismatch."
[[ "$PROFILE_GET_TASK_ALLOW" != "true" ]] \
  || die "A development provisioning profile was supplied."
[[ "$PROFILE_PROVISIONS_ALL" != "true" ]] \
  || die "An enterprise provisioning profile was supplied."

python3 - "$PROFILE_PLIST" <<'PY'
from datetime import datetime, timezone
import plistlib
import sys
from pathlib import Path

with Path(sys.argv[1]).open("rb") as handle:
    profile = plistlib.load(handle)
expiration = profile["ExpirationDate"]
if expiration.tzinfo is None:
    expiration = expiration.replace(tzinfo=timezone.utc)
if expiration <= datetime.now(timezone.utc):
    raise SystemExit("ERROR: Provisioning profile is expired.")
if profile.get("ProvisionedDevices"):
    raise SystemExit("ERROR: Ad Hoc or Development profile detected; App Store profile must not list devices.")
PY

PROFILE_CERT_COUNT="$(
  python3 - "$PROFILE_PLIST" "$CERT_PEM" <<'PY'
import hashlib
import plistlib
import ssl
import sys
from pathlib import Path

with Path(sys.argv[1]).open("rb") as handle:
    profile = plistlib.load(handle)
cert_pem = Path(sys.argv[2]).read_text()
cert_der = ssl.PEM_cert_to_DER_cert(cert_pem)
target = hashlib.sha256(cert_der).hexdigest()
profile_hashes = [
    hashlib.sha256(bytes(cert)).hexdigest()
    for cert in profile.get("DeveloperCertificates", [])
]
if target not in profile_hashes:
    raise SystemExit("ERROR: The provisioning profile does not contain the supplied distribution certificate.")
print(len(profile_hashes))
PY
)"

printf '[3/4] Validating App Store Connect API private key...\n'
grep -q "BEGIN PRIVATE KEY" "$API_KEY_PATH" \
  || die "The API key does not contain a PRIVATE KEY block."
openssl pkey -in "$API_KEY_PATH" -check -noout >/dev/null 2>&1 \
  || die "The App Store Connect API private key failed validation."

EXPECTED_API_FILENAME="AuthKey_${KEY_ID}.p8"
API_FILENAME="$(basename "$API_KEY_PATH")"
if [[ "$API_FILENAME" != "$EXPECTED_API_FILENAME" ]]; then
  printf 'WARNING: API key filename is %s; Apple tools commonly expect %s.\n' \
    "$API_FILENAME" "$EXPECTED_API_FILENAME" >&2
fi

API_PUBLIC_DIGEST="$(
  openssl pkey -in "$API_KEY_PATH" -pubout -outform DER 2>/dev/null \
    | shasum -a 256 | awk '{print $1}'
)"

printf '[4/4] Writing non-secret validation summary...\n'
export OUTPUT_JSON BUNDLE_ID TEAM_ID KEY_ID ISSUER_ID
export CERT_SUBJECT CERT_ISSUER CERT_NOT_BEFORE CERT_NOT_AFTER CERT_SHA256
export PROFILE_NAME PROFILE_UUID PROFILE_TEAM_ID PROFILE_APP_ID PROFILE_EXPIRATION PROFILE_CERT_COUNT
export API_FILENAME API_PUBLIC_DIGEST

python3 - <<'PY'
import json
import os
from pathlib import Path

summary = {
    "app": "AI引継ぎ帳",
    "bundle_id": os.environ["BUNDLE_ID"],
    "team_id": os.environ["TEAM_ID"],
    "certificate": {
        "type": "Apple Distribution",
        "subject": os.environ["CERT_SUBJECT"],
        "issuer": os.environ["CERT_ISSUER"],
        "not_before": os.environ["CERT_NOT_BEFORE"],
        "not_after": os.environ["CERT_NOT_AFTER"],
        "sha256_fingerprint": os.environ["CERT_SHA256"],
        "contains_matching_private_key": True,
        "valid_now": True,
    },
    "provisioning_profile": {
        "name": os.environ["PROFILE_NAME"],
        "uuid": os.environ["PROFILE_UUID"],
        "team_id": os.environ["PROFILE_TEAM_ID"],
        "application_identifier": os.environ["PROFILE_APP_ID"],
        "expiration": os.environ["PROFILE_EXPIRATION"],
        "distribution_type": "App Store Connect",
        "contains_distribution_certificate": True,
        "developer_certificate_count": int(os.environ["PROFILE_CERT_COUNT"]),
        "lists_devices": False,
        "get_task_allow": False,
        "provisions_all_devices": False,
    },
    "app_store_connect_api": {
        "key_id": os.environ["KEY_ID"],
        "issuer_id": os.environ["ISSUER_ID"],
        "private_key_filename": os.environ["API_FILENAME"],
        "public_key_sha256": os.environ["API_PUBLIC_DIGEST"],
        "private_key_valid": True,
        "network_authentication_tested": False,
    },
    "secrets_in_summary": False,
    "ready_for_local_signing_or_secret_registration": True,
}
path = Path(os.environ["OUTPUT_JSON"]).expanduser().resolve()
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(path)
PY

unset P12_PASSWORD
printf '\nVALIDATION_OK\n'
printf 'Certificate: Apple Distribution, valid and paired with private key\n'
printf 'Profile: App Store Connect, %s, %s\n' "$PROFILE_NAME" "$PROFILE_UUID"
printf 'API key: local private key structure valid\n'
printf 'Summary: %s\n' "$OUTPUT_JSON"
printf 'No certificate, private key, profile, password, or API private key was copied into the summary.\n'
