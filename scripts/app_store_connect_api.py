#!/usr/bin/env python3
"""Minimal App Store Connect API transport.

Credentials are supplied only through environment variables or a local key path.
The module never prints the issuer ID, key ID, private key, or JWT. Write methods
are exposed to the semantic allow-list gateway, not as a free-form user surface.
"""

import argparse
import base64
import json
import os
import subprocess
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

BASE_URL = "https://api.appstoreconnect.apple.com"
ALLOWED_METHODS = {"GET", "POST", "PATCH"}


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def read_der_length(data: bytes, pos: int):
    first = data[pos]
    pos += 1
    if first < 0x80:
        return first, pos
    count = first & 0x7F
    if count == 0 or count > 4 or pos + count > len(data):
        raise ValueError("Unsupported DER length")
    value = int.from_bytes(data[pos : pos + count], "big")
    return value, pos + count


def der_ecdsa_to_jose(signature: bytes, size: int = 32) -> bytes:
    pos = 0
    if len(signature) < 2 or signature[pos] != 0x30:
        raise ValueError("Invalid DER ECDSA signature")
    pos += 1
    seq_len, pos = read_der_length(signature, pos)
    if pos + seq_len != len(signature):
        raise ValueError("Invalid DER sequence length")

    values = []
    for _ in range(2):
        if pos >= len(signature) or signature[pos] != 0x02:
            raise ValueError("Invalid DER integer")
        pos += 1
        int_len, pos = read_der_length(signature, pos)
        if pos + int_len > len(signature):
            raise ValueError("Truncated DER integer")
        value = signature[pos : pos + int_len]
        pos += int_len
        while len(value) > 1 and value[0] == 0:
            value = value[1:]
        if len(value) > size:
            raise ValueError("ECDSA integer is too large")
        values.append(value.rjust(size, b"\0"))

    if pos != len(signature):
        raise ValueError("Trailing DER data")
    return values[0] + values[1]


def load_private_key():
    key_path = os.environ.get("ASC_PRIVATE_KEY_PATH")
    key_text = os.environ.get("ASC_PRIVATE_KEY")
    if key_path:
        return Path(key_path), None
    if not key_text:
        raise RuntimeError("Set ASC_PRIVATE_KEY or ASC_PRIVATE_KEY_PATH.")

    tmp = tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False)
    try:
        tmp.write(key_text.replace("\\n", "\n"))
        tmp.flush()
    finally:
        tmp.close()
    os.chmod(tmp.name, 0o600)
    return Path(tmp.name), Path(tmp.name)


def make_token(issuer_id: str, key_id: str, key_path: Path, lifetime: int = 600) -> str:
    now = int(time.time())
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    payload = {
        "iss": issuer_id,
        "iat": now,
        "exp": now + lifetime,
        "aud": "appstoreconnect-v1",
    }
    encoded_header = b64url(json.dumps(header, separators=(",", ":")).encode())
    encoded_payload = b64url(json.dumps(payload, separators=(",", ":")).encode())
    signing_input = f"{encoded_header}.{encoded_payload}".encode("ascii")

    result = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", str(key_path)],
        input=signing_input,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        message = result.stderr.decode("utf-8", "replace").strip()
        raise RuntimeError(f"OpenSSL signing failed: {message}")

    signature = b64url(der_ecdsa_to_jose(result.stdout))
    return f"{encoded_header}.{encoded_payload}.{signature}"


def api_request(token: str, path: str, method: str = "GET", payload=None):
    method = method.upper()
    if method not in ALLOWED_METHODS:
        raise ValueError(f"Unsupported App Store Connect method: {method}")
    if not path.startswith("/v1/"):
        raise ValueError("Only /v1/ App Store Connect API paths are allowed.")
    if len(path) > 2000 or "\n" in path or "\r" in path:
        raise ValueError("Invalid App Store Connect API path.")

    body = None
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
    }
    if payload is not None:
        body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        headers["Content-Type"] = "application/json"

    request = urllib.request.Request(
        BASE_URL + path,
        data=body,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read()
            if not raw:
                return response.status, None
            return response.status, json.loads(raw.decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body_text = exc.read().decode("utf-8", "replace")
        try:
            error_payload = json.loads(body_text)
        except json.JSONDecodeError:
            error_payload = {"raw": body_text[:2000]}
        raise RuntimeError(
            f"App Store Connect API {method} {path} returned HTTP {exc.code}: {error_payload}"
        ) from None


def api_get(token: str, path: str):
    return api_request(token, path, method="GET")


def main():
    parser = argparse.ArgumentParser(
        description="Read-only App Store Connect API credential check."
    )
    parser.add_argument(
        "--path",
        default="/v1/apps?limit=1",
        help="Read-only /v1/ API path (default: /v1/apps?limit=1).",
    )
    args = parser.parse_args()

    issuer_id = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer_id or not key_id:
        raise SystemExit("Missing ASC_ISSUER_ID or ASC_KEY_ID.")

    key_path, cleanup = load_private_key()
    try:
        token = make_token(issuer_id, key_id, key_path)
        status, response_payload = api_get(token, args.path)
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)

    count = len(response_payload.get("data", [])) if isinstance(response_payload, dict) else 0
    print(
        f"PASS: App Store Connect API reachable "
        f"(HTTP {status}, returned_items={count})."
    )


if __name__ == "__main__":
    main()
