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
YOBI = CONTENT.parent
REPO = YOBI.parents[1]
GENERATED = HERE / "generated"
NATIVE_RELEASE = YOBI / "ios" / "Resources" / "questions.release.json"
LEGAL_BANK = CONTENT / "mock-bank"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def run(*parts: object) -> None:
    command = [str(part) for part in parts]
    print("RUN:", " ".join(command), flush=True)
    subprocess.run(command, cwd=REPO, check=True)


def build_uniqueness_base(current_base: str) -> Path:
    combined = load(NATIVE_RELEASE)
    for path in sorted(LEGAL_BANK.glob("*.release.json")):
        combined.extend(load(path))
    for path in sorted(HERE.glob("*.release.json")):
        if path.name != f"{current_base}.release.json":
            combined.extend(load(path))
    ids = [item.get("id") for item in combined]
    if any(not value for value in ids) or len(ids) != len(set(ids)):
        raise ValueError("uniqueness base has missing/duplicate IDs")
    temp = tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", suffix=".json", delete=False)
    with temp:
        json.dump(combined, temp, ensure_ascii=False, indent=2)
        temp.write("\n")
    return Path(temp.name)


def process(base: str, persist: bool) -> None:
    py = sys.executable
    candidate = HERE / f"{base}.candidates.json"
    if not candidate.exists():
        raise ValueError(f"missing candidate bank: {candidate.name}")
    GENERATED.mkdir(parents=True, exist_ok=True)
    answer_audit = GENERATED / f"{base}.answer-audit.json"
    staging = GENERATED / f"{base}.staging.json"
    quality = GENERATED / f"{base}.quality.json"
    release = GENERATED / f"{base}.release.json"
    canonical = HERE / f"{base}.release.json"

    run(py, CONTENT / "mock-bank" / "validate_general_candidates.py", candidate)
    run(py, HERE / "audit_deterministic_general.py", "--bank", candidate, "--report", answer_audit)
    run(py, HERE / "stage_general_candidates.py", "--bank", candidate, "--answer-audit", answer_audit, "--output", staging)

    uniqueness = build_uniqueness_base(base)
    try:
        run(py, CONTENT / "mock-bank" / "audit_global_uniqueness.py", "--base", uniqueness, "--expansion", staging)
    finally:
        uniqueness.unlink(missing_ok=True)

    run(
        py,
        CONTENT / "audit_practice_release_quality.py",
        "--input",
        staging,
        "--report",
        quality,
        "--require-pass",
    )
    run(
        py,
        CONTENT / "promote_practice_release.py",
        "--staging",
        staging,
        "--quality",
        quality,
        "--output",
        release,
    )
    promoted = load(release)
    source = load(candidate)
    if len(promoted) != len(source):
        raise ValueError("promotion count mismatch")
    if any(item.get("release_eligible") is not True or item.get("audit_status") != "release_passed" for item in promoted):
        raise ValueError("promotion invariant failed")
    if any(item.get("subject") != "一般教養" or item.get("origin_type") != "self_authored_original" for item in promoted):
        raise ValueError("general bank origin/subject invariant failed")
    if persist:
        shutil.copyfile(release, canonical)
        print(f"PERSISTED {canonical.relative_to(REPO)}")
    print(f"PASS {base}: deterministic general-bank release pipeline ({len(promoted)} items)")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--batch", action="append", default=[])
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--persist", action="store_true")
    args = parser.parse_args()
    if args.batch:
        bases = sorted(set(args.batch))
    elif args.all:
        bases = sorted(path.name.removesuffix(".candidates.json") for path in HERE.glob("*.candidates.json"))
    else:
        raise SystemExit("--batch or --all required")
    for base in bases:
        process(base, args.persist)
    print(f"SUMMARY: passed={len(bases)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
