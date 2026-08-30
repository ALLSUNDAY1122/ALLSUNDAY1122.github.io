#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import secrets
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

REPO = "ALLSUNDAY1122/ALLSUNDAY1122.github.io"
RELAY = "https://gybchnyqlqwmajwkhsly.supabase.co/functions/v1/scanner-golden-probe-relay"
WORKFLOW_ID = "scanner-parity-golden-video-probe"
BRANCH = "scanner-parity/integration"
UUID_RE = re.compile(r"^[0-9a-fA-F-]{36}$")
SHA_RE = re.compile(r"^[0-9a-f]{40}$")
TERMINAL = {"finished", "failed", "canceled", "timeout", "skipped"}


def request_json(url: str, *, method: str = "GET", headers: dict[str, str] | None = None, body: dict | None = None, timeout: int = 60) -> tuple[int, dict]:
    data = None if body is None else json.dumps(body, separators=(",", ":")).encode()
    req = urllib.request.Request(url, data=data, method=method, headers=headers or {})
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        raw = exc.read()
        try:
            parsed = json.loads(raw) if raw else {}
        except Exception:
            parsed = {"error": "non-json HTTP error"}
        return exc.code, parsed


def github_oidc_token() -> str:
    request_url = os.environ.get("ACTIONS_ID_TOKEN_REQUEST_URL", "")
    request_token = os.environ.get("ACTIONS_ID_TOKEN_REQUEST_TOKEN", "")
    if not request_url or not request_token:
        raise RuntimeError("GitHub OIDC environment unavailable")
    sep = "&" if "?" in request_url else "?"
    url = request_url + sep + urllib.parse.urlencode({"audience": "scanner-golden-probe-relay"})
    status, payload = request_json(url, headers={"Authorization": f"bearer {request_token}"})
    token = payload.get("value")
    if status != 200 or not isinstance(token, str) or not token:
        raise RuntimeError("GitHub OIDC token acquisition failed")
    return token


def codemagic_api(token: str, path: str, *, method: str = "GET", body: dict | None = None) -> tuple[int, dict]:
    return request_json(f"https://api.codemagic.io{path}", method=method, headers={"x-auth-token": token, "Accept": "application/json"}, body=body, timeout=60)


def find_app_id(token: str) -> str:
    status, response = codemagic_api(token, "/apps")
    if status < 200 or status >= 300:
        raise RuntimeError(f"Codemagic app discovery failed with HTTP {status}")
    apps = response.get("applications") or response.get("data") or []
    if isinstance(apps, dict):
        apps = apps.get("applications") or []
    needle = REPO.lower()
    candidates: list[str] = []
    for app in apps:
        serialized = json.dumps(app, ensure_ascii=False).lower().replace(".git", "")
        if needle in serialized or needle.split("/")[-1] in serialized:
            value = app.get("_id") or app.get("id")
            if value:
                candidates.append(str(value))
    unique = sorted(set(candidates))
    if len(unique) != 1:
        raise RuntimeError(f"Codemagic app resolution was not unique; candidates={len(unique)}")
    return unique[0]


def main() -> int:
    command_path = Path(sys.argv[1] if len(sys.argv) > 1 else "automation/scanner-parity-golden-video-probe-command.json")
    result_path = Path(sys.argv[2] if len(sys.argv) > 2 else "/tmp/scanner-golden-video-probe-result.json")
    command = json.loads(command_path.read_text(encoding="utf-8"))
    run_id = str(command.get("run_id") or "")
    if not UUID_RE.fullmatch(run_id):
        raise SystemExit("Invalid probe command")
    prepared_sha = Path("/tmp/scanner-video-probe-prepared-sha.txt").read_text(encoding="utf-8").strip()
    if not SHA_RE.fullmatch(prepared_sha):
        raise SystemExit("Prepared integration SHA unavailable")
    cm_token = os.environ.get("CM_API_TOKEN", "").strip()
    if not cm_token:
        raise SystemExit("Missing CM_API_TOKEN")

    result: dict = {"ok": False, "run_id": run_id, "mode": "probe", "workflow_id": WORKFLOW_ID, "branch": BRANCH, "source_sha": prepared_sha}
    download_token = secrets.token_urlsafe(48)
    registered = False
    try:
        oidc = github_oidc_token()
        status, registration = request_json(
            f"{RELAY}/register-download",
            method="POST",
            headers={"Authorization": f"Bearer {oidc}"},
            body={"run_id": run_id, "download_token": download_token},
        )
        if status < 200 or status >= 300 or not registration.get("ok"):
            raise RuntimeError(f"Probe relay registration failed with HTTP {status}")
        registered = True

        app_id = find_app_id(cm_token)
        payload = {
            "appId": app_id,
            "workflowId": WORKFLOW_ID,
            "branch": BRANCH,
            "environment": {"variables": {
                "GOLDEN_RUN_ID": run_id,
                "GOLDEN_DOWNLOAD_TOKEN": download_token,
                "GOLDEN_RELAY_URL": RELAY,
                "GOLDEN_EXPECTED_SOURCE_SHA": prepared_sha,
            }},
            "instanceType": "mac_mini_m2",
        }
        status, started = codemagic_api(cm_token, "/builds", method="POST", body=payload)
        build_id = started.get("buildId") or started.get("id")
        if status < 200 or status >= 300 or not build_id:
            raise RuntimeError(f"Codemagic probe start failed with HTTP {status}")
        result["build_id"] = str(build_id)
        result["status"] = "started"
        result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

        deadline = time.time() + 2700
        last = None
        while time.time() < deadline:
            s, details = codemagic_api(cm_token, f"/v3/builds/{build_id}")
            if s < 200 or s >= 300:
                raise RuntimeError(f"Codemagic probe status failed with HTTP {s}")
            data = details.get("data") or details
            current = str(data.get("status") or "")
            if current != last:
                print(f"Codemagic video probe status: {current}")
                last = current
            result["status"] = current
            result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            if current in TERMINAL:
                result["ok"] = current == "finished"
                result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
                return 0 if result["ok"] else 4
            time.sleep(20)
        raise RuntimeError("Timed out waiting for Codemagic video probe")
    except Exception as exc:
        result["error"] = str(exc)
        result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"Golden video probe gateway failed: {exc}", file=sys.stderr)
        return 1
    finally:
        if registered:
            try:
                request_json(f"{RELAY}/cleanup?run_id={run_id}", method="POST", headers={"Authorization": f"Bearer {download_token}"}, timeout=60)
            except Exception:
                pass
        download_token = ""

if __name__ == "__main__":
    raise SystemExit(main())
