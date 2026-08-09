#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
PREP = HERE / "prepare_audit_data.py"
VALIDATOR = ROOT / "automation" / "learning-sprint-question-pipeline" / "validate_questions.py"
CONFIG = HERE / "learning-sprint-audit.json"


def run(cmd):
    print("+", " ".join(str(x) for x in cmd))
    return subprocess.run([str(x) for x in cmd], check=False).returncode


def main():
    rc = run([sys.executable, PREP])
    if rc:
        return rc
    return run([sys.executable, VALIDATOR, CONFIG])


if __name__ == "__main__":
    raise SystemExit(main())
