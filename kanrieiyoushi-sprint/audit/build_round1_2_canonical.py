#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / "audit"
R1 = AUDIT / "data/questions.round1.canonical.json"
R2 = AUDIT / "data/questions.round2.canonical.json"
OUT = AUDIT / "data/questions.round1-2.canonical.json"


def main():
    subprocess.check_call([sys.executable, str(AUDIT / "build_round2_canonical.py")])
    if not R1.exists():
        subprocess.check_call([sys.executable, str(AUDIT / "build_round1_canonical.py")])
    r1 = json.loads(R1.read_text(encoding="utf-8"))
    r2 = json.loads(R2.read_text(encoding="utf-8"))
    if len(r1) != 200 or len(r2) != 200:
        raise SystemExit(f"round size mismatch: r1={len(r1)} r2={len(r2)}")
    data = r1 + r2
    ids = [q["id"] for q in data]
    if len(ids) != len(set(ids)):
        raise SystemExit("cross-round duplicate IDs")
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"built {len(data)} questions -> {OUT}")

if __name__ == "__main__":
    main()
