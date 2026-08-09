#!/usr/bin/env python3
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEGACY_JS = [
    ROOT / "questions-121-150.js",
    ROOT / "questions-151-180.js",
    ROOT / "questions-181-210.js",
    ROOT / "questions-211-240.js",
]
EXTRA_JSON = [
    ROOT / "audit/round2-extra-121-140.json",
    ROOT / "audit/round2-extra-141-160.json",
    ROOT / "audit/round2-extra-161-170.json",
    ROOT / "audit/round2-extra-171-180.json",
    ROOT / "audit/round2-extra-181-190.json",
    ROOT / "audit/round2-extra-191-200.json",
]
OUT = ROOT / "audit/data/questions.round2.canonical.json"
RIGHTS = "独自作問。既存過去問本文・選択肢の転載なし。一次資料による事実監査は公開昇格前に実施。"
EXPECTED = {"社会・環境":16,"人体・疾病":26,"食べ物":25,"基礎栄養":14,"応用栄養":16,"栄養教育":13,"臨床栄養":26,"公衆栄養":16,"給食経営":18,"応用力":30}


def read_js_array(path: Path):
    text = path.read_text(encoding="utf-8")
    marker = ".concat(["
    if marker not in text:
        raise ValueError(f"concat JSON array not found: {path}")
    start = text.index(marker) + len(".concat(")
    arr, _ = json.JSONDecoder().raw_decode(text[start:])
    return arr


def legacy_to_canonical(q, idx):
    return {
        "id": f"KNR2-{idx:03d}",
        "round": 2,
        "subject": q["c"],
        "topic": q["t"],
        "question": q["q"],
        "choices": q["a"],
        "correct_index": q["x"],
        "memory_line": q.get("m", ""),
        "short_reason": q.get("r", ""),
        "explanation": q.get("d", ""),
        "source_url": q.get("s", ""),
        "reference_date": q.get("y", "2026-08-09"),
        "source_status": "candidate_from_v04_requires_reaudit",
        "origin_type": "draft_original_pending_source_audit",
        "rights_basis": RIGHTS,
        "audit_status": "candidate_structure",
        "legacy_id": q.get("id"),
    }


def main():
    legacy = []
    for path in LEGACY_JS:
        legacy.extend(read_js_array(path))
    if len(legacy) != 120:
        raise SystemExit(f"legacy candidate count mismatch: {len(legacy)}/120")

    out = [legacy_to_canonical(q, i) for i, q in enumerate(legacy, 1)]
    for path in EXTRA_JSON:
        items = json.loads(path.read_text(encoding="utf-8"))
        out.extend(items)

    if len(out) != 200:
        raise SystemExit(f"round2 count mismatch: {len(out)}/200")
    ids = [q["id"] for q in out]
    if len(ids) != len(set(ids)):
        raise SystemExit("round2 duplicate IDs")
    counts = Counter(q["subject"] for q in out)
    if dict(counts) != EXPECTED:
        raise SystemExit(f"round2 distribution mismatch: {dict(counts)}")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"built round2 {len(out)} questions -> {OUT}")
    print("distribution:", dict(counts))

if __name__ == "__main__":
    main()
