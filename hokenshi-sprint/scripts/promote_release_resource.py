#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CANONICAL = ROOT / "content" / "questions.canonical.json"
RELEASE = ROOT / "content" / "questions.release-ready.json"
BUNDLED = ROOT / "NativePackage" / "Sources" / "HokenshiSprintFeature" / "Resources" / "questions.json"
MANIFEST = ROOT / "content" / "release-manifest.json"
BASELINE = "2026-08-13"
PRODUCT_ID = "jp.allsunday1122.hokenshi.premium"
FREE_PATTERN = re.compile(r"^HOK-R1-[A-J]-0[1-3]$")
FREE_COUNT = 30
PREMIUM_COUNT = 300


def compact_hash(rows: list[dict]) -> str:
    payload = json.dumps(rows, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def main() -> None:
    rows = json.loads(CANONICAL.read_text(encoding="utf-8"))
    if len(rows) != 330:
        raise RuntimeError(f"release requires 330 canonical questions, got {len(rows)}")

    ids: set[str] = set()
    release_rows: list[dict] = []
    for row in rows:
        label = row.get("id", "unknown")
        if label in ids:
            raise RuntimeError(f"duplicate id at promotion: {label}")
        ids.add(label)
        if row.get("origin_type") != "original_from_primary_source":
            raise RuntimeError(f"{label}: non-original content cannot be promoted")
        if not str(row.get("rights_basis", "")).strip():
            raise RuntimeError(f"{label}: rights_basis missing")
        if not str(row.get("source_url", "")).startswith("https://"):
            raise RuntimeError(f"{label}: primary source URL must be https")
        if row.get("source_checked_at") != BASELINE:
            raise RuntimeError(f"{label}: source_checked_at must be {BASELINE}")
        if row.get("law_baseline_date") != BASELINE:
            raise RuntimeError(f"{label}: law_baseline_date must be {BASELINE}")
        promoted = dict(row)
        promoted["audit_status"] = "release_ready"
        # Free tier: Round 1, questions 01-03 from each of the 10 subject buckets.
        # This yields 30 balanced free questions; every other question is premium.
        promoted["premium"] = FREE_PATTERN.fullmatch(label) is None
        release_rows.append(promoted)

    free_rows = [row for row in release_rows if not row["premium"]]
    premium_rows = [row for row in release_rows if row["premium"]]
    if len(free_rows) != FREE_COUNT or len(premium_rows) != PREMIUM_COUNT:
        raise RuntimeError(
            f"monetization split must be free={FREE_COUNT}/premium={PREMIUM_COUNT}, "
            f"got free={len(free_rows)}/premium={len(premium_rows)}"
        )
    free_subject_counts: dict[str, int] = {}
    for row in free_rows:
        free_subject_counts[row["subject"]] = free_subject_counts.get(row["subject"], 0) + 1
    if len(free_subject_counts) != 10 or any(count != 3 for count in free_subject_counts.values()):
        raise RuntimeError(f"free tier must expose 3 questions in each of 10 subjects: {free_subject_counts}")

    digest = compact_hash(release_rows)
    RELEASE.parent.mkdir(parents=True, exist_ok=True)
    BUNDLED.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(release_rows, ensure_ascii=False, indent=2) + "\n"
    RELEASE.write_text(payload, encoding="utf-8")
    BUNDLED.write_text(payload, encoding="utf-8")
    MANIFEST.write_text(
        json.dumps(
            {
                "app_key": "hokenshi-sprint",
                "generated_at": BASELINE,
                "question_count": 330,
                "rounds": 3,
                "questions_per_round": 110,
                "audit_status": "release_ready",
                "sha256": digest,
                "source": "questions.canonical.json after canonical/current-guidance gates",
                "monetization": {
                    "type": "non_consumable_unlock",
                    "product_id": PRODUCT_ID,
                    "free_questions": FREE_COUNT,
                    "premium_questions": PREMIUM_COUNT,
                    "free_policy": "round1 questions 01-03 in each of 10 subjects",
                    "mock_exams": "premium",
                },
            },
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )
    print(
        f"PASS: promoted={len(release_rows)} free={len(free_rows)} premium={len(premium_rows)} sha256={digest}"
    )
    print(f"release={RELEASE}")
    print(f"bundled={BUNDLED}")


if __name__ == "__main__":
    main()
