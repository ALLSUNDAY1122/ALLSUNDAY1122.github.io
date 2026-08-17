#!/usr/bin/env python3
"""Safe Codemagic build gateway for ChatGPT-driven release operations.

Credentials are read only from GitHub Actions secrets. The command file contains
no secret values. App Store review submission is explicitly blocked.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import yaml

REQUEST_ID_RE = re.compile(r"^[A-Za-z0-9._-]{1,100}$")
WORKFLOW_ID_RE = re.compile(r"^[A-Za-z0-9._-]{1,120}$")
TERMINAL = {"finished", "failed", "canceled", "timeout", "skipped"}


def api_json(url: str, token: str, method: str = "GET", payload: dict | None = None) -> tuple[int, dict]:
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("Content-Type", "application/json")
    req.add_header("x-auth-token", token)
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read().decode("utf-8")
            return response.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            parsed = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            parsed = {"error": raw[:1000]}
        return exc.code, parsed


def load_command(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("Command must be a JSON object.")
    request_id = data.get("request_id")
    if not isinstance(request_id, str) or not REQUEST_ID_RE.fullmatch(request_id):
        raise ValueError("Invalid request_id.")
    action = data.get("action")
    if action not in {"inspect", "build"}:
        raise ValueError("action must be inspect or build.")
    return data


def application_summary(app: dict) -> dict:
    return {
        "id": app.get("_id") or app.get("id"),
        "name": app.get("appName") or app.get("name"),
        "repositoryUrl": app.get("repositoryUrl") or app.get("repository_url") or app.get("repoUrl"),
    }


def find_app(apps: list[dict], repository: str) -> tuple[str | None, list[dict]]:
    needle = repository.lower().replace("https://github.com/", "").replace(".git", "")
    candidates = []
    for app in apps:
        serialized = json.dumps(app, ensure_ascii=False).lower().replace(".git", "")
        if needle in serialized or needle.split("/")[-1] in serialized:
            candidates.append(application_summary(app))
    ids = [c.get("id") for c in candidates if c.get("id")]
    return (ids[0] if len(set(ids)) == 1 else None), candidates


def validate_workflow(workflow_id: str, yaml_path: Path) -> None:
    if not WORKFLOW_ID_RE.fullmatch(workflow_id):
        raise ValueError("Invalid workflow_id.")
    config = yaml.safe_load(yaml_path.read_text(encoding="utf-8")) or {}
    workflows = config.get("workflows") or {}
    if workflow_id not in workflows:
        raise ValueError(f"Workflow not found in codemagic.yaml: {workflow_id}")
    workflow = workflows[workflow_id] or {}
    publishing = workflow.get("publishing") or {}
    asc = publishing.get("app_store_connect") or {}
    if asc.get("submit_to_app_store") is True:
        raise ValueError("Blocked: workflow is configured to submit to the App Store review/release path.")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--command", default="automation/codemagic-build-command.json")
    parser.add_argument("--output", default="codemagic-result.json")
    args = parser.parse_args()

    output_path = Path(args.output)
    result: dict = {"ok": False}
    try:
        command = load_command(Path(args.command))
        result["request_id"] = command["request_id"]
        result["action"] = command["action"]

        token = os.environ.get("CM_API_TOKEN", "").strip()
        if not token:
            raise RuntimeError("Missing GitHub Actions secret CM_API_TOKEN.")

        repository = command.get("repository") or os.environ.get("GITHUB_REPOSITORY") or "ALLSUNDAY1122/ALLSUNDAY1122.github.io"
        status, apps_response = api_json("https://api.codemagic.io/apps", token)
        if status < 200 or status >= 300:
            raise RuntimeError(f"Codemagic GET /apps failed with HTTP {status}: {apps_response}")
        apps = apps_response.get("applications") or apps_response.get("data") or []
        if isinstance(apps, dict):
            apps = apps.get("applications") or []
        app_id, candidates = find_app(apps, repository)
        result["application_candidates"] = candidates

        if command["action"] == "inspect":
            result["ok"] = True
            result["resolved_app_id"] = app_id
            if not app_id:
                result["note"] = "Could not uniquely resolve appId; use one candidate id in the next build command."
            output_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
            print(f"PASS: Codemagic API connected; candidates={len(candidates)} resolved={bool(app_id)}")
            return 0

        workflow_id = command.get("workflow_id")
        branch = command.get("branch", "main")
        if not isinstance(workflow_id, str):
            raise ValueError("workflow_id is required for build action.")
        if branch != "main":
            raise ValueError("Only main branch builds are allowed by the gateway.")
        validate_workflow(workflow_id, Path("codemagic.yaml"))

        requested_app_id = command.get("app_id") or os.environ.get("CM_APP_ID") or app_id
        if not requested_app_id:
            raise RuntimeError("Codemagic appId could not be resolved uniquely.")

        payload = {"appId": requested_app_id, "workflowId": workflow_id, "branch": branch}
        start_status, start_response = api_json("https://api.codemagic.io/builds", token, method="POST", payload=payload)
        if start_status < 200 or start_status >= 300:
            raise RuntimeError(f"Codemagic POST /builds failed with HTTP {start_status}: {start_response}")
        build_id = start_response.get("buildId") or start_response.get("id")
        if not build_id:
            raise RuntimeError(f"Codemagic did not return a buildId: {start_response}")

        result.update({
            "app_id": requested_app_id,
            "workflow_id": workflow_id,
            "branch": branch,
            "build_id": build_id,
            "build_url": f"https://codemagic.io/app/{requested_app_id}/build/{build_id}",
            "status": "started",
        })
        output_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"Codemagic build started: workflow={workflow_id} build_id={build_id}")

        wait = command.get("wait", True)
        if wait:
            timeout_seconds = int(command.get("timeout_seconds", 3600))
            timeout_seconds = max(60, min(timeout_seconds, 4200))
            deadline = time.time() + timeout_seconds
            last_status = ""
            while time.time() < deadline:
                poll_status, poll_response = api_json(f"https://codemagic.io/api/v3/builds/{build_id}", token)
                if poll_status < 200 or poll_status >= 300:
                    raise RuntimeError(f"Codemagic build status failed with HTTP {poll_status}: {poll_response}")
                data = poll_response.get("data") or poll_response
                current = data.get("status")
                if current != last_status:
                    print(f"Codemagic status: {current}")
                    last_status = current
                result["status"] = current
                output_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
                if current in TERMINAL:
                    result["ok"] = current == "finished"
                    output_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
                    if current != "finished":
                        raise RuntimeError(f"Codemagic build ended with status: {current}")
                    print(f"PASS: Codemagic build finished: {build_id}")
                    return 0
                time.sleep(30)
            raise RuntimeError("Timed out waiting for Codemagic build.")

        result["ok"] = True
        output_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
        return 0

    except Exception as exc:
        result["error"] = str(exc)
        output_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
