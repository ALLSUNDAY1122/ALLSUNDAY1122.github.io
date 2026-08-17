#!/usr/bin/env python3
"""Safe App Store Connect API gateway runner.

The command file is committed without credentials. Apple credentials are supplied
only by the GitHub Actions secret store. This first version intentionally allows
GET requests only; write operations require dedicated, reviewed handlers.
"""

import argparse
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, load_private_key, make_token

REQUEST_ID_RE = re.compile(r"^[A-Za-z0-9._-]{1,100}$")


def load_command(path: Path) -> dict:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("Command must be a JSON object.")

    request_id = payload.get("request_id")
    method = payload.get("method")
    api_path = payload.get("path")

    if not isinstance(request_id, str) or not REQUEST_ID_RE.fullmatch(request_id):
        raise ValueError("request_id must match [A-Za-z0-9._-]{1,100}.")
    if method != "GET":
        raise ValueError("Gateway is read-only: only GET is allowed.")
    if not isinstance(api_path, str) or not api_path.startswith("/v1/"):
        raise ValueError("Only /v1/ App Store Connect API paths are allowed.")
    if len(api_path) > 2000 or "\n" in api_path or "\r" in api_path:
        raise ValueError("Invalid API path.")

    return {"request_id": request_id, "method": method, "path": api_path}


def main() -> None:
    parser = argparse.ArgumentParser(description="Execute a safe App Store Connect command.")
    parser.add_argument(
        "--command",
        default="automation/app-store-connect-command.json",
        help="Path to the command JSON file.",
    )
    parser.add_argument(
        "--output",
        default="asc-result.json",
        help="Path for the API result artifact.",
    )
    args = parser.parse_args()

    command = load_command(Path(args.command))
    issuer_id = os.environ.get("ASC_ISSUER_ID")
    key_id = os.environ.get("ASC_KEY_ID")
    if not issuer_id or not key_id:
        raise SystemExit("Missing ASC_ISSUER_ID or ASC_KEY_ID.")

    key_path, cleanup = load_private_key()
    try:
        token = make_token(issuer_id, key_id, key_path)
        status, response = api_get(token, command["path"])
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)

    result = {
        "request_id": command["request_id"],
        "method": command["method"],
        "path": command["path"],
        "http_status": status,
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "response": response,
    }
    Path(args.output).write_text(
        json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    count = len(response.get("data", [])) if isinstance(response, dict) else 0
    print(
        f"PASS: request_id={command['request_id']} HTTP {status} "
        f"returned_items={count}"
    )


if __name__ == "__main__":
    main()
