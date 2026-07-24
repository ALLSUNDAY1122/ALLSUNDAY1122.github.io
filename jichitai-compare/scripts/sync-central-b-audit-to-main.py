#!/usr/bin/env python3
# Temporary Issue-triggered runner for Central B audit synchronization.
import json
import subprocess
from collections import Counter
from pathlib import Path

ROOT = Path.cwd()
AUDIT_REL = "jichitai-compare/operations/audits/central-b-accuracy-audit-20260725.json"
SYNC_BRANCH = "coord/central-b-main-sync-final-20260725"
SYNC_DATE = "2026-07-25"
SYNC_TIME = "2026-07-25T05:10:00+09:00"


def git_show(ref: str, path: str) -> str:
    return subprocess.run(
        ["git", "show", f"{ref}:{path}"],
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    ).stdout


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    audit_text = git_show("origin/region/central", AUDIT_REL)
    audit = json.loads(audit_text)
    targets: dict[str, set[str]] = {}
    entry_count = 0

    for finding in audit.get("findings", []):
        for error in finding.get("confirmedErrors", []):
            if error.get("status") != "corrected_in_audit_pr_2926":
                continue
            code = str(error["code"])
            service = str(error["service"])
            targets.setdefault(code, set()).add(service)
            entry_count += 1

    if entry_count != 57:
        raise RuntimeError(f"expected 57 corrections, found {entry_count}")

    applied = 0
    changed_codes: list[str] = []

    for code in sorted(targets):
        municipality_rel = f"jichitai-compare/data/municipalities/{code[:2]}/{code}.json"
        municipality_path = ROOT / municipality_rel
        current = read_json(municipality_path)
        audited = json.loads(git_show("origin/region/central", municipality_rel))

        for service in sorted(targets[code]):
            if service not in audited.get("services", {}):
                raise RuntimeError(f"missing audited service: {code}/{service}")
            current.setdefault("services", {})[service] = audited["services"][service]
            applied += 1

        current["summary"] = audited.get("summary", current.get("summary"))
        current["updatedAt"] = SYNC_DATE
        write_json(municipality_path, current)
        changed_codes.append(code)

        task_path = ROOT / f"jichitai-compare/operations/tasks/{code}.json"
        if task_path.exists():
            task = read_json(task_path)
            counts = Counter(item.get("status") for item in current.get("services", {}).values())
            task["verifiedCount"] = counts.get("verified", 0)
            task["researchingCount"] = counts.get("researching", 0)
            task["unavailableCount"] = counts.get("unavailable", 0)
            task["needsMediumReviewCount"] = counts.get("needs_medium_review", 0)
            task["currentBranch"] = SYNC_BRANCH
            task["pullRequestNumber"] = None
            task["lastCheckedAt"] = SYNC_DATE
            task["lastUpdatedAt"] = SYNC_TIME
            task["lastUpdatedBy"] = "中日本調査班B・全国同期"

            source_urls: list[str] = []
            for item in current.get("services", {}).values():
                url = (item.get("source") or {}).get("url")
                if url and url not in source_urls:
                    source_urls.append(url)
            task["officialSources"] = source_urls

            note = (
                f"精度監査PR #2926の訂正対象（{', '.join(sorted(targets[code]))}）を"
                "最新mainへサービス単位で同期。"
            )
            if note not in task.setdefault("notes", []):
                task["notes"].append(note)
            write_json(task_path, task)

    if applied != 57:
        raise RuntimeError(f"expected 57 applied services, found {applied}")

    audit_path = ROOT / AUDIT_REL
    audit_path.parent.mkdir(parents=True, exist_ok=True)
    audit_path.write_text(audit_text.rstrip() + "\n", encoding="utf-8")

    write_json(
        ROOT / "jichitai-compare/operations/audits/central-b-main-sync-20260725.json",
        {
            "issue": 3131,
            "sourcePullRequest": 2926,
            "synchronizationPullRequest": None,
            "sourceBranch": "region/central",
            "targetBranch": "main",
            "workingBranch": SYNC_BRANCH,
            "municipalityCount": len(changed_codes),
            "serviceCorrectionCount": applied,
            "municipalityCodes": changed_codes,
            "syncedAt": SYNC_TIME,
        },
    )

    print(f"applied {applied} corrections across {len(changed_codes)} municipalities")


if __name__ == "__main__":
    main()
