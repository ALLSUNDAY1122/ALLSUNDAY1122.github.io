#!/usr/bin/env python3
"""Fail CI if Apple signing secrets or prohibited credential files are tracked."""

from __future__ import annotations

import fnmatch
import re
import subprocess
from pathlib import Path

FORBIDDEN_PATTERNS = (
    "*.p12",
    "*.pfx",
    "*.mobileprovision",
    "AuthKey_*.p8",
    "*.cer",
    "*.key",
)

PRIVATE_KEY_PATTERN = re.compile(
    rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"
)
P12_BASE64_LITERAL = re.compile(
    rb"APPLE_DISTRIBUTION_CERTIFICATE_P12_BASE64\s*[:=]\s*[\"']?[A-Za-z0-9+/]{80,}={0,2}"
)
API_KEY_BASE64_LITERAL = re.compile(
    rb"APP_STORE_CONNECT_API_KEY_P8_BASE64\s*[:=]\s*[\"']?[A-Za-z0-9+/]{80,}={0,2}"
)

ALLOWLISTED_PATHS = {
    "scripts/scan_forbidden_apple_secrets.py",
}


def tracked_files() -> list[str]:
    output = subprocess.check_output(["git", "ls-files", "-z"])
    return [item.decode("utf-8") for item in output.split(b"\0") if item]


def main() -> None:
    violations: list[str] = []

    for relative in tracked_files():
        if relative in ALLOWLISTED_PATHS:
            continue
        path = Path(relative)
        name = path.name

        for pattern in FORBIDDEN_PATTERNS:
            if fnmatch.fnmatch(name, pattern):
                violations.append(f"forbidden credential file: {relative}")
                break

        try:
            data = path.read_bytes()
        except (OSError, IsADirectoryError):
            continue

        if PRIVATE_KEY_PATTERN.search(data):
            violations.append(f"private key block found: {relative}")
        if P12_BASE64_LITERAL.search(data):
            violations.append(f"literal P12 Base64 secret found: {relative}")
        if API_KEY_BASE64_LITERAL.search(data):
            violations.append(f"literal API key Base64 secret found: {relative}")

    if violations:
        print("APPLE_SECRET_SCAN_FAILED")
        for violation in sorted(set(violations)):
            print(f"- {violation}")
        raise SystemExit(1)

    print("APPLE_SECRET_SCAN_OK")
    print("No tracked Apple signing credential files or private-key blocks were found.")


if __name__ == "__main__":
    main()
