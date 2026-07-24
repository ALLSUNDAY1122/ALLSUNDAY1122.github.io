#!/usr/bin/env python3
import json
import subprocess
from collections import Counter
from pathlib import Path

REPO = Path.cwd()
AUDIT_REL = "jichitai-compare/operations/audits/central-b-accuracy-audit-20260725.json"
BRANCH = "coord/central-b-main-audit-sync-20260725"
SYNC_DATE = "2026-07-25"
SYNC_TIME = "2026-07-25T04:50:00+09:00"


def git_show(ref, path):
    return subprocess.run(
        ["git", "show", f"{ref}:{path}"], check=True,
        capture_output=True, text=True, encoding="utf-8"
    ).stdout


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")


def main():
    audit_text = git_show("origin/region/central", AUDIT_REL)
    audit = json.loads(audit_text)
    targets = {}
    entries = 0
    for finding in audit.get("findings", []):
        for error in finding.get("confirmedErrors", []):
            if error.get("status") == "corrected_in_audit_pr_2926":
                targets.setdefault(str(error["code"]), set()).add(str(error["service"]))
                entries += 1
    if entries != 57:
        raise RuntimeError(f"expected 57 corrections, found {entries}")

    applied = 0
    codes = []
    for code in sorted(targets):
        municipality_rel = f"jichitai-compare/data/municipalities/{code[:2]}/{code}.json"
        municipality_path = REPO / municipality_rel
        current = read_json(municipality_path)
        source = json.loads(git_show("origin/region/central", municipality_rel))
        for service in sorted(targets[code]):
            current["services"][service] = source["services"][service]
            applied += 1
        current["summary"] = source.get("summary", current.get("summary"))
        current["updatedAt"] = SYNC_DATE
        write_json(municipality_path, current)
        codes.append(code)

        task_path = REPO / f"jichitai-compare/operations/tasks/{code}.json"
        if task_path.exists():
            task = read_json(task_path)
            counts = Counter(item.get("status") for item in current["services"].values())
            task["verifiedCount"] = counts.get("verified", 0)
            task["researchingCount"] = counts.get("researching", 0)
            task["unavailableCount"] = counts.get("unavailable", 0)
            task["needsMediumReviewCount"] = counts.get("needs_medium_review", 0)
            task["currentBranch"] = BRANCH
            task["pullRequestNumber"] = None
            task["lastCheckedAt"] = SYNC_DATE
            task["lastUpdatedAt"] = SYNC_TIME
            task["lastUpdatedBy"] = "中日本調査班B・全国同期"
            sources = []
            for item in current["services"].values():
                url = (item.get("source") or {}).get("url")
                if url and url not in sources:
                    sources.append(url)
            task["officialSources"] = sources
            note = f"精度監査PR #2926の訂正対象（{', '.join(sorted(targets[code]))}）を最新mainへサービス単位で同期。"
            if note not in task.setdefault("notes", []):
                task["notes"].append(note)
            write_json(task_path, task)

    if applied != 57:
        raise RuntimeError(f"expected 57 applied services, found {applied}")

    audit_path = REPO / AUDIT_REL
    audit_path.parent.mkdir(parents=True, exist_ok=True)
    audit_path.write_text(audit_text.rstrip() + "\n", encoding="utf-8")
    write_json(REPO / "jichitai-compare/operations/audits/central-b-main-sync-20260725.json", {
        "issue": 3131,
        "sourcePullRequest": 2926,
        "sourceBranch": "region/central",
        "targetBranch": "main",
        "municipalityCount": len(codes),
        "serviceCorrectionCount": applied,
        "municipalityCodes": codes,
        "syncedAt": SYNC_TIME
    })
    print(f"applied {applied} corrections across {len(codes)} municipalities")


if __name__ == "__main__":
    main()
