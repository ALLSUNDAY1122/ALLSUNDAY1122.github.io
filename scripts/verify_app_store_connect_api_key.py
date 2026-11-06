#!/usr/bin/env python3
"""Create and optionally validate an App Store Connect API JWT without third-party packages."""

from __future__ import annotations

import argparse
import base64
import json
import subprocess
import time
import urllib.error
import urllib.request
from pathlib import Path


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def parse_der_ecdsa_signature(der: bytes, part_size: int = 32) -> bytes:
    """Convert ASN.1 DER ECDSA signature to JOSE raw R || S."""
    if len(der) < 8 or der[0] != 0x30:
        raise ValueError("Not a DER ECDSA sequence")

    idx = 1
    seq_len = der[idx]
    idx += 1
    if seq_len & 0x80:
        n = seq_len & 0x7F
        seq_len = int.from_bytes(der[idx : idx + n], "big")
        idx += n
    if idx + seq_len != len(der):
        raise ValueError("Invalid DER sequence length")

    parts = []
    for _ in range(2):
        if der[idx] != 0x02:
            raise ValueError("Expected DER integer")
        idx += 1
        length = der[idx]
        idx += 1
        if length & 0x80:
            n = length & 0x7F
            length = int.from_bytes(der[idx : idx + n], "big")
            idx += n
        value = der[idx : idx + length]
        idx += length
        value = value.lstrip(b"\x00")
        if len(value) > part_size:
            raise ValueError("ECDSA integer is too large")
        parts.append(value.rjust(part_size, b"\x00"))

    if idx != len(der):
        raise ValueError("Unexpected trailing DER data")
    return parts[0] + parts[1]


def create_token(key_path: Path, key_id: str, issuer_id: str, lifetime: int = 300) -> str:
    now = int(time.time())
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    payload = {
        "iss": issuer_id,
        "iat": now,
        "exp": now + lifetime,
        "aud": "appstoreconnect-v1",
    }
    signing_input = (
        b64url(json.dumps(header, separators=(",", ":")).encode())
        + "."
        + b64url(json.dumps(payload, separators=(",", ":")).encode())
    )

    proc = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", str(key_path)],
        input=signing_input.encode(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.decode(errors="replace").strip())
    raw_signature = parse_der_ecdsa_signature(proc.stdout)
    return signing_input + "." + b64url(raw_signature)


def validate_api(token: str) -> dict:
    request = urllib.request.Request(
        "https://api.appstoreconnect.apple.com/v1/apps?limit=1",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read()
            parsed = json.loads(body) if body else {}
            return {
                "http_status": response.status,
                "authenticated": 200 <= response.status < 300,
                "returned_app_count": len(parsed.get("data", [])),
            }
    except urllib.error.HTTPError as exc:
        body = exc.read().decode(errors="replace")
        error_codes = []
        try:
            parsed = json.loads(body)
            error_codes = [item.get("code") for item in parsed.get("errors", [])]
        except json.JSONDecodeError:
            pass
        return {
            "http_status": exc.code,
            "authenticated": False,
            "error_codes": error_codes,
        }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--key", required=True, type=Path)
    parser.add_argument("--key-id", required=True)
    parser.add_argument("--issuer-id", required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--offline-only", action="store_true")
    args = parser.parse_args()

    if not args.key.is_file():
        raise SystemExit("API key file not found")
    if len(args.key_id) != 10 or not args.key_id.isalnum():
        raise SystemExit("Key ID must be 10 alphanumeric characters")
    if len(args.issuer_id) != 36:
        raise SystemExit("Issuer ID must be a 36-character UUID")

    key_text = args.key.read_text(encoding="utf-8", errors="replace")
    if "BEGIN PRIVATE KEY" not in key_text:
        raise SystemExit("The file is not an App Store Connect .p8 private key")

    token = create_token(args.key, args.key_id, args.issuer_id)
    segments = token.split(".")
    result = {
        "key_id": args.key_id,
        "issuer_id": args.issuer_id,
        "jwt_created": len(segments) == 3,
        "jwt_signature_bytes": len(
            base64.urlsafe_b64decode(segments[2] + "=" * (-len(segments[2]) % 4))
        ),
        "network_validation_performed": not args.offline_only,
    }

    if not args.offline_only:
        result["app_store_connect_api"] = validate_api(token)

    output = json.dumps(result, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(output + "\n", encoding="utf-8")
    print(output)


if __name__ == "__main__":
    main()
