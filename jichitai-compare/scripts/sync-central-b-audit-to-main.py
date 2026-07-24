#!/usr/bin/env python3
import json
import subprocess
from collections import Counter
from pathlib import Path

REPO = Path.cwd()
AUDIT_REL = "jichitai-compare/operations/audits/central-b-accuracy-audit-20260725.json"
BRANCH = "sync/main-central-b-audit-20260725"
SYNC_DATE = "2026-07-25"
SYNC_TIME = "2026-07-25T04:35:00+09:00"


def git_show(ref: str, path: str) -> str:
    result = subprocess.run(
        ["git", "show", f"{ref}:{path}"],
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return result.stdout


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")


def main() -> None:
    audit_text = git_show("origin/region/central", AUDIT_REL)
    audit = json.loads(audit_text)

    targets: dict[str, set[str]] = {}
    total_entries = 0
    for finding in audit.get("findings", []):
        for error in finding.get("confirmedErrors", []):
            if error.get("status") != "corrected_in_audit_pr_2926":
                continue
            code = str(error["code"])
            service = str(error["service"])
            targets.setdefault(code, set()).add(service)
            total_entries += 1

    if total_entries != 57:
        raise RuntimeError(f"Expected 57 audit corrections, found {total_entries}")

    changed_services = 0
    changed_codes: list[str] = []

    for code in sorted(targets):
        prefecture = code[:2]
        municipality_rel = f"jichitai-compare/data/municipalities/{prefecture}/{code}.json"
        municipality_path = REPO / municipality_rel
        current = load_json(municipality_path)
        audited = json.loads(git_show("origin/region/central", municipality_rel))

        for service in sorted(targets[code]):
            if service not in audited.get("services", {}):
                raise RuntimeError(f"Missing audited service {code}/{service}")
            current.setdefault("services", {})[service] = audited["services"][service]
            changed_services += 1

        # The one-line municipality summary is derived from the service set and may
        # otherwise continue to advertise a removed general-purpose programme.
        current["summary"] = audited.get("summary", current.get("summary"))
        current["updatedAt"] = SYNC_DATE
        write_json(municipality_path, current)
        changed_codes.append(code)

        task_rel = f"jichitai-compare/operations/tasks/{code}.json"
        task_path = REPO / task_rel
        if task_path.exists():
            task = load_json(task_path)
            counts = Counter(
                service_data.get("status")
                for service_data in current.get("services", {}).values()
            )
            task["verifiedCount"] = counts.get("verified", 0)
            task["researchingCount"] = counts.get("researching", 0)
            task["unavailableCount"] = counts.get("unavailable", 0)
            task["needsMediumReviewCount"] = counts.get("needs_medium_review", 0)
            task["currentBranch"] = BRANCH
            task["pullRequestNumber"] = None
            task["lastCheckedAt"] = SYNC_DATE
            task["lastUpdatedAt"] = SYNC_TIME
            task["lastUpdatedBy"] = "中日本調査班B・全国同期"

            sources: list[str] = []
            for service_data in current.get("services", {}).values():
                url = (service_data.get("source") or {}).get("url")
                if url and url not in sources:
                    sources.append(url)
            task["officialSources"] = sources

            note = f"精度監査PR #2926の訂正対象（{', '.join(sorted(targets[code]))}）を最新mainへサービス単位で同期。"
            notes = task.setdefault("notes", [])
            if note not in notes:
                notes.append(note)
            write_json(task_path, task)

    if changed_services != 57:
        raise RuntimeError(f"Expected to apply 57 services, applied {changed_services}")

    audit_path = REPO / AUDIT_REL
    audit_path.parent.mkdir(parents=True, exist_ok=True)
    audit_path.write_text(audit_text.rstrip() + "\n", encoding="utf-8")

    report = {
        "issue": 3131,
        "sourcePullRequest": 2926,
        "sourceBranch": "region/central",
        "targetBranch": "main",
        "municipalityCount": len(changed_codes),
        "serviceCorrectionCount": changed_services,
        "municipalityCodes": changed_codes,
        "syncedAt": SYNC_TIME,
    }
    write_json(REPO / "jichitai-compare/operations/audits/central-b-main-sync-20260725.json", report)
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
