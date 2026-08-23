#!/usr/bin/env python3
"""Temporary, narrowly scoped Scan Lab TestFlight launcher.

Only the vetted Scan Lab release branch/workflow is accepted. The command carries
no credentials; CM_API_TOKEN is read from GitHub Actions secrets. App Store review
submission is never invoked here.
"""

import argparse
import json
import os
import urllib.parse
import urllib.request
from pathlib import Path

REPOSITORY = "ALLSUNDAY1122/ALLSUNDAY1122.github.io"
BRANCH = "testflight/splat-native-ios-20260824"
WORKFLOW_ID = "splat-native-ios"
APP_ID = "6a769d81a1add9d06020b524"
HQ_HEAD = "17b52b79f032e7abe225bc216cc2d0ac2b71fadf"
ASC_APP_ID = "6803778932"
BUNDLE_ID = "jp.allsunday1122.splatlab"
API_ROOT = "https://api.github.com/repos/ALLSUNDAY1122/ALLSUNDAY1122.github.io"


def get_json(url: str) -> dict:
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json", "User-Agent": "scanlab-release-gateway"})
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def get_text(url: str) -> str:
    req = urllib.request.Request(url, headers={"Accept": "text/plain", "User-Agent": "scanlab-release-gateway"})
    with urllib.request.urlopen(req, timeout=30) as response:
        return response.read().decode("utf-8")


def app_tree(ref: str) -> dict[str, str]:
    encoded = urllib.parse.quote(ref, safe="")
    commit = get_json(f"{API_ROOT}/commits/{encoded}")
    tree_sha = ((commit.get("commit") or {}).get("tree") or {}).get("sha")
    if not tree_sha:
        raise SystemExit(f"Could not resolve tree for {ref}")
    tree = get_json(f"{API_ROOT}/git/trees/{tree_sha}?recursive=1")
    if tree.get("truncated") is True:
        raise SystemExit(f"Refused: recursive tree truncated for {ref}")
    return {
        str(item.get("path")): str(item.get("sha"))
        for item in tree.get("tree", [])
        if isinstance(item, dict)
        and item.get("type") == "blob"
        and str(item.get("path", "")).startswith("splat-native-ios/")
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--command", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    command = json.loads(Path(args.command).read_text(encoding="utf-8"))
    required = {
        "action": "build",
        "repository": REPOSITORY,
        "branch": BRANCH,
        "workflow_id": WORKFLOW_ID,
        "app_id": APP_ID,
        "expected_hq_head": HQ_HEAD,
        "app_store_build_number": "2",
    }
    for key, expected in required.items():
        if command.get(key) != expected:
            raise SystemExit(f"Refused: {key} mismatch")

    hq_tree = app_tree(HQ_HEAD)
    release_tree = app_tree(BRANCH)
    if hq_tree != release_tree:
        paths = sorted(set(hq_tree) | set(release_tree))
        diffs = [p for p in paths if hq_tree.get(p) != release_tree.get(p)]
        raise SystemExit(f"Refused: release app source differs from HQ: {diffs[:10]}")

    raw_url = "https://raw.githubusercontent.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/" + BRANCH + "/codemagic.yaml"
    config = get_text(raw_url)
    required_fragments = [
        "splat-native-ios:",
        "APP_STORE_CONNECT_APP_ID: 6803778932",
        "BUNDLE_ID: jp.allsunday1122.splatlab",
        "CURRENT_PROJECT_VERSION: 2",
        "Using TestFlight build number 2",
        "submit_to_testflight: true",
        "submit_to_app_store: false",
    ]
    for fragment in required_fragments:
        if fragment not in config:
            raise SystemExit(f"Refused: release config missing {fragment!r}")
    if "submit_to_app_store: true" in config:
        raise SystemExit("Refused: App Store submission enabled")

    token = os.environ.get("CM_API_TOKEN", "").strip()
    if not token:
        raise SystemExit("Missing CM_API_TOKEN")
    payload = {"appId": APP_ID, "workflowId": WORKFLOW_ID, "branch": BRANCH}
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        "https://api.codemagic.io/builds",
        data=body,
        headers={"x-auth-token": token, "Content-Type": "application/json", "Accept": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as response:
        started = json.loads(response.read().decode("utf-8"))
    build_id = started.get("buildId") or started.get("id")
    if not build_id:
        raise SystemExit("Codemagic did not return build id")

    result = {
        "request_id": command.get("request_id"),
        "ok": True,
        "status": "started",
        "build_id": build_id,
        "repository": REPOSITORY,
        "branch": BRANCH,
        "workflow_id": WORKFLOW_ID,
        "validated_hq_head": HQ_HEAD,
        "app_store_build_number": "2",
        "app_store_connect_app_id": ASC_APP_ID,
        "bundle_id": BUNDLE_ID,
        "submit_to_testflight": True,
        "submit_to_app_store": False,
    }
    Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: started Scan Lab TestFlight Build 2 retry {build_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
