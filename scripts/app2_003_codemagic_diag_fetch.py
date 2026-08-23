#!/usr/bin/env python3
"""Fetch only sanitized APP2-003 Codemagic diagnostic/production logs."""
from __future__ import annotations

import argparse
import io
import json
import os
import re
import urllib.request
import zipfile
from pathlib import Path

REPOSITORY = "ALLSUNDAY1122/yoru-no-shoka"
WORKFLOW_ID = "yoru-ios"
BRANCH = "main"
ALLOWED_LOGS = ("yoru-production.log", "yoru-diagnostic.log")


def api_json(token: str, url: str):
    req = urllib.request.Request(url, method="GET")
    req.add_header("x-auth-token", token)
    with urllib.request.urlopen(req, timeout=30) as response:
        raw = response.read().decode("utf-8")
        return json.loads(raw) if raw else {}


def sanitize_log(text: str) -> str:
    text = text[:30000]
    patterns = [
        r"(?i)(token|secret|password|api[_-]?key)\s*[=:]\s*\S+",
        r"(?i)(authorization:)\s*\S+",
    ]
    for pattern in patterns:
        text = re.sub(pattern, lambda m: m.group(1) + "=[REDACTED]", text)
    return text


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--command", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    command = json.loads(Path(args.command).read_text(encoding="utf-8"))
    request_id = str(command.get("request_id", ""))
    action = command.get("action")
    build_id = str(command.get("build_id", ""))
    if not request_id.startswith("app2-003-") or action != "fetch_diagnostic" or len(build_id) < 8:
        raise SystemExit("Invalid APP2-003 diagnostic command")

    token = os.environ.get("CM_API_TOKEN", "").strip()
    if not token:
        raise SystemExit("Missing CM_API_TOKEN")

    result = {
        "request_id": request_id,
        "action": action,
        "repository": REPOSITORY,
        "workflow_id": WORKFLOW_ID,
        "branch": BRANCH,
        "build_id": build_id,
        "ok": False,
    }
    try:
        response = api_json(token, f"https://codemagic.io/api/v3/builds/{build_id}")
        details = response.get("data") or response
        result["status"] = details.get("status")
        artifacts = details.get("artifacts") or []
        artifact = next((a for a in artifacts if a.get("short_lived_download_url")), None)
        if not artifact:
            raise RuntimeError("No APP2-003 log artifact download URL")
        with urllib.request.urlopen(artifact["short_lived_download_url"], timeout=30) as response_obj:
            payload = response_obj.read()
        with zipfile.ZipFile(io.BytesIO(payload)) as archive:
            names = archive.namelist()
            log_name = None
            for preferred in ALLOWED_LOGS:
                log_name = next((name for name in names if name.endswith(preferred)), None)
                if log_name:
                    break
            if not log_name:
                raise RuntimeError(f"APP2-003 log missing from artifact: {names[:20]}")
            text = archive.read(log_name).decode("utf-8", errors="replace")
        result["diagnostic_log"] = sanitize_log(text)
        result["ok"] = True
        return 0
    except Exception as exc:
        result["error"] = str(exc)
        return 1
    finally:
        Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    raise SystemExit(main())
