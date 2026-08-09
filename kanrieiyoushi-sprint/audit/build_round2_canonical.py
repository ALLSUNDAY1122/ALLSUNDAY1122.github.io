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
REBALANCE_JSON = [
    ROOT / "audit/round2-rebalance-201-216.json",
    ROOT / "audit/round2-rebalance-217-232.json",
]
OUT = ROOT / "audit/data/questions.round2.canonical.json"
RIGHTS = "独自作問。既存過去問本文・選択肢の転載なし。一次資料による事実監査は公開昇格前に実施。"
EXPECTED = {"社会・環境":16,"人体・疾病":26,"食べ物":25,"基礎栄養":14,"応用栄養":16,"栄養教育":13,"臨床栄養":26,"公衆栄養":16,"給食経営":18,"応用力":30}

# 初回FAILで旧v0.4候補120問の実配分が 7/19/18/5/7/4/19/7/10/24 と判明。
# 新規80問から必要な48問だけ採用し、余剰32問は候補資産として保持する。
SELECTED_EXTRA_IDS = (
    {f"KNR2-{n:03d}" for n in range(121,132)} |
    {f"KNR2-{n:03d}" for n in range(139,146)} |
    {f"KNR2-{n:03d}" for n in range(152,166)} |
    {f"KNR2-{n:03d}" for n in range(173,189)}
)


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

    selected = []
    for path in EXTRA_JSON:
        for q in json.loads(path.read_text(encoding="utf-8")):
            if q["id"] in SELECTED_EXTRA_IDS:
                selected.append(q)
    if len(selected) != 48:
        raise SystemExit(f"selected extra count mismatch: {len(selected)}/48")
    out.extend(selected)

    rebalance = []
    for path in REBALANCE_JSON:
        rebalance.extend(json.loads(path.read_text(encoding="utf-8")))
    if len(rebalance) != 32:
        raise SystemExit(f"rebalance count mismatch: {len(rebalance)}/32")
    out.extend(rebalance)

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
    print("legacy=120 selected_extra=48 rebalance=32 reserved_extra=32")

if __name__ == "__main__":
    main()
