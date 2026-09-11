#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

OUTPUT_DIR="${OUTPUT_DIR:-$(pwd)/apple_distribution_csr}"
EMAIL=""
COMMON_NAME="Kohei Morita AI Handover Log"
COUNTRY="JP"

usage() {
  cat <<'EOF'
Generate an encrypted RSA private key and PKCS#10 CSR for an Apple Distribution certificate.

Usage:
  ./generate_apple_distribution_csr_macos.sh \
    --email apple-account@example.com \
    [--common-name "Kohei Morita AI Handover Log"] \
    [--output /secure/path]

Password input:
  By default, the script securely prompts for the private-key password.
  For controlled automation only, set CSR_PRIVATE_KEY_PASSWORD in the environment.

Outputs:
  AppleDistribution.key.pem
  AppleDistribution.certSigningRequest
  AppleDistribution.csr-report.json

The private key must never be uploaded to Apple, GitHub, ChatGPT, Notion, email,
cloud storage, or a public/shared folder.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --email) EMAIL="$2"; shift 2 ;;
    --common-name) COMMON_NAME="$2"; shift 2 ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    --country) COUNTRY="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

command -v openssl >/dev/null 2>&1 || {
  echo "ERROR: openssl is required." >&2
  exit 1
}
command -v shasum >/dev/null 2>&1 || {
  echo "ERROR: shasum is required." >&2
  exit 1
}

[[ "$EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]] || {
  echo "ERROR: provide the Apple Developer account email with --email." >&2
  exit 1
}
[[ -n "$COMMON_NAME" ]] || { echo "ERROR: common name is empty." >&2; exit 1; }
[[ "$COUNTRY" =~ ^[A-Z]{2}$ ]] || { echo "ERROR: country must be a two-letter code." >&2; exit 1; }

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
KEY_PATH="$OUTPUT_DIR/AppleDistribution.key.pem"
CSR_PATH="$OUTPUT_DIR/AppleDistribution.certSigningRequest"
REPORT_PATH="$OUTPUT_DIR/AppleDistribution.csr-report.json"

for path in "$KEY_PATH" "$CSR_PATH" "$REPORT_PATH"; do
  [[ ! -e "$path" ]] || {
    echo "ERROR: refusing to overwrite existing file: $path" >&2
    exit 1
  }
done

KEY_PASSWORD="${CSR_PRIVATE_KEY_PASSWORD:-}"
if [[ -z "$KEY_PASSWORD" ]]; then
  read -r -s -p "Create a strong password for the CSR private key: " KEY_PASSWORD
  printf '\n'
  read -r -s -p "Confirm the private-key password: " KEY_PASSWORD_CONFIRM
  printf '\n'
  [[ "$KEY_PASSWORD" == "$KEY_PASSWORD_CONFIRM" ]] || {
    echo "ERROR: passwords do not match." >&2
    exit 1
  }
fi

(( ${#KEY_PASSWORD} >= 12 )) || {
  echo "ERROR: private-key password must be at least 12 characters." >&2
  exit 1
}

export KEY_PASSWORD
openssl genpkey \
  -algorithm RSA \
  -pkeyopt rsa_keygen_bits:2048 \
  -aes-256-cbc \
  -pass env:KEY_PASSWORD \
  -out "$KEY_PATH"

SUBJECT="/emailAddress=$EMAIL/CN=$COMMON_NAME/C=$COUNTRY"
openssl req \
  -new \
  -sha256 \
  -key "$KEY_PATH" \
  -passin env:KEY_PASSWORD \
  -subj "$SUBJECT" \
  -out "$CSR_PATH"

openssl req -in "$CSR_PATH" -noout -verify >/dev/null
KEY_BITS="$(openssl pkey -in "$KEY_PATH" -passin env:KEY_PASSWORD -text -noout 2>/dev/null | awk '/Private-Key:/{gsub(/[()]/,"",$2); print $2; exit}')"
CSR_SUBJECT="$(openssl req -in "$CSR_PATH" -noout -subject | sed 's/^subject=//')"
PUBLIC_KEY_SHA256="$(
  openssl req -in "$CSR_PATH" -pubkey -noout \
    | openssl pkey -pubin -outform DER \
    | shasum -a 256 \
    | awk '{print $1}'
)"
KEY_SHA256="$(shasum -a 256 "$KEY_PATH" | awk '{print $1}')"
CSR_SHA256="$(shasum -a 256 "$CSR_PATH" | awk '{print $1}')"

chmod 600 "$KEY_PATH"
chmod 600 "$CSR_PATH"

export OUTPUT_DIR KEY_PATH CSR_PATH REPORT_PATH EMAIL COMMON_NAME COUNTRY KEY_BITS
export CSR_SUBJECT PUBLIC_KEY_SHA256 KEY_SHA256 CSR_SHA256
python3 - <<'PY'
import json
import os
from pathlib import Path

report = {
    "purpose": "Apple Distribution certificate signing request",
    "email": os.environ["EMAIL"],
    "common_name": os.environ["COMMON_NAME"],
    "country": os.environ["COUNTRY"],
    "key": {
        "algorithm": "RSA",
        "bits": int(os.environ["KEY_BITS"]),
        "encrypted": True,
        "file": Path(os.environ["KEY_PATH"]).name,
        "sha256": os.environ["KEY_SHA256"],
    },
    "csr": {
        "format": "PKCS#10",
        "signature": "SHA-256",
        "subject": os.environ["CSR_SUBJECT"],
        "file": Path(os.environ["CSR_PATH"]).name,
        "sha256": os.environ["CSR_SHA256"],
        "public_key_sha256": os.environ["PUBLIC_KEY_SHA256"],
        "verified": True,
    },
    "sensitive_values_in_report": False,
    "next_action": "Upload only the .certSigningRequest file to Apple Developer Certificates. Keep the private key local.",
}
Path(os.environ["REPORT_PATH"]).write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY

unset KEY_PASSWORD KEY_PASSWORD_CONFIRM CSR_PRIVATE_KEY_PASSWORD

cat <<EOF

APPLE_DISTRIBUTION_CSR_READY

CSR to upload:
  $CSR_PATH

Encrypted private key to keep securely:
  $KEY_PATH

Safe report:
  $REPORT_PATH

Upload only AppleDistribution.certSigningRequest.
Never upload AppleDistribution.key.pem.
EOF
