#!/usr/bin/env python3
"""Read-only audit of GitHub Actions action references.

Usage: python scripts/audit_actions_pins.py [--root PATH] [--strict] [--json]

Default mode reports findings without failing CI. --strict exits 1 if any
non-local action is not pinned to a full commit SHA / container digest.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

USES = re.compile(r"^\s*(?:-\s*)?uses\s*:\s*(.+?)\s*(?:#.*)?$")
FULL_SHA = re.compile(r"^[0-9a-fA-F]{40}$")
IMAGE_DIGEST = re.compile(r"^sha256:[0-9a-fA-F]{64}$")


def audit(root: Path) -> list[dict[str, object]]:
    workflows = root / ".github" / "workflows"
    if not workflows.is_dir():
        raise FileNotFoundError(f"Workflow directory not found: {workflows}")
    findings: list[dict[str, object]] = []
    for path in sorted((*workflows.glob("*.yml"), *workflows.glob("*.yaml"))):
        if path.is_symlink():
            continue
        for lineno, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
            match = USES.match(line)
            if not match:
                continue
            ref = match.group(1).strip().strip("'\"")
            if ref.startswith("./"):
                continue  # Local actions are resolved from the same commit.
            if ref.startswith("docker://"):
                pinned = "@" in ref and bool(IMAGE_DIGEST.fullmatch(ref.rsplit("@", 1)[-1]))
            else:
                pinned = "@" in ref and bool(FULL_SHA.fullmatch(ref.rsplit("@", 1)[-1]))
            if not pinned:
                findings.append({"file": path.relative_to(root).as_posix(), "line": lineno, "uses": ref})
    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--strict", action="store_true", help="exit 1 on findings (opt-in)")
    parser.add_argument("--json", action="store_true", help="emit machine-readable findings")
    args = parser.parse_args()
    try:
        findings = audit(args.root)
    except (FileNotFoundError, OSError, UnicodeError) as exc:
        parser.exit(2, f"audit error: {exc}\n")
    if args.json:
        print(json.dumps({"unpinned": len(findings), "findings": findings}, ensure_ascii=False, indent=2))
    else:
        print(f"GitHub Actions unpinned external references: {len(findings)}")
        for item in findings:
            print(f"{item['file']}:{item['line']}: {item['uses']}")
    return 1 if args.strict and findings else 0


if __name__ == "__main__":
    raise SystemExit(main())
