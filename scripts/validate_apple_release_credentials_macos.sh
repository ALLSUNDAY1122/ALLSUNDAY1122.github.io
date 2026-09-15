#!/usr/bin/env bash
set -Eeuo pipefail

BUNDLE_ID="jp.allsunday.aihandoverlog"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$(pwd)/apple_credential_validation}"
OFFLINE_API=0

usage() {
  cat <<'EOF'
Usage:
  ./validate_apple_release_credentials_macos.sh \
    --certificate AppleDistribution.p12 \
    --profile AppStore.mobileprovision \
    --api-key AuthKey_XXXXXXXXXX.p8 \
    --team-id ABCDEFGHIJ \
    --key-id KLMNOPQRST \
    --issuer-id 00000000-0000-0000-0000-000000000000

Options:
  --offline-api   Validate JWT creation without contacting App Store Connect
  --output PATH   Sanitized report directory
EOF
}

CERTIFICATE=""; PROFILE=""; API_KEY=""; TEAM_ID=""; KEY_ID=""; ISSUER_ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --certificate) CERTIFICATE="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --api-key) API_KEY="$2"; shift 2 ;;
    --team-id) TEAM_ID="$2"; shift 2 ;;
    --key-id) KEY_ID="$2"; shift 2 ;;
    --issuer-id) ISSUER_ID="$2"; shift 2 ;;
    --offline-api) OFFLINE_API=1; shift ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

[[ "$(uname -s)" == "Darwin" ]] || { echo "ERROR: macOS is required." >&2; exit 1; }
for command_name in security openssl plutil python3 shasum; do
  command -v "$command_name" >/dev/null 2>&1 || { echo "ERROR: missing $command_name" >&2; exit 1; }
done
[[ -f "$CERTIFICATE" ]] || { echo "ERROR: .p12 not found." >&2; exit 1; }
[[ -f "$PROFILE" ]] || { echo "ERROR: .mobileprovision not found." >&2; exit 1; }
[[ -f "$API_KEY" ]] || { echo "ERROR: .p8 not found." >&2; exit 1; }
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || { echo "ERROR: invalid Team ID." >&2; exit 1; }
[[ "$KEY_ID" =~ ^[A-Z0-9]{10}$ ]] || { echo "ERROR: invalid Key ID." >&2; exit 1; }
[[ "$ISSUER_ID" =~ ^[0-9a-fA-F-]{36}$ ]] || { echo "ERROR: invalid Issuer ID." >&2; exit 1; }

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
WORK="$(mktemp -d)"
KEYCHAIN="$WORK/check.keychain-db"
PROFILE_PLIST="$WORK/profile.plist"
CERT_PEM="$WORK/certificate.pem"
KEYCHAIN_PASSWORD="$(openssl rand -base64 36 | tr -d '\n')"
cleanup() {
  set +e
  security delete-keychain "$KEYCHAIN" >/dev/null 2>&1
  rm -rf "$WORK"
  unset P12_PASSWORD KEYCHAIN_PASSWORD
}
trap cleanup EXIT

read -r -s -p "Enter the .p12 export password: " P12_PASSWORD
printf '\n'
export P12_PASSWORD
openssl pkcs12 -in "$CERTIFICATE" -passin env:P12_PASSWORD -clcerts -nokeys -out "$CERT_PEM" >/dev/null 2>&1 || {
  echo "ERROR: unable to open .p12." >&2; exit 1;
}
CERT_SUBJECT="$(openssl x509 -in "$CERT_PEM" -noout -subject)"
echo "$CERT_SUBJECT" | grep -q "Apple Distribution" || { echo "ERROR: not Apple Distribution." >&2; exit 1; }
openssl x509 -in "$CERT_PEM" -checkend 86400 -noout || { echo "ERROR: certificate expires within 24 hours." >&2; exit 1; }
CERT_NOT_AFTER="$(openssl x509 -in "$CERT_PEM" -noout -enddate | cut -d= -f2-)"
CERT_SHA1="$(openssl x509 -in "$CERT_PEM" -noout -fingerprint -sha1 | cut -d= -f2 | tr -d ':')"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$CERTIFICATE" -P "$P12_PASSWORD" -A -t agg -f pkcs12 -k "$KEYCHAIN" >/dev/null
security find-identity -v -p codesigning "$KEYCHAIN" | grep -q "Apple Distribution" || {
  echo "ERROR: .p12 does not include a usable private key." >&2; exit 1;
}

security cms -D -i "$PROFILE" > "$PROFILE_PLIST"
plutil -lint "$PROFILE_PLIST" >/dev/null
PROFILE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$PROFILE_PLIST")"
PROFILE_UUID="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$PROFILE_PLIST")"
PROFILE_TEAM_ID="$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' "$PROFILE_PLIST")"
PROFILE_APP_ID="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' "$PROFILE_PLIST")"
PROFILE_EXPIRATION="$(/usr/libexec/PlistBuddy -c 'Print :ExpirationDate' "$PROFILE_PLIST")"
GET_TASK_ALLOW="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:get-task-allow' "$PROFILE_PLIST" 2>/dev/null || true)"
PROVISIONS_ALL="$(/usr/libexec/PlistBuddy -c 'Print :ProvisionsAllDevices' "$PROFILE_PLIST" 2>/dev/null || true)"
PROVISIONED_DEVICES="$(/usr/libexec/PlistBuddy -c 'Print :ProvisionedDevices' "$PROFILE_PLIST" 2>/dev/null || true)"
[[ "$PROFILE_TEAM_ID" == "$TEAM_ID" ]] || { echo "ERROR: profile Team ID mismatch." >&2; exit 1; }
[[ "$PROFILE_APP_ID" == "$TEAM_ID.$BUNDLE_ID" ]] || { echo "ERROR: profile Bundle ID mismatch." >&2; exit 1; }
[[ "$GET_TASK_ALLOW" != "true" ]] || { echo "ERROR: development profile supplied." >&2; exit 1; }
[[ "$PROVISIONS_ALL" != "true" ]] || { echo "ERROR: enterprise profile supplied." >&2; exit 1; }
[[ -z "$PROVISIONED_DEVICES" ]] || { echo "ERROR: device-based profile supplied." >&2; exit 1; }

python3 - "$PROFILE_PLIST" "$CERT_SHA1" <<'PY'
import hashlib, plistlib, sys
with open(sys.argv[1], 'rb') as handle:
    profile = plistlib.load(handle)
expected = sys.argv[2].upper()
actual = [hashlib.sha1(item).hexdigest().upper() for item in profile.get('DeveloperCertificates', [])]
if expected not in actual:
    raise SystemExit('ERROR: profile does not contain the supplied distribution certificate')
PY

grep -q "BEGIN PRIVATE KEY" "$API_KEY" || { echo "ERROR: invalid .p8 key." >&2; exit 1; }
API_RESULT="$OUTPUT_DIR/app-store-connect-api-validation.json"
API_ARGS=(--key "$API_KEY" --key-id "$KEY_ID" --issuer-id "$ISSUER_ID" --output "$API_RESULT")
(( OFFLINE_API == 1 )) && API_ARGS+=(--offline-only)
python3 "$SCRIPT_DIR/verify_app_store_connect_api_key.py" "${API_ARGS[@]}"

API_AUTHENTICATED="$(python3 - "$API_RESULT" "$OFFLINE_API" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as handle:
    data = json.load(handle)
offline = sys.argv[2] == '1'
if offline:
    valid = data.get('jwt_created') is True and data.get('jwt_signature_bytes') == 64
else:
    valid = data.get('app_store_connect_api', {}).get('authenticated') is True
print(str(valid).lower())
PY
)"
[[ "$API_AUTHENTICATED" == "true" ]] || {
  echo "ERROR: App Store Connect API authentication failed." >&2
  exit 1
}

export OUTPUT_DIR BUNDLE_ID TEAM_ID KEY_ID ISSUER_ID PROFILE_NAME PROFILE_UUID PROFILE_EXPIRATION CERT_NOT_AFTER API_AUTHENTICATED OFFLINE_API
export P12_SHA256="$(shasum -a 256 "$CERTIFICATE" | awk '{print $1}')"
export PROFILE_SHA256="$(shasum -a 256 "$PROFILE" | awk '{print $1}')"
export API_KEY_SHA256="$(shasum -a 256 "$API_KEY" | awk '{print $1}')"
python3 - <<'PY'
import json, os
from pathlib import Path
report = {
  'app': 'AI引継ぎ帳',
  'bundle_id': os.environ['BUNDLE_ID'],
  'team_id': os.environ['TEAM_ID'],
  'certificate': {'type': 'Apple Distribution', 'expires': os.environ['CERT_NOT_AFTER'], 'p12_sha256': os.environ['P12_SHA256'], 'private_key_present': True},
  'profile': {'name': os.environ['PROFILE_NAME'], 'uuid': os.environ['PROFILE_UUID'], 'expires': os.environ['PROFILE_EXPIRATION'], 'profile_sha256': os.environ['PROFILE_SHA256'], 'type': 'App Store Connect distribution'},
  'api_key': {
      'key_id': os.environ['KEY_ID'],
      'issuer_id': os.environ['ISSUER_ID'],
      'p8_sha256': os.environ['API_KEY_SHA256'],
      'network_validation_performed': os.environ['OFFLINE_API'] != '1',
      'authenticated_or_offline_jwt_valid': os.environ['API_AUTHENTICATED'] == 'true'
  },
  'validation': {'team_match': True, 'bundle_match': True, 'certificate_match': True, 'sensitive_values_in_report': False}
}
path = Path(os.environ['OUTPUT_DIR']) / 'apple-release-credential-validation.json'
path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(path)
PY

echo "APPLE_RELEASE_CREDENTIALS_VALID"
echo "Profile: $PROFILE_NAME"
echo "API validation: $API_AUTHENTICATED"
echo "Sanitized report: $OUTPUT_DIR/apple-release-credential-validation.json"
