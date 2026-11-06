#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

PRIVATE_KEY=""
CERTIFICATE=""
OUTPUT_PATH="${OUTPUT_PATH:-$(pwd)/AppleDistribution.p12}"
REPORT_PATH=""
ALLOW_NON_APPLE_TEST_CERTIFICATE=0

usage() {
  cat <<'EOF'
Verify an Apple Distribution .cer against the CSR private key and create a .p12.

Usage:
  ./build_apple_distribution_p12_macos.sh \
    --private-key /secure/AppleDistribution.key.pem \
    --certificate /Downloads/distribution.cer \
    [--output /secure/AppleDistribution.p12]

Password input:
  The script securely prompts for the private-key password and new .p12 password.
  For controlled automation only:
    CSR_PRIVATE_KEY_PASSWORD
    P12_OUTPUT_PASSWORD

The .p12 contains a private key. Store it as a sensitive credential.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --private-key) PRIVATE_KEY="$2"; shift 2 ;;
    --certificate) CERTIFICATE="$2"; shift 2 ;;
    --output) OUTPUT_PATH="$2"; shift 2 ;;
    --report) REPORT_PATH="$2"; shift 2 ;;
    --allow-non-apple-test-certificate) ALLOW_NON_APPLE_TEST_CERTIFICATE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

for command_name in openssl shasum python3; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "ERROR: missing command: $command_name" >&2
    exit 1
  }
done

[[ -f "$PRIVATE_KEY" ]] || { echo "ERROR: private key not found." >&2; exit 1; }
[[ -f "$CERTIFICATE" ]] || { echo "ERROR: certificate not found." >&2; exit 1; }

OUTPUT_DIR="$(dirname "$OUTPUT_PATH")"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
OUTPUT_PATH="$OUTPUT_DIR/$(basename "$OUTPUT_PATH")"
REPORT_PATH="${REPORT_PATH:-$OUTPUT_DIR/AppleDistribution.p12-report.json}"

for path in "$OUTPUT_PATH" "$REPORT_PATH"; do
  [[ ! -e "$path" ]] || {
    echo "ERROR: refusing to overwrite existing file: $path" >&2
    exit 1
  }
done

PRIVATE_KEY_PASSWORD="${CSR_PRIVATE_KEY_PASSWORD:-}"
if [[ -z "$PRIVATE_KEY_PASSWORD" ]]; then
  read -r -s -p "Enter the CSR private-key password: " PRIVATE_KEY_PASSWORD
  printf '\n'
fi

P12_PASSWORD="${P12_OUTPUT_PASSWORD:-}"
if [[ -z "$P12_PASSWORD" ]]; then
  read -r -s -p "Create a strong password for AppleDistribution.p12: " P12_PASSWORD
  printf '\n'
  read -r -s -p "Confirm the .p12 password: " P12_PASSWORD_CONFIRM
  printf '\n'
  [[ "$P12_PASSWORD" == "$P12_PASSWORD_CONFIRM" ]] || {
    echo "ERROR: .p12 passwords do not match." >&2
    exit 1
  }
fi

(( ${#P12_PASSWORD} >= 12 )) || {
  echo "ERROR: .p12 password must be at least 12 characters." >&2
  exit 1
}

WORK="$(mktemp -d)"
CERT_PEM="$WORK/distribution.pem"
cleanup() {
  set +e
  rm -rf "$WORK"
  unset PRIVATE_KEY_PASSWORD P12_PASSWORD P12_PASSWORD_CONFIRM
  unset CSR_PRIVATE_KEY_PASSWORD P12_OUTPUT_PASSWORD
}
trap cleanup EXIT

if openssl x509 -in "$CERTIFICATE" -noout >/dev/null 2>&1; then
  openssl x509 -in "$CERTIFICATE" -out "$CERT_PEM"
elif openssl x509 -inform DER -in "$CERTIFICATE" -noout >/dev/null 2>&1; then
  openssl x509 -inform DER -in "$CERTIFICATE" -out "$CERT_PEM"
else
  echo "ERROR: certificate is neither valid PEM nor DER X.509." >&2
  exit 1
fi

CERT_SUBJECT="$(openssl x509 -in "$CERT_PEM" -noout -subject | sed 's/^subject=//')"
CERT_ISSUER="$(openssl x509 -in "$CERT_PEM" -noout -issuer | sed 's/^issuer=//')"
if (( ALLOW_NON_APPLE_TEST_CERTIFICATE == 0 )); then
  printf '%s\n' "$CERT_SUBJECT" | grep -q "Apple Distribution" || {
    echo "ERROR: certificate subject is not Apple Distribution." >&2
    exit 1
  }
fi

openssl x509 -in "$CERT_PEM" -checkend 604800 -noout >/dev/null || {
  echo "ERROR: certificate is expired or expires within seven days." >&2
  exit 1
}

export PRIVATE_KEY_PASSWORD
KEY_PUBLIC_SHA256="$(
  openssl pkey \
    -in "$PRIVATE_KEY" \
    -passin env:PRIVATE_KEY_PASSWORD \
    -pubout -outform DER \
    | shasum -a 256 \
    | awk '{print $1}'
)"
CERT_PUBLIC_SHA256="$(
  openssl x509 -in "$CERT_PEM" -pubkey -noout \
    | openssl pkey -pubin -outform DER \
    | shasum -a 256 \
    | awk '{print $1}'
)"

[[ "$KEY_PUBLIC_SHA256" == "$CERT_PUBLIC_SHA256" ]] || {
  echo "ERROR: certificate does not match the supplied private key." >&2
  exit 1
}

export P12_PASSWORD
openssl pkcs12 \
  -export \
  -inkey "$PRIVATE_KEY" \
  -passin env:PRIVATE_KEY_PASSWORD \
  -in "$CERT_PEM" \
  -name "Apple Distribution" \
  -passout env:P12_PASSWORD \
  -out "$OUTPUT_PATH"

openssl pkcs12 \
  -in "$OUTPUT_PATH" \
  -passin env:P12_PASSWORD \
  -clcerts -nokeys -noout >/dev/null

PRIVATE_KEY_COUNT="$(
  openssl pkcs12 \
    -in "$OUTPUT_PATH" \
    -passin env:P12_PASSWORD \
    -nocerts -nodes 2>/dev/null \
    | grep -c "BEGIN PRIVATE KEY" || true
)"
[[ "$PRIVATE_KEY_COUNT" -ge 1 ]] || {
  echo "ERROR: generated .p12 does not contain a private key." >&2
  exit 1
}

CERT_NOT_BEFORE="$(openssl x509 -in "$CERT_PEM" -noout -startdate | cut -d= -f2-)"
CERT_NOT_AFTER="$(openssl x509 -in "$CERT_PEM" -noout -enddate | cut -d= -f2-)"
CERT_SERIAL="$(openssl x509 -in "$CERT_PEM" -noout -serial | cut -d= -f2-)"
CERT_SHA256="$(openssl x509 -in "$CERT_PEM" -noout -fingerprint -sha256 | cut -d= -f2 | tr -d ':')"
P12_SHA256="$(shasum -a 256 "$OUTPUT_PATH" | awk '{print $1}')"
chmod 600 "$OUTPUT_PATH"

export REPORT_PATH OUTPUT_PATH CERT_SUBJECT CERT_ISSUER CERT_NOT_BEFORE CERT_NOT_AFTER
export CERT_SERIAL CERT_SHA256 P12_SHA256 KEY_PUBLIC_SHA256 CERT_PUBLIC_SHA256
python3 - <<'PY'
import json
import os
from pathlib import Path

report = {
    "purpose": "Apple Distribution PKCS#12 signing identity",
    "certificate": {
        "subject": os.environ["CERT_SUBJECT"],
        "issuer": os.environ["CERT_ISSUER"],
        "serial": os.environ["CERT_SERIAL"],
        "not_before": os.environ["CERT_NOT_BEFORE"],
        "not_after": os.environ["CERT_NOT_AFTER"],
        "sha256_fingerprint": os.environ["CERT_SHA256"],
    },
    "key_match": {
        "matched": True,
        "private_key_public_sha256": os.environ["KEY_PUBLIC_SHA256"],
        "certificate_public_sha256": os.environ["CERT_PUBLIC_SHA256"],
    },
    "p12": {
        "file": Path(os.environ["OUTPUT_PATH"]).name,
        "sha256": os.environ["P12_SHA256"],
        "private_key_present": True,
        "password_protected": True,
    },
    "sensitive_values_in_report": False,
    "next_action": "Validate this .p12 together with the App Store provisioning profile and App Store Connect API key.",
}
Path(os.environ["REPORT_PATH"]).write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY

cat <<EOF

APPLE_DISTRIBUTION_P12_READY

Sensitive .p12:
  $OUTPUT_PATH

Safe report:
  $REPORT_PATH

Next:
  Run validate_apple_release_credentials_macos.sh with this .p12,
  the App Store Connect provisioning profile, and the API .p8 key.
EOF
