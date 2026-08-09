#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = [
    ROOT / "questions.js",
    ROOT / "data/round1-extra-121-140.js",
    ROOT / "data/round1-extra-141-160.js",
    ROOT / "data/round1-extra-161-180.js",
    ROOT / "data/round1-extra-181-200.js",
]
OUT = ROOT / "audit/data/questions.round1.canonical.json"
RIGHTS = "一次資料の事実関係・数値・制度のみ参照し、問題文・選択肢・解説を独自作成。過去問転載なし。"
QUESTION_TEXT_OVERRIDES = {
    "KN101": "納品された生鮮魚介類を大量調理施設で冷蔵保管する。衛生管理マニュアルに沿う保管温度はどれか。"
}

def read_array(path: Path):
    text = path.read_text(encoding="utf-8")
    if ".concat([" in text:
        start = text.index(".concat([") + len(".concat(")
    elif "=[" in text:
        start = text.index("=[") + 1
    else:
        raise ValueError(f"JSON array not found: {path}")
    arr, _ = json.JSONDecoder().raw_decode(text[start:])
    return arr

def main():
    src = []
    for path in SOURCES:
        src.extend(read_array(path))
    out = []
    for q in src:
        out.append({
            "id": q["id"],
            "round": 1,
            "subject": q["c"],
            "topic": q["t"],
            "question": QUESTION_TEXT_OVERRIDES.get(q["id"], q["q"]),
            "choices": q["a"],
            "correct_index": q["x"],
            "memory_line": q.get("m", ""),
            "short_reason": q.get("r", ""),
            "explanation": q["d"],
            "source_url": q["s"],
            "reference_date": q["y"],
            "origin_type": "original_from_primary_source",
            "rights_basis": RIGHTS,
            "audit_status": q.get("z", "pending"),
        })
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"built {len(out)} questions -> {OUT}")

if __name__ == "__main__":
    main()
