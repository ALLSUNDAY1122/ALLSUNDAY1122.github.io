#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
CONTENT = HERE.parent
REPO = CONTENT.parents[2]
NATIVE_RELEASE = CONTENT.parent / "ios" / "Resources" / "questions.release.json"
GENERATED = HERE / "generated"

SHARED_DEPENDENCIES = {
    "learning-sprint/yobi-tantou/content-loop/validate_candidates.py",
    "learning-sprint/yobi-tantou/content-loop/audit_candidate_sources.py",
    "learning-sprint/yobi-tantou/content-loop/audit_candidate_answers.py",
    "learning-sprint/yobi-tantou/content-loop/stage_practice_release_candidates.py",
    "learning-sprint/yobi-tantou/content-loop/audit_practice_release_quality.py",
    "learning-sprint/yobi-tantou/content-loop/promote_practice_release.py",
    "learning-sprint/yobi-tantou/content-loop/mock-bank/merge_distractor_notes.py",
    "learning-sprint/yobi-tantou/content-loop/mock-bank/audit_global_uniqueness.py",
    "learning-sprint/yobi-tantou/content-loop/mock-bank/run_mock_bank_pipeline.py",
    ".github/workflows/yobi-mock-bank-pipeline.yml",
}

COMPANION_SUFFIXES = (
    ".candidates.json",
    "-source-locks.json",
    "-answer-audit.json",
    "-distractors.json",
)


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def run(*parts: object) -> None:
    command = [str(p) for p in parts]
    print("RUN:", " ".join(command), flush=True)
    subprocess.run(command, cwd=REPO, check=True)


def all_batch_bases() -> list[str]:
    return sorted(path.name.removesuffix(".candidates.json") for path in HERE.glob("*.candidates.json"))


def base_from_path(path: str) -> str | None:
    name = Path(path).name
    for suffix in COMPANION_SUFFIXES:
        if name.endswith(suffix):
            return name[: -len(suffix)]
    return None


def changed_paths(base: str, head: str) -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", base, head],
        cwd=REPO,
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def select_batches(git_base: str | None, git_head: str | None, force_all: bool) -> list[str]:
    batches = all_batch_bases()
    if force_all or not git_base or not git_head or set(git_base) == {"0"}:
        return batches
    changed = changed_paths(git_base, git_head)
    if any(path in SHARED_DEPENDENCIES for path in changed):
        return batches
    selected = {base for path in changed if (base := base_from_path(path))}
    return sorted(selected)


def paths_for(base: str) -> dict[str, Path]:
    return {
        "candidate": HERE / f"{base}.candidates.json",
        "locks": HERE / f"{base}-source-locks.json",
        "answers": HERE / f"{base}-answer-audit.json",
        "distractors": HERE / f"{base}-distractors.json",
        "canonical": HERE / f"{base}.release.json",
        "staging": GENERATED / f"{base}.staging.json",
        "enriched": GENERATED / f"{base}.enriched-staging.json",
        "quality": GENERATED / f"{base}.quality.json",
        "release": GENERATED / f"{base}.release.json",
    }


def ensure_complete_source_set(base: str, p: dict[str, Path]) -> bool:
    required = (p["candidate"], p["locks"], p["answers"], p["distractors"])
    missing = [path.name for path in required if not path.exists()]
    if missing:
        print(f"HOLD {base}: source set incomplete; missing={missing}")
        return False
    return True


def validate_mock_assignment(base: str, items: list[dict]) -> None:
    mock_ids = {item.get("practice_mock_id") for item in items}
    if len(mock_ids) != 1 or None in mock_ids:
        raise ValueError(f"{base}: every candidate must carry one identical practice_mock_id")
    if any(item.get("exam_year") is not None for item in items):
        raise ValueError(f"{base}: original mock candidates cannot carry official exam_year")


def build_uniqueness_base(current_base: str) -> Path:
    combined = load(NATIVE_RELEASE)
    if not isinstance(combined, list):
        raise ValueError("native release bank must be a JSON array")
    for path in sorted(HERE.glob("*.release.json")):
        if path.name == f"{current_base}.release.json":
            continue
        items = load(path)
        if not isinstance(items, list):
            raise ValueError(f"{path.name}: canonical mock release must be a JSON array")
        combined.extend(items)
    ids = [item.get("id") for item in combined]
    if any(not qid for qid in ids) or len(ids) != len(set(ids)):
        raise ValueError(f"{current_base}: uniqueness base has missing/duplicate IDs")
    temp = tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", suffix=".json", delete=False)
    with temp:
        json.dump(combined, temp, ensure_ascii=False, indent=2)
        temp.write("\n")
    return Path(temp.name)


def process_batch(base: str, persist: bool) -> bool:
    p = paths_for(base)
    if not ensure_complete_source_set(base, p):
        return False

    candidates = load(p["candidate"])
    if not isinstance(candidates, list) or not candidates:
        raise ValueError(f"{base}: candidates must be a non-empty JSON array")
    validate_mock_assignment(base, candidates)
    GENERATED.mkdir(parents=True, exist_ok=True)

    py = sys.executable
    run(py, CONTENT / "validate_candidates.py", p["candidate"])
    run(py, CONTENT / "audit_candidate_sources.py", "--bank", p["candidate"], "--locks", p["locks"])
    run(
        py,
        CONTENT / "audit_candidate_answers.py",
        "--bank",
        p["candidate"],
        "--audit",
        p["answers"],
        "--locks",
        p["locks"],
    )
    run(
        py,
        CONTENT / "stage_practice_release_candidates.py",
        "--candidates",
        p["candidate"],
        "--locks",
        p["locks"],
        "--answers",
        p["answers"],
        "--output",
        p["staging"],
    )
    run(
        py,
        HERE / "merge_distractor_notes.py",
        "--input",
        p["staging"],
        "--notes",
        p["distractors"],
        "--output",
        p["enriched"],
    )

    uniqueness_base = build_uniqueness_base(base)
    try:
        run(
            py,
            HERE / "audit_global_uniqueness.py",
            "--base",
            uniqueness_base,
            "--expansion",
            p["enriched"],
        )
    finally:
        uniqueness_base.unlink(missing_ok=True)

    run(
        py,
        CONTENT / "audit_practice_release_quality.py",
        "--input",
        p["enriched"],
        "--report",
        p["quality"],
        "--require-pass",
    )
    run(
        py,
        CONTENT / "promote_practice_release.py",
        "--staging",
        p["enriched"],
        "--quality",
        p["quality"],
        "--output",
        p["release"],
    )

    promoted = load(p["release"])
    if len(promoted) != len(candidates):
        raise ValueError(f"{base}: promotion count mismatch")
    if any(item.get("audit_status") != "release_passed" or item.get("release_eligible") is not True for item in promoted):
        raise ValueError(f"{base}: promoted invariant failed")

    if persist:
        shutil.copyfile(p["release"], p["canonical"])
        print(f"PERSISTED {p['canonical'].relative_to(REPO)}")
    print(f"PASS {base}: full mock-bank release pipeline ({len(promoted)} items)")
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--git-base")
    parser.add_argument("--git-head")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--persist", action="store_true")
    parser.add_argument("--batch", action="append", default=[])
    args = parser.parse_args()

    if args.batch:
        selected = sorted(set(args.batch))
    else:
        selected = select_batches(args.git_base, args.git_head, args.all)

    if not selected:
        print("PASS: no source batch requires re-audit for this change")
        return 0

    known = set(all_batch_bases())
    unknown = sorted(set(selected) - known)
    if unknown:
        raise SystemExit(f"FAIL: unknown batch base(s): {unknown}")

    completed = 0
    held = 0
    for base in selected:
        if process_batch(base, args.persist):
            completed += 1
        else:
            held += 1
    print(f"SUMMARY: selected={len(selected)} passed={completed} hold_incomplete={held}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
