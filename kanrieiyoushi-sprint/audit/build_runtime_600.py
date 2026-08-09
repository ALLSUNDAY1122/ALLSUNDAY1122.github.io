#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / "audit"
CANON = AUDIT / "data/questions.round1-2-3.canonical.json"
OUT = ROOT / "questions600.js"


def main():
    subprocess.check_call([sys.executable, str(AUDIT / "build_round1_2_3_canonical.py")])
    data = json.loads(CANON.read_text(encoding="utf-8"))
    if len(data) != 600:
        raise SystemExit(f"runtime source count mismatch: {len(data)}/600")
    runtime = []
    for q in data:
        runtime.append({
            "id": q["id"], "round": int(q["round"]), "c": q["subject"], "t": q["topic"],
            "q": q["question"], "a": q["choices"], "x": int(q["correct_index"]),
            "m": q.get("memory_line", ""), "r": q.get("short_reason", ""), "d": q.get("explanation", ""),
            "s": q.get("source_url", ""), "y": q.get("reference_date", ""), "z": "approved"
        })
    OUT.write_text("window.KANRI_Q=" + json.dumps(runtime, ensure_ascii=False, separators=(",", ":")) + ";\n", encoding="utf-8")
    print(f"built runtime questions: {len(runtime)} -> {OUT}")
    for r in (1, 2, 3):
        print(f"round{r}=", sum(1 for q in runtime if q["round"] == r))

if __name__ == "__main__":
    main()
