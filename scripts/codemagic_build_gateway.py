#!/usr/bin/env python3
"""Safe Codemagic gateway for ChatGPT-driven release operations.

Codemagic's public Builds API supports starting and cancelling builds, but does
not expose a documented GET /builds/{id} status endpoint. Completion is therefore
observed through the documented workflow status badge and, for iOS release
artifacts, fresh App Store Connect/TestFlight readback.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import urllib.error
import urllib.request
from pathlib import Path

import yaml

REQUEST_ID_RE = re.compile(r"^[A-Za-z0-9._-]{1,100}$")
WORKFLOW_ID_RE = re.compile(r"^[A-Za-z0-9._-]{1,120}$")
REPOSITORY_RE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
SENSITIVE_KEY_PARTS = ("secret", "token", "password", "credential", "private", "apikey", "api_key", "environment", "variable")
SCANLAB_BUILD3_BRANCH = "testflight/splat-native-ios-20260824-build3"
KANRIEIYOUSHI_RELEASE_BRANCH = "release/kanrieiyoushi-testflight-20260911"
TORU_TANGO_RELEASE_BRANCH = "release/toru-tango-build10-20260912"
PINNED_RELEASE_BRANCHES = {SCANLAB_BUILD3_BRANCH, KANRIEIYOUSHI_RELEASE_BRANCH, TORU_TANGO_RELEASE_BRANCH}


def _parse_response(raw: str) -> dict:
    if not raw:
        return {"_empty_response": True}
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        return {"_non_json_response": raw[:2000]}
    return parsed if isinstance(parsed, dict) else {"_json_response": parsed}


def api_json(url: str, token: str, method: str = "GET", payload: dict | None = None) -> tuple[int, dict]:
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("Content-Type", "application/json")
    req.add_header("Accept", "application/json")
    req.add_header("x-auth-token", token)
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return response.status, _parse_response(response.read().decode("utf-8", errors="replace"))
    except urllib.error.HTTPError as exc:
        return exc.code, _parse_response(exc.read().decode("utf-8", errors="replace"))


def api_text(url: str, token: str = "") -> tuple[int, str]:
    req = urllib.request.Request(url, method="GET")
    req.add_header("Accept", "image/svg+xml,text/plain,*/*")
    if token:
        req.add_header("x-auth-token", token)
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return response.status, response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8", errors="replace")


def sanitize(value):
    if isinstance(value, dict):
        return {k: ("[REDACTED]" if any(p in str(k).lower() for p in SENSITIVE_KEY_PARTS) else sanitize(v)) for k, v in value.items()}
    if isinstance(value, list):
        return [sanitize(v) for v in value]
    return value


def load_command(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("Command must be a JSON object.")
    request_id = data.get("request_id")
    if not isinstance(request_id, str) or not REQUEST_ID_RE.fullmatch(request_id):
        raise ValueError("Invalid request_id.")
    action = data.get("action")
    if action not in {"inspect", "inspect_workflow_status", "build"}:
        raise ValueError("action must be inspect, inspect_workflow_status, or build.")
    return data


def application_summary(app: dict) -> dict:
    return {"id": app.get("_id") or app.get("id"), "name": app.get("appName") or app.get("name"), "repositoryUrl": app.get("repositoryUrl") or app.get("repository_url") or app.get("repoUrl")}


def find_app(apps: list[dict], repository: str) -> tuple[str | None, list[dict]]:
    needle = repository.lower().replace("https://github.com/", "").replace(".git", "")
    candidates = []
    for app in apps:
        serialized = json.dumps(app, ensure_ascii=False).lower().replace(".git", "")
        if needle in serialized or needle.split("/")[-1] in serialized:
            candidates.append(application_summary(app))
    ids = [c.get("id") for c in candidates if c.get("id")]
    return (ids[0] if len(set(ids)) == 1 else None), candidates


def _load_remote_workflow_config(repository: str, branch: str) -> dict:
    url = f"https://raw.githubusercontent.com/{repository}/{branch}/codemagic.yaml"
    req = urllib.request.Request(url, headers={"Accept": "text/plain", "User-Agent": "codemagic-gateway"})
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"Could not fetch codemagic.yaml: HTTP {exc.code}") from exc
    return yaml.safe_load(raw) or {}


def workflow_config(repository: str, branch: str) -> dict:
    if repository == "ALLSUNDAY1122/ALLSUNDAY1122.github.io":
        if branch == "main":
            return yaml.safe_load(Path("codemagic.yaml").read_text(encoding="utf-8")) or {}
        if branch in PINNED_RELEASE_BRANCHES:
            return _load_remote_workflow_config(repository, branch)
        raise ValueError("Only main or an explicitly pinned release branch is allowed for this repository.")
    if not REPOSITORY_RE.fullmatch(repository):
        raise ValueError("Invalid repository.")
    if branch != "main":
        raise ValueError("Only main branch workflow validation is allowed.")
    return _load_remote_workflow_config(repository, branch)


def validate_workflow(repository: str, branch: str, workflow_id: str) -> None:
    if not WORKFLOW_ID_RE.fullmatch(workflow_id):
        raise ValueError("Invalid workflow_id.")
    workflows = (workflow_config(repository, branch).get("workflows") or {})
    if workflow_id not in workflows:
        raise ValueError(f"Workflow not found in {repository}/codemagic.yaml: {workflow_id}")
    asc = ((workflows[workflow_id] or {}).get("publishing") or {}).get("app_store_connect") or {}
    if asc.get("submit_to_app_store") is True:
        raise ValueError("Blocked: workflow is configured to submit to the App Store review/release path.")


def badge_state(svg: str) -> str:
    text = re.sub(r"<[^>]+>", " ", svg).lower()
    for state in ("building", "passing", "failing", "success", "failed", "unknown"):
        if state in text:
            return state
    return "unclassified"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--command", default="automation/codemagic-build-command.json")
    parser.add_argument("--output", default="codemagic-result.json")
    args = parser.parse_args()
    output_path = Path(args.output)
    result: dict = {"ok": False}
    try:
        command = load_command(Path(args.command))
        result.update({"request_id": command["request_id"], "action": command["action"]})
        token = os.environ.get("CM_API_TOKEN", "").strip()
        if not token:
            raise RuntimeError("Missing GitHub Actions secret CM_API_TOKEN.")

        repository = command.get("repository") or os.environ.get("GITHUB_REPOSITORY") or "ALLSUNDAY1122/ALLSUNDAY1122.github.io"
        status, apps_response = api_json("https://api.codemagic.io/apps", token)
        if status < 200 or status >= 300:
            raise RuntimeError(f"Codemagic GET /apps failed with HTTP {status}: {sanitize(apps_response)}")
        apps = apps_response.get("applications") or apps_response.get("data") or []
        if isinstance(apps, dict):
            apps = apps.get("applications") or []
        app_id, candidates = find_app(apps, repository)
        result["application_candidates"] = candidates

        if command["action"] == "inspect":
            result.update({"ok": True, "resolved_app_id": app_id})
            if not app_id:
                result["note"] = "Could not uniquely resolve appId; provide an explicit app_id for workflow-specific commands."
            output_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
            print(f"PASS: Codemagic API connected; candidates={len(candidates)} resolved={bool(app_id)}")
            return 0

        workflow_id = command.get("workflow_id")
        if not isinstance(workflow_id, str) or not WORKFLOW_ID_RE.fullmatch(workflow_id):
            raise ValueError("Valid workflow_id is required.")
        requested_app_id = command.get("app_id") or app_id or os.environ.get("CM_APP_ID")
        if not requested_app_id:
            raise RuntimeError("Codemagic appId could not be resolved uniquely.")

        if command["action"] == "inspect_workflow_status":
            badge_url = f"https://api.codemagic.io/apps/{requested_app_id}/{workflow_id}/status_badge.svg"
            badge_status, svg = api_text(badge_url, token)
            if badge_status < 200 or badge_status >= 300:
                raise RuntimeError(f"Codemagic status badge failed with HTTP {badge_status}")
            state = badge_state(svg)
            result.update({"ok": True, "app_id": requested_app_id, "workflow_id": workflow_id, "workflow_status": state,
                           "note": "Workflow badge is latest-workflow evidence, not a build-id-specific completion record. Confirm iOS release artifacts with fresh ASC/TestFlight readback."})
            output_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
            print(f"PASS: Codemagic workflow badge status={state}; workflow={workflow_id}")
            return 0

        branch = command.get("branch", "main")
        allowed_branch = branch == "main" or (repository == "ALLSUNDAY1122/ALLSUNDAY1122.github.io" and branch in PINNED_RELEASE_BRANCHES)
        if not allowed_branch:
            raise ValueError("Branch is not allowed by the Codemagic gateway.")
        validate_workflow(repository, branch, workflow_id)
        if command.get("wait") is True:
            raise ValueError("wait=true is unsupported: Codemagic's documented Builds API has no build-status GET endpoint. Start with wait=false and verify via workflow badge plus ASC/TestFlight readback.")

        payload = {"appId": requested_app_id, "workflowId": workflow_id, "branch": branch}
        start_status, start_response = api_json("https://api.codemagic.io/builds", token, method="POST", payload=payload)
        if start_status < 200 or start_status >= 300:
            raise RuntimeError(f"Codemagic POST /builds failed with HTTP {start_status}: {sanitize(start_response)}")
        build_id = start_response.get("buildId") or start_response.get("id")
        if not build_id:
            raise RuntimeError(f"Codemagic did not return a buildId: {sanitize(start_response)}")
        result.update({"ok": True, "app_id": requested_app_id, "workflow_id": workflow_id, "branch": branch, "build_id": build_id,
                       "build_url": f"https://codemagic.io/app/{requested_app_id}/build/{build_id}", "status": "started",
                       "completion_verification": "Use inspect_workflow_status for latest workflow health and fresh ASC/TestFlight readback for uploaded iOS artifact."})
        output_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"Codemagic build started safely: workflow={workflow_id} build_id={build_id}; no unsupported polling attempted")
        return 0
    except Exception as exc:
        result["error"] = str(exc)
        output_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"FAIL: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
