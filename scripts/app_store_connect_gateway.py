#!/usr/bin/env python3
"""Safe App Store Connect API gateway runner.

The command file is committed without credentials. Apple credentials are supplied
only by the GitHub Actions secret store. The gateway is intentionally read-only:
GET requests only. A command may contain either one request or a bounded batch.
"""

import argparse
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path

from app_store_connect_api import api_get, load_private_key, make_token

REQUEST_ID_RE = re.compile(r"^[A-Za-z0-9._-]{1,100}$")
MAX_BATCH = 50


def validate_path(api_path: object) -> str:
    if not isinstance(api_path, str) or not api_path.startswith("/v1/"):
        raise ValueError("Only /v1/ App Store Connect API paths are allowed.")
    if len(api_path) > 2000 or "\n" in api_path or "\r" in api_path:
        raise ValueError("Invalid API path.")
    return api_path


def validate_request(item: object, index: int) -> dict:
    if not isinstance(item, dict):
        raise ValueError(f"requests[{index}] must be an object.")
    method = item.get("method", "GET")
    if method != "GET":
        raise ValueError("Gateway is read-only: only GET is allowed.")
    label = item.get("label", f"request-{index + 1}")
    if not isinstance(label, str) or not REQUEST_ID_RE.fullmatch(label):
        raise ValueError(f"requests[{index}].label is invalid.")
    return {"label": label, "method": "GET", "path": validate_path(item.get("path"))}


def load_command(path: Path) -> dict:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("Command must be a JSON object.")

    request_id = payload.get("request_id")
    if not isinstance(request_id, str) or not REQUEST_ID_RE.fullmatch(request_id):
        raise ValueError("request_id must match [A-Za-z0-9._-]{1,100}.")

    if "requests" in payload:
        requests = payload.get("requests")
        if not isinstance(requests, list) or not requests:
            raise ValueError("requests must be a non-empty array.")
        if len(requests) > MAX_BATCH:
            raise ValueError(f"Batch exceeds maximum of {MAX_BATCH} requests.")
        return {
            "request_id": request_id,
            "requests": [validate_request(item, i) for i, item in enumerate(requests)],
        }

    method = payload.get("method")
    if method != "GET":
        raise ValueError("Gateway is read-only: only GET is allowed.")
    return {
        "request_id": request_id,
        "requests": [{"label": "single", "method": "GET", "path": validate_path(payload.get("path"))}],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Execute safe read-only App Store Connect commands.")
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
    results = []
    try:
        token = make_token(issuer_id, key_id, key_path)
        for req in command["requests"]:
            status, response = api_get(token, req["path"])
            results.append({
                "label": req["label"],
                "method": "GET",
                "path": req["path"],
                "http_status": status,
                "response": response,
            })
    finally:
        if cleanup:
            cleanup.unlink(missing_ok=True)

    result = {
        "request_id": command["request_id"],
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "request_count": len(results),
        "results": results,
    }
    Path(args.output).write_text(
        json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    total_items = 0
    for entry in results:
        response = entry["response"]
        total_items += len(response.get("data", [])) if isinstance(response, dict) else 0
    print(
        f"PASS: request_id={command['request_id']} requests={len(results)} "
        f"returned_items={total_items}"
    )


if __name__ == "__main__":
    main()
