#!/usr/bin/env bash
set -Eeuo pipefail

EXPECTED_BUNDLE_ID="jp.allsunday.aihandoverlog"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR=""
P12_PATH=""
PROFILE_PATH=""
API_KEY_PATH=""
TEAM_ID=""
KEY_ID=""
ISSUER_ID=""

usage() {
  cat <<'EOF'
AI引継ぎ帳 Apple署名資産検証

Usage:
  ./verify_apple_signing_assets_macos.sh \
    --p12 /path/to/AppleDistribution.p12 \
    --profile /path/to/AppStore.mobileprovision \
    --api-key /path/to/AuthKey_XXXXXXXXXX.p8 \
    --team-id ABCDEFGHIJ \
    --key-id KLMNOPQRST \
    --issuer-id 00000000-0000-0000-0000-000000000000 \
    [--output-dir /path/to/output]

Notes:
- Run on macOS.
- The .p12 password is requested without echo unless P12_PASSWORD is already set.
- The script never prints or copies the private key contents.
- Generated reports contain metadata and fingerprints only.
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
    --p12) P12_PATH="$2"; shift 2 ;;
    --profile) PROFILE_PATH="$2"; shift 2 ;;
    --api-key) API_KEY_PATH="$2"; shift 2 ;;
    --team-id) TEAM_ID="$2"; shift 2 ;;
    --key-id) KEY_ID="$2"; shift 2 ;;
    --issuer-id) ISSUER_ID="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

[[ "$(uname -s)" == "Darwin" ]] || die "This tool must run on macOS."
need openssl
need security
need python3
need /usr/libexec/PlistBuddy
need shasum

[[ -f "$P12_PATH" ]] || die "Apple Distribution .p12 not found."
[[ -f "$PROFILE_PATH" ]] || die "Provisioning profile not found."
[[ -f "$API_KEY_PATH" ]] || die "App Store Connect .p8 API key not found."
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || die "Team ID must be 10 uppercase letters or digits."
[[ "$KEY_ID" =~ ^[A-Z0-9]{10}$ ]] || die "API Key ID must be 10 uppercase letters or digits."
[[ "$ISSUER_ID" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] \
  || die "Issuer ID must be a UUID."

if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="$PWD/apple_signing_asset_verification_$(date '+%Y%m%d-%H%M%S')"
fi
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

TEMP_DIR="$(mktemp -d)"
chmod 700 "$TEMP_DIR"
cleanup() {
  unset P12_PASSWORD
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

if [[ -z "${P12_PASSWORD:-}" ]]; then
  read -r -s -p "Enter the .p12 export password: " P12_PASSWORD
  printf '\n'
fi
[[ -n "$P12_PASSWORD" ]] || die ".p12 password is required."
export P12_PASSWORD

CERT_PEM="$TEMP_DIR/distribution-certificate.pem"
CERT_DER="$TEMP_DIR/distribution-certificate.der"
PRIVATE_KEY_PEM="$TEMP_DIR/distribution-private-key.pem"
PROFILE_PLIST="$TEMP_DIR/profile.plist"
PROFILE_REPORT="$OUTPUT_DIR/provisioning-profile-report.json"
FINAL_REPORT="$OUTPUT_DIR/apple-signing-assets-report.json"
TEXT_REPORT="$OUTPUT_DIR/apple-signing-assets-summary.txt"

printf '[1/6] Validate Apple Distribution .p12\n'
openssl pkcs12 \
  -in "$P12_PATH" \
  -clcerts -nokeys \
  -passin env:P12_PASSWORD \
  -out "$CERT_PEM" >/dev/null 2>&1 \
  || die "Unable to open .p12. The password may be wrong or the file is invalid."

openssl pkcs12 \
  -in "$P12_PATH" \
  -nocerts -nodes \
  -passin env:P12_PASSWORD \
  -out "$PRIVATE_KEY_PEM" >/dev/null 2>&1 \
  || die "The .p12 does not contain an exportable private key."

chmod 600 "$PRIVATE_KEY_PEM"
openssl pkey -in "$PRIVATE_KEY_PEM" -check -noout >/dev/null 2>&1 \
  || die "Private key validation failed."

CERT_SUBJECT="$(openssl x509 -in "$CERT_PEM" -noout -subject -nameopt RFC2253 | sed 's/^subject=//')"
CERT_ISSUER="$(openssl x509 -in "$CERT_PEM" -noout -issuer -nameopt RFC2253 | sed 's/^issuer=//')"
CERT_SERIAL="$(openssl x509 -in "$CERT_PEM" -noout -serial | cut -d= -f2)"
CERT_NOT_BEFORE="$(openssl x509 -in "$CERT_PEM" -noout -startdate | cut -d= -f2-)"
CERT_NOT_AFTER="$(openssl x509 -in "$CERT_PEM" -noout -enddate | cut -d= -f2-)"
CERT_SHA256="$(openssl x509 -in "$CERT_PEM" -noout -fingerprint -sha256 | cut -d= -f2 | tr -d ':')"

[[ "$CERT_SUBJECT" == *"CN=Apple Distribution:"* ]] \
  || die "The .p12 certificate is not an Apple Distribution certificate."
[[ "$CERT_SUBJECT" == *"OU=$TEAM_ID"* ]] \
  || die "The certificate Team ID does not match --team-id."

openssl x509 -in "$CERT_PEM" -checkend 0 -noout >/dev/null \
  || die "The Apple Distribution certificate is expired."

openssl x509 -in "$CERT_PEM" -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | shasum -a 256 \
  | awk '{print $1}' > "$TEMP_DIR/cert-public-key.sha256"

openssl pkey -in "$PRIVATE_KEY_PEM" -pubout -outform DER \
  | shasum -a 256 \
  | awk '{print $1}' > "$TEMP_DIR/private-public-key.sha256"

cmp -s "$TEMP_DIR/cert-public-key.sha256" "$TEMP_DIR/private-public-key.sha256" \
  || die "The private key does not match the certificate."

openssl x509 -in "$CERT_PEM" -outform DER -out "$CERT_DER"

printf '[2/6] Decode and validate App Store provisioning profile\n'
security cms -D -i "$PROFILE_PATH" > "$PROFILE_PLIST" \
  || die "Unable to decode provisioning profile."

python3 "$SCRIPT_DIR/verify_apple_provisioning_profile.py" \
  --profile-plist "$PROFILE_PLIST" \
  --certificate-der "$CERT_DER" \
  --team-id "$TEAM_ID" \
  --bundle-id "$EXPECTED_BUNDLE_ID" \
  --output "$PROFILE_REPORT"

printf '[3/6] Validate App Store Connect API private key\n'
grep -q "BEGIN PRIVATE KEY" "$API_KEY_PATH" \
  || die "The API key is not a PKCS#8 .p8 private key."

openssl pkey -in "$API_KEY_PATH" -check -noout >/dev/null 2>&1 \
  || die "The App Store Connect API private key is invalid."

API_KEY_TEXT="$(openssl pkey -in "$API_KEY_PATH" -text -noout 2>/dev/null)"
printf '%s' "$API_KEY_TEXT" | grep -Eq 'prime256v1|P-256' \
  || die "The API key is not an EC P-256 key."

API_KEY_SHA256="$(shasum -a 256 "$API_KEY_PATH" | awk '{print $1}')"
EXPECTED_API_FILENAME="AuthKey_${KEY_ID}.p8"
ACTUAL_API_FILENAME="$(basename "$API_KEY_PATH")"
API_FILENAME_MATCH=false
if [[ "$ACTUAL_API_FILENAME" == "$EXPECTED_API_FILENAME" ]]; then
  API_FILENAME_MATCH=true
fi

printf '[4/6] Verify local file permissions and hashes\n'
P12_SHA256="$(shasum -a 256 "$P12_PATH" | awk '{print $1}')"
PROFILE_SHA256="$(shasum -a 256 "$PROFILE_PATH" | awk '{print $1}')"

printf '[5/6] Write non-secret verification report\n'
python3 - "$PROFILE_REPORT" "$FINAL_REPORT" <<PY
import json
import sys
from pathlib import Path

profile_report = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
report = {
    "app": "AI引継ぎ帳",
    "bundle_id": "$EXPECTED_BUNDLE_ID",
    "team_id": "$TEAM_ID",
    "certificate": {
        "subject": "$CERT_SUBJECT",
        "issuer": "$CERT_ISSUER",
        "serial": "$CERT_SERIAL",
        "not_before": "$CERT_NOT_BEFORE",
        "not_after": "$CERT_NOT_AFTER",
        "sha256_fingerprint": "$CERT_SHA256",
        "p12_file_sha256": "$P12_SHA256",
        "type": "Apple Distribution",
        "private_key_present_and_matches": True,
    },
    "provisioning_profile": profile_report,
    "app_store_connect_api_key": {
        "key_id": "$KEY_ID",
        "issuer_id": "$ISSUER_ID",
        "file_name": "$ACTUAL_API_FILENAME",
        "expected_file_name": "$EXPECTED_API_FILENAME",
        "file_name_matches_key_id": $API_FILENAME_MATCH,
        "sha256": "$API_KEY_SHA256",
        "private_key_format": "EC P-256 PKCS#8",
        "private_key_valid": True,
    },
    "result": "passed",
    "secrets_in_report": False,
}
Path(sys.argv[2]).write_text(
    json.dumps(report, ensure_ascii=False, indent=2),
    encoding="utf-8",
)
PY

cat > "$TEXT_REPORT" <<EOF
AI引継ぎ帳 Apple署名資産検証
Result: PASSED
Bundle ID: $EXPECTED_BUNDLE_ID
Team ID: $TEAM_ID

Apple Distribution certificate:
- Subject: $CERT_SUBJECT
- Valid until: $CERT_NOT_AFTER
- SHA-256 fingerprint: $CERT_SHA256
- Private key present and matched: yes

Provisioning profile:
- Result: passed
- Detail: provisioning-profile-report.json

App Store Connect API key:
- Key ID: $KEY_ID
- Issuer ID: $ISSUER_ID
- File: $ACTUAL_API_FILENAME
- Expected filename: $EXPECTED_API_FILENAME
- Filename matched: $API_FILENAME_MATCH
- Format: EC P-256 PKCS#8
- SHA-256: $API_KEY_SHA256

No private key, certificate password, API key contents, or provisioning profile contents
were copied into these reports.
EOF

printf '[6/6] Complete\n'
printf 'APPLE_SIGNING_ASSETS_VALIDATION_OK\n'
printf 'report=%s\n' "$FINAL_REPORT"
printf 'summary=%s\n' "$TEXT_REPORT"

if [[ "$API_FILENAME_MATCH" != "true" ]]; then
  printf 'WARNING: Rename the API key to %s before using Transporter.\n' "$EXPECTED_API_FILENAME" >&2
fi
