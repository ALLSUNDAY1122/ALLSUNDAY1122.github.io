#!/usr/bin/env python3
"""APP2-003 fixed Codemagic gateway for 夜の書架.

Allowed actions are inspect, inspect_app, add_app, add_fresh_app, delete_app,
build, and inspect_build. The target repository, workflow, and branch are
hard-coded. App Store review submission is not part of this gateway.
"""
from __future__ import annotations

import argparse
import json
import os
import urllib.error
import urllib.request
from pathlib import Path

REPOSITORY = "ALLSUNDAY1122/yoru-no-shoka"
REPOSITORY_URL = "https://github.com/ALLSUNDAY1122/yoru-no-shoka.git"
WORKFLOW_ID = "yoru-ios"
BRANCH = "main"
SENSITIVE = ("token", "secret", "password", "credential", "private", "api_key", "apikey", "sshkey", "ssh_key")


def sanitize(value):
    if isinstance(value, dict):
        return {
            key: ("[REDACTED]" if any(part in str(key).lower() for part in SENSITIVE) else sanitize(child))
            for key, child in value.items()
        }
    if isinstance(value, list):
        return [sanitize(item) for item in value]
    return value


def api_json(token: str, url: str, method: str = "GET", payload: dict | None = None):
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(url, data=body, method=method)
    request.add_header("Content-Type", "application/json")
    request.add_header("x-auth-token", token)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read().decode("utf-8")
            return response.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            parsed = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            parsed = {"error": raw[:1200]}
        return exc.code, parsed


def app_summary(app: dict) -> dict:
    return {
        "id": app.get("_id") or app.get("id"),
        "name": app.get("appName") or app.get("name"),
        "repositoryUrl": app.get("repositoryUrl") or app.get("repository_url") or app.get("repoUrl"),
        "branches": app.get("branches"),
    }


def safe_app_details(app: dict) -> dict:
    allowed_exact = {
        "_id", "id", "appName", "name", "repositoryUrl", "repository_url", "repoUrl",
        "repositoryId", "repository_id", "repositoryName", "repository_name", "repositoryOwner",
        "repository_owner", "branches", "branch", "teamId", "team_id", "provider", "scmType",
        "scm_type", "repositoryType", "repository_type", "integration", "integrationId",
        "integration_id", "archived", "disabled", "isRepositoryRemoved", "repositoryRemoved",
        "repositoryUnavailable", "webhookUrl", "workflowIds"
    }
    return {key: sanitize(value) for key, value in app.items() if key in allowed_exact}


def list_apps(token: str):
    status, response = api_json(token, "https://api.codemagic.io/apps")
    if not 200 <= status < 300:
        raise RuntimeError(f"Codemagic GET /apps HTTP {status}: {sanitize(response)}")
    apps = response.get("applications") or response.get("data") or []
    if isinstance(apps, dict):
        apps = apps.get("applications") or []
    return apps


def matching_apps(apps: list[dict]) -> list[dict]:
    needle = REPOSITORY.lower()
    short = needle.split("/")[-1]
    matched = []
    for app in apps:
        serial = json.dumps(app, ensure_ascii=False).lower().replace(".git", "")
        if needle in serial or short in serial:
            matched.append(app)
    return matched


def find_app(apps: list[dict]) -> tuple[str | None, list[dict]]:
    matched = matching_apps(apps)
    candidates = [app_summary(app) for app in matched]
    ids = {item.get("id") for item in candidates if item.get("id")}
    return (next(iter(ids)) if len(ids) == 1 else None), candidates


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--command", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    command = json.loads(Path(args.command).read_text(encoding="utf-8"))
    request_id = str(command.get("request_id", ""))
    if not request_id.startswith("app2-003-"):
        raise SystemExit("Unexpected request_id")
    action = command.get("action")
    if action not in {"inspect", "inspect_app", "add_app", "add_fresh_app", "delete_app", "build", "inspect_build"}:
        raise SystemExit("Unsupported APP2-003 Codemagic action")

    token = os.environ.get("CM_API_TOKEN", "").strip()
    if not token:
        raise SystemExit("Missing CM_API_TOKEN")

    output = Path(args.output)
    result: dict = {
        "request_id": request_id,
        "action": action,
        "repository": REPOSITORY,
        "workflow_id": WORKFLOW_ID,
        "branch": BRANCH,
        "ok": False,
    }

    try:
        if action == "inspect_build":
            build_id = str(command.get("build_id", ""))
            if len(build_id) < 8:
                raise RuntimeError("Invalid build_id")
            status, response = api_json(token, f"https://codemagic.io/api/v3/builds/{build_id}")
            if not 200 <= status < 300:
                raise RuntimeError(f"Codemagic build inspect HTTP {status}: {sanitize(response)}")
            details = response.get("data") or response
            result.update({"ok": True, "build_id": build_id, "status": details.get("status"), "build_details": sanitize(details)})
            return 0

        apps = list_apps(token)
        app_id, candidates = find_app(apps)
        result["application_candidates"] = candidates
        result["resolved_app_id"] = app_id

        if action == "inspect":
            result["ok"] = True
            return 0

        if action == "inspect_app":
            explicit_id = str(command.get("app_id", "")).strip()
            target_id = explicit_id or app_id
            if not target_id:
                raise RuntimeError("Night Library Codemagic application is not uniquely resolved")
            status, response = api_json(token, f"https://api.codemagic.io/apps/{target_id}")
            if not 200 <= status < 300:
                raise RuntimeError(f"Codemagic GET /apps/:id HTTP {status}: {sanitize(response)}")
            app = response.get("application") if isinstance(response.get("application"), dict) else response
            result.update({"ok": True, "app_id": target_id, "app_details": safe_app_details(app)})
            return 0

        if action == "delete_app":
            target_id = str(command.get("app_id", "")).strip()
            if target_id not in {item.get("id") for item in candidates}:
                raise RuntimeError("Refusing to delete an app that is not a current 夜の書架 candidate")
            status, response = api_json(token, f"https://api.codemagic.io/apps/{target_id}", method="DELETE")
            if not 200 <= status < 300:
                raise RuntimeError(f"Codemagic DELETE /apps/:id HTTP {status}: {sanitize(response)}")
            apps_after = list_apps(token)
            remaining = [app_summary(app) for app in matching_apps(apps_after)]
            if target_id in {item.get("id") for item in remaining}:
                raise RuntimeError("Codemagic delete read-back still contains target app")
            result.update({"ok": True, "changed": True, "app_id": target_id, "application_candidates": remaining})
            return 0

        if action in {"add_app", "add_fresh_app"}:
            if action == "add_app" and app_id:
                result.update({"ok": True, "changed": False, "app_id": app_id})
                return 0
            status, response = api_json(token, "https://api.codemagic.io/apps", method="POST", payload={"repositoryUrl": REPOSITORY_URL})
            if not 200 <= status < 300:
                raise RuntimeError(f"Codemagic POST /apps HTTP {status}: {sanitize(response)}")
            created = response.get("application") if isinstance(response.get("application"), dict) else response
            created_id = created.get("_id") or created.get("id")
            if not created_id:
                raise RuntimeError(f"Codemagic app create returned no id: {sanitize(response)}")
            status, readback = api_json(token, f"https://api.codemagic.io/apps/{created_id}")
            if not 200 <= status < 300:
                raise RuntimeError(f"Codemagic created app read-back HTTP {status}: {sanitize(readback)}")
            created_app = readback.get("application") if isinstance(readback.get("application"), dict) else readback
            apps_after = list_apps(token)
            result.update({
                "ok": True,
                "changed": True,
                "app_id": created_id,
                "created_app_details": safe_app_details(created_app),
                "application_candidates": [app_summary(app) for app in matching_apps(apps_after)],
            })
            return 0

        explicit_id = str(command.get("app_id", "")).strip()
        target_id = explicit_id or app_id
        if not target_id:
            raise RuntimeError("Night Library Codemagic application is not uniquely resolved")
        status, response = api_json(token, "https://api.codemagic.io/builds", method="POST", payload={"appId": target_id, "workflowId": WORKFLOW_ID, "branch": BRANCH})
        if not 200 <= status < 300:
            raise RuntimeError(f"Codemagic POST /builds HTTP {status}: {sanitize(response)}")
        build_id = response.get("buildId") or response.get("id")
        if not build_id:
            raise RuntimeError(f"Codemagic build start returned no build id: {sanitize(response)}")
        result.update({"ok": True, "app_id": target_id, "build_id": build_id, "status": "started", "build_url": f"https://codemagic.io/app/{target_id}/build/{build_id}"})
        return 0
    except Exception as exc:
        result["error"] = str(exc)
        return 1
    finally:
        output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(sanitize(result), ensure_ascii=False))


if __name__ == "__main__":
    raise SystemExit(main())
