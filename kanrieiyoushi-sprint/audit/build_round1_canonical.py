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
OVERRIDES = {
    "KN101": {
        "question": "納品された生鮮魚介類を大量調理施設で冷蔵保管する。衛生管理マニュアルに沿う保管温度はどれか。"
    },
    "KN141": {
        "question": "くるみを原材料に含む容器包装されたクッキーを販売する。現在のアレルギー表示として最も適切なのはどれか。",
        "choices": ["くるみを特定原材料として表示する", "表示は任意なので省略する", "『ナッツ類』とのみ表示する", "小麦表示だけあればよい", "商品名にくるみと書かなければよい"],
        "correct_index": 0,
        "memory_line": "くるみは特定原材料であり、対象となる加工食品では義務表示の対象。",
        "short_reason": "改正年の暗記ではなく、実際の表示判断として使えることが重要。",
        "explanation": "くるみは特定原材料に追加されており、対象となる容器包装された加工食品では食品表示基準に従ってアレルギー表示を行う。"
    }
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

def formal_id(raw_id: str) -> str:
    if raw_id.startswith("KN") and raw_id[2:].isdigit() and int(raw_id[2:]) >= 121:
        return f"KNR1-{int(raw_id[2:]):03d}"
    return raw_id

def main():
    src = []
    for path in SOURCES:
        src.extend(read_array(path))
    out = []
    for q in src:
        o = OVERRIDES.get(q["id"], {})
        out.append({
            "id": formal_id(q["id"]),
            "round": 1,
            "subject": q["c"],
            "topic": q["t"],
            "question": o.get("question", q["q"]),
            "choices": o.get("choices", q["a"]),
            "correct_index": o.get("correct_index", q["x"]),
            "memory_line": o.get("memory_line", q.get("m", "")),
            "short_reason": o.get("short_reason", q.get("r", "")),
            "explanation": o.get("explanation", q["d"]),
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
